import SwiftUI

struct TimerView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var reflexCueManager: ReflexCueManager
    var historyStore: WorkoutHistoryStore
    @Environment(\.colorScheme) var colorScheme
    @State private var workoutSaved = false
    @State private var showFinishedAnimation = false

    private var phaseGradient: LinearGradient {
        switch timerManager.state.phase {
        case .idle:
            return LinearGradient(
                colors: [Color.gray.opacity(0.8), Color.gray],
                startPoint: .top,
                endPoint: .bottom
            )
        case .prepare:
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.65, blue: 0.0),
                    Color(red: 0.95, green: 0.75, blue: 0.1),
                    Color(red: 0.90, green: 0.70, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .round:
            return LinearGradient(
                colors: [
                    Color(red: 0.7, green: 0.1, blue: 0.1),
                    Color(red: 0.9, green: 0.2, blue: 0.2),
                    Color(red: 0.75, green: 0.15, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .rest:
            return LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.55, blue: 0.3),
                    Color(red: 0.2, green: 0.75, blue: 0.4),
                    Color(red: 0.15, green: 0.65, blue: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .finished:
            return LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.55, blue: 0.3),
                    Color(red: 0.2, green: 0.75, blue: 0.4),
                    Color(red: 0.15, green: 0.65, blue: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var formattedElapsedTime: String {
        let total = timerManager.totalElapsedTime
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            phaseGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: timerManager.state.phase)

            if timerManager.state.phase == .finished {
                finishedView
                    .onAppear {
                        saveWorkoutIfNeeded()
                    }
            } else {
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        if timerManager.currentPreset?.reflexEnabled == true {
                            Button {
                                reflexCueManager.toggle()
                            } label: {
                                Image(systemName: reflexCueManager.isEnabled ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(reflexCueManager.isEnabled ? "Disable reflex cues" : "Enable reflex cues")
                        }
                        Button {
                            timerManager.isMuted.toggle()
                        } label: {
                            Image(systemName: timerManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(timerManager.isMuted ? "Unmute" : "Mute")
                        .accessibilityHint(timerManager.isMuted ? "Turns sounds and haptics on" : "Turns sounds and haptics off")
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                    }

                    Spacer()

                    Text(timerManager.state.phaseDisplayName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))

                    if let cueText = reflexCueManager.currentCueText {
                        Text(cueText.uppercased())
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(Color(red: 1.0, green: 0.8, blue: 0.3))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cueText)
                    }

                    Text(timerManager.state.formattedTime)
                        .font(.system(size: 120, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if let preset = timerManager.currentPreset {
                        RoundProgressView(
                            currentRound: timerManager.state.currentRound,
                            totalRounds: preset.numberOfRounds,
                            phase: timerManager.state.phase
                        )
                        .padding(.horizontal, 40)
                    }

                    Spacer()

                    controlsView
                        .padding(.bottom, 50)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }

    private var finishedView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(formattedElapsedTime)
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .scaleEffect(showFinishedAnimation ? 1.0 : 0.8)
                .opacity(showFinishedAnimation ? 1.0 : 0.0)

            if let preset = timerManager.currentPreset {
                Text("\(preset.numberOfRounds) rounds")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 8)
                    .opacity(showFinishedAnimation ? 1.0 : 0.0)
            }

            Spacer()

            Button {
                HapticManager.shared.mediumTap()
                timerManager.stop()
            } label: {
                Text("Done")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
            .opacity(showFinishedAnimation ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showFinishedAnimation = true
            }
        }
        .onDisappear {
            showFinishedAnimation = false
        }
    }

    private var controlsView: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                if timerManager.state.phase == .prepare ||
                   timerManager.state.phase == .round ||
                   timerManager.state.phase == .rest {
                    Button {
                        HapticManager.shared.lightTap()
                        timerManager.restartCurrentRound()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Restart phase")
                    .accessibilityHint("Restarts the current \(timerManager.state.phase.rawValue) phase from the beginning")
                }

                if timerManager.state.phase == .prepare ||
                   timerManager.state.phase == .rest {
                    Button {
                        HapticManager.shared.lightTap()
                        timerManager.skipPhase()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Skip phase")
                    .accessibilityHint("Skips the current \(timerManager.state.phase.rawValue) phase and moves to the next")
                }

                if timerManager.state.phase == .rest {
                    Button {
                        HapticManager.shared.lightTap()
                        timerManager.addTime(20)
                    } label: {
                        Text("+20s")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Add 20 seconds")
                    .accessibilityHint("Adds 20 seconds of extra rest time")
                }
            }

            HStack(spacing: 32) {
                Button {
                    HapticManager.shared.mediumTap()
                    timerManager.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Stop")
                .accessibilityHint("Stops the timer and returns to preset list")

                if timerManager.state.phase != .finished {
                    Button {
                        HapticManager.shared.mediumTap()
                        timerManager.togglePauseResume()
                    } label: {
                        Image(systemName: timerManager.state.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                            .frame(width: 88, height: 88)
                            .background(Color.white.opacity(0.25))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(timerManager.state.isRunning ? "Pause" : "Resume")
                    .accessibilityHint(timerManager.state.isRunning ? "Pauses the timer" : "Resumes the timer")
                }
            }
        }
    }
}

struct RoundProgressView: View {
    let currentRound: Int
    let totalRounds: Int
    let phase: TimerPhase

    var body: some View {
        VStack(spacing: 12) {
            Text("Round \(currentRound) of \(totalRounds)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private var progressPercentage: CGFloat {
        guard totalRounds > 0 else { return 0 }
        return CGFloat(currentRound) / CGFloat(totalRounds)
    }
}

// MARK: - Private Methods

extension TimerView {
    private func saveWorkoutIfNeeded() {
        guard !workoutSaved, let preset = timerManager.currentPreset else { return }

        // Save to local history
        let record = WorkoutRecord(
            presetName: preset.name,
            totalTime: timerManager.totalElapsedTime,
            roundsCompleted: timerManager.state.currentRound,
            totalRounds: preset.numberOfRounds
        )
        historyStore.addRecord(record)

        workoutSaved = true
    }
}

#Preview {
    TimerManager.shared.start(with: .boxingStandard)
    return TimerView(timerManager: TimerManager.shared, reflexCueManager: TimerManager.shared.reflexCueManager, historyStore: WorkoutHistoryStore())
}
