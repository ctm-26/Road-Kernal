# Road Kernel — Architecture

Tech stack, the concrete fixes for the build walls, module layout, the phased
data model, app modes, the timing engine, and privacy/export design.

---

## 1. Why the first build failed — and the fixes

These are the standard walls a first SwiftUI + MapKit + CoreLocation + SwiftData
app hits. Any one of them stops you cold; together they explain an empty repo.
Cross-check against your failed attempt — odds are it was one or more of these,
on top of the scope problem from [CRITIQUE.md](CRITIQUE.md#5-scope--the-real-reason-it-failed).

### 1.1 Missing location usage description → instant crash
If `NSLocationWhenInUseUsageDescription` is absent from Info.plist, the app
**crashes the moment** you call `requestWhenInUseAuthorization()`. This is the #1
first-app crash and looks like "it just dies on launch."

**Fix:** add to Info.plist (Target ▸ Info, or Info.plist source):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Road Kernel shows your position on the map and attaches it to signals you mark.</string>
```
Add `NSLocationAlwaysAndWhenInUseUsageDescription` only if/when you add background
location later (not in v0.1).

### 1.2 iOS 17 MapKit SwiftUI rewrite → won't compile
MapKit's SwiftUI API was rewritten in iOS 17. Most tutorials still use the
deprecated `Map(coordinateRegion:)` / `MapAnnotation`, which mix badly with the
new API and produce confusing compile errors.

**Fix — use the new API:**
```swift
import SwiftUI
import MapKit

struct MapScreen: View {
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            // Annotation("Signal", coordinate: signal.coordinate) { SignalPin() }
        }
        .mapStyle(.hybrid(elevation: .realistic)) // satellite/hybrid cockpit look
    }
}
```
Key new names: `Map(position:)`, `MapCameraPosition`, `UserAnnotation()`,
`Annotation` / `Marker`, `.mapStyle(.hybrid(...))`.

### 1.3 SwiftData availability mismatch
`@Model`, `ModelContainer`, and `@Query` require **iOS 17 + Xcode 15**. A
deployment target below 17 (or an older Xcode) breaks the build with availability
errors.

**Fix:** set the iPadOS deployment target to **17.0+**.

### 1.4 LocationManager pitfalls
CoreLocation requires a delegate object with specific shape; getting it wrong
yields "no location updates" or silent failure.

**Fix — the canonical pattern:**
```swift
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()        // strong reference — required
    @Published var location: CLLocation?
    @Published var authorization: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func request() { manager.requestWhenInUseAuthorization() }  // triggers prompt
    func start()   { manager.startUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        authorization = m.authorizationStatus
        if authorization == .authorizedWhenInUse { m.startUpdatingLocation() }
    }
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        location = locs.last
    }
}
```
Pitfalls this avoids: not retaining the manager, not setting the delegate before
requesting, requesting off the main thread, and forgetting to publish updates.

### 1.5 The scope wall
Even with every API correct, building all tables/modes/prediction at once never
runs. **Fix = the v0.1 slice:** one model (`Signal`), one button. See
[ROADMAP.md](ROADMAP.md).

---

## 2. Tech stack & deployment

- **UI:** SwiftUI, SwiftUI app lifecycle (`@main App`).
- **Map:** MapKit (iOS 17 `Map` API), `.mapStyle(.hybrid(elevation: .realistic))`.
- **Location:** CoreLocation, **When-In-Use** authorization (preferred for
  privacy and battery; background not needed in v0.1).
- **Persistence:** SwiftData; `.modelContainer(for:)` on the root scene.
- **Min deployment:** iPadOS 17.0+.
- **Network:** none. No accounts, no analytics, no cloud sync in v0.1.

---

## 3. Module / file layout (target Xcode project)

```
RoadKernel/
├─ RoadKernelApp.swift          // @main App, .modelContainer(for: [Signal.self])
├─ Location/
│  └─ LocationManager.swift     // CLLocationManager wrapper (see §1.4)
├─ Models/
│  ├─ Signal.swift              // v0.1
│  ├─ SignalObservation.swift   // v0.2
│  ├─ SignalApproach.swift      // phase 3
│  ├─ SignalTimingEstimate.swift// phase 4
│  ├─ Place.swift               // phase 6
│  ├─ Person.swift              // phase 6
│  └─ PersonPlaceLink.swift     // phase 6
├─ Views/
│  ├─ MapScreen.swift           // full-screen Map + pins + UserAnnotation
│  ├─ ControlPanel.swift        // big bottom buttons ("Mark Signal Here")
│  └─ SignalDetailView.swift    // tap-a-pin detail
├─ Export/
│  └─ JSONExporter.swift        // v0.1; GeoJSON / SQLite backup later
└─ Support/
   └─ Enums.swift               // Confidence, Source, Direction, Movement, ObservedState
