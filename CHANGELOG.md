## 0.1.0

Initial release.

* A faithful Dart port of d3-force — many-body charge (Barnes-Hut quadtree), link
  springs with degree-weighted bias, and hard-sphere collision, integrated with
  velocity-Verlet. A permanent alpha floor plus per-tick recenter and momentum damping
  keep the layout alive without drifting.
* `ForceGraphView` widget with pan, zoom, drag-to-pin, hover (desktop), double-tap
  (touch), and an auto-fit pass on first render that yields to the first user gesture.
* `CustomPainter` rendering: zoom-damped node radii, labels, hover/neighbor dimming,
  phantom dashed rings, and an animated link-traversal highlight.
* Idle-sleep — the render loop halts when the layout settles and wakes on
  interaction or data change. Configurable via `idleSleep`, `sleepSpeedThreshold`,
  `sleepFrames` (default on).
* Fully configurable physics, sizing, and colors via `ForceGraphConfig` and
  `ForceGraphTheme` (including `ForceGraphConfig.mobile()` and `ForceGraphTheme.light()`),
  with automatic desktop/mobile switching at a breakpoint.
* Cached label painters and resolved config for steady-state performance; dangling
  links are filtered and the quadtree split is depth-capped for robustness.
