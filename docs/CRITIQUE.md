# Road Kernel — Critique

An honest assessment of the concept. The goal is not to talk you out of it — the
core idea is good — but to separate what to keep from what will hurt you, and to
name why the first build never reached a running state.

---

## 1. What's strong (keep all of this)

- **Overlay, not competitor.** "Don't rebuild Apple Maps; build the layer it
  doesn't give you" is exactly the right framing. It keeps scope honest and the
  app genuinely useful from day one.
- **Local-first / no-cloud privacy.** No accounts, no analytics, no server. For a
  personal field tool that will hold home addresses and relationship notes, this
  is the correct default and a real differentiator.
- **Export-early instinct.** Treating your data as the treasure and supporting
  JSON/GeoJSON/SQLite export early is the right call — it future-proofs the data
  against the app itself.
- **Data before prediction.** Collecting good signal data before attempting any
  timing math is the correct sequencing. ("A shopping cart with one haunted
  wheel" is a real failure mode for premature prediction.)
- **Traceability fields.** Putting `id / createdAt / updatedAt / source /
  confidence / notes` on every record is excellent. Keep it. Future-you will
  thank present-you for never having to ask "where did this data come from?"

---

## 2. The central risk: safety & liability

This is the part the concept underweights, and it deserves to drive the design.

- **"Stopped mode" is still distraction.** NHTSA's driver-distraction guidelines
  target visual-manual tasks from in-vehicle devices. At a red light, the
  driver's attention belongs on the signal and surrounding traffic — not on
  finding and tapping RED/YELLOW/GREEN on an iPad. A "stopped at a light" logging
  mode is precisely the kind of glance-and-tap task those guidelines warn about.
- **"Likely green" is advice, and advice creates liability.** An app that
  displays a countdown or "probably green" can encourage a driver to roll a red
  or enter an intersection on a prediction. That is a safety hazard and a legal
  exposure.
- **The fix — reframe the product:** Road Kernel is a **memory / notebook**,
  never a **driving instruction**. Concretely:
  - Logging is **passenger-only** in early versions (capture by a passenger, or
    by you while parked).
  - Driver-side capture waits until **voice** and **hardware buttons** exist, so
    eyes and hands stay on the road.
  - Timing is shown as *descriptive history with explicit low confidence*, never
    as a "go now" signal.

---

## 3. Prediction is oversold

- The offset model (`cyclePosition = (now - knownRedStart) % cycleLength`) only
  works for **fixed-cycle** signals. Most intersections worth predicting are
  **actuated or adaptive** — driven by inductive loops, pedestrian buttons,
  emergency preemption, and time-of-day programs. Their cycle isn't constant, so
  the math will be confidently wrong a lot of the time.
- **Keep the feature, lower the promise.** Compute red/green/yellow/cycle
  averages and sample counts as *descriptive statistics*. Surface them with
  honest confidence ("not enough samples," "low confidence," "unknown"). Never a
  precise countdown presented as actionable.

---

## 4. GPS attribution will misfire

- Consumer horizontal accuracy is ~8–40 m. Real intersections are frequently
  closer together than that, and a single large intersection can be ~40 m across.
  "Find nearest signal within 40 m and attach the observation" will routinely
  attach to the wrong signal.
- **Heading doesn't save you at low speed.** Compass/derived heading is noisy or
  meaningless when stopped or crawling — exactly when you'd be logging.
- **The fix — design for ambiguity, not silent automation:**
  - Store accuracy/speed/heading *with every observation* (the concept already
    does this — good).
  - Prefer **manual confirm** of the nearest signal over silent auto-attach.
  - Use heading only as a *filter/tiebreaker*, and **ask the user when ambiguous**
    rather than guessing.

---

## 5. Scope — the real reason it failed

The concept says "keep the first beast small," but its own MVP already implies
roughly **eight data tables** (signals, approaches, observations, timing
estimates, places, people, links, road notes), **multiple interaction modes**,
and a **prediction engine**. Trying to stand all of that up before a single pin
renders means the project never reaches a runnable state — and an empty repo is
what that looks like.

**A true v0.1 is one model and one button:** a `Signal`, and "Mark Signal Here."
Everything else — observations, approaches, timing, people/places, modes — is a
later phase. See [ROADMAP.md](ROADMAP.md).

---

## 6. Tech indecision

The concept hedges: "SwiftData *or* SQLite *or* Core Data," and "use both." That
hedge is itself a source of paralysis.

- **Decision: SwiftData now.** It's the fastest Apple-native path to a working
  prototype on iPadOS 17+, and it persists to SQLite under the hood anyway.
- **SQLite/GeoJSON live at the export layer only.** You get portability and
  inspectability where it matters (your exported treasure) without paying the
  cost of a hand-rolled persistence layer before the app even runs.

---

## 7. Summary

| Keep                                   | Fix                                             |
| -------------------------------------- | ----------------------------------------------- |
| Overlay-not-competitor philosophy      | Reframe as memory/notebook, never driving advice|
| Local-first privacy, no cloud          | Passenger-only logging until voice/hardware buttons |
| Export-early, traceability fields      | Lower prediction's promise; descriptive + honest confidence |
| Data-before-prediction sequencing      | Design GPS attribution for ambiguity (manual confirm) |
| Phased thinking                        | Collapse v0.1 to **one model, one button**      |
|                                        | Commit to **SwiftData**; SQLite/GeoJSON at export only |

The idea is sound. The failure was scope and a few standard first-build walls —
both fixable. See [ARCHITECTURE.md](ARCHITECTURE.md) for the concrete fixes.
