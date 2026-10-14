import SwiftUI

struct WatchTimerView: View {
    @ObservedObject var timerManager: WatchTimerManager

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
        case .rest, .finished:
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

    var body: some View {
        if timerManager.state.phase == .finished {
            finishedView
        } else {
            timerView
        }
    }

    private var timerView: some View {
        ZStack {
            phaseGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: timerManager.state.phase)

            VStack(spacing: 4) {
                Spacer()

                Text(timerManager.state.phaseDisplayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))

                Text(timerManager.state.formattedTime)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                if let preset = timerManager.currentPreset {
                    Text("Round \(timerManager.state.currentRound)/\(preset.numberOfRounds)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Fixed 3-button layout - always same positions
                HStack {
                    Button {
                        timerManager.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        timerManager.togglePauseResume()
                    } label: {
                        Image(systemName: timerManager.state.isRunning ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        timerManager.skipPhase()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .opacity(timerManager.state.phase == .prepare || timerManager.state.phase == .rest ? 1 : 0)
                    }
                    .buttonStyle(.plain)
                    .disabled(timerManager.state.phase == .round)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .navigationBarHidden(true)
    }

    private var finishedView: some View {
        ZStack {
            phaseGradient
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)

                Text("Done!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(formattedTotalTime)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                if let preset = timerManager.currentPreset {
                    Text("\(preset.numberOfRounds) rounds")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Button {
                    timerManager.stop()
                } label: {
                    Text("OK")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    private var formattedTotalTime: String {
        let total = timerManager.totalElapsedTime
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    let manager = WatchTimerManager()
    manager.start(with: .boxingStandard)
    return WatchTimerView(timerManager: manager)
}
