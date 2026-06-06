import SwiftUI
import SwiftData

/// Tap-a-pin detail. Editing the `@Bindable` model mutates SwiftData directly;
/// autosave persists it. Review-mode actions (merge/split) arrive in a later phase.
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
