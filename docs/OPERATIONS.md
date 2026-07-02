# Operability Design — running Road Kernel better

Design for making the app reliable to build, run, and use in the car. Four
tracks, each with concrete changes, effort (S/M/L), and why it matters. A
recommended build order is at the end.

---

## Track 1 — Build / CI reliability  *(highest value)*

**Problem:** nothing compiles until you're on a Mac. The `import UIKit` bug sat
undetected because there's no automated build. Every change is a gamble.

**Design:** a GitHub Actions workflow on a macOS runner that reproduces your
local steps on every push/PR to `claude/road-kernel-project-*`.

- `.github/workflows/ci.yml`, runner `macos-14` (Xcode 15 / iOS 17 SDK).
- Steps: `brew install xcodegen` → `xcodegen generate` →
  `xcodebuild build` for an **iPhone** simulator **and** an **iPad** simulator →
  `xcodebuild test` (runs `RoadKernelTests`).
- Building both destinations catches device-family / API-availability breaks;
  the pure unit tests (crypto, telemetry, matcher, settings) run green in CI.
- **Won't cover:** MultipeerConnectivity pairing (needs real devices) and GPS —
  those stay manual. CI proves *it compiles and the logic tests pass*, which is
  exactly the gap today.
- Optional add-on (S): SwiftLint step for style, with a lenient `.swiftlint.yml`.

**Effort:** S–M. **Payoff:** every future change is checked automatically; the
PR shows a green/red check. This is the single biggest quality-of-life win.

---

## Track 2 — On-device driving setup

**Problem:** the app isn't yet practical to actually run while driving — screen
sleeps, the link doesn't recover, and the controller stops in the background.

**Design (code):**
- **Keep-awake (S):** `isIdleTimerDisabled = true` while telemetry is live, via a
  small `.keepAwake(_:)` view modifier bound to `hub.connectionStatus`.
- **Auto-reconnect (M):** when the session drops to `.notConnected` but the user
  hasn't disconnected, the link re-advertises/re-browses with backoff instead of
  going idle. Add a `shouldStayConnected` flag + a retry timer in `TelemetryLink`.
- **Background controller (M):** the iPhone must keep sending GPS with the app
  backgrounded/screen-off. Requires `UIBackgroundModes: [location]` +
  `allowsBackgroundLocationUpdates = true` on the controller's `LocationManager`.
  ⚠️ This has battery and App-Store-review implications — opt-in, controller-only.
- **Remember last role/source + auto-start (S):** persist role in `SettingsStore`;
  optional "auto-connect on launch" toggle so it's one-glance, zero-tap.
- **Landscape lock for dashboard (S):** iPad dashboard prefers landscape.

**Design (physical, non-code):**
- Two mounts (iPhone near the driver as controller/sensor, iPad as dashboard).
- MultipeerConnectivity uses Bluetooth + peer-to-peer Wi-Fi, so it **doesn't need
  a shared router** — but both devices still need Wi-Fi + Bluetooth **on** and the
  Local Network permission granted. Document this.

**Effort:** M overall. **Payoff:** the difference between a demo and something you
can leave running on a drive.

---

## Track 3 — In-app diagnostics

**Problem:** the current Debug disclosure shows an event log but not *health*.
When something's off mid-drive you can't tell if it's GPS, the link, or the data.

**Design:** a dedicated **Diagnostics** view (promote the debug panel) showing:
- **Link:** state, connected peer + verified fingerprint, sent/received counts,
  decode-failure count.
- **GPS:** authorization, seconds since last fix, horizontal accuracy, whether
  speed/heading are real vs unknown.
- **Rate:** live samples/sec (sanity-check the stream is flowing).
- **Export:** a share-sheet button dumping the event log + counters as text.

Instrumentation: add counters to `TelemetryLink` (`sent`, `received`,
`decodeFailures`) and a small sample-rate calc in `TelemetryHub`.

**Effort:** M. **Payoff:** you diagnose "why is the dashboard blank" in seconds
instead of guessing.

---

## Track 4 — Dashboard UX polish

**Problem:** it's readable, but not tuned for glancing at speed while moving.

**Design:**
- **Live "focus" mode (S):** when connected, hide the role picker/controls and
  enlarge the primary metric; tap once to reveal controls. Less chrome, less
  temptation to fiddle.
- **Primary-metric emphasis (S):** speed dominates; secondary values smaller.
- **High-contrast + bigger type (S):** legibility in sunlight; larger gauge digits.
- **Optional day/night (M):** currently dark-only; add a light high-contrast theme
  and auto-switch, or leave dark and just maximize contrast.
- **Reduce taps (S):** overlaps with Track 2 auto-start.

**Effort:** S–M. **Payoff:** safer, faster to read; feels finished.

---

## Recommended build order
1. **Track 1 (CI)** — buildable right now without a Mac; protects everything after it.
2. **Track 2 quick wins** — keep-awake + remember role/auto-start (both S).
3. **Track 3 diagnostics** — makes Track 2's harder bits (auto-reconnect, background) debuggable.
4. **Track 2 auto-reconnect + background location.**
5. **Track 4 UX polish** — once the plumbing is trustworthy.

Each is independent and shippable on its own; nothing here adds a dependency
(CI uses Homebrew XcodeGen; SwiftLint is optional).
