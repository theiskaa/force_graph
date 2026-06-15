import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  test('builds neighbor map and id lookup, dropping dangling links', () {
    final nodes = [ForceNode(id: 'a'), ForceNode(id: 'b'), ForceNode(id: 'c')];
    final links = [
      ForceLink('a', 'b'),
      ForceLink('b', 'c'),
      ForceLink('a', 'ghost'),
    ];
    final c = ForceGraphController(nodes: nodes, links: links);
    expect(c.links.length, 2);
    expect(c.nodeById('b')!.id, 'b');
    expect(c.nodeById('missing'), isNull);
    expect(c.areNeighbors('a', 'b'), isTrue);
    expect(c.areNeighbors('a', 'c'), isFalse);
  });

  test('tick increments tickCount and updates kinetic energy', () {
    final nodes = [ForceNode(id: 'a'), ForceNode(id: 'b')];
    final c = ForceGraphController(nodes: nodes, links: [ForceLink('a', 'b')]);
    c.tick();
    c.tick();
    expect(c.tickCount, 2);
    expect(c.meanKineticEnergy, isNonNegative);
  });

  test('updateConfig is a no-op for the same instance and rebuilds otherwise',
      () {
    const cfg = ForceGraphConfig();
    final c = ForceGraphController(
        nodes: [ForceNode(id: 'a')], links: const [], config: cfg);
    c.updateConfig(cfg);
    expect(c.config, same(cfg));
    final next = cfg.copyWith(linkDistance: 99);
    c.updateConfig(next);
    expect(c.config.linkDistance, 99);
  });

  test('empty graph ticks safely with zero kinetic energy', () {
    final c = ForceGraphController(nodes: [], links: const []);
    c.tick();
    expect(c.meanKineticEnergy, 0);
  });

  test('recenter pulls the centroid toward the origin early on', () {
    final nodes = [
      ForceNode(id: 'a')..x = 1000..y = 1000,
      ForceNode(id: 'b')..x = 1100..y = 1100,
    ];
    final c = ForceGraphController(nodes: nodes, links: const []);
    for (var i = 0; i < 50; i++) {
      c.tick();
    }
    final cx = (nodes[0].x + nodes[1].x) / 2;
    final cy = (nodes[0].y + nodes[1].y) / 2;
    expect(cx.abs(), lessThan(1000));
    expect(cy.abs(), lessThan(1000));
  });

  test('pinned nodes are excluded from recenter/damping', () {
    final pinned = ForceNode(id: 'p')
      ..x = 50
      ..y = 50
      ..fx = 50
      ..fy = 50;
    final free = ForceNode(id: 'f')..x = 60..y = 60;
    final c = ForceGraphController(nodes: [pinned, free], links: const []);
    c.tick();
    expect(pinned.x, 50);
    expect(pinned.y, 50);
  });

  test('reheat delegates to the simulation', () {
    final c = ForceGraphController(nodes: [ForceNode(id: 'a')], links: const []);
    c.simulation.alpha = 0.01;
    c.reheat(0.4);
    expect(c.simulation.alpha, 0.4);
  });
}
