import 'dart:math' as math;

import 'package:force_graph/src/forces/force.dart';
import 'package:force_graph/src/lcg.dart';
import 'package:force_graph/src/models.dart';

class LinkForce implements Force {
  LinkForce(
    this.links, {
    required this.distance,
    required this.strength,
    this.iterations = 1,
  });

  final List<ForceLink> links;
  double distance;
  double strength;
  int iterations;

  late Lcg _random;

  @override
  void initialize(List<ForceNode> nodes, Lcg random) {
    _random = random;
    final byId = <String, ForceNode>{for (final n in nodes) n.id: n};
    final count = List<int>.filled(nodes.length, 0);

    for (final link in links) {
      link.sourceNode = byId[link.source]!;
      link.targetNode = byId[link.target]!;
      count[link.sourceNode.index]++;
      count[link.targetNode.index]++;
    }
    for (final link in links) {
      final cs = count[link.sourceNode.index];
      final ct = count[link.targetNode.index];
      link.bias = cs / (cs + ct);
      link.strengthValue = strength;
      link.distanceValue = distance;
    }
  }

  @override
  void apply(double alpha) {
    for (var k = 0; k < iterations; k++) {
      for (final link in links) {
        final source = link.sourceNode;
        final target = link.targetNode;
        var x = target.x + target.vx - source.x - source.vx;
        if (x == 0) x = _random.jiggle();
        var y = target.y + target.vy - source.y - source.vy;
        if (y == 0) y = _random.jiggle();
        var l = math.sqrt(x * x + y * y);
        l = (l - link.distanceValue) / l * alpha * link.strengthValue;
        x *= l;
        y *= l;
        final bias = link.bias;
        target.vx -= x * bias;
        target.vy -= y * bias;
        source.vx += x * (1 - bias);
        source.vy += y * (1 - bias);
      }
    }
  }
}
