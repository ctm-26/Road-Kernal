import SwiftUI
import SwiftData

/// Searchable list of all marked signals. Complements the map by letting you
/// quickly find, review, or edit a signal by name or intersection without
/// navigating on the map.
struct SignalListView: View {
    @Query(sort: \Signal.updatedAt, order: .reverse) private var signals: [Signal]
    @Query(sort: \SignalObservation.timestamp, order: .reverse) private var observations: [SignalObservation]
    @State private var searchText = ""
    @State private var selectedSignal: Signal?

    private var filtered: [Signal] {
        guard !searchText.isEmpty else { return signals }
        let q = searchText.lowercased()
        return signals.filter {
            $0.name.lowercased().contains(q) ||
            $0.intersectionName.lowercased().contains(q)
        }
    }

    /// Most-recent observed state per signal (observations sorted newest-first).
    private var lastStateByID: [UUID: ObservedState] {
        Dictionary(observations.map { ($0.signalID, $0.observedState) },
                   uniquingKeysWith: { first, _ in first })
    }

    /// Observation count per signal.
    private var countByID: [UUID: Int] {
        Dictionary(grouping: observations, by: { $0.signalID }).mapValues { $0.count }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { signal in
                SignalRow(
                    signal: signal,
                    lastState: lastStateByID[signal.id],
                    observationCount: countByID[signal.id] ?? 0
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedSignal = signal }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .navigationTitle("Signals")
            .searchable(text: $searchText, prompt: "Name or intersection")
            .overlay {
                if signals.isEmpty {
                    ContentUnavailableView(
                        "No Signals Yet",
                        systemImage: "trafficlight",
                        description: Text("Tap \"Mark Signal Here\" on the Map tab while at an intersection.")
                    )
                } else if !searchText.isEmpty && filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .sheet(item: $selectedSignal) { SignalDetailView(signal: $0) }
    }
}

// MARK: - Row

private struct SignalRow: View {
    let signal: Signal
    let lastState: ObservedState?
    let observationCount: Int

    var body: some View {
        HStack(spacing: 12) {
            // Last-state indicator dot (gray when no observations).
            let stateColor = lastState.map { $0 == .unknown ? Color.gray : $0.displayColor } ?? Color.gray.opacity(0.5)
            Circle()
                .fill(stateColor)
                .frame(width: 12, height: 12)
                .shadow(color: stateColor.opacity(0.8), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(signal.name.isEmpty ? "Unnamed Signal" : signal.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if !signal.intersectionName.isEmpty {
                    Text(signal.intersectionName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                ConfidenceBadge(confidence: signal.confidence)
                if observationCount > 0 {
                    Text("\(observationCount) obs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Confidence badge

private struct ConfidenceBadge: View {
    let confidence: Confidence

    var body: some View {
        Text(confidence.rawValue.capitalized)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch confidence {
        case .low:      return .red
        case .medium:   return .yellow
        case .high:     return Theme.Colors.primary
        case .verified: return .blue
        }
    }
}
