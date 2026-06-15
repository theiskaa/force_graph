# force_graph — Hard Review: Known Problems

Adversarial self-review of the implementation. Severity: **P1** = functional bug a
user will hit, **P2** = correctness/parity divergence from the web original, **P3** =
performance, **P4** = robustness/edge case, **P5** = limitation/polish.

## Resolution status (updated)
- **Fixed in code**: 1.1, 1.2 (fit/focus guard), 2.1 (world-font label threshold),
  2.2 (drag raises `alphaTarget`), 3.1 (label TextPainter cache), 3.2 (idle-sleep,
  default on, configurable), 3.4 (cached effective config), 4.1 (dangling links
  filtered), 4.2 (quadtree split depth cap), 4.3 (rebuild controller on data change),
  4.4 (dead `alphaMin` removed), 5.1 (Semantics), 5.2 (mid-gesture release),
  5.3 (two-stage auto-fit). 2.3 partially addressed via `ForceGraphTheme.light()`.
- **By design / documented (no code change)**: 2.4 (host sets `fontFamily`),
  2.5 (visual not bit determinism), 3.3 (3× collide rebuild is algorithmically
  required; mitigated by idle-sleep), 2.5/5.5, 5.4 (single-blob recenter).

---

## P1 — Functional bugs

### 1.1 `focusId` and `fitToken` fits are silently dead after any interaction
`lib/src/widget.dart`

`_onFrame` only starts a queued fit when `!_userTookOver`:
```dart
if (_fitRequested && !_userTookOver) { _fitRequested = false; _beginFit(elapsed); }
```
But:
- `_focusOn()` calls `_takeOver()` (which sets `_userTookOver = true`) **and then**
  `_animateTo()` (which sets `_fitRequested = true`). The guard then blocks it on the
  next frame, so `focusId` **never animates**.
- `fitView()` via `fitToken` does not call `_takeOver`, but once the user has panned/
  zoomed/tapped even once, `_userTookOver` is permanently true, so the re-center FAB in
  the example **stops working** after the first interaction.

The `!_userTookOver` guard should gate **only the initial auto-fit**, not explicit
programmatic fits. Fix: have `_requestAutoFit` check `_userTookOver` itself, and let
`_beginFit` run unconditionally for explicit fits (e.g. a separate `_autoFit` flag).

### 1.2 `_animateTo` has a dead assignment
`lib/src/widget.dart` — `_animateTo` sets `_fitRequested = false` then immediately
`_fitRequested = true`. The first line is dead. Harmless but signals the muddled
fit-state machine behind 1.1.

---

## P2 — Parity divergence from the web graph

### 2.1 Label visibility threshold is inverted relative to the web
`lib/src/painter.dart`

Web (`Graph.tsx`) hides a label when the **world-space** font `< 1.5`:
`fontSize = min(11/scale, 13)` → labels disappear only when zoomed **in** past ~7.3×.

This port checks the **screen-space** font instead:
```dart
final screenFont = worldFont * scale;
if (screenFont >= config.labelMinScreenFontSize /* 1.5 */ ...)
```
→ labels disappear when zoomed **out** below ~0.12×. Opposite regime. Arguably better
UX, but it is **not** parity. To match the original, threshold on `worldFont >= 1.5`.

### 2.2 Drag uses `reheat(alpha)` instead of `alphaTarget`
`lib/src/widget.dart` / `simulation.dart`

d3/the web raise **`alphaTarget`** to ~0.3 while dragging and restore the floor on
release. This port bumps **`alpha`** once via `reheat()`. The graph stays lively because
of the permanent `alphaTarget = 0.02` floor, but the "energetic while held" feel differs
slightly from the original.

### 2.3 Only the default dark theme is reproduced
`lib/src/config.dart` — `ForceGraphTheme` hard-codes the dark-theme RGBA values from the
web's CSS variables. The web swaps these per active theme (multiple themes exist). The
package is customizable, so this is acceptable, but "exact behavior" only holds for the
default theme out of the box.

### 2.4 Label font family differs
`ForceGraphTheme.fontFamily` defaults to `null` → Flutter's platform default, not the
web's `Inter`. Labels render in a different typeface unless the host supplies a font.

### 2.5 Force registration order is assumed, not verified against the library
`lib/src/controller.dart` registers `link → charge → collide`. This matches my reading of
`force-graph`'s defaults (`link, charge, center`) plus `Graph.tsx` removing `center` and
appending `collide`. d3 applies forces in insertion order, so order affects the result.
Believed correct but not empirically confirmed against the running JS.

---

## P3 — Performance

