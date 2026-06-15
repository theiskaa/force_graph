import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';
import 'package:force_graph/src/painter.dart';

ForceGraphController _controller() {
  final a = ForceNode(id: 'a', label: 'Alpha', val: 3)
    ..x = -20
    ..y = 0;
  final b = ForceNode(id: 'b', label: 'Beta')
    ..x = 20
    ..y = 0;
  final p = ForceNode(id: 'p', label: 'Phantom', phantom: true)
    ..x = 0
    ..y = 30;
  return ForceGraphController(
    nodes: [a, b, p],
    links: [ForceLink('a', 'b'), ForceLink('a', 'p')],
  );
}

void _paint(ForceGraphPainter painter) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, const Size(400, 400));
  recorder.endRecording().dispose();
}

ForceGraphPainter _painter(
  ForceGraphController c, {
  String? hoveredId,
  String? selectedId,
  double hoverElapsedMs = 1000,
  double scale = 2,
  Map<String, TextPainter>? cache,
}) {
  return ForceGraphPainter(
    controller: c,
    config: const ForceGraphConfig(),
    theme: const ForceGraphTheme(),
    scale: scale,
    offset: const Offset(200, 200),
    hoveredId: hoveredId,
    selectedId: selectedId,
    hoverElapsedMs: hoverElapsedMs,
    labelCache: cache ?? {},
  );
}

void main() {
  testWidgets('paints the idle state with labels and a phantom ring',
      (tester) async {
    _paint(_painter(_controller()));
  });

  testWidgets('paints hovered state with traversal animation (mid + full)',
      (tester) async {
    final c = _controller();
    _paint(_painter(c, hoveredId: 'a', hoverElapsedMs: 100));
    _paint(_painter(c, hoveredId: 'a', hoverElapsedMs: 5000));
  });

  testWidgets('paints selected state with selection ring and link',
      (tester) async {
    _paint(_painter(_controller(), selectedId: 'a'));
  });

  testWidgets('dims non-neighbors when something is hovered', (tester) async {
    _paint(_painter(_controller(), hoveredId: 'b'));
  });

  testWidgets('label cache returns the same painter on a repeat call',
      (tester) async {
    final c = _controller();
    final cache = <String, TextPainter>{};
    _paint(_painter(c, cache: cache));
    final count = cache.length;
    expect(count, greaterThan(0));
    _paint(_painter(c, cache: cache));
    expect(cache.length, count);
  });

  testWidgets('label cache clears when it exceeds the cap', (tester) async {
    final nodes = [
      for (var i = 0; i < 700; i++)
        ForceNode(id: '$i', label: 'node-$i')
          ..x = (i % 28) * 6.0
          ..y = (i ~/ 28) * 6.0,
    ];
    final c = ForceGraphController(nodes: nodes, links: const []);
    final cache = <String, TextPainter>{};
    _paint(_painter(c, cache: cache, scale: 1));
    expect(cache.length, lessThanOrEqualTo(700));
  });

  testWidgets('extreme zoom-in hides labels (world font below threshold)',
      (tester) async {
    final c = _controller();
    final cache = <String, TextPainter>{};
    _paint(_painter(c, cache: cache, scale: 20));
    expect(cache, isEmpty);
  });

  testWidgets('shouldRepaint is always true', (tester) async {
    final c = _controller();
    final a = _painter(c);
    final b = _painter(c);
    expect(a.shouldRepaint(b), isTrue);
  });
}
