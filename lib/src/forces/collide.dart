import 'dart:math' as math;

import 'package:force_graph/src/forces/force.dart';
import 'package:force_graph/src/lcg.dart';
import 'package:force_graph/src/models.dart';
import 'package:force_graph/src/quadtree.dart';

/// The collision force, a port of d3-force's `forceCollide`.
///
/// Resolves overlaps between node disks so they don't visually intersect, using
/// anticipated positions (`x + vx`) and a quadtree to find candidate pairs.
/// Larger-radius nodes are displaced less (the correction is split by area), and
/// [iterations] passes per tick make separation firmer.
class CollideForce implements Force {
  CollideForce({
    required this.radius,
    this.strength = 1,
    this.iterations = 3,
  });

  /// Returns the collision radius of a node.
  final double Function(ForceNode) radius;

  /// Fraction of the overlap resolved per pass, in `[0, 1]`.
  double strength;

  /// Separation passes per tick.
  int iterations;

  late List<ForceNode> _nodes;
  late Lcg _random;
  late List<double> _radii;

  late ForceNode _node;
  late double _ri, _ri2, _xi, _yi;

  @override
  void initialize(List<ForceNode> nodes, Lcg random) {
    _nodes = nodes;
    _random = random;
    _radii = List<double>.filled(nodes.length, 0);
    for (final n in nodes) {
      _radii[n.index] = radius(n);
    }
  }

  @override
  void apply(double alpha) {
    for (var k = 0; k < iterations; k++) {
      final tree = Quadtree(_nodes, anticipate: true);
      tree.visitAfter(_prepare);
      for (final node in _nodes) {
        _node = node;
        _ri = _radii[node.index];
        _ri2 = _ri * _ri;
        _xi = node.x + node.vx;
        _yi = node.y + node.vy;
        tree.visit(_applyTo);
      }
    }
  }

  /// Records the largest radius in each cell so [_applyTo] can prune cells that
  /// are too far to overlap the current node.
  void _prepare(QuadNode quad, double x0, double y0, double x1, double y1) {
    if (quad.data != null) {
      quad.r = _radii[quad.data!.index];
      return;
    }
    quad.r = 0;
    for (final c in quad.children!) {
      if (c != null && c.r > quad.r) quad.r = c.r;
    }
  }

  /// Pushes the current node and an overlapping [quad] apart, or returns true to
  /// prune a cell that cannot reach the node's disk.
  bool _applyTo(QuadNode quad, double x0, double y0, double x1, double y1) {
    final rj = quad.r;
    final r = _ri + rj;
    if (quad.data != null) {
      final other = quad.data!;
      // index check resolves each unordered pair exactly once.
      if (other.index > _node.index) {
        var x = _xi - other.x - other.vx;
        var y = _yi - other.y - other.vy;
        var l = x * x + y * y;
        if (l < r * r) {
          if (x == 0) {
            x = _random.jiggle();
            l += x * x;
          }
          if (y == 0) {
            y = _random.jiggle();
            l += y * y;
          }
          l = math.sqrt(l);
          l = (r - l) / l * strength;
          x *= l;
          y *= l;
          final rj2 = rj * rj;
          var share = rj2 / (_ri2 + rj2);
          _node.vx += x * share;
          _node.vy += y * share;
          share = 1 - share;
          other.vx -= x * share;
          other.vy -= y * share;
        }
      }
      return false;
    }
    return x0 > _xi + r || x1 < _xi - r || y0 > _yi + r || y1 < _yi - r;
  }
}
