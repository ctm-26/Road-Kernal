import SwiftUI

/// The bottom cockpit panel: large, high-contrast buttons. The primary action
/// ("Mark Signal Here") is oversized per the low-touch safety design.
struct ControlPanel: View {
    let signalCount: Int
    let canMark: Bool
    let onMarkSignal: () -> Void
    let onCenter: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onCenter) {
                    Label("Center", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PanelButtonStyle(tint: .blue))

                Button(action: onExport) {
                    Label("Export (\(signalCount))", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PanelButtonStyle(tint: .gray))
                .disabled(signalCount == 0)
            }

            Button(action: onMarkSignal) {
                Label("Mark Signal Here", systemImage: "trafficlight")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
            }
            .buttonStyle(PanelButtonStyle(tint: .yellow, prominent: true))
            .disabled(!canMark)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}

struct PanelButtonStyle: ButtonStyle {
    var tint: Color
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, prominent ? 0 : 14)
            .foregroundStyle(prominent ? .black : .white)
            .background(
                tint.opacity(configuration.isPressed ? 0.6 : (prominent ? 1 : 0.85)),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}
