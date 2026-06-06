import SwiftUI

/// The bottom cockpit panel: large, high-contrast buttons. RED/YELLOW/GREEN log
/// an observed state (passenger-only per the low-touch safety design); the
/// primary "Mark Signal Here" action is oversized.
struct ControlPanel: View {
    let signalCount: Int
    let hasLocation: Bool
    let onMarkSignal: () -> Void
    let onLogState: (ObservedState) -> Void
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

            HStack(spacing: 12) {
                stateButton(.red, "Red")
                stateButton(.yellow, "Yellow")
                stateButton(.green, "Green")
            }

            Button(action: onMarkSignal) {
                Label("Mark Signal Here", systemImage: "trafficlight")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
            }
            .buttonStyle(PanelButtonStyle(tint: .yellow, prominent: true))
            .disabled(!hasLocation)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }

    private func stateButton(_ state: ObservedState, _ title: String) -> some View {
        Button { onLogState(state) } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .buttonStyle(PanelButtonStyle(tint: state.displayColor, prominent: true))
        .disabled(!hasLocation)
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
