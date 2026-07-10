# Road Kernel

A **privacy-first iPadOS map cockpit and companion telemetry system** for the roads you actually use.

Road Kernel is not intended to replace Apple Maps. Routing, traffic, and satellite imagery already exist. The project explores the layer a general navigation product does not provide: personally observed road infrastructure, field notes, timing samples, local telemetry, and verifiable exports owned by the person collecting them.

## Project status

**Active prototype.**

The repository contains Swift source, unit tests, XcodeGen configuration, architecture and risk documentation, setup instructions, and operational diagnostics. The project was authored from Linux and still requires full compilation and device validation on a Mac with Xcode.

> Source present does not equal field-ready. Until the Xcode and on-device validation gates pass, treat this as an engineering prototype rather than a production or safety-critical system.

## What the system currently explores

### Personal road-knowledge layer

- Full-screen MapKit interface with CoreLocation tracking
- Manually placed traffic signals and editable signal details
- RED, YELLOW, and GREEN observation logging
- Manual nearest-signal confirmation rather than silent attribution
- Observation history and suggested confidence based on sample count
- Road-asset placement for signals, signs, rail crossings, lane or marking zones, and stop-line anchors
- JSON export of field data

### Verifiable local data

- Per-install signing identity stored through the Keychain
- Content-addressed, signed records
- Merkle-parent links between observations and their source signals
- Signed export bundles with verification support
- Local-first design with no account or cloud requirement

This is a verifiable data-network foundation, not a blockchain. The goal is provenance and tamper evidence without creating public surveillance infrastructure.

### Companion telemetry

- One application with iPhone controller and iPad dashboard roles
- GPS and deterministic mock telemetry sources
- OBD source slot and stub for future BLE, ELM327, PID, or CAN work
- Local peer transport through MultipeerConnectivity
- Signed pairing proofs so peers demonstrate possession of their device identity
- Connection status, event logs, failure surfacing, and an in-app debug panel

The OBD source is architectural scaffolding only. It does not yet decode live vehicle data.

## Engineering evidence

The repository is organized to make design claims inspectable:

- Unit tests for models, export behavior, signing, pairing, matching, and related pure logic
- A deliberately phased roadmap in which every phase must produce a running application
- An explicit critique of scope, safety, GPS attribution, reliability, and likely failure modes
- Setup and running guides with expected results and troubleshooting steps
- No hidden cloud service or account dependency

## Build and validation

Start with:

1. **[SETUP.md](SETUP.md)** for XcodeGen or manual Xcode project creation.
2. **[docs/RUNNING.md](docs/RUNNING.md)** for role, mock-data, pairing, and diagnostic test flows.

Typical XcodeGen path:

```bash
brew install xcodegen
xcodegen generate
open RoadKernel.xcodeproj
```

Run the unit-test target in Xcode before attempting paired-device flows.

## Documentation map

Read these in order:

1. **[docs/CRITIQUE.md](docs/CRITIQUE.md)**: what is strong, what is risky, and why earlier versions failed to become a running product.
2. **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**: stack, module boundaries, data model, app modes, and privacy design.
3. **[docs/ROADMAP.md](docs/ROADMAP.md)**: deliberately small build phases and validation gates.
4. **[docs/NETWORK.md](docs/NETWORK.md)**: signed, content-addressed records, provenance, and the privacy firewall.
5. **[docs/RUNNING.md](docs/RUNNING.md)**: concrete setup, test flows, expected behavior, and diagnostics.

## Technical stack

| Concern | Choice |
| --- | --- |
| User interface | SwiftUI |
| Mapping | MapKit, iOS 17 SwiftUI `Map` API |
| Location | CoreLocation, When-In-Use permission |
| Persistence | SwiftData |
| Cryptography | CryptoKit and Keychain-backed identity |
| Local transport | MultipeerConnectivity |
| Project generation | XcodeGen |
| Minimum target | iPadOS and iOS 17+ |
| Cloud dependency | None |

## Explicit boundaries

- Road Kernel is not a navigation or traffic-prediction product.
- It must not encourage interaction while driving; field input requires a safe interaction design and real-world testing.
- Suggested confidence is not verified truth.
- GPS proximity does not prove that an observation belongs to a particular signal; confirmation remains manual.
- The OBD source does not yet connect to an adapter or decode vehicle frames.
- Signed data proves origin and integrity, not correctness.
- Source and tests have not yet passed the full Mac, Xcode, simulator, and paired-device validation sequence.

## Guiding principle

> Do not compete with Apple Maps. Build the layer Apple Maps does not give you, preserve user ownership, and keep every build phase small enough to verify.

## AI-assisted engineering disclosure

AI tools assisted with architecture exploration, implementation, testing, critique, and documentation. The repository deliberately preserves limitations and validation gaps. Claims should be evaluated against the source, tests, and actual device results rather than agent confidence or commit volume.

## License

No license has been selected yet. Until one is added, the source remains all-rights-reserved by default.
