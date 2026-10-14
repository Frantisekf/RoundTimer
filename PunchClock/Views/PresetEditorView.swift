import SwiftUI

struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let preset: Preset?
    let onSave: (Preset) -> Void

    @State private var name: String = ""
    @State private var prepareMinutes: Int = 0
    @State private var prepareSeconds: Int = 10
    @State private var roundMinutes: Int = 3
    @State private var roundSeconds: Int = 0
    @State private var restMinutes: Int = 1
    @State private var restSeconds: Int = 0
    @State private var numberOfRounds: Int = 12
    @State private var reflexEnabled: Bool = false
    @State private var reflexIntensity: ReflexIntensity = .medium
    @State private var reflexCategories: Set<ReflexCueCategory> = Set(ReflexCueCategory.allCases)

    private var isEditing: Bool { preset != nil }

    @Environment(\.verticalSizeClass) var verticalSizeClass

    private var pickerHeight: CGFloat {
        verticalSizeClass == .compact ? 60 : 80
    }

    private var prepareTime: Int { prepareMinutes * 60 + prepareSeconds }
    private var roundTime: Int { roundMinutes * 60 + roundSeconds }
    private var restTime: Int { restMinutes * 60 + restSeconds }

    private var totalWorkoutTime: Int {
        prepareTime + (roundTime * numberOfRounds) + (restTime * max(numberOfRounds - 1, 0))
    }

    private var formattedTotalTime: String {
        let hours = totalWorkoutTime / 3600
        let minutes = (totalWorkoutTime % 3600) / 60
        let seconds = totalWorkoutTime % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Preset Name", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    if name.isEmpty {
                        Text("Enter a name to save")
                            .foregroundStyle(.red)
                    }
                }

                Section("Rounds") {
                    Stepper("\(numberOfRounds) rounds", value: $numberOfRounds, in: 1...99)
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
                savePreset()
            } label: {
                VStack(spacing: 2) {
                    Text("Save Preset")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(formattedTotalTime)
                        .font(.subheadline)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
            .background(Color.orange)
            .disabled(name.isEmpty)
            .opacity(name.isEmpty ? 0.5 : 1.0)
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let preset = preset {
                    name = preset.name
                    prepareMinutes = preset.prepareTime / 60
                    prepareSeconds = preset.prepareTime % 60
                    roundMinutes = preset.roundTime / 60
                    roundSeconds = preset.roundTime % 60
                    restMinutes = preset.restTime / 60
                    restSeconds = preset.restTime % 60
                    numberOfRounds = preset.numberOfRounds
                    reflexEnabled = preset.reflexEnabled
                    reflexIntensity = preset.reflexIntensity
                    reflexCategories = preset.reflexCategories
                }
            }
        }
    }

    private func savePreset() {
        let newPreset = Preset(
            id: preset?.id ?? UUID(),
            name: name,
            prepareTime: max(prepareTime, 5),
            roundTime: max(roundTime, 10),
            restTime: max(restTime, 5),
            numberOfRounds: numberOfRounds,
            reflexEnabled: reflexEnabled,
            reflexIntensity: reflexIntensity,
            reflexCategories: reflexCategories
        )

        onSave(newPreset)
        dismiss()
    }
}

#Preview {
    PresetEditorView(preset: nil, onSave: { _ in })
}
