import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';
import 'package:force_graph/src/lcg.dart';

class _RecordingForce implements Force {
  int initCount = 0;
  int applyCount = 0;
  double lastAlpha = 0;

  @override
  void initialize(List<ForceNode> nodes, Lcg random) => initCount++;

  @override
  void apply(double alpha) {
    applyCount++;
    lastAlpha = alpha;
  }
}

void main() {
  test('initializeNodes seeds positions and indices', () {
    final nodes = [for (var i = 0; i < 5; i++) ForceNode(id: '$i')];
    final sim = ForceSimulation(nodes);
    for (var i = 0; i < nodes.length; i++) {
      expect(nodes[i].index, i);
      expect(nodes[i].x.isNaN, isFalse);
      expect(nodes[i].y.isNaN, isFalse);
    }
    expect(sim.alpha, 1);
  });

  test('pinned nodes seed from fx/fy and stay put on tick', () {
    final pinned = ForceNode(id: 'p')
      ..fx = 12
      ..fy = -7;
    final sim = ForceSimulation([pinned]);
    expect(pinned.x, 12);
    expect(pinned.y, -7);
    sim.tick();
    expect(pinned.x, 12);
    expect(pinned.y, -7);
    expect(pinned.vx, 0);
    expect(pinned.vy, 0);
  });

  test('NaN velocities are reset on initialize', () {
    final n = ForceNode(id: 'a')
      ..x = 1
      ..y = 1
      ..vx = double.nan
      ..vy = double.nan;
    ForceSimulation([n]).initializeNodes();
    expect(n.vx, 0);
    expect(n.vy, 0);
  });

  test('free node integrates velocity with retain factor', () {
    final n = ForceNode(id: 'a')
      ..x = 0
      ..y = 0
      ..vx = 10
      ..vy = 0;
    final sim = ForceSimulation([n]);
    sim.velocityRetain = 0.6;
    sim.tick();
    expect(n.vx, closeTo(6, 1e-9));
    expect(n.x, closeTo(6, 1e-9));
  });

  test('alpha decays toward alphaTarget', () {
    final sim = ForceSimulation([ForceNode(id: 'a')..x = 0..y = 0]);
    sim.alphaTarget = 0;
    sim.alphaDecay = 0.5;
    final before = sim.alpha;
    sim.tick();
    expect(sim.alpha, lessThan(before));
  });

  test('forces are initialized, applied, cleared and reinitialized', () {
    final sim = ForceSimulation([ForceNode(id: 'a')..x = 0..y = 0]);
    final f = _RecordingForce();
    sim.addForce(f);
    expect(f.initCount, 1);
    sim.tick();
    expect(f.applyCount, 1);
    expect(f.lastAlpha, sim.alpha);
    sim.reinitialize();
    expect(f.initCount, 2);
    sim.clearForces();
    sim.tick();
    expect(f.applyCount, 1);
  });

  test('reheat raises alpha but never lowers it', () {
    final sim = ForceSimulation([ForceNode(id: 'a')..x = 0..y = 0]);
    sim.alpha = 0.01;
    sim.reheat(0.5);
    expect(sim.alpha, 0.5);
    sim.reheat(0.1);
    expect(sim.alpha, 0.5);
  });

  test('onTick callback fires after integration', () {
    var called = 0;
    final sim = ForceSimulation([ForceNode(id: 'a')..x = 0..y = 0]);
    sim.onTick = () => called++;
    sim.tick();
    sim.tick();
    expect(called, 2);
  });
}
