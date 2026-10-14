import SwiftUI

struct PresetSetupView: View {
    let preset: Preset
    let onStart: (Preset) -> Void
    let onCancel: () -> Void

    @State private var rounds: Int
    @State private var roundMinutes: Int
    @State private var roundSeconds: Int
    @State private var restMinutes: Int
    @State private var restSeconds: Int
    @State private var prepareMinutes: Int
    @State private var prepareSeconds: Int
    @State private var reflexEnabled: Bool
    @State private var reflexIntensity: ReflexIntensity
    @State private var reflexCategories: Set<ReflexCueCategory>

    init(preset: Preset, onStart: @escaping (Preset) -> Void, onCancel: @escaping () -> Void) {
        self.preset = preset
        self.onStart = onStart
        self.onCancel = onCancel

        _rounds = State(initialValue: preset.numberOfRounds)
        _roundMinutes = State(initialValue: preset.roundTime / 60)
        _roundSeconds = State(initialValue: preset.roundTime % 60)
        _restMinutes = State(initialValue: preset.restTime / 60)
        _restSeconds = State(initialValue: preset.restTime % 60)
        _prepareMinutes = State(initialValue: preset.prepareTime / 60)
        _prepareSeconds = State(initialValue: preset.prepareTime % 60)
        _reflexEnabled = State(initialValue: preset.reflexEnabled)
        _reflexIntensity = State(initialValue: preset.reflexIntensity)
        _reflexCategories = State(initialValue: preset.reflexCategories)
    }

    private var prepareTime: Int { prepareMinutes * 60 + prepareSeconds }

    @Environment(\.verticalSizeClass) var verticalSizeClass

    private var pickerHeight: CGFloat {
        verticalSizeClass == .compact ? 60 : 80
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Rounds") {
                        Stepper("\(rounds) rounds", value: $rounds, in: 1...99)
                    }

                    Section {
                        HStack {
                            Picker("Minutes", selection: $roundMinutes) {
                                ForEach(0...10, id: \.self) { minute in
                                    Text("\(minute) min").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)

                            Picker("Seconds", selection: $roundSeconds) {
                                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { second in
                                    Text("\(second) sec").tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                        .frame(height: pickerHeight)
                    } header: {
                        Label("Round", systemImage: "flame.fill")
                            .foregroundStyle(.red)
                    }

                    Section {
                        HStack {
                            Picker("Minutes", selection: $restMinutes) {
                                ForEach(0...5, id: \.self) { minute in
                                    Text("\(minute) min").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)

                            Picker("Seconds", selection: $restSeconds) {
                                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { second in
                                    Text("\(second) sec").tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                        .frame(height: pickerHeight)
                    } header: {
                        Label("Rest", systemImage: "pause.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Section {
                        HStack {
                            Picker("Minutes", selection: $prepareMinutes) {
                                ForEach(0...2, id: \.self) { minute in
                                    Text("\(minute) min").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)

                            Picker("Seconds", selection: $prepareSeconds) {
                                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { second in
                                    Text("\(second) sec").tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                        .frame(height: pickerHeight)
                    } header: {
                        Label("Prepare", systemImage: "clock")
                            .foregroundStyle(.yellow)
                    }

                    Section {
                        Toggle("Reflex Training", isOn: $reflexEnabled)

                        if reflexEnabled {
                            Picker("Intensity", selection: $reflexIntensity) {
                                ForEach(ReflexIntensity.allCases, id: \.self) { intensity in
                                    Text(intensity.displayName).tag(intensity)
                                }
                            }

                            ForEach(ReflexCueCategory.allCases, id: \.self) { category in
                                Toggle(category.displayName, isOn: Binding(
                                    get: { reflexCategories.contains(category) },
                                    set: { enabled in
                                        if enabled {
                                            reflexCategories.insert(category)
                                        } else if reflexCategories.count > 1 {
                                            reflexCategories.remove(category)
                                        }
                                    }
                                ))
                            }
                        }
                    } header: {
                        Label("Reflex Training", systemImage: "bolt.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Button {
                    HapticManager.shared.mediumTap()
                    let adjustedPreset = Preset(
                        id: preset.id,
                        name: preset.name,
                        prepareTime: prepareTime,
                        roundTime: roundMinutes * 60 + roundSeconds,
                        restTime: restMinutes * 60 + restSeconds,
                        numberOfRounds: rounds,
                        reflexEnabled: reflexEnabled,
                        reflexIntensity: reflexIntensity,
                        reflexCategories: reflexCategories
                    )
                    onStart(adjustedPreset)
                } label: {
                    VStack(spacing: 2) {
                        Text("Start Timer")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(totalTimeFormatted)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }
                .background(Color.green)
            }
            .navigationTitle(preset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private var totalTimeFormatted: String {
        let roundTime = roundMinutes * 60 + roundSeconds
        let restTime = restMinutes * 60 + restSeconds
        let total = prepareTime + (roundTime * rounds) + (restTime * max(rounds - 1, 0))

        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    PresetSetupView(
        preset: .boxingStandard,
        onStart: { _ in },
        onCancel: { }
    )
}