```
Architecture is light MVVM: `LocationManager` (observable), SwiftData models as
the store, SwiftUI views querying via `@Query`.

---

## 4. Data model — introduced by phase (NOT all at once)

Every model carries the shared traceability fields:
`id: UUID`, `createdAt`, `updatedAt`, `source: Source`, `confidence: Confidence`,
`notes: String`.

### Shared enums (`Support/Enums.swift`)
```swift
enum Source: String, Codable { case manual, imported, observed, estimated }
enum Confidence: String, Codable { case low, medium, high, verified }
enum Direction: String, Codable { case north, south, east, west, unknown } // bound direction
enum Movement: String, Codable { case straight, left, right, uTurn, pedestrian, unknown }
enum ObservedState: String, Codable { case red, yellow, green, greenArrow, redArrow, unknown }
```

### v0.1 — `Signal` (the only model that ships first)
```swift
import SwiftData
import CoreLocation

@Model
final class Signal {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var name: String
    var intersectionName: String
    var createdAt: Date
    var updatedAt: Date
    var confidenceRaw: String   // Confidence
    var sourceRaw: String       // Source
    var notes: String

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
    init(coordinate: CLLocationCoordinate2D, source: Source = .manual) {
        self.id = UUID()
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.name = ""; self.intersectionName = ""
        self.createdAt = .now; self.updatedAt = .now
        self.confidenceRaw = Confidence.low.rawValue
        self.sourceRaw = source.rawValue
        self.notes = ""
    }
}
```

### v0.2 — `SignalObservation`
`signalId`, `timestamp`, `observedState`, `latitude/longitude`, `speed`,
`heading`, `horizontalAccuracy` (+ shared fields). One row per RED/YELLOW/GREEN
tap. Store accuracy/speed/heading so a later pass can re-attribute bad samples
(see [CRITIQUE.md §4](CRITIQUE.md#4-gps-attribution-will-misfire)).

### Phase 3 — `SignalApproach`
`signalId`, `direction`, `movement`, `laneDescription`, `hasProtectedArrow`.
Lets a single intersection hold multiple phases (NB straight, NB left, …).
Observations gain an optional `approachId`.

### Phase 4 — `SignalTimingEstimate`
Derived: `signalId`, optional `approachId`, `avgRed`, `avgGreen`, `avgYellow`,
`avgCycle`, `sampleCount`, `confidence`. Descriptive only — see
[CRITIQUE.md §3](CRITIQUE.md#3-prediction-is-oversold).

### Phase 6 — `Place`, `Person`, `PersonPlaceLink`
Private place/contact layer with `privacyLevel`
(`publicLooking / personal / private / hidden`) and relation types
(`livesHere / worksHere / familyHome / friendHome / business / memory / unknown`).

---

## 5. App modes & the speed soft-gate

- **v0.1 ships ONE screen** (map + bottom control panel). Modes are a later layer
  — do not build the mode system before the map runs.
- Eventual modes: **Drive** (read-only, huge "mark later"), **Stopped**
  (passenger logging), **Review** (edit/merge/export), plus **Debug**
  (GPS accuracy/heading/speed/nearest-signal radius).
- **Speed soft-gate:** when GPS speed is above a threshold, hide advanced
  controls. Treat it as *advisory only* — GPS speed is noisy and a passenger may
  be operating the iPad. It is never a hard safety guarantee. See
  [CRITIQUE.md §2](CRITIQUE.md#2-the-central-risk-safety--liability).

---

## 6. Timing engine (phase 4+, out of v0.1/v0.2)

1. From ordered observations, detect state transitions and compute red/green/
   yellow durations and full-cycle length (timestamp math — no AI).
2. Aggregate into averages + sample counts → `SignalTimingEstimate`.
3. Confidence from: number of samples, recency, cycle consistency, and
   time-of-day / weekday match. Surface as words ("likely," "low confidence,"
   "not enough samples"), never a precise actionable countdown.

---

## 7. Privacy & export

- **Local-only:** no server, no analytics, no account, no cloud by default.
- **Privacy Mode:** one tap hides the contact/place layer (names, photos, home
  pins, notes) while keeping the normal map — mandatory for the contact layer
  because the iPad is physically visible in the car.
- **Sensitive categories** (treat with care): home addresses, contact photos,
  relationship notes, frequent locations, medical/VA locations.
- **Export:** JSON in v0.1 (your data is the treasure). GeoJSON (for other
  mapping tools) and a SQLite backup later. Per-pin privacy levels.
- **Later:** Face ID / passcode to open, encrypted backup, "delete recent
  location trail," "panic clean view."

---

## 8. Next step

This document is written so the **v0.1 Xcode project is unambiguous to scaffold**:
the file layout (§3), the four build-wall fixes (§1), and the `Signal` model (§4)
are everything needed for the first runnable slice. The phased
[ROADMAP.md](ROADMAP.md) defines what to build, in what order, with each phase
yielding a running app.
