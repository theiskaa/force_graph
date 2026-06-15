import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  test('ForceNode defaults', () {
    final n = ForceNode(id: 'a');
    expect(n.id, 'a');
    expect(n.label, '');
    expect(n.color, const Color(0xFF888888));
    expect(n.val, 1);
    expect(n.phantom, isFalse);
    expect(n.data, isNull);
    expect(n.x.isNaN, isTrue);
    expect(n.y.isNaN, isTrue);
    expect(n.vx, 0);
    expect(n.vy, 0);
    expect(n.fx, isNull);
    expect(n.fy, isNull);
    expect(n.index, 0);
  });

  test('ForceNode custom values and mutable state', () {
    final n = ForceNode(
      id: 'b',
      label: 'Beta',
      color: const Color(0xFF112233),
      val: 5,
      phantom: true,
      data: {'k': 'v'},
    );
    expect(n.label, 'Beta');
    expect(n.color, const Color(0xFF112233));
    expect(n.val, 5);
    expect(n.phantom, isTrue);
    expect((n.data as Map)['k'], 'v');
    n
      ..x = 1
      ..y = 2
      ..vx = 3
      ..vy = 4
      ..fx = 5
      ..fy = 6
      ..index = 7;
    expect([n.x, n.y, n.vx, n.vy, n.fx, n.fy, n.index], [1, 2, 3, 4, 5, 6, 7]);
  });

  test('ForceLink defaults and fields', () {
    final l = ForceLink('a', 'b');
    expect(l.source, 'a');
    expect(l.target, 'b');
    expect(l.reason, '');
    final r = ForceLink('a', 'b', reason: 'because');
    expect(r.reason, 'because');
  });
}
