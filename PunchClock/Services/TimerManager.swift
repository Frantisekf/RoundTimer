import Foundation
import Combine
import ActivityKit
import UIKit
import UserNotifications

final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published var state = TimerState()
    @Published var totalElapsedTime: Int = 0
    @Published var isMuted: Bool = false

    var liveActivitiesSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private var timer: Timer?
    private var preset: Preset?
    private var phaseEndTime: Date?
    private var startTime: Date?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private let soundManager = SoundManager.shared
    private let hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    let reflexCueManager = ReflexCueManager()

    var currentPreset: Preset? { preset }

    init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncTimeWithRealTime()
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Audio continues in background via AVAudioSession - no notifications needed
        }
    }

    deinit {
        timer?.invalidate()
        endBackgroundTask()
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start(with preset: Preset) {
        self.preset = preset
        state.currentRound = 1
        state.isRunning = true
        startTime = Date()
        totalElapsedTime = 0

        // Skip prepare phase if prepareTime is 0
        if preset.prepareTime > 0 {
            state.phase = .prepare
            state.timeRemaining = preset.prepareTime
        } else {
            state.phase = .round
            state.timeRemaining = preset.roundTime
        }

        phaseEndTime = Date().addingTimeInterval(TimeInterval(state.timeRemaining))

        soundManager.setupAudioSession()
        soundManager.startBackgroundAudio()
        enableScreenAwake(true)
        startTimer()
        reflexCueManager.configure(with: preset)
        startLiveActivity(preset: preset)
        scheduleAllNotifications(preset: preset)
    }

    func pause() {
        state.isRunning = false
        timer?.invalidate()
        timer = nil
        phaseEndTime = nil
        cancelAllNotifications()
        updateLiveActivity()
    }

    func resume() {
        guard state.phase != .idle && state.phase != .finished else { return }
        guard let preset = preset else { return }
        state.isRunning = true
        phaseEndTime = Date().addingTimeInterval(TimeInterval(state.timeRemaining))
        startTimer()
        rescheduleNotificationsFromCurrentState(preset: preset)
        updateLiveActivity()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        phaseEndTime = nil
        state = TimerState()
        reflexCueManager.stop()
        soundManager.stopBackgroundAudio()
        enableScreenAwake(false)
        cancelAllNotifications()
        endLiveActivity()
        endBackgroundTask()
    }

    func togglePauseResume() {
        if state.isRunning {
            pause()
        } else {
            resume()
        }
    }

    func restartCurrentRound() {
        guard let preset = preset else { return }

        switch state.phase {
        case .prepare:
            state.timeRemaining = preset.prepareTime
        case .round:
            state.timeRemaining = preset.roundTime
        case .rest:
            state.timeRemaining = preset.restTime
        default:
            break
        }

        phaseEndTime = Date().addingTimeInterval(TimeInterval(state.timeRemaining))

        if !state.isRunning {
            resume()
        }

        updateLiveActivity()
    }

    func skipPhase() {
        guard let preset = preset else { return }
        state.timeRemaining = 0
        transitionToNextPhase(preset: preset)

        // Auto-resume if paused
        if !state.isRunning && state.phase != .finished {
            resume()
        }
    }

    func addTime(_ seconds: Int) {
        state.timeRemaining += seconds
        if let endTime = phaseEndTime {
            phaseEndTime = endTime.addingTimeInterval(TimeInterval(seconds))
        }
        updateLiveActivity()
    }

    // MARK: - Private Methods

    private func syncTimeWithRealTime() {
        guard state.isRunning, let endTime = phaseEndTime, let preset = preset else { return }

        let remaining = Int(endTime.timeIntervalSince(Date()))

        if remaining > 0 {
            state.timeRemaining = remaining
        } else {
            catchUpPhases(missedSeconds: -remaining, preset: preset)
        }
    }

    /// Advances through phases that elapsed while the app was suspended.
    ///
    /// Internal rather than private so the tests can drive it directly: it is the one
    /// piece of logic here that cannot be exercised through the public surface without
    /// waiting out a real workout.
    ///
    /// Silent by design. A bell marks a transition as it happens; these already happened,
    /// unheard, and ringing one for each would fire the whole backlog at once the moment
    /// someone unlocks their phone — several bells on top of each other for a gap of a few
    /// rounds. The live transitions still ring, in `transitionToNextPhase`.
    func catchUpPhases(missedSeconds: Int, preset: Preset) {
        var secondsToProcess = missedSeconds

        while secondsToProcess > 0 && state.phase != .finished {
            switch state.phase {
            case .prepare:
                state.phase = .round
                state.timeRemaining = preset.roundTime

            case .round:
                if state.currentRound >= preset.numberOfRounds {
                    state.phase = .finished
                    state.isRunning = false
                    state.timeRemaining = 0
                    timer?.invalidate()
                    timer = nil
                    endBackgroundTask()
                    endLiveActivity()
                    return
                } else {
                    state.phase = .rest
                    state.timeRemaining = preset.restTime
                }

            case .rest:
                state.currentRound += 1
                state.phase = .round
                state.timeRemaining = preset.roundTime

            default:
                return
            }

            if secondsToProcess >= state.timeRemaining {
                secondsToProcess -= state.timeRemaining
                state.timeRemaining = 0
            } else {
                state.timeRemaining -= secondsToProcess
                secondsToProcess = 0
            }
        }

        phaseEndTime = Date().addingTimeInterval(TimeInterval(state.timeRemaining))
        updateLiveActivity()
    }

    private func startTimer() {
        timer?.invalidate()
        beginBackgroundTask()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func tick() {
        guard let preset = preset else { return }

        if let start = startTime {
            totalElapsedTime = Int(Date().timeIntervalSince(start))
        }

        handleSoundCues()

        if state.phase == .round {
            reflexCueManager.tick(isMuted: isMuted)
        }

        if state.timeRemaining > 0 {
            state.timeRemaining -= 1
        } else {
            transitionToNextPhase(preset: preset)
        }
    }

    private func handleSoundCues() {
        guard !isMuted else { return }

        switch state.phase {
        case .prepare:
            if state.timeRemaining <= 3 && state.timeRemaining > 0 {
                soundManager.playCountdown()
                hapticLight.impactOccurred()
            }

        case .round:
            // 10 second warning clapper (check at 11 so it plays when display shows 10)
            if state.timeRemaining == 11 {
                soundManager.playClapper()
                hapticMedium.impactOccurred()
            }
            // Final countdown beeps at 3, 2, 1
            if state.timeRemaining <= 3 && state.timeRemaining > 0 {
                soundManager.playCountdown()
                hapticMedium.impactOccurred()
            }

        case .rest:
            // 10 second warning clapper (check at 11 so it plays when display shows 10)
            if state.timeRemaining == 11 {
                soundManager.playClapper()
                hapticMedium.impactOccurred()
            }
            // Countdown beeps at 3, 2, 1
            if state.timeRemaining <= 3 && state.timeRemaining > 0 {
                soundManager.playCountdown()
                hapticLight.impactOccurred()
            }

        default:
            break
        }
    }

    private func transitionToNextPhase(preset: Preset) {
        switch state.phase {
        case .prepare:
            if !isMuted {
                soundManager.playBell()
                hapticHeavy.impactOccurred()
            }
            state.phase = .round
            state.timeRemaining = preset.roundTime
            phaseEndTime = Date().addingTimeInterval(TimeInterval(state.timeRemaining))
            updateLiveActivity()

        case .round:
            reflexCueManager.pauseSpeech()

            if !isMuted {
                soundManager.playBell()
                hapticHeavy.impactOccurred()
            }

            if state.currentRound >= preset.numberOfRounds {
                state.phase = .finished
                state.isRunning = false
                phaseEndTime = nil
                if let start = startTime {
                    totalElapsedTime = Int(Date().timeIntervalSince(start))
                }
                timer?.invalidate()
                timer = nil
                soundManager.stopBackgroundAudio()
                enableScreenAwake(false)
                cancelAllNotifications()
                endBackgroundTask()
                endLiveActivity()
            } else if preset.restTime > 0 {
                // Normal rest period
                state.phase = .rest
                state.timeRemaining = preset.restTime
                phaseEndTime = Date().addingTimeInterval(TimeInterval(state.timeRemaining))
                updateLiveActivity()
            } else {
                // Skip rest if restTime is 0, go straight to next round
                state.currentRound += 1
                state.phase = .round
                state.timeRemaining = preset.roundTime
                phaseEndTime = Date().addingTimeInterval(TimeInterval(state.timeRemaining))
                updateLiveActivity()
            }

        case .rest:
            if !isMuted {
                soundManager.playBell()
                hapticHeavy.impactOccurred()
            }
            state.currentRound += 1
            state.phase = .round
            state.timeRemaining = preset.roundTime
            phaseEndTime = Date().addingTimeInterval(TimeInterval(state.timeRemaining))
            updateLiveActivity()

        default:
            break
        }
    }

    // MARK: - Background Task

    private func beginBackgroundTask() {
        endBackgroundTask()

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Live Activity

    private var currentActivity: Activity<TimerActivityAttributes>?

    private func startLiveActivity(preset: Preset) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TimerActivityAttributes(presetName: preset.name)
        let contentState = TimerActivityAttributes.ContentState(
            phase: state.phase.rawValue,
            endTime: Date().addingTimeInterval(TimeInterval(state.timeRemaining)),
            timeRemaining: state.timeRemaining,
            currentRound: state.currentRound,
            totalRounds: preset.numberOfRounds,
            isRunning: state.isRunning
        )

        do {
            // Set stale date slightly after phase ends so it dims if app is killed
            let staleDate = Date().addingTimeInterval(TimeInterval(state.timeRemaining) + 5)
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: staleDate),
                pushType: nil
            )
        } catch {
            // Live Activity failed to start
        }
    }

    private func updateLiveActivity() {
        guard let activity = currentActivity, let preset = preset else { return }

        let contentState = TimerActivityAttributes.ContentState(
            phase: state.phase.rawValue,
            endTime: Date().addingTimeInterval(TimeInterval(state.timeRemaining)),
            timeRemaining: state.timeRemaining,
            currentRound: state.currentRound,
            totalRounds: preset.numberOfRounds,
            isRunning: state.isRunning
        )

        Task {
            // Update stale date for new phase
            let staleDate = Date().addingTimeInterval(TimeInterval(state.timeRemaining) + 5)
            await activity.update(ActivityContent(state: contentState, staleDate: staleDate))
        }
    }

    private func endLiveActivity() {
        guard let activity = currentActivity, let preset = preset else { return }

        let finalContentState = TimerActivityAttributes.ContentState(
            phase: state.phase.rawValue,
            endTime: Date(),
            timeRemaining: 0,
            currentRound: state.currentRound,
            totalRounds: preset.numberOfRounds,
            isRunning: state.isRunning
        )

        Task {
            await activity.end(
                ActivityContent(state: finalContentState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        currentActivity = nil
    }

    // MARK: - Screen Awake

    private func enableScreenAwake(_ enabled: Bool) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = enabled
        }
    }

    // MARK: - Local Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleAllNotifications(preset: Preset) {
        cancelAllNotifications()

        var currentTime: TimeInterval = 0

        // Prepare phase
        if preset.prepareTime > 0 {
            // Bell at end of prepare
            currentTime += TimeInterval(preset.prepareTime)
            scheduleNotification(at: currentTime, title: "Round 1", body: "Fight!", sound: "bell.m4a")
        }

        // Round and rest phases
        for round in 1...preset.numberOfRounds {
            let roundStart = currentTime

            // 10-second warning during round
            if preset.roundTime > 10 {
                scheduleNotification(at: roundStart + TimeInterval(preset.roundTime - 10), title: "10 seconds", body: "Round \(round) ending soon", sound: "clapper.m4a")
            }

            // Bell at end of round
            currentTime += TimeInterval(preset.roundTime)

            if round < preset.numberOfRounds {
                scheduleNotification(at: currentTime, title: "Rest", body: "Round \(round) complete", sound: "bell.m4a")

                // 10-second warning during rest
                if preset.restTime > 10 {
                    scheduleNotification(at: currentTime + TimeInterval(preset.restTime - 10), title: "10 seconds", body: "Get ready for round \(round + 1)", sound: "clapper.m4a")
                }

                // Bell at end of rest
                currentTime += TimeInterval(preset.restTime)
                scheduleNotification(at: currentTime, title: "Round \(round + 1)", body: "Fight!", sound: "bell.m4a")
            } else {
                // Final round complete
                scheduleNotification(at: currentTime, title: "Workout Complete", body: "All \(preset.numberOfRounds) rounds finished!", sound: "bell.m4a")
            }
        }
    }

    private func scheduleNotification(at timeInterval: TimeInterval, title: String, body: String, sound: String) {
        guard timeInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func rescheduleNotificationsFromCurrentState(preset: Preset) {
        cancelAllNotifications()

        var currentTime: TimeInterval = TimeInterval(state.timeRemaining)

        // Schedule based on current phase
        switch state.phase {
        case .prepare:
            // Bell at end of prepare
            scheduleNotification(at: currentTime, title: "Round 1", body: "Fight!", sound: "bell.m4a")
            currentTime += scheduleRemainingRounds(from: 1, startingAt: currentTime, preset: preset)

        case .round:
            // 10-second warning if still time
            if state.timeRemaining > 10 {
                scheduleNotification(at: currentTime - 10, title: "10 seconds", body: "Round \(state.currentRound) ending soon", sound: "clapper.m4a")
            }
            // Bell at end of current round
            if state.currentRound < preset.numberOfRounds {
                scheduleNotification(at: currentTime, title: "Rest", body: "Round \(state.currentRound) complete", sound: "bell.m4a")
                currentTime += scheduleRemainingRounds(from: state.currentRound, startingAt: currentTime, preset: preset, includeCurrentRoundRest: true)
            } else {
                scheduleNotification(at: currentTime, title: "Workout Complete", body: "All \(preset.numberOfRounds) rounds finished!", sound: "bell.m4a")
            }

        case .rest:
            // 10-second warning if still time
            if state.timeRemaining > 10 {
                scheduleNotification(at: currentTime - 10, title: "10 seconds", body: "Get ready for round \(state.currentRound + 1)", sound: "clapper.m4a")
            }
            // Bell at end of rest
            scheduleNotification(at: currentTime, title: "Round \(state.currentRound + 1)", body: "Fight!", sound: "bell.m4a")
            currentTime += scheduleRemainingRounds(from: state.currentRound + 1, startingAt: currentTime, preset: preset, includeCurrentRoundRest: false)

        default:
            break
        }
    }

    private func scheduleRemainingRounds(from startRound: Int, startingAt baseTime: TimeInterval, preset: Preset, includeCurrentRoundRest: Bool = false) -> TimeInterval {
        var currentTime = baseTime

        for round in startRound...preset.numberOfRounds {
            // Add rest time if needed (for rounds after the first one we're scheduling, or if explicitly including)
            if round > startRound || includeCurrentRoundRest {
                if preset.restTime > 10 {
                    scheduleNotification(at: currentTime + TimeInterval(preset.restTime - 10), title: "10 seconds", body: "Get ready for round \(round)", sound: "clapper.m4a")
                }
                currentTime += TimeInterval(preset.restTime)
                if round > startRound {
                    scheduleNotification(at: currentTime, title: "Round \(round)", body: "Fight!", sound: "bell.m4a")
                }
            }

            // Round warning and end
            if preset.roundTime > 10 {
                scheduleNotification(at: currentTime + TimeInterval(preset.roundTime - 10), title: "10 seconds", body: "Round \(round) ending soon", sound: "clapper.m4a")
            }
            currentTime += TimeInterval(preset.roundTime)

            if round < preset.numberOfRounds {
                scheduleNotification(at: currentTime, title: "Rest", body: "Round \(round) complete", sound: "bell.m4a")
            } else {
                scheduleNotification(at: currentTime, title: "Workout Complete", body: "All \(preset.numberOfRounds) rounds finished!", sound: "bell.m4a")
            }
        }

        return currentTime - baseTime
    }
}