### 3.1 A new `TextPainter` is built + laid out for every visible node, every frame
`lib/src/painter.dart` — up to 146 `TextPainter.layout()` calls per frame at 60fps.
`TextPainter` is expensive; labels should be cached (keyed by text/size/color) or pre-laid
out, especially since the simulation runs forever.

### 3.2 The simulation never sleeps
`alphaTarget = 0.02` (floor) + a free-running `Ticker` means the graph ticks, rebuilds the
`CustomPaint`, and repaints all nodes/links/labels **every frame forever**, even at rest.
This mirrors the web (which also never freezes), but it is a continuous CPU/battery cost
with no idle path. Consider an idle detector that stops the ticker when `alpha` and total
kinetic energy fall below a threshold, restarting on interaction.

### 3.3 Quadtree is rebuilt 4× per tick
`many_body.dart` builds one tree/tick; `collide.dart` builds a fresh tree **per iteration**
(3×). Each build re-allocates `QuadNode`s and `List<QuadNode?>.filled(4)` internal arrays.
Fine at ~150 nodes; will dominate cost on large graphs. No node pooling/reuse.

### 3.4 Mobile config is re-allocated and forces rebuilt on every parent rebuild
`widget.dart` — `_effectiveConfig` returns a **new** `ForceGraphConfig.mobile()` each call
when `mobileConfig` is null. `didUpdateWidget` → `updateConfig`'s `identical()` check is
therefore always false on mobile, so all three forces are torn down and re-initialized on
every rebuild. Cache the effective config instance (and/or compare by value).

---

## P4 — Robustness / edge cases

### 4.1 Dangling link ids crash the simulation
`lib/src/forces/link.dart` — `link.sourceNode = byId[link.source]!` throws if a link
references an id with no node. The example pre-filters links, but the library itself has no
guard. Should skip/validate dangling links instead of asserting.

### 4.2 Quadtree can infinite-loop on near-but-not-equal coincident points
`lib/src/quadtree.dart` — the `do { ... } while (i == j)` split loop separates two points by
subdividing. If two points are distinct but closer than float precision can resolve within
the cell, the bounds stop changing while `i == j` stays true → **infinite loop / hang**.
d3-quadtree shares this theoretical risk and relies on jiggle/spacing to avoid it; a depth
cap (fall back to a coincident chain) would harden it.

### 4.3 Node/link **set** changes after mount are ignored
`widget.dart` — the `ForceGraphController` is built once in `initState`; `didUpdateWidget`
updates config and fit but never rebuilds the controller when `widget.nodes`/`widget.links`
change. Callers must change the widget `key` to load new data. No add/remove API.

### 4.4 `alphaMin` is dead
`simulation.dart` exposes `alphaMin` and the controller sets it, but `tick()` never reads it
(there is no stop condition). Either implement the stop (ties into 3.2) or remove the field
to avoid implying behavior that doesn't exist.

---

## P5 — Limitations / polish

### 5.1 No accessibility semantics
The web wraps the canvas in `role="img"` with an aria-label. The Flutter widget exposes no
`Semantics`. Screen readers see nothing.

### 5.2 Mid-gesture pointer-count transitions are rough
`_onScaleUpdate` — if a drag (1 pointer) gains a second finger, control falls through to
pan/zoom while the dragged node stays pinned until `onScaleEnd`. Minor visual glitch on
the 1↔2 finger boundary.

### 5.3 Auto-fit target is stale by the time it animates
`fitView()` snapshots the bounding box at ~300ms and animates over 500ms while the sim is
still expanding, so the final framing can be slightly loose. Matches the web's behavior but
worth a continuous-fit option.

### 5.4 `RECENTER_TICKS`/recenter assumes a single connected blob
The centroid recenter + momentum-zeroing assumes one cluster. Disconnected components or a
graph dragged far off-origin during the first 300 ticks can feel like they're being tugged
back. Same as the web, noted for completeness.

### 5.5 Determinism is "visually identical", not bit-identical
The LCG matches d3 constants, but float64 evaluation order and the simplified quadtree
bounding-square (vs d3's doubling `cover`) mean exact coordinates will diverge from the JS
reference over many ticks. Layout *character* matches; exact positions do not.

---

## Verified OK (spot-checked, no issue found)
- d3 force math: many-body Barnes-Hut criterion + COM accumulation, link spring + degree
  bias, collide area-weighted resolution, velocity-Verlet integration, alpha decay.
- `velocityDecay 0.4` → retain `0.6` mapping matches d3's `1 - x` convention.
- Theme RGBA → ARGB conversions (line/lineHover/nodeDim/traverseTrail/...) are correct.
- Node radius / zoom-damping (`scale^0.65`) screen size matches the web.
- Self-force / single-node / all-coincident cases do not divide by zero or NaN.
- Package and example both pass `flutter analyze`; physics tests pass; macOS build links.
