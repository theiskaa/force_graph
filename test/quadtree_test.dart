import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/src/models.dart';
import 'package:force_graph/src/quadtree.dart';

ForceNode _at(String id, double x, double y) => ForceNode(id: id)
  ..x = x
  ..y = y;

void main() {
  test('empty tree has no root and visits are no-ops', () {
    final t = Quadtree([]);
    expect(t.root, isNull);
    var visited = 0;
    t.visit((n, a, b, c, d) {
      visited++;
      return false;
    });
    t.visitAfter((n, a, b, c, d) => visited++);
    expect(visited, 0);
  });

  test('single node is a leaf root', () {
    final t = Quadtree([_at('a', 1, 2)]);
    expect(t.root, isNotNull);
    expect(t.root!.isLeaf, isTrue);
  });

  test('distinct nodes subdivide; visitAfter sees every cell', () {
    final nodes = [
      _at('a', 0, 0),
      _at('b', 100, 0),
      _at('c', 0, 100),
      _at('d', 100, 100),
    ];
    final t = Quadtree(nodes);
    expect(t.root!.isLeaf, isFalse);
    var cells = 0;
    t.visitAfter((n, a, b, c, d) => cells++);
    expect(cells, greaterThanOrEqualTo(nodes.length));
  });

  test('coincident nodes chain instead of subdividing', () {
    final t = Quadtree([_at('a', 5, 5), _at('b', 5, 5), _at('c', 5, 5)]);
    expect(t.root!.isLeaf, isTrue);
    expect(t.root!.next, isNotNull);
  });

  test('coincident point at a deep leaf chains there', () {
    final t = Quadtree([_at('a', 0, 0), _at('b', 100, 100), _at('c', 0, 0)]);
    var chained = 0;
    t.visit((n, a, b, c, d) {
      if (n.isLeaf && n.next != null) chained++;
      return false;
    });
    expect(chained, 1);
  });

  test('huge span forces the split depth cap without hanging', () {
    final nodes = [
      _at('far', 1e18, 1e18),
      _at('p', 5, 5),
      _at('q', 5 + 1e-12, 5),
    ];
    final t = Quadtree(nodes);
    expect(t.root, isNotNull);
  });

  test('NaN coordinates are skipped', () {
    final good = _at('a', 1, 1);
    final bad = ForceNode(id: 'b')
      ..x = double.nan
      ..y = 1;
    final t = Quadtree([good, bad]);
    var leaves = 0;
    t.visit((n, a, b, c, d) {
      if (n.isLeaf && n.data != null) leaves++;
      return false;
    });
    expect(leaves, 1);
  });

  test('anticipate mode indexes by x+vx', () {
    final n = _at('a', 0, 0)
      ..vx = 10
      ..vy = 20;
    final t = Quadtree([n], anticipate: true);
    expect(t.x1, greaterThan(10));
  });

  test('visit pruning stops descent when callback returns true', () {
    final nodes = [for (var i = 0; i < 8; i++) _at('n$i', i * 20.0, 0)];
    final t = Quadtree(nodes);
    var visits = 0;
    t.visit((n, a, b, c, d) {
      visits++;
      return true;
    });
    expect(visits, 1);
  });
}
