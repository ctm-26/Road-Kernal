# Road Kernel — Roadmap

Deliberately small phases. The hard rule, learned from the first attempt:

> **Every phase must produce a *running* app.** If a phase can't be opened and
> used on the iPad, it's too big — cut it down.

This is the antidote to the "feature hydra" that left the repo empty. Keep the
first beast small, named, and fed.

---

## v0.1 — The smallest runnable thing
**Goal:** Open app → see map → follow my location → tap one button to mark a
traffic light. That's it.

- Full-screen MapKit map, `.mapStyle(.hybrid(elevation: .realistic))`.
- Live user-location dot (`UserAnnotation()`), When-In-Use authorization.
- One giant **"Mark Signal Here"** button in a bottom control panel.
- SwiftData `Signal` model — persisted locally.
- Saved signals render as pins.
- Tap a pin → basic detail (coords, created date, notes).
- **Export signals as JSON.**

**Data:** `Signal` only.
**Build walls to clear first:** Info.plist location key, iOS 17 `Map` API,
SwiftData target 17+, `LocationManager` pattern — all in
[ARCHITECTURE.md §1](ARCHITECTURE.md#1-why-the-first-build-failed--and-the-fixes).
**Deliverable:** your own personal signal map exists and survives relaunch.
**Safety:** logging while parked/passenger only.

---

## v0.2 — Observations
**Goal:** record red/yellow/green states with timestamps.

- `SignalObservation` model (stores state, timestamp, lat/lon, speed, heading,
  accuracy).
- RED / YELLOW / GREEN buttons.
- Attach each observation to the nearest signal **with manual confirm** (don't
  silently auto-attach — see
  [CRITIQUE.md §4](CRITIQUE.md#4-gps-attribution-will-misfire)).
- Observation history + sample count on the detail screen.
- `confidence` field surfaced.

**Deliverable:** you can collect timing data.
**Safety:** passenger-only capture until voice/hardware buttons exist.

---

## Phase 3 — Direction & approach
**Goal:** separate northbound / southbound / left-turn data.

- `SignalApproach` model (direction, movement, lane, protected arrow).
- Heading capture; direction + movement selectors.
- Observations link to an approach.

**Deliverable:** the app knows *which* signal phase you observed.

---

## Phase 4 — Timing estimates
**Goal:** basic, honest signal timing.

- Detect state transitions; compute red/green/yellow/cycle durations.
- `SignalTimingEstimate` (averages, sample count, confidence).
- Show on detail screen as **descriptive stats with explicit confidence** —
  never an actionable countdown (see
  [CRITIQUE.md §3](CRITIQUE.md#3-prediction-is-oversold)).

**Deliverable:** the app can describe timing for well-sampled signals.

---

## Phase 5 — Review & cleanup
**Goal:** make the data maintainable long-term.

- Merge duplicate signals / split accidentally-merged ones.
- Rename intersections, delete bad observations, nudge pin locations.
- Export CSV / JSON / **GeoJSON** + SQLite backup.

**Deliverable:** your local signal map stays clean over time.

---

## Phase 6 — Private place / contact layer
**Goal:** add your private map world.

- `Place`, `Person`, `PersonPlaceLink` models with per-pin privacy levels.
- Manual place pins (long-press → add place); contact photo bubbles later.
- **Privacy Mode** — one tap hides all personal info while keeping the map.

**Deliverable:** the map shows your private layer, safely hideable.

---

## Cross-cutting guardrails (every phase)

- **Memory, not advice.** Never present anything as a driving instruction.
- **Passenger-only logging** until voice and hardware-button input exist.
- **Honest confidence** everywhere; "unknown" and "not enough samples" are valid,
  first-class states.
- **Local-only.** No network, accounts, or analytics introduced silently.
- **Export stays current.** Each new model is added to the JSON export in the same
  phase it's introduced — your data is the treasure.

---

## Suggested immediate next step

Scaffold the **v0.1 Xcode project** from
[ARCHITECTURE.md §3](ARCHITECTURE.md#3-module--file-layout-target-xcode-project):
`RoadKernelApp`, `LocationManager`, `Signal`, `MapScreen`, `ControlPanel`,
`SignalDetailView`, `JSONExporter`. One model, one button, runnable.
