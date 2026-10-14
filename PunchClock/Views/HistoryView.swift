import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyStore: WorkoutHistoryStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.records.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !historyStore.records.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                historyStore.clearHistory()
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No Workouts Yet")
                .font(.headline)

            Text("Complete a workout to see it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyListView: some View {
        List {
            Section {
                statsRow
            }

            Section("Recent Workouts") {
                ForEach(historyStore.records) { record in
                    WorkoutRecordRow(record: record)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                historyStore.deleteRecord(record)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            StatBox(title: "Workouts", value: "\(historyStore.totalWorkouts)")
            StatBox(title: "This Week", value: "\(historyStore.thisWeekWorkouts)")
            StatBox(title: "Total Time", value: historyStore.formattedTotalTime)
        }
        .padding(.vertical, 8)
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutRecordRow: View {
    let record: WorkoutRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(record.presetName)
                        .font(.headline)

                    if record.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(record.formattedTime)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(record.roundsCompleted)/\(record.totalRounds) rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .environmentObject(WorkoutHistoryStore())
}
