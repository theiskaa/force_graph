import 'dart:math' as math;

import 'package:force_graph/src/forces/force.dart';
import 'package:force_graph/src/lcg.dart';
import 'package:force_graph/src/models.dart';

class ForceSimulation {
  ForceSimulation(this.nodes, {Lcg? random}) : random = random ?? Lcg() {
    initializeNodes();
  }

  final List<ForceNode> nodes;
  final Lcg random;

  final List<Force> _forces = [];

  double alpha = 1;
  double alphaDecay = 0.008;
  double alphaTarget = 0.02;
  double velocityRetain = 0.6;

  void Function()? onTick;

  static const double _initialRadius = 10;
  static final double _initialAngle = math.pi * (3 - math.sqrt(5));

  void initializeNodes() {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      node.index = i;
      if (node.fx != null) node.x = node.fx!;
      if (node.fy != null) node.y = node.fy!;
      if (node.x.isNaN || node.y.isNaN) {
        final radius = _initialRadius * math.sqrt(0.5 + i);
        final angle = i * _initialAngle;
        node.x = radius * math.cos(angle);
        node.y = radius * math.sin(angle);
      }
      if (node.vx.isNaN || node.vy.isNaN) {
        node.vx = 0;
        node.vy = 0;
      }
    }
  }

  void addForce(Force force) {
    force.initialize(nodes, random);
    _forces.add(force);
  }

  void clearForces() => _forces.clear();

  void reinitialize() {
    for (final f in _forces) {
      f.initialize(nodes, random);
    }
  }

  void tick() {
    alpha += (alphaTarget - alpha) * alphaDecay;
    for (final force in _forces) {
      force.apply(alpha);
    }
    for (final node in nodes) {
      if (node.fx == null) {
        node.vx *= velocityRetain;
        node.x += node.vx;
      } else {
        node.x = node.fx!;
        node.vx = 0;
      }
      if (node.fy == null) {
        node.vy *= velocityRetain;
        node.y += node.vy;
      } else {
        node.y = node.fy!;
        node.vy = 0;
      }
    }
    onTick?.call();
  }

  void reheat([double target = 0.3]) {
    alpha = math.max(alpha, target);
  }
}
