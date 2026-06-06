import SwiftUI
import MapKit
import SwiftData

/// The single v0.1 screen: full-screen hybrid map, live location, signal pins,
/// and a bottom control panel. One model, one primary button — deliberately small.
struct MapScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Signal.createdAt, order: .reverse) private var signals: [Signal]
    @StateObject private var locationManager = LocationManager()

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedSignal: Signal?
    @State private var exportText: String?

    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            ForEach(signals) { signal in
                Annotation(signal.name.isEmpty ? "Signal" : signal.name,
                           coordinate: signal.coordinate) {
                    SignalPin()
                        .onTapGesture { selectedSignal = signal }
                }
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))   // satellite/hybrid cockpit look
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            ControlPanel(
                signalCount: signals.count,
                canMark: locationManager.location != nil,
                onMarkSignal: markSignalHere,
                onCenter: { camera = .userLocation(fallback: .automatic) },
                onExport: { exportText = makeExportJSON() }
            )
        }
        .overlay(alignment: .top) {
            if locationManager.authorization == .denied {
                authorizationBanner
            }
        }
        .sheet(item: $selectedSignal) { SignalDetailView(signal: $0) }
        .sheet(item: Binding(get: { exportText.map(ExportPayload.init) },
                             set: { exportText = $0?.text })) { payload in
            ExportView(text: payload.text)
        }
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.start()
        }
    }

    private func markSignalHere() {
        guard let coordinate = locationManager.location?.coordinate else { return }
        context.insert(Signal(coordinate: coordinate, source: .manual))
    }

    /// Prefer a signed, verifiable bundle (first step toward the data network);
    /// fall back to plain JSON if the device identity can't be loaded.
    private func makeExportJSON() -> String {
        if let identity = try? KeychainIdentity.loadOrCreate(),
           let json = try? JSONExporter.signedBundleJSON(signals: signals, identity: identity) {
            return json
        }
        return JSONExporter.export(signals: signals)
    }

    private var authorizationBanner: some View {
        Text("Location access is off. Enable it in Settings to mark signals.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
    }
}

/// Wraps the export string so it can drive a `.sheet(item:)`.
private struct ExportPayload: Identifiable {
    let text: String
    var id: String { text }
}

struct SignalPin: View {
    var body: some View {
        Image(systemName: "trafficlight")
            .font(.title2)
            .foregroundStyle(.yellow)
            .padding(6)
            .background(.black.opacity(0.6), in: Circle())
    }
}
