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
    @Query(sort: \RoadAsset.updatedAt, order: .reverse) private var roadAssets: [RoadAsset]
    @StateObject private var locationManager = LocationManager()

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedSignalID: UUID?
    @State private var selectedAssetID: UUID?
    @State private var draggingSignalID: UUID?
    @State private var draggingAssetID: UUID?
    @State private var draggingStopLineAssetID: UUID?
    @State private var editingAsset: RoadAsset?
    @State private var pending: PendingObservation?
    @State private var exportText: String?

    /// Keyed by signalID -> most likely current state. Single taps are noisy, so
    /// the marker waits for a few captures and then uses the strongest recent pattern.
    private var inferredStateByID: [UUID: ObservedState] {
        Dictionary(grouping: observations, by: { $0.signalID }).compactMapValues { samples in
            SignalStateInference.inferredState(from: Array(samples.prefix(5)))
        }
    }

    private var isDraggingMapItem: Bool {
        draggingSignalID != nil || draggingAssetID != nil || draggingStopLineAssetID != nil
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: isDraggingMapItem ? [] : .all) {
                UserAnnotation()

                ForEach(roadAssets) { asset in
                    MapCircle(center: asset.coordinate, radius: asset.zoneRadiusMeters)
                        .foregroundStyle(assetZoneColor(asset).opacity(0.14))
                        .stroke(assetZoneColor(asset).opacity(0.68), lineWidth: selectedAssetID == asset.id ? 2 : 1)

                    Annotation("Stop line", coordinate: asset.stopLineCoordinate, anchor: .center) {
                        StopLineAnchorMarker(direction: asset.direction)
                            .onTapGesture {
                                selectedAssetID = asset.id
                                selectedSignalID = nil
                            }
                            .gesture(stopLineDragGesture(for: asset, proxy: proxy))
                    }

                    Annotation(asset.label.isEmpty ? asset.kind.defaultLabel : asset.label,
                               coordinate: asset.coordinate,
                               anchor: .center) {
                        RoadAssetMarker(asset: asset,
                                        isSelected: selectedAssetID == asset.id,
                                        isDragging: draggingAssetID == asset.id)
                            .onTapGesture {
                                selectedAssetID = asset.id
                                selectedSignalID = nil
                                editingAsset = asset
                            }
                            .gesture(assetDragGesture(for: asset, proxy: proxy))
                    }
                }

                ForEach(signals) { signal in
                    Annotation(signal.name.isEmpty ? "Signal" : signal.name,
                               coordinate: signal.coordinate,
                               anchor: .center) {
                        SignalPin(
                            name: signal.name,
                            inferredState: inferredStateByID[signal.id],
                            isSelected: selectedSignalID == signal.id,
                            isDragging: draggingSignalID == signal.id
                        )
                        .onTapGesture {
                            selectedSignalID = signal.id
                            selectedAssetID = nil
                        }
                        .gesture(signalDragGesture(for: signal, proxy: proxy))
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    RoadAssetToolbox { kind, point in
                        dropAsset(kind, at: point, proxy: proxy)
                    }

                    if locationManager.authorization == .denied {
                        authorizationBanner
                    }
                    if let selectedSignal {
                        selectedSignalBanner(selectedSignal)
                    }
                    if let selectedAsset {
                        selectedAssetBanner(selectedAsset)
                    }
                }
                .padding(.top, 8)
            }
        }
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
        .sheet(item: $editingAsset) { asset in
            RoadAssetDetailSheet(asset: asset) {
                context.delete(asset)
                selectedAssetID = nil
                editingAsset = nil
            }
        }
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

    private var selectedSignal: Signal? {
        guard let selectedSignalID else { return nil }
        return signals.first { $0.id == selectedSignalID }
    }

    private var selectedAsset: RoadAsset? {
        guard let selectedAssetID else { return nil }
        return roadAssets.first { $0.id == selectedAssetID }
    }

    // MARK: - Actions

    private func markSignalHere() {
        guard let coordinate = locationManager.location?.coordinate else { return }
        let signal = Signal(coordinate: coordinate, source: .manual)
        signal.name = SignalNameFormatter.fallbackName(for: coordinate)
        context.insert(signal)
        selectedSignalID = signal.id
        selectedAssetID = nil
        refreshName(for: signal, at: coordinate)
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
        selectedSignalID = signal.id
        selectedAssetID = nil
    }

    private func createSignalAndAttach(_ pending: PendingObservation) {
        let signal = Signal(coordinate: pending.coordinate, source: .observed)
        signal.name = SignalNameFormatter.fallbackName(for: pending.coordinate)
        context.insert(signal)
        refreshName(for: signal, at: pending.coordinate)
        attach(pending, to: signal)
    }

    private func dropAsset(_ kind: RoadAssetKind, at point: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(point, from: .global) else { return }
        let asset = RoadAsset(kind: kind, coordinate: coordinate)
        context.insert(asset)
        selectedAssetID = asset.id
        selectedSignalID = nil
        editingAsset = asset
    }

    private func move(_ signal: Signal, to coordinate: CLLocationCoordinate2D) {
        signal.latitude = coordinate.latitude
        signal.longitude = coordinate.longitude
        signal.updatedAt = .now
        selectedSignalID = signal.id
        selectedAssetID = nil
    }

    private func move(_ asset: RoadAsset, to coordinate: CLLocationCoordinate2D) {
        asset.move(to: coordinate)
        selectedAssetID = asset.id
        selectedSignalID = nil
    }

    private func moveStopLine(_ asset: RoadAsset, to coordinate: CLLocationCoordinate2D) {
        asset.stopLineLatitude = coordinate.latitude
        asset.stopLineLongitude = coordinate.longitude
        asset.updatedAt = .now
        selectedAssetID = asset.id
        selectedSignalID = nil
    }

    private func finishMoving(_ signal: Signal) {
        draggingSignalID = nil
        refreshName(for: signal, at: signal.coordinate)
    }

    private func finishMovingAsset() {
        draggingAssetID = nil
        draggingStopLineAssetID = nil
    }

    private func signalDragGesture(for signal: Signal, proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .global) else { return }
                draggingSignalID = signal.id
                move(signal, to: coordinate)
            }
            .onEnded { _ in finishMoving(signal) }
    }

    private func assetDragGesture(for asset: RoadAsset, proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .global) else { return }
                draggingAssetID = asset.id
                move(asset, to: coordinate)
            }
            .onEnded { _ in finishMovingAsset() }
    }

    private func stopLineDragGesture(for asset: RoadAsset, proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .global) else { return }
                draggingStopLineAssetID = asset.id
                moveStopLine(asset, to: coordinate)
            }
            .onEnded { _ in finishMovingAsset() }
    }

    private func refreshName(for signal: Signal, at coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        Task {
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks?.first,
                  let name = SignalNameFormatter.condensedName(from: placemark) else { return }
            await MainActor.run {
                signal.name = name
                signal.intersectionName = name
                signal.updatedAt = .now
            }
        }
    }

    /// Prefer a signed, verifiable bundle (first step toward the data network);
    /// fall back to plain JSON if the device identity can't be loaded.
    private func makeExportJSON() -> String {
        if let identity = try? KeychainIdentity.loadOrCreate(),
           let json = try? JSONExporter.signedBundleJSON(signals: signals,
                                                          observations: observations,
                                                          roadAssets: roadAssets,
                                                          identity: identity) {
            return json
        }
        return JSONExporter.export(signals: signals, observations: observations, roadAssets: roadAssets)
    }

    private var authorizationBanner: some View {
        Text("Location access is off. Enable it in Settings to mark signals.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
    }

    private func selectedSignalBanner(_ signal: Signal) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
            Text(signal.name.isEmpty ? "SELECTED SIGNAL" : signal.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("HOLD + DRAG")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal)
    }

    private func selectedAssetBanner(_ asset: RoadAsset) -> some View {
        HStack(spacing: 10) {
            Image(systemName: asset.kind.systemImage)
            Text(asset.label.isEmpty ? asset.kind.defaultLabel : asset.label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("ANCHOR + ZONE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Button("Edit") { editingAsset = asset }
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal)
    }

    private func assetZoneColor(_ asset: RoadAsset) -> Color {
        switch asset.kind {
        case .signalHead: return .yellow
        case .stopSign: return .red
        case .yieldSign: return .orange
        case .railroadCrossing: return .purple
        case .laneZone: return .blue
        case .roadMarking: return .white
        }
    }
}

/// Wraps the export string so it can drive a `.sheet(item:)`.
private struct ExportPayload: Identifiable {
    let text: String
    var id: String { text }
}

private enum SignalStateInference {
    static func inferredState(from observations: [SignalObservation], minimumSamples: Int = 3) -> ObservedState? {
        guard observations.count >= minimumSamples else { return nil }
        let counts = Dictionary(grouping: observations, by: { $0.observedState }).mapValues(\.count)
        return observations
            .map(\.observedState)
            .max { lhs, rhs in (counts[lhs] ?? 0) < (counts[rhs] ?? 0) }
    }
}

struct SignalPin: View {
    var name: String
    var inferredState: ObservedState? = nil
    var isSelected = false
    var isDragging = false

    private var fillColor: Color {
        inferredState?.displayColor ?? .gray.opacity(0.72)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: isSelected ? 54 : 46, height: isSelected ? 54 : 46)
                    .shadow(color: fillColor.opacity(inferredState == nil ? 0.3 : 0.85), radius: isSelected ? 12 : 7)

                Circle()
                    .strokeBorder(isSelected ? .white : .black.opacity(0.75), lineWidth: isSelected ? 4 : 3)
                    .frame(width: isSelected ? 58 : 50, height: isSelected ? 58 : 50)

                Image(systemName: inferredState == nil ? "trafficlight" : "circle.fill")
                    .font(inferredState == nil ? .title3 : .caption)
                    .foregroundStyle(inferredState == nil ? .yellow : .white.opacity(0.92))
            }
            .scaleEffect(isDragging ? 1.14 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isSelected)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isDragging)

            if isSelected {
                Text(name.isEmpty ? "SIGNAL" : name)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.72), in: Capsule())
            }
        }
        .contentShape(Rectangle())
    }
}
