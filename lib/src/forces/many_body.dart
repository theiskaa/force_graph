import 'dart:math' as math;

import 'package:force_graph/src/forces/force.dart';
import 'package:force_graph/src/lcg.dart';
import 'package:force_graph/src/models.dart';
import 'package:force_graph/src/quadtree.dart';

/// The many-body (charge) force, a port of d3-force's `forceManyBody`.
///
/// Negative [strength] repels nodes and positive attracts; the Apeirron graph
/// uses a strong negative charge so nodes spread out. Long-range interaction is
/// approximated with a Barnes-Hut quadtree: a cell far enough away (per the
/// [theta] criterion) is treated as a single aggregate body, making the cost
/// roughly `O(n log n)` instead of `O(n²)`.
class ManyBodyForce implements Force {
  ManyBodyForce({
    required this.strength,
    this.distanceMin = 1,
    double distanceMax = double.infinity,
    this.theta = 0.9,
  }) : distanceMax2 = distanceMax * distanceMax,
       distanceMin2 = distanceMin * distanceMin,
       theta2 = theta * theta;

  /// Per-node charge; negative repels.
  double strength;

  /// Minimum interaction distance, clamping the force between very close nodes.
  final double distanceMin;
  final double distanceMin2;

  /// Squared maximum interaction distance; pairs farther apart are ignored.
  final double distanceMax2;

  /// Barnes-Hut accuracy parameter: smaller is more accurate and slower.
  final double theta;
  final double theta2;

  late List<ForceNode> _nodes;
  late Lcg _random;
  late List<double> _strengths;

  late ForceNode _node;
  double _alpha = 0;

  @override
  void initialize(List<ForceNode> nodes, Lcg random) {
    _nodes = nodes;
    _random = random;
    _strengths = List<double>.filled(nodes.length, 0);
    for (var i = 0; i < nodes.length; i++) {
      _strengths[nodes[i].index] = strength;
    }
  }

  @override
  void apply(double alpha) {
    _alpha = alpha;
    final tree = Quadtree(_nodes);
    tree.visitAfter(_accumulate);
    for (final node in _nodes) {
      _node = node;
      tree.visit(_applyTo);
    }
  }

  /// Rolls each cell's summed charge and charge-weighted centre of mass up the
  /// tree (post-order), so [_applyTo] can approximate distant cells.
  void _accumulate(QuadNode quad, double x0, double y0, double x1, double y1) {
    var strength = 0.0;
    if (quad.children != null) {
      var weight = 0.0, x = 0.0, y = 0.0;
      for (final c in quad.children!) {
        if (c == null || c.value == 0) continue;
        final cstr = c.value;
        final w = cstr.abs();
        strength += cstr;
        weight += w;
        x += w * c.cx;
        y += w * c.cy;
      }
      quad.cx = weight != 0 ? x / weight : 0;
      quad.cy = weight != 0 ? y / weight : 0;
    } else {
      QuadNode? q = quad;
      quad.cx = quad.data!.x;
      quad.cy = quad.data!.y;
      do {
        strength += _strengths[q!.data!.index];
        q = q.next;
      } while (q != null);
    }
    quad.value = strength;
  }

  /// Accumulates the charge from [quad] onto the current node. Returns true to
  /// stop descending once the cell is approximated or out of range.
  bool _applyTo(QuadNode quad, double x0, double y0, double x1, double y1) {
    if (quad.value == 0) return true;
    var x = quad.cx - _node.x;
    var y = quad.cy - _node.y;
    final w = x1 - x0;
    var l = x * x + y * y;

    // Barnes-Hut: if the cell is far enough relative to its width, treat its
    // whole mass as one body at the centre of mass and stop descending.
    if (w * w / theta2 < l) {
      if (l < distanceMax2) {
        if (x == 0) {
          x = _random.jiggle();
          l += x * x;
        }
        if (y == 0) {
          y = _random.jiggle();
          l += y * y;
        }
        if (l < distanceMin2) l = math.sqrt(distanceMin2 * l);
        _node.vx += x * quad.value * _alpha / l;
        _node.vy += y * quad.value * _alpha / l;
      }
      return true;
    }

    if (quad.children != null || l >= distanceMax2) return false;

    if (quad.data != _node || quad.next != null) {
      if (x == 0) {
        x = _random.jiggle();
        l += x * x;
      }
      if (y == 0) {
        y = _random.jiggle();
        l += y * y;
      }
      if (l < distanceMin2) l = math.sqrt(distanceMin2 * l);
    }
    QuadNode? q = quad;
    do {
      if (q!.data != _node) {
        final ww = _strengths[q.data!.index] * _alpha / l;
        _node.vx += x * ww;
        _node.vy += y * ww;
      }
      q = q.next;
    } while (q != null);
    return false;
  }
}
