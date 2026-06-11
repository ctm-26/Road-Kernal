import SwiftUI

struct RoadAssetToolbox: View {
    let onDrop: (RoadAssetKind, CGPoint) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RoadAssetKind.allCases) { kind in
                    RoadAssetToolButton(kind: kind, onDrop: onDrop)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

private struct RoadAssetToolButton: View {
    let kind: RoadAssetKind
    let onDrop: (RoadAssetKind, CGPoint) -> Void
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: kind.systemImage)
                .font(.headline)
            Text(kind.label.uppercased())
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(width: 68, height: 52)
        .background(toolColor.opacity(isDragging ? 0.95 : 0.72), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(isDragging ? 0.8 : 0.18), lineWidth: 1))
        .scaleEffect(isDragging ? 1.08 : 1)
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { _ in isDragging = true }
                .onEnded { value in
                    isDragging = false
                    onDrop(kind, value.location)
                }
        )
    }

    private var toolColor: Color {
        switch kind {
        case .signalHead: return .black
        case .stopSign: return .red
        case .yieldSign: return .orange
        case .railroadCrossing: return .purple
        case .laneZone: return .blue
        case .roadMarking: return .gray
        }
    }
}

struct RoadAssetMarker: View {
    let asset: RoadAsset
    let isSelected: Bool
    let isDragging: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                markerShape
                    .fill(assetColor)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                    .shadow(color: assetColor.opacity(0.75), radius: isSelected ? 10 : 5)

                markerShape
                    .stroke(isSelected ? Color.white : Color.black.opacity(0.75), lineWidth: isSelected ? 3 : 2)
                    .frame(width: isSelected ? 48 : 40, height: isSelected ? 48 : 40)

                Image(systemName: asset.kind.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isDragging ? 1.12 : 1)

            if isSelected {
                Text(asset.label.isEmpty ? asset.kind.defaultLabel : asset.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.72), in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isSelected)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isDragging)
    }

    private var markerShape: AnyShape {
        switch asset.kind {
        case .stopSign: return AnyShape(RoundedRectangle(cornerRadius: 8))
        case .yieldSign: return AnyShape(Triangle())
        default: return AnyShape(Circle())
        }
    }

    private var assetColor: Color {
        switch asset.kind {
        case .signalHead: return .yellow
        case .stopSign: return .red
        case .yieldSign: return .orange
        case .railroadCrossing: return .purple
        case .laneZone: return .blue
        case .roadMarking: return .gray
        }
    }
}

struct StopLineAnchorMarker: View {
    let direction: Direction

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
            Image(systemName: directionIcon)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.black)
        }
        .shadow(color: .black.opacity(0.5), radius: 4)
    }

    private var directionIcon: String {
        switch direction {
        case .north: return "arrow.up"
        case .south: return "arrow.down"
        case .east: return "arrow.right"
        case .west: return "arrow.left"
        case .unknown: return "scope"
        }
    }
}

struct RoadAssetDetailSheet: View {
    @Bindable var asset: RoadAsset
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    Picker("Type", selection: $asset.kind) {
                        ForEach(RoadAssetKind.allCases) { kind in
                            Label(kind.label, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    TextField("Label", text: $asset.label)
                        .textInputAutocapitalization(.characters)
                }

                Section("Direction") {
                    Picker("Approach", selection: $asset.direction) {
                        ForEach(Direction.allCases, id: \.rawValue) { direction in
                            Text(direction.rawValue.capitalized).tag(direction)
                        }
                    }
                    Picker("Movement", selection: $asset.movement) {
                        ForEach(Movement.allCases, id: \.rawValue) { movement in
                            Text(movement.rawValue.capitalized).tag(movement)
                        }
                    }
                    Button("Reset Stop-Line Anchor") {
                        asset.resetStopLineForDirection()
                    }
                }

                Section("Zone") {
                    Stepper(value: $asset.zoneRadiusMeters, in: 2...80, step: 1) {
                        LabeledContent("Radius", value: String(format: "%.0f m", asset.zoneRadiusMeters))
                    }
                }

                if asset.kind == .railroadCrossing {
                    Section("Rail Timing") {
                        Stepper(value: $asset.railWarningSeconds, in: 0...120, step: 1) {
                            LabeledContent("Warning", value: String(format: "%.0f s", asset.railWarningSeconds))
                        }
                        Stepper(value: $asset.railGateDownSeconds, in: 0...120, step: 1) {
                            LabeledContent("Gate Down", value: String(format: "%.0f s", asset.railGateDownSeconds))
                        }
                    }
                }

                Section("Notes") {
                    TextField("Lane notes, markings, timing details", text: $asset.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Asset", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(asset.kind.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        asset.updatedAt = .now
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}
