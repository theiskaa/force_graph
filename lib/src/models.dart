import 'dart:ui' show Color;

/// A single node in the force simulation.
///
/// The simulation mutates the position/velocity fields in place each tick,
/// mirroring how d3-force augments plain objects with `x`/`y`/`vx`/`vy`. Pass
/// arbitrary host data through [data] to keep the package data-agnostic.
class ForceNode {
  ForceNode({
    required this.id,
    this.label = '',
    this.color = const Color(0xFF888888),
    this.val = 1,
    this.phantom = false,
    this.data,
  });

  /// Stable identifier used to resolve links and look the node up.
  final String id;

  /// Text drawn beneath the node (empty hides the label).
  final String label;

  /// Fill colour of the node disk.
  final Color color;

  /// Relative weight; drives the rendered and collision radius. In the Apeirron
  /// graph this is the node's connection count.
  final double val;

  /// When true the node renders hollow with a dashed ring. Purely cosmetic —
  /// the physics treat it like any other node.
  final bool phantom;

  /// Opaque host payload, returned to callbacks on tap/hover.
  final Object? data;

  /// Current position, seeded by the simulation (`NaN` until then).
  double x = double.nan;
  double y = double.nan;

  /// Current velocity, integrated each tick.
  double vx = 0;
  double vy = 0;

  /// Pinned position. While non-null the integrator holds the node here, used
  /// to drag a node. Mirrors d3's `fx`/`fy`.
  double? fx;
  double? fy;

  /// Index assigned by the simulation on initialization, used by forces for
  /// array lookups.
  int index = 0;
}

/// An undirected edge between two [ForceNode] ids.
class ForceLink {
  ForceLink(this.source, this.target, {this.reason = ''});

  /// Id of the source endpoint.
  final String source;

  /// Id of the target endpoint.
  final String target;

  /// Optional host metadata describing the connection (unused by the physics).
  final String reason;

  /// Endpoints resolved from ids, filled in by the link force on initialize.
  late ForceNode sourceNode;
  late ForceNode targetNode;

  /// Degree-based share of the spring correction applied to the target (the
  /// source gets `1 - bias`), so high-degree hubs move less.
  late double bias;

  /// Per-link spring strength and rest distance, cached on initialize.
  late double strengthValue;
  late double distanceValue;
}
