import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  test('simulation settles connected nodes to finite positions', () {
    final nodes = [
      ForceNode(id: 'a', val: 1),
      ForceNode(id: 'b', val: 1),
    ];
    final links = [ForceLink('a', 'b')];
    final controller = ForceGraphController(
      nodes: nodes,
      links: links,
      config: const ForceGraphConfig(),
    );

    for (var i = 0; i < 600; i++) {
      controller.tick();
    }

    final a = controller.nodeById('a')!;
    final b = controller.nodeById('b')!;
    expect(a.x.isFinite, isTrue);
    expect(b.x.isFinite, isTrue);
  });

  test('charge keeps a large graph finite', () {
    final nodes = [for (var i = 0; i < 200; i++) ForceNode(id: '$i', val: 1)];
    final links = [
      for (var i = 1; i < 200; i++) ForceLink('${i - 1}', '$i'),
    ];
    final controller = ForceGraphController(nodes: nodes, links: links);
    for (var i = 0; i < 300; i++) {
      controller.tick();
    }
    expect(nodes.every((n) => n.x.isFinite && n.y.isFinite), isTrue);
  });

  test('dangling links are dropped, not fatal', () {
    final nodes = [ForceNode(id: 'a'), ForceNode(id: 'b')];
    final links = [
      ForceLink('a', 'b'),
      ForceLink('a', 'ghost'),
      ForceLink('void', 'b'),
    ];
    final controller = ForceGraphController(nodes: nodes, links: links);
    expect(controller.links.length, 1);
    for (var i = 0; i < 100; i++) {
      controller.tick();
    }
    expect(nodes.every((n) => n.x.isFinite), isTrue);
  });

  test('coincident and near-coincident nodes do not hang the quadtree', () {
    final nodes = <ForceNode>[];
    for (var i = 0; i < 50; i++) {
      nodes.add(ForceNode(id: 'dup$i')
        ..x = 5
        ..y = 5);
    }
    for (var i = 0; i < 50; i++) {
      nodes.add(ForceNode(id: 'near$i')
        ..x = 5 + i * 1e-12
        ..y = 5);
    }
    final controller = ForceGraphController(nodes: nodes, links: const []);
    for (var i = 0; i < 300; i++) {
      controller.tick();
    }
    expect(nodes.every((n) => n.x.isFinite && n.y.isFinite), isTrue);
  });

  test('mean kinetic energy decays below the idle sleep threshold', () {
    final nodes = [for (var i = 0; i < 80; i++) ForceNode(id: '$i', val: 1)];
    final links = [
      for (var i = 1; i < 80; i++) ForceLink('${i - 1}', '$i'),
    ];
    const config = ForceGraphConfig();
    final controller =
        ForceGraphController(nodes: nodes, links: links, config: config);
    for (var i = 0; i < 1200; i++) {
      controller.tick();
    }
    expect(controller.meanKineticEnergy, lessThan(config.sleepSpeedThreshold),
        reason: 'settled energy ${controller.meanKineticEnergy} should be '
            'below sleepSpeedThreshold ${config.sleepSpeedThreshold}');
  });
}
