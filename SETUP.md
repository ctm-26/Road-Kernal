# Road Kernel — Build & Run (v0.1)

Target: **iPadOS 17+**, Xcode 15+. The Swift sources live in `RoadKernel/`,
tests in `RoadKernelTests/`. There is no checked-in `.xcodeproj` — it is
generated from `project.yml` so it never drifts or rots.

## Path A — XcodeGen (recommended, one command)

```bash
brew install xcodegen      # once
xcodegen generate          # run from the repo root → creates RoadKernel.xcodeproj
open RoadKernel.xcodeproj
```

Then in Xcode: pick an **iPad simulator** (or your device) and press **⌘R** to run,
**⌘U** to test.

Run tests from the command line instead:

```bash
xcodebuild test \
  -project RoadKernel.xcodeproj \
  -scheme RoadKernel \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)'
```

> Note: `RoadKernel.xcodeproj` is generated and git-ignored — regenerate with
> `xcodegen generate` any time you add files.

## Path B — Manual Xcode project (no XcodeGen install)

1. **File ▸ New ▸ Project ▸ iOS ▸ App.** Name it `RoadKernel`, Interface
   **SwiftUI**, Storage **SwiftData** (or None), Language **Swift**.
2. Set the **iOS Deployment Target to 17.0** and **iPad** under Supported
   Destinations (target ▸ General).
3. Delete the template `ContentView.swift` / generated app file, then drag the
   `RoadKernel/` source folders into the project ("Create groups", add to the
   app target).
4. **Add the location permission key** (this is the #1 crash if missing):
   target ▸ **Info** ▸ add `Privacy - Location When In Use Usage Description`
   = "Road Kernel shows your position on the map and attaches it to traffic
   signals you mark."
5. For tests: **File ▸ New ▸ Target ▸ Unit Testing Bundle**, then add
   `RoadKernelTests/JSONExporterTests.swift` to it.
6. **⌘R** to run, **⌘U** to test.

## What v0.1 does

Full-screen hybrid map, live location dot, **Mark Signal Here** (saves a
`Signal` at your current location), pins you can tap to view/edit/delete, and
**Export** to JSON. Data persists locally via SwiftData.

## Tests

`RoadKernelTests/JSONExporterTests.swift` covers the pure-logic layer that can be
verified without a screen:

- `Signal` defaults and the enum ⇄ raw-string accessors round-trip
- JSON export produces valid, decodable output
- exported coordinates / names / enums survive a full encode→decode round-trip

These are fast logic tests — the kind that stay green as the app grows. UI flows
(map rendering, location prompts) are verified by running on a simulator/device.

> Heads-up: this scaffold was authored on Linux and **could not be compiled
> here**. The code targets the iOS 17 APIs documented in `docs/ARCHITECTURE.md`;
> if the first build surfaces anything, it'll be a minor API/SDK detail, not a
> structural problem.
