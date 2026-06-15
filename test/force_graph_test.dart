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
}
