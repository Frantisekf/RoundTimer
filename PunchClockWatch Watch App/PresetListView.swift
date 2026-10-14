import SwiftUI

struct PresetListView: View {
    @EnvironmentObject var presetStore: WatchPresetStore
    @ObservedObject var timerManager: WatchTimerManager

    var body: some View {
        List {
            ForEach(presetStore.presets) { preset in
                Button {
                    timerManager.start(with: preset)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name)
                            .font(.headline)

                        HStack(spacing: 6) {
                            Label(formatTime(preset.roundTime), systemImage: "flame.fill")
                                .foregroundStyle(.red)
                            Label(formatTime(preset.restTime), systemImage: "pause.circle")
                                .foregroundStyle(.green)
                            Label("\(preset.numberOfRounds)", systemImage: "repeat")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.carousel)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs == 0 {
            return "\(minutes)m"
        }
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

#Preview {
    NavigationStack {
        PresetListView(timerManager: WatchTimerManager())
            .environmentObject(WatchPresetStore())
    }
}
