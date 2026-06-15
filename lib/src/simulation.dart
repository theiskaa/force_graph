import 'dart:math' as math;

import 'package:force_graph/src/forces/force.dart';
import 'package:force_graph/src/lcg.dart';
import 'package:force_graph/src/models.dart';

/// The velocity-Verlet integrator at the heart of d3-force, ported to Dart.
///
/// One [tick] decays [alpha], applies every registered [Force] in insertion
/// order, then integrates positions. The host drives [tick] once per frame
/// (react-force-graph runs one step per rendered frame rather than on d3's
/// internal timer).
class ForceSimulation {
  ForceSimulation(this.nodes, {Lcg? random}) : random = random ?? Lcg() {
    initializeNodes();
  }

  final List<ForceNode> nodes;

  /// Shared deterministic generator handed to each force.
  final Lcg random;

  final List<Force> _forces = [];

  /// Current simulation heat; forces scale by it and it decays toward
  /// [alphaTarget] each tick.
  double alpha = 1;

  /// Fraction of the gap to [alphaTarget] closed per tick.
  double alphaDecay = 0.008;

  /// Floor that [alpha] settles to. A small positive value keeps the layout
  /// gently alive instead of freezing; raised transiently while dragging.
  double alphaTarget = 0.02;

  /// Fraction of velocity carried into the next tick. d3 stores
  /// `1 - velocityDecay`, so the web's `velocityDecay = 0.4` is `0.6` here.
  double velocityRetain = 0.6;

  /// Invoked at the end of every [tick], after integration — used by the
  /// controller for its per-tick recenter and momentum damping.
  void Function()? onTick;

  static const double _initialRadius = 10;
  static final double _initialAngle = math.pi * (3 - math.sqrt(5));

  /// Seeds unset node positions on a phyllotaxis spiral (identical to d3) so the
  /// first frame matches the reference layout, and assigns each node its index.
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

  /// Registers and initializes [force]. Order matters: forces apply in the
  /// order added (link, then charge, then collide in this package).
  void addForce(Force force) {
    force.initialize(nodes, random);
    _forces.add(force);
  }

  /// Removes all forces (the controller calls this before re-adding on a config
  /// change, so node positions are preserved).
  void clearForces() => _forces.clear();

  /// Re-runs every force's initialize, e.g. after the node set changes.
  void reinitialize() {
    for (final f in _forces) {
      f.initialize(nodes, random);
    }
  }

  /// Advances the simulation by one step.
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

  /// Raises [alpha] to at least [target] to reactivate a settled layout.
  void reheat([double target = 0.3]) {
    alpha = math.max(alpha, target);
  }
}
