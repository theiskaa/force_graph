## 0.0.2

* Fixed: programmatic `fitView`/`focusId` and the fit token now work after the user
  has panned, zoomed, or tapped (the auto-fit guard no longer blocks explicit fits).
* Changed: label visibility now matches the web original (threshold on world-space font).
* Added: idle-sleep — the render loop halts when the layout settles and there is no
  interaction, and wakes on touch/hover/scroll/data change. Configurable via
  `idleSleep`, `sleepSpeedThreshold`, `sleepFrames` (default on).
* Added: node drag raises `alphaTarget` (`dragAlphaTarget`) like d3, restoring the floor
  on release.
* Added: `ForceGraphView.semanticLabel`, `ForceGraphTheme.light()`.
* Performance: cache label `TextPainter`s; cache the resolved (mobile/desktop) config so
  forces are no longer rebuilt on every frame.
* Robustness: dangling links are filtered instead of crashing; quadtree split has a depth
  cap to prevent hangs on sub-precision coincident points; controller rebuilds when the
  node/link set changes; mid-gesture finger-count transitions release the dragged node.

## 0.0.1

* Initial release: d3-force physics port (charge, link, collide) with an interactive
  `ForceGraphView` widget and configurable physics/theme.
