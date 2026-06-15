# force_graph

<p align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Style](https://img.shields.io/badge/style-flutter__lints-40c4ff)](https://pub.dev/packages/flutter_lints)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

</p>

"force_graph renders interactive force-directed graphs in Flutter through a fully in-tree pipeline: a hand port of d3-force (charge, link, and collide) on a Barnes-Hut quadtree, a velocity-Verlet integrator, and a `CustomPainter` render layer — no platform views, no WebView, no JavaScript."

force_graph ships as a pure-Dart library exposing a single drop-in widget. Its physics are a faithful port of [`d3-force`](https://github.com/d3/d3-force), the engine behind `react-force-graph`, so a graph laid out by this package matches the web reference in feel and behavior rather than approximating it. The many-body charge force runs over a Barnes-Hut quadtree to keep long-range repulsion near `O(n log n)`, link springs pull connected nodes toward a rest distance with a degree-weighted bias so that hubs move less than their leaves, and a hard-sphere collision pass keeps node disks from overlapping; all three are integrated each tick with velocity-Verlet. A permanent alpha floor keeps the layout gently alive instead of freezing, while a per-tick recenter and momentum-damping step stop the graph from slowly drifting off screen.

On top of the simulation, a `CustomPainter` draws the graph with zoom-damped node radii, labels, hover and neighbor dimming, dashed rings for phantom nodes, and an animated highlight that travels along a hovered node's links. Interaction covers panning, zooming, dragging a node to pin it, hovering on desktop and double-tapping on touch, and an auto-fit pass on first render that quietly yields to the first user gesture. Because a force layout never truly comes to rest, the widget sleeps its render loop once the graph settles and wakes it again on the next interaction or data change, and it caches laid-out labels across frames. Every physics, sizing, and color value is exposed through `ForceGraphConfig` and `ForceGraphTheme`, and the widget switches between a desktop and a mobile configuration automatically at a breakpoint you choose.

## Install

Add force_graph to your `pubspec.yaml` as a git dependency and run `flutter pub get`. If you have the package checked out locally, point at it with a `path` dependency instead.

```yaml
dependencies:
  force_graph:
    git:
      url: https://github.com/theiskaa/force_graph.git
```

## Usage

A graph is nothing more than a list of nodes and a list of links; hand both to a `ForceGraphView` and drop it into any sized box. The widget fills its parent, so place it inside a `Positioned.fill`, an `Expanded`, or a `SizedBox`.

```dart
import 'package:flutter/material.dart';
import 'package:force_graph/force_graph.dart';

class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nodes = [
      ForceNode(id: 'a', label: 'Alpha', color: Colors.indigo, val: 3),
      ForceNode(id: 'b', label: 'Beta', color: Colors.teal),
      ForceNode(id: 'c', label: 'Gamma', color: Colors.orange),
    ];
    final links = [
      ForceLink('a', 'b'),
      ForceLink('a', 'c'),
    ];

    return Scaffold(
      body: ForceGraphView(
        nodes: nodes,
        links: links,
        onNodeTap: (node) => debugPrint('tapped ${node.id}'),
      ),
    );
  }
}
```

Beyond the data and callbacks, the widget accepts a handful of host-driven controls. `selectedId` draws a selection ring around a node, `focusId` pans and zooms to center one, and bumping `fitToken` to a new value re-fits the whole graph on demand. `paused` freezes the simulation while leaving pan and zoom live, the `onNodeTap`, `onNodeHover`, and `onBackgroundTap` callbacks report interaction, and `onReady` hands you the underlying `ForceGraphController` when you need direct control.

## Configuration

Physics, sizing, and interaction are tuned through `ForceGraphConfig`. You pass one configuration for wide layouts and, optionally, a second `mobileConfig` that the widget adopts below `breakpoint`; `ForceGraphConfig.mobile()` provides lighter defaults — a weaker charge, shorter links, smaller nodes, and a larger touch hit area. The most commonly adjusted options are summarized below, and the dartdoc on `ForceGraphConfig` documents the full set.

```dart
ForceGraphView(
  nodes: nodes,
  links: links,
  config: const ForceGraphConfig(
    chargeStrength: -800,
    linkDistance: 140,
    idleSleep: true,
  ),
  mobileConfig: ForceGraphConfig.mobile(),
)
```

| Option                | Default      | Description                                                       |
| --------------------- | ------------ | ----------------------------------------------------------------- |
| `chargeStrength`      | `-600`       | Many-body charge; negative repels.                                |
| `chargeDistanceMax`   | `800`        | Maximum charge interaction distance.                              |
| `linkDistance`        | `160`        | Spring rest length for links.                                     |
| `linkStrength`        | `0.08`       | Spring stiffness, `[0, 1]`.                                       |
| `collidePadding`      | `2`          | Extra gap added to each collision radius.                         |
| `alphaDecay`          | `0.008`      | Cooling rate per tick.                                            |
| `alphaTarget`         | `0.02`       | Resting heat floor that keeps the layout gently alive.            |
| `velocityDecay`       | `0.4`        | Friction (d3 convention; `0.6` of velocity is retained per tick). |
| `recenterTicks`       | `300`        | Initial ticks during which the centroid is pulled to the origin.  |
| `idleSleep`           | `true`       | Halt the render loop when the layout settles; wake on input.      |
| `minZoom` / `maxZoom` | `0.05` / `8` | View zoom clamps.                                                 |

Colors and the label font are carried separately by `ForceGraphTheme`. The defaults reproduce a dark canvas, and `ForceGraphTheme.light()` is a ready-made light variant that also accepts a font family, so restyling the graph is a matter of passing a theme rather than touching the painter.

```dart
ForceGraphView(
  nodes: nodes,
  links: links,
  theme: ForceGraphTheme.light(fontFamily: 'Inter'),
)
```

## How it works

Each tick decays the simulation's `alpha`, applies the forces in order — link, then charge, then collide — and integrates positions with velocity-Verlet, the same pipeline as `d3-force`. The many-body and collide forces build a Barnes-Hut quadtree every tick so that long-range repulsion stays near `O(n log n)` rather than `O(n²)`. The widget drives one tick per frame through a `Ticker`, matching how `react-force-graph` advances its layout, and `idleSleep` stops that ticker once mean kinetic energy stays below a threshold for a short while, restarting it on any interaction or data change.

## Example

The [`example/`](example/) directory contains a runnable app that replicates the knowledge graph from [Apeirron](https://github.com/theiskaa/apeirron) — the web project these physics were ported from — rendering its real 146-node graph from a bundled JSON snapshot. Run it with `flutter run` from inside the directory.

```sh
cd example
flutter run
```

## License

Released under the [MIT License](LICENSE).
