import 'package:force_graph/src/config.dart';
import 'package:force_graph/src/forces/collide.dart';
import 'package:force_graph/src/forces/link.dart';
import 'package:force_graph/src/forces/many_body.dart';
import 'package:force_graph/src/models.dart';
import 'package:force_graph/src/simulation.dart';

class ForceGraphController {
  ForceGraphController({
    required this.nodes,
    required this.links,
    ForceGraphConfig config = const ForceGraphConfig(),
  }) : _config = config {
    _build();
  }

  final List<ForceNode> nodes;
  final List<ForceLink> links;

  ForceGraphConfig _config;
  ForceGraphConfig get config => _config;

  late ForceSimulation simulation;
  late Map<String, ForceNode> _byId;
  late Map<String, Set<String>> neighbors;

  int tickCount = 0;

  void _build() {
    _byId = {for (final n in nodes) n.id: n};

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
    simulation.alphaMin = 0;
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

  void updateConfig(ForceGraphConfig config) {
    if (identical(config, _config)) return;
    _config = config;
    _applyForces();
  }

  ForceNode? nodeById(String id) => _byId[id];

  bool areNeighbors(String a, String b) => neighbors[a]?.contains(b) ?? false;

  void tick() => simulation.tick();

  void reheat([double target = 0.3]) => simulation.reheat(target);

  void _afterTick() {
    if (nodes.isEmpty) return;
    tickCount++;
    final recenterPos = tickCount <= _config.recenterTicks;

    var sumX = 0.0, sumY = 0.0, sumVx = 0.0, sumVy = 0.0;
    var count = 0;
    for (final n in nodes) {
      if (n.fx != null || n.fy != null) continue;
      sumX += n.x;
      sumY += n.y;
      sumVx += n.vx;
      sumVy += n.vy;
      count++;
    }
    if (count == 0) return;

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
