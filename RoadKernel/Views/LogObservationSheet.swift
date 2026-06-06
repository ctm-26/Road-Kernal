import SwiftUI
import CoreLocation

/// In-flight observation awaiting the user's choice of which signal it belongs to.
/// Not persisted — it only carries what the confirmation sheet needs.
struct PendingObservation: Identifiable {
    let id = UUID()
    let state: ObservedState
    let location: CLLocation?
    let coordinate: CLLocationCoordinate2D
    let candidates: [Signal]
}

/// Manual nearest-signal confirmation. We never silently auto-attach an
/// observation (docs/CRITIQUE.md §4): the user confirms the signal or creates a
/// new one here.
struct LogObservationSheet: View {
    let pending: PendingObservation
    let onAttach: (Signal) -> Void
    let onCreateNew: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Circle().fill(pending.state.displayColor).frame(width: 22, height: 22)
                        Text("Logging \(pending.state.displayLabel)").font(.headline)
                    }
                }

                if pending.candidates.isEmpty {
                    Section {
                        Text("No known signal nearby.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Attach to which signal?") {
                        ForEach(pending.candidates) { signal in
                            Button {
                                onAttach(signal)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(signal.name.isEmpty ? "Unnamed signal" : signal.name)
                                    Text(String(format: "%.0f m away",
                                                SignalMatcher.distance(from: pending.coordinate, to: signal)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        onCreateNew()
                        dismiss()
                    } label: {
                        Label("Create new signal here & attach", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Confirm Signal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
