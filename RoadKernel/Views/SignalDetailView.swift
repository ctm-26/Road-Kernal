import SwiftUI
import SwiftData

/// Tap-a-pin detail. Editing the `@Bindable` model mutates SwiftData directly;
/// autosave persists it. v0.2 adds the observation history + suggested confidence.
struct SignalDetailView: View {
    @Bindable var signal: Signal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $signal.name)
                    TextField("Intersection", text: $signal.intersectionName)
                }
                Section("Metadata") {
                    LabeledContent("Confidence", value: signal.confidence.rawValue.capitalized)
                    LabeledContent("Source", value: signal.source.rawValue.capitalized)
                    LabeledContent("Created",
                                   value: signal.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Latitude", value: String(format: "%.6f", signal.latitude))
                    LabeledContent("Longitude", value: String(format: "%.6f", signal.longitude))
                }

                ObservationHistorySection(signalID: signal.id)

                Section("Notes") {
                    TextField("Notes", text: $signal.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button(role: .destructive) {
                        context.delete(signal)
                        dismiss()
                    } label: {
                        Label("Delete Signal", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(signal.name.isEmpty ? "Signal" : signal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        signal.updatedAt = .now
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Observations for one signal, queried by its stable ID. Sample count drives a
/// *suggested* (never overclaimed) confidence.
private struct ObservationHistorySection: View {
    @Query private var observations: [SignalObservation]

    init(signalID: UUID) {
        _observations = Query(
            filter: #Predicate<SignalObservation> { $0.signalID == signalID },
            sort: \.timestamp,
            order: .reverse
        )
    }

    var body: some View {
        Section("Observations") {
            LabeledContent("Samples", value: "\(observations.count)")
            LabeledContent("Suggested confidence",
                           value: ConfidenceHeuristic.suggested(sampleCount: observations.count).rawValue.capitalized)

            if !observations.isEmpty {
                stateBreakdownRow
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            if observations.isEmpty {
                Text("No observations yet. Use Red / Yellow / Green while stopped (passenger).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(observations.prefix(10))) { observation in
                    HStack(spacing: 10) {
                        Circle().fill(observation.observedState.displayColor)
                            .frame(width: 12, height: 12)
                        Text(observation.observedState.displayLabel)
                        Spacer()
                        Text(observation.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Breakdown

    /// Groups observations by state, ordered consistently for the bar.
    private var stateCounts: [(ObservedState, Int)] {
        let grouped = Dictionary(grouping: observations, by: { $0.observedState })
        return ObservedState.allCases.compactMap { state in
            guard let count = grouped[state]?.count, count > 0 else { return nil }
            return (state, count)
        }
    }

    /// Proportional Canvas bar + per-state count chips in one row.
    private var stateBreakdownRow: some View {
        let counts = stateCounts
        let total = observations.count
        return VStack(spacing: 6) {
            // Proportional colour bar drawn with Canvas to avoid GeometryReader in Form.
            Canvas { ctx, size in
                var x: CGFloat = 0
                for (state, count) in counts {
                    let w = size.width * CGFloat(count) / CGFloat(total)
                    let rect = CGRect(x: x, y: 0, width: w, height: size.height)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 0),
                             with: .color(state.displayColor))
                    x += w
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // Per-state dot + count chips.
            HStack(spacing: 12) {
                ForEach(counts, id: \.0.rawValue) { state, count in
                    HStack(spacing: 4) {
                        Circle().fill(state.displayColor).frame(width: 8, height: 8)
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }
}
