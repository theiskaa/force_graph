import 'package:force_graph/src/config.dart';
import 'package:force_graph/src/forces/collide.dart';
import 'package:force_graph/src/forces/link.dart';
import 'package:force_graph/src/forces/many_body.dart';
import 'package:force_graph/src/models.dart';
import 'package:force_graph/src/simulation.dart';

/// Owns the [ForceSimulation] and wires the package's three forces (link,
/// charge, collide) to a [ForceGraphConfig].
///
/// It also performs the per-tick bookkeeping the web graph relies on: damping
/// net momentum so the layout doesn't drift, and recentering its centroid to
/// the origin during the initial spread-out phase. Holds the neighbour map and
/// id lookups used by rendering and hit-testing.
class ForceGraphController {
  ForceGraphController({
    required this.nodes,
    required List<ForceLink> links,
    ForceGraphConfig config = const ForceGraphConfig(),
  }) : _config = config {
    _build(links);
  }

  /// The simulated nodes (mutated in place by the simulation).
  final List<ForceNode> nodes;

  /// Links with both endpoints present; dangling links are dropped on build.
  late final List<ForceLink> links;

  ForceGraphConfig _config;

  /// The active configuration.
  ForceGraphConfig get config => _config;

  /// The underlying integrator.
  late ForceSimulation simulation;
  late Map<String, ForceNode> _byId;

  /// Adjacency map: node id to the set of connected node ids.
  late Map<String, Set<String>> neighbors;

  /// Number of ticks elapsed since construction.
  int tickCount = 0;

  /// Mean per-node kinetic energy from the last tick; the widget uses it to
  /// decide when the layout has settled enough to sleep.
  double meanKineticEnergy = 0;

  void _build(List<ForceLink> rawLinks) {
    _byId = {for (final n in nodes) n.id: n};

    links = [
      for (final l in rawLinks)
        if (_byId.containsKey(l.source) && _byId.containsKey(l.target)) l,
    ];

    neighbors = {};
    for (final link in links) {
      neighbors.putIfAbsent(link.source, () => <String>{}).add(link.target);
      neighbors.putIfAbsent(link.target, () => <String>{}).add(link.source);
    }

    simulation = ForceSimulation(nodes);
    _applyForces();
    simulation.onTick = _afterTick;
  }

  void _applyForces() {
    simulation.alphaDecay = _config.alphaDecay;
    simulation.alphaTarget = _config.alphaTarget;
    simulation.velocityRetain = _config.velocityRetain;

    simulation.clearForces();
    simulation.addForce(LinkForce(
      links,
      distance: _config.linkDistance,
      strength: _config.linkStrength,
      iterations: _config.linkIterations,
    ));
    simulation.addForce(ManyBodyForce(
      strength: _config.chargeStrength,
      distanceMax: _config.chargeDistanceMax,
    ));
    simulation.addForce(CollideForce(
      radius: _config.collideRadius,
      strength: 1,
      iterations: _config.collideIterations,
    ));
  }

  /// Rebuilds the forces from [config] without disturbing node positions. A
  /// no-op when the same config instance is passed again.
  void updateConfig(ForceGraphConfig config) {
    if (identical(config, _config)) return;
    _config = config;
    _applyForces();
  }

  /// Returns the node with the given [id], or null.
  ForceNode? nodeById(String id) => _byId[id];

  /// Whether nodes [a] and [b] are directly linked.
  bool areNeighbors(String a, String b) => neighbors[a]?.contains(b) ?? false;

  /// Advances the simulation by one tick.
  void tick() => simulation.tick();

  /// Reactivates a settled layout (see [ForceSimulation.reheat]).
  void reheat([double target = 0.3]) => simulation.reheat(target);

  /// Runs after each tick: tracks kinetic energy, damps net momentum so the
  /// graph doesn't translate, and recenters the centroid during the first
  /// [ForceGraphConfig.recenterTicks] ticks. Pinned (dragged) nodes are skipped.
  void _afterTick() {
    if (nodes.isEmpty) return;
    tickCount++;
    final recenterPos = tickCount <= _config.recenterTicks;

    var sumX = 0.0, sumY = 0.0, sumVx = 0.0, sumVy = 0.0, sumKe = 0.0;
    var count = 0;
    for (final n in nodes) {
      if (n.fx != null || n.fy != null) continue;
      sumX += n.x;
      sumY += n.y;
      sumVx += n.vx;
      sumVy += n.vy;
      sumKe += n.vx * n.vx + n.vy * n.vy;
      count++;
    }
    if (count == 0) {
      meanKineticEnergy = 0;
      return;
    }

    meanKineticEnergy = sumKe / count;

    final avgX = sumX / count;
    final avgY = sumY / count;
    final avgVx = sumVx / count;
    final avgVy = sumVy / count;

    for (final n in nodes) {
      if (n.fx != null || n.fy != null) continue;
      if (recenterPos) {
        n.x -= avgX;
        n.y -= avgY;
      }
      n.vx -= avgVx;
      n.vy -= avgVy;
    }
  }
}
