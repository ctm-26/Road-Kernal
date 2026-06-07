# Running Road Kernel (build + telemetry flow)

## Prerequisites
- macOS with Xcode 15+ (iOS 17 SDK).
- XcodeGen: `brew install xcodegen`.

## Generate the project and run
```bash
cd Road-Kernal
xcodegen generate          # writes RoadKernel.xcodeproj (and RoadKernel/Info.plist)
open RoadKernel.xcodeproj
```
In Xcode: pick the **RoadKernel** scheme → choose an iPhone or iPad → Run (⌘R).
Run tests with ⌘U.

**Expected on launch:** a dark app with three tabs — **Map**, **Telemetry**, **Settings**.

## Test 1 — Mock dashboard (one device, no pairing)
1. **Settings** tab → Telemetry source → **Mock**.
2. **Telemetry** tab → **Start Mock**.
3. Expected: status badge shows **Mock**; the Speed and RPM gauges animate and the
   Gear/Throttle/Brake/Fuel/Lap cards update. No network needed.

## Test 2 — Role switch
- On the **Telemetry** tab the **Dashboard / Controller** segmented control is enabled
  while disconnected. iPhone defaults to Controller, iPad to Dashboard; either can be
  switched. The view swaps between the full dashboard and the compact controller.

## Test 3 — iPhone ↔ iPad pairing (two real devices)
Use two real devices on the **same Wi‑Fi** (see simulator note below).
1. Settings → source **GPS** on both.
2. **iPad**: Telemetry → role **Dashboard** → **Connect to Controller**.
3. **iPhone**: Telemetry → role **Controller** → **Start Broadcasting**.
4. Approve the **Local Network** prompt on both, and the **Location** prompt on the iPhone.
5. Expected: badge goes **Searching… → Connected**, a green **“Verified peer · <id>”**
   badge appears, and the iPad dashboard shows the iPhone’s live speed/heading. The
   **Debug** panel logs `Advertising / Found verified peer / Invited / Accepted / Connected`.

## Failure states are visible (not silent)
- The status badge turns **red “Error”** on failure; the line under the header shows the
  latest event, and the **Debug** disclosure shows the full activity log.
- An **unverified** peer is logged as `Ignored unverified peer` / `Rejected unverified
  invitation` rather than silently connecting.

## Troubleshooting
| Symptom | Cause / fix |
|---|---|
| Badge red “Error”, log says *Advertising/Browsing failed* | Local Network permission denied. iOS **Settings → Privacy & Security → Local Network → Road Kernel** = on, then relaunch. |
| Stuck on **Searching…** | Both devices must be on the same Wi‑Fi, both started, with **one Controller and one Dashboard**. |
| Log shows *Ignored unverified peer* | The peer didn’t present a valid signed proof — both devices must be running this build. |
| Pairing won’t work on Simulator | MultipeerConnectivity over local network is unreliable between simulators; use **two real devices**. Mock mode works fine on a simulator. |
| Location/speed shows `—` on the controller | GPS needs a real fix; in Simulator set **Features → Location**, or test outdoors. |

## Notes
- The device signing key is created automatically in the Keychain on first connect.
- Mock data covers fields a phone can’t measure (rpm/gear/fuel); OBD is a stub (no data yet).
