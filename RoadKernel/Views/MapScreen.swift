import SwiftUI
import MapKit
import SwiftData
import CoreLocation

/// The main screen: full-screen hybrid map, live location, signal pins, and the
/// control panel. v0.2 adds RED/YELLOW/GREEN observation logging with manual
/// nearest-signal confirmation.
struct MapScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Signal.createdAt, order: .reverse) private var signals: [Signal]
    @Query(sort: \SignalObservation.timestamp, order: .reverse) private var observations: [SignalObservation]
    @StateObject private var locationManager = LocationManager()

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedSignal: Signal?
    @State private var pending: PendingObservation?
    @State private var exportText: String?

    /// Keyed by signalID → most recent observed state. Observations are already
    /// sorted newest-first by the @Query, so first-wins gives the latest state.
    private var lastStateByID: [UUID: ObservedState] {
        Dictionary(observations.map { ($0.signalID, $0.observedState) },
                   uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            ForEach(signals) { signal in
                Annotation(signal.name.isEmpty ? "Signal" : signal.name,
                           coordinate: signal.coordinate) {
                    SignalPin(lastState: lastStateByID[signal.id])
                        .onTapGesture { selectedSignal = signal }
                }
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))   // satellite/hybrid cockpit look
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            ControlPanel(
                signalCount: signals.count,
                hasLocation: locationManager.location != nil,
                onMarkSignal: markSignalHere,
                onLogState: beginLog,
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
        .sheet(item: $pending) { pending in
            LogObservationSheet(
                pending: pending,
                onAttach: { attach(pending, to: $0) },
                onCreateNew: { createSignalAndAttach(pending) }
            )
        }
        .sheet(item: Binding(get: { exportText.map(ExportPayload.init) },
                             set: { exportText = $0?.text })) { payload in
            ExportView(text: payload.text)
        }
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.start()
        }
    }

    // MARK: - Actions

    private func markSignalHere() {
        guard let coordinate = locationManager.location?.coordinate else { return }
        context.insert(Signal(coordinate: coordinate, source: .manual))
    }

    private func beginLog(_ state: ObservedState) {
        guard let coordinate = locationManager.location?.coordinate else { return }
        pending = PendingObservation(
            state: state,
            location: locationManager.location,
            coordinate: coordinate,
            candidates: SignalMatcher.candidates(near: coordinate, in: signals)
        )
    }

    private func attach(_ pending: PendingObservation, to signal: Signal) {
        let observation: SignalObservation
        if let location = pending.location {
            observation = SignalObservation(signalID: signal.id, state: pending.state, location: location)
        } else {
            observation = SignalObservation(signalID: signal.id, state: pending.state,
                                            coordinate: pending.coordinate)
        }
        context.insert(observation)
    }

    private func createSignalAndAttach(_ pending: PendingObservation) {
        let signal = Signal(coordinate: pending.coordinate, source: .observed)
        context.insert(signal)
        attach(pending, to: signal)
    }

    /// Prefer a signed, verifiable bundle (first step toward the data network);
    /// fall back to plain JSON if the device identity can't be loaded.
    private func makeExportJSON() -> String {
        if let identity = try? KeychainIdentity.loadOrCreate(),
           let json = try? JSONExporter.signedBundleJSON(signals: signals,
                                                          observations: observations,
                                                          identity: identity) {
            return json
        }
        return JSONExporter.export(signals: signals, observations: observations)
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
    var lastState: ObservedState? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "trafficlight")
                .font(.title2)
                .foregroundStyle(.yellow)
                .padding(6)
                .background(.black.opacity(0.6), in: Circle())
            if let state = lastState, state != .unknown {
                Circle()
                    .fill(state.displayColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: state.displayColor, radius: 5)
                    .offset(x: 2, y: -2)
            }
        }
    }
}
