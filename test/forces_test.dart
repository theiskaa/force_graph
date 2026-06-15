import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';
import 'package:force_graph/src/lcg.dart';

void main() {
  group('ManyBodyForce', () {
    test('repels two separated nodes', () {
      final a = ForceNode(id: 'a')..x = -5..y = 0;
      final b = ForceNode(id: 'b')..x = 5..y = 0;
      final nodes = [a, b]..asMap().forEach((i, n) => n.index = i);
      final f = ManyBodyForce(strength: -100);
      f.initialize(nodes, Lcg());
      f.apply(1);
      expect(a.vx, lessThan(0));
      expect(b.vx, greaterThan(0));
    });

    test('coincident nodes are jiggled, not NaN', () {
      final a = ForceNode(id: 'a')..x = 0..y = 0;
      final b = ForceNode(id: 'b')..x = 0..y = 0;
      final nodes = [a, b]..asMap().forEach((i, n) => n.index = i);
      final f = ManyBodyForce(strength: -100);
      f.initialize(nodes, Lcg());
      f.apply(1);
      expect(a.vx.isFinite, isTrue);
      expect(b.vy.isFinite, isTrue);
    });

    test('distanceMax skips far interactions', () {
      final a = ForceNode(id: 'a')..x = 0..y = 0;
      final b = ForceNode(id: 'b')..x = 1000..y = 0;
      final nodes = [a, b]..asMap().forEach((i, n) => n.index = i);
      final f = ManyBodyForce(strength: -100, distanceMax: 10);
      f.initialize(nodes, Lcg());
      f.apply(1);
      expect(a.vx, 0);
    });

    test('large graph approximates via Barnes-Hut and stays finite', () {
      final nodes = [
        for (var i = 0; i < 60; i++)
          ForceNode(id: '$i')
            ..x = (i % 10) * 10.0
            ..y = (i ~/ 10) * 10.0
            ..index = i,
      ];
      final f = ManyBodyForce(strength: -50);
      f.initialize(nodes, Lcg());
      f.apply(1);
      expect(nodes.every((n) => n.vx.isFinite && n.vy.isFinite), isTrue);
    });
  });

  group('LinkForce', () {
    test('pulls a stretched link toward its rest distance', () {
      final a = ForceNode(id: 'a')..x = 0..y = 0..index = 0;
      final b = ForceNode(id: 'b')..x = 500..y = 0..index = 1;
      final link = ForceLink('a', 'b');
      final f = LinkForce([link], distance: 100, strength: 0.5);
      f.initialize([a, b], Lcg());
      expect(link.bias, closeTo(0.5, 1e-9));
      f.apply(1);
      expect(a.vx, greaterThan(0));
      expect(b.vx, lessThan(0));
    });

    test('coincident link endpoints are jiggled', () {
      final a = ForceNode(id: 'a')..x = 0..y = 0..index = 0;
      final b = ForceNode(id: 'b')..x = 0..y = 0..index = 1;
      final f = LinkForce([ForceLink('a', 'b')],
          distance: 30, strength: 0.5, iterations: 2);
      f.initialize([a, b], Lcg());
      f.apply(1);
      expect(a.vx.isFinite, isTrue);
    });
  });

  group('CollideForce', () {
    test('separates overlapping nodes', () {
      final a = ForceNode(id: 'a')..x = 0..y = 0..index = 0;
      final b = ForceNode(id: 'b')..x = 1..y = 0..index = 1;
      final f = CollideForce(radius: (_) => 10);
      f.initialize([a, b], Lcg());
      f.apply(1);
      expect(a.vx, lessThan(0));
      expect(b.vx, greaterThan(0));
    });

    test('leaves distant nodes untouched (prune path)', () {
      final a = ForceNode(id: 'a')..x = 0..y = 0..index = 0;
      final b = ForceNode(id: 'b')..x = 500..y = 0..index = 1;
      final f = CollideForce(radius: (_) => 5);
      f.initialize([a, b], Lcg());
      f.apply(1);
      expect(a.vx, 0);
      expect(b.vx, 0);
    });

    test('exactly coincident overlapping nodes are jiggled', () {
      final a = ForceNode(id: 'a')..x = 0..y = 0..index = 0;
      final b = ForceNode(id: 'b')..x = 0..y = 0..index = 1;
      final f = CollideForce(radius: (_) => 10);
      f.initialize([a, b], Lcg());
      f.apply(1);
      expect(a.vx.isFinite && a.vy.isFinite, isTrue);
    });
  });
}
