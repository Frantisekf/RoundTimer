import SwiftUI

struct ContentView: View {
    @EnvironmentObject var presetStore: PresetStore
    @EnvironmentObject var historyStore: WorkoutHistoryStore
    @ObservedObject private var timerManager = TimerManager.shared
    @State private var selectedPreset: Preset?
    @State private var showingPresetEditor = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var editingPreset: Preset?
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                if timerManager.state.phase == .idle {
                    presetListView
                        .transition(.opacity)
                } else {
                    TimerView(timerManager: timerManager, reflexCueManager: timerManager.reflexCueManager, historyStore: historyStore)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: timerManager.state.phase == .idle)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startTimerFromSiri)) { notification in
            if let presetName = notification.userInfo?["presetName"] as? String,
               let preset = presetStore.presets.first(where: { $0.name == presetName }) {
                timerManager.start(with: preset)
            } else if let firstPreset = presetStore.presets.first {
                timerManager.start(with: firstPreset)
            }
        }
    }

    private var presetListView: some View {
        List {
            Section {
                ForEach(Array(presetStore.presets.enumerated()), id: \.element.id) { index, preset in
                    PresetRow(preset: preset)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.shared.lightTap()
                            selectedPreset = preset
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                presetStore.deletePreset(preset)
                            } label: {
                                Image(systemName: "trash")
                            }

                            Button {
                                editingPreset = preset
                                showingPresetEditor = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .tint(.blue)
                        }
                        .listRowSeparator(.hidden, edges: .top)
                        .listRowSeparator(index == presetStore.presets.count - 1 ? .hidden : .visible, edges: .bottom)
                }
            }

            if settings.showQuotes {
                Section {
                    QuoteView()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button {
                        showingHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Round Timer")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingPreset = nil
                    showingPresetEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
                .environmentObject(historyStore)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingPresetEditor) {
            PresetEditorView(
                preset: editingPreset,
                onSave: { preset in
                    if editingPreset != nil {
                        presetStore.updatePreset(preset)
                    } else {
                        presetStore.addPreset(preset)
                    }
                }
            )
        }
        .sheet(item: $selectedPreset) { preset in
            PresetSetupView(
                preset: preset,
                onStart: { adjustedPreset in
                    selectedPreset = nil
                    // Small delay for sheet dismiss animation to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        timerManager.start(with: adjustedPreset)
                    }
                },
                onCancel: {
                    selectedPreset = nil
                }
            )
        }
    }
}

struct PresetRow: View {
    let preset: Preset

    private var totalWorkoutTime: Int {
        preset.prepareTime + (preset.roundTime * preset.numberOfRounds) + (preset.restTime * max(preset.numberOfRounds - 1, 0))
    }

