# Road Kernel

A **private iPadOS map cockpit** — a personal overlay layer on top of Apple Maps
for the roads you actually drive. Not a navigation app. Apple Maps already does
routing, traffic, and satellite imagery; Road Kernel records the things it
*doesn't* remember for you:

- Traffic signals you've personally observed
- Light-timing observations (red/yellow/green samples)
- Private place pins (contacts, houses, useful spots, road notes)

Think of it as a personal **map knowledge graph**: not just coordinates, but
meaning — collected as field data, stored locally, owned by you.

## Status

**v0.1 scaffold + design docs.** The `RoadKernel/` Swift sources implement the
smallest runnable slice (map, location, Mark Signal, pins, detail, JSON export),
with unit tests in `RoadKernelTests/`. The design documents explain the concept,
the fixes for what sank the first build, and the road ahead.

> Authored on Linux — **not yet compiled**. Build it on a Mac with Xcode; see
> [SETUP.md](SETUP.md).

## Build & run

See **[SETUP.md](SETUP.md)** — `xcodegen generate` then open in Xcode, or create
the project manually. v0.1 = one model (`Signal`), one button ("Mark Signal Here").

## Read these in order

1. **[docs/CRITIQUE.md](docs/CRITIQUE.md)** — honest critique: what's strong, the
   real risks (safety, prediction reliability, GPS attribution, scope), and the
   most likely reasons the first build never reached a running state.
2. **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — tech stack, the specific
   build-failure fixes, module/file layout, the phased data model, app modes, the
   timing engine, and privacy/export design.
3. **[docs/ROADMAP.md](docs/ROADMAP.md)** — corrected, deliberately small build
   phases. Every phase must produce a *running* app.

## Tech stack (target)

| Concern        | Choice                                   |
| -------------- | ---------------------------------------- |
| UI             | SwiftUI                                  |
| Map            | MapKit (iOS 17 SwiftUI `Map` API)        |
| Location       | CoreLocation (When-In-Use)               |
| Persistence    | SwiftData (SQLite/GeoJSON at export only) |
| Min deployment | iPadOS 17+                               |
| Network        | None — local-only, no accounts, no cloud |

## Guiding principle

> Do not compete with Apple Maps. Build the layer Apple Maps does not give you —
> and keep the first beast small, named, and fed.
