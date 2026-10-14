import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct PunchClockWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.3))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: phaseIcon(for: context.state.phase))
                            .foregroundStyle(phaseColor(for: context.state.phase))
                        Text(phaseName(for: context.state.phase))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Text("Round")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(context.state.currentRound)/\(context.state.totalRounds)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    if context.state.isRunning && context.state.endTime > Date() {
                        Text(context.state.endTime, style: .timer)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    } else if !context.state.isRunning {
                        Text(formatTime(context.state.timeRemaining))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    } else {
                        Text("0:00")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.presetName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !context.state.isRunning {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: phaseIcon(for: context.state.phase))
                    .foregroundStyle(phaseColor(for: context.state.phase))
            } compactTrailing: {
                if context.state.isRunning && context.state.endTime > Date() {
                    Text(context.state.endTime, style: .timer)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .foregroundStyle(phaseColor(for: context.state.phase))
                        .frame(width: 42)
                        .fixedSize()
                } else if !context.state.isRunning {
                    Text(formatTime(context.state.timeRemaining))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                        .frame(width: 42)
                        .fixedSize()
                } else {
                    Text("0:00")
                        .monospacedDigit()
                        .foregroundStyle(phaseColor(for: context.state.phase))
                        .frame(width: 42)
                        .fixedSize()
                }
            } minimal: {
                Image(systemName: phaseIcon(for: context.state.phase))
                    .foregroundStyle(phaseColor(for: context.state.phase))
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: phaseIcon(for: context.state.phase))
                        .foregroundStyle(phaseColor(for: context.state.phase))
                    Text(phaseName(for: context.state.phase))
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text("Round \(context.state.currentRound)/\(context.state.totalRounds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if context.state.isRunning && context.state.endTime > Date() {
                    Text(context.state.endTime, style: .timer)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                } else if !context.state.isRunning {
                    Text(formatTime(context.state.timeRemaining))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Text("0:00")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }

            Text(context.attributes.presetName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func phaseIcon(for phase: String) -> String {
        switch phase {
        case "prepare": return "clock.badge.exclamationmark"
        case "round": return "flame.fill"
        case "rest": return "pause.circle.fill"
        case "finished": return "checkmark.circle.fill"
        default: return "timer"
        }
    }

    private func phaseColor(for phase: String) -> Color {
        switch phase {
        case "prepare": return .yellow
        case "round": return .red
        case "rest": return .green
        case "finished": return .blue
        default: return .gray
        }
    }

    private func phaseName(for phase: String) -> String {
        switch phase {
        case "prepare": return "Get Ready"
        case "round": return "Fight!"
        case "rest": return "Rest"
        case "finished": return "Done"
        default: return "Timer"
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

@available(iOS 17.0, *)
#Preview("Notification", as: .content, using: TimerActivityAttributes(presetName: "Boxing Standard")) {
   PunchClockWidgetLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState(phase: "prepare", endTime: Date().addingTimeInterval(10), timeRemaining: 10, currentRound: 1, totalRounds: 12, isRunning: true)
    TimerActivityAttributes.ContentState(phase: "round", endTime: Date().addingTimeInterval(180), timeRemaining: 180, currentRound: 5, totalRounds: 12, isRunning: true)
    TimerActivityAttributes.ContentState(phase: "rest", endTime: Date().addingTimeInterval(60), timeRemaining: 60, currentRound: 5, totalRounds: 12, isRunning: false)
}