    private var formattedTotalTime: String {
        let hours = totalWorkoutTime / 3600
        let minutes = (totalWorkoutTime % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Text("\(preset.numberOfRounds) rounds")
                    Text(formatTime(preset.roundTime))
                    Text("\(formatTime(preset.restTime)) rest")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedTotalTime)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs == 0 {
            return "\(minutes)min"
        }
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

struct QuoteView: View {
    private static let quotes: [(quote: String, author: String)] = [
        // Muhammad Ali
        ("Float like a butterfly, sting like a bee.", "Muhammad Ali"),
        ("Champions aren't made in gyms. Champions are made from something deep inside them.", "Muhammad Ali"),
        ("I hated every minute of training, but I said, don't quit. Suffer now and live the rest of your life as a champion.", "Muhammad Ali"),
        ("The fight is won or lost far away from witnesses – behind the lines, in the gym.", "Muhammad Ali"),
        ("To be a great champion you must believe you are the best. If you're not, pretend you are.", "Muhammad Ali"),
        ("You don't lose if you get knocked down; you lose if you stay down.", "Muhammad Ali"),
        ("I am the greatest. I said that even before I knew I was.", "Muhammad Ali"),
        ("He who is not courageous enough to take risks will accomplish nothing in life.", "Muhammad Ali"),

        // Mike Tyson
        ("Everyone has a plan until they get punched in the face.", "Mike Tyson"),
        ("Discipline is doing what you hate to do, but doing it like you love it.", "Mike Tyson"),
        ("I'm a dreamer. I have to dream and reach for the stars.", "Mike Tyson"),

        // Bruce Lee
        ("I fear not the man who has practiced 10,000 kicks once, but I fear the man who has practiced one kick 10,000 times.", "Bruce Lee"),
        ("Be water, my friend.", "Bruce Lee"),
        ("The successful warrior is the average man, with laser-like focus.", "Bruce Lee"),
        ("Adapt what is useful, reject what is useless, and add what is specifically your own.", "Bruce Lee"),

        // Conor McGregor
        ("We're not just here to take part, we're here to take over.", "Conor McGregor"),
        ("There's no talent here, this is hard work. This is an obsession.", "Conor McGregor"),
        ("I stay ready so I don't have to get ready.", "Conor McGregor"),
        ("Doubt is only removed by action.", "Conor McGregor"),

        // Khabib Nurmagomedov
        ("If you work hard, the sky's the limit.", "Khabib Nurmagomedov"),
        ("Humble in victory, humble in defeat.", "Khabib Nurmagomedov"),

        // Rickson Gracie
        ("A brave man, a real fighter is not measured by how many times he falls, but how many times he stands up.", "Rickson Gracie"),
        ("Flow with whatever may happen and let your mind be free.", "Rickson Gracie"),
        ("If you want to be a lion, you must train with lions.", "Rickson Gracie"),
        ("The biggest enemy you have is yourself.", "Rickson Gracie"),
        ("Jiu-jitsu is about waiting for the right time to do the right move.", "Rickson Gracie"),

        // Helio Gracie
        ("Always assume that your opponent is going to be bigger, stronger and faster than you.", "Helio Gracie"),
        ("There is no losing in jiu-jitsu. You either win or you learn.", "Carlos Gracie Sr."),

        // Georges St-Pierre
        ("I'm not impressed by your performance.", "Georges St-Pierre"),
        ("I'm not the best because I beat everyone. I'm the best because I beat myself.", "Georges St-Pierre"),

        // Anderson Silva
        ("I'm not afraid of anyone, but I respect everyone.", "Anderson Silva"),

        // Ronda Rousey
        ("Some people like to call me cocky or arrogant, but I just think, how dare you assume I should think less of myself.", "Ronda Rousey"),

        // Nate Diaz
        ("I'm not surprised, motherfuckers.", "Nate Diaz"),
        ("Don't be scared, homie.", "Nate Diaz"),

        // Classic Boxing
        ("It's not whether you get knocked down, it's whether you get up.", "Vince Lombardi"),
        ("A champion is someone who gets up when they can't.", "Jack Dempsey"),
        ("The hardest battle you'll ever fight is the battle to be yourself.", "Cus D'Amato"),
        ("The more you sweat in training, the less you bleed in combat.", "Richard Marcinko"),
        ("To see a man beaten not by a better opponent but by himself is a tragedy.", "Cus D'Amato"),

        // Other fighters
        ("Hard work and training. There's no secret formula.", "Manny Pacquiao"),
        ("It ain't about how hard you hit. It's about how hard you can get hit and keep moving forward.", "Rocky Balboa"),
        ("The more I train, the luckier I get.", "Sugar Ray Leonard"),

        // Jocko Willink
        ("Discipline equals freedom.", "Jocko Willink"),
        ("Don't expect to be motivated every day. You won't be. Get up and go.", "Jocko Willink"),
        ("The only way to truly fail is to give up.", "Jocko Willink"),
        ("Get after it.", "Jocko Willink"),
        ("Default aggressive.", "Jocko Willink"),
        ("Don't count on motivation. Count on discipline.", "Jocko Willink"),
        ("You have to own everything in your world. That's what it means to be a leader.", "Jocko Willink"),
        ("Hesitation is the enemy. It will kill you.", "Jocko Willink"),

        // David Goggins
        ("You are in danger of living a life so comfortable and soft, that you will die without ever realizing your potential.", "David Goggins"),
        ("We live in a world where mediocrity is often rewarded. Don't buy into that.", "David Goggins"),
        ("When you think you're done, you're only at 40% of your potential.", "David Goggins"),
        ("Suffering is the true test of life.", "David Goggins"),
        ("Stay hard.", "David Goggins"),

        // Stoic Philosophy
        ("We suffer more often in imagination than in reality.", "Seneca"),
        ("He who fears death will never do anything worthy of a living man.", "Seneca"),
        ("No man is free who is not master of himself.", "Epictetus"),
        ("It is not death that a man should fear, but he should fear never beginning to live.", "Marcus Aurelius"),
        ("You have power over your mind, not outside events. Realize this, and you will find strength.", "Marcus Aurelius"),
        ("The obstacle is the way.", "Marcus Aurelius"),
        ("What stands in the way becomes the way.", "Marcus Aurelius"),
        ("First say to yourself what you would be; then do what you have to do.", "Epictetus"),
        ("Difficulties strengthen the mind, as labor does the body.", "Seneca"),
        ("A gem cannot be polished without friction, nor a man perfected without trials.", "Seneca"),

        // More fighters
        ("I don't count my sit-ups. I only start counting when it starts hurting.", "Muhammad Ali"),
        ("Champions keep playing until they get it right.", "Billie Jean King"),
        ("The more you train, the less you bleed.", "Navy SEAL saying"),
        ("Pain is weakness leaving the body.", "U.S. Marines"),
        ("Sweat more in training, bleed less in war.", "Spartan Warrior Creed")
    ]

    @State private var currentQuote: (quote: String, author: String)

    init() {
        _currentQuote = State(initialValue: Self.quotes.randomElement() ?? Self.quotes[0])
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.title3)
                .foregroundStyle(.secondary.opacity(0.4))

            Text(currentQuote.quote)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("— \(currentQuote.author)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                currentQuote = Self.quotes.randomElement() ?? Self.quotes[0]
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PresetStore())
        .environmentObject(WorkoutHistoryStore())
}
