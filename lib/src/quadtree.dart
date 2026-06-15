import 'package:force_graph/src/models.dart';

class QuadNode {
  ForceNode? data;
  QuadNode? next;
  List<QuadNode?>? children;

  double value = 0;
  double cx = 0;
  double cy = 0;
  double r = 0;

  bool get isLeaf => children == null;
}

typedef QuadVisitor = bool Function(
    QuadNode node, double x0, double y0, double x1, double y1);

class Quadtree {
  QuadNode? root;
  late double x0, y0, x1, y1;
  final bool _anticipate;

  double _cx(ForceNode n) => _anticipate ? n.x + n.vx : n.x;
  double _cy(ForceNode n) => _anticipate ? n.y + n.vy : n.y;

  Quadtree(List<ForceNode> nodes, {bool anticipate = false})
      : _anticipate = anticipate {
    var minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;
    for (final n in nodes) {
      final px = anticipate ? n.x + n.vx : n.x;
      final py = anticipate ? n.y + n.vy : n.y;
      if (px < minX) minX = px;
      if (px > maxX) maxX = px;
      if (py < minY) minY = py;
      if (py > maxY) maxY = py;
    }
    if (minX > maxX) {
      minX = minY = 0;
      maxX = maxY = 1;
    }
    final span = (maxX - minX) > (maxY - minY) ? (maxX - minX) : (maxY - minY);
    x0 = minX;
    y0 = minY;
    x1 = minX + span + 1;
    y1 = minY + span + 1;

    for (final n in nodes) {
      _add(n, anticipate ? n.x + n.vx : n.x, anticipate ? n.y + n.vy : n.y);
    }
  }

  void _add(ForceNode d, double x, double y) {
    if (x.isNaN || y.isNaN) return;
    final leaf = QuadNode()..data = d;
    if (root == null) {
      root = leaf;
      return;
    }
    var node = root;
    var lx0 = x0, ly0 = y0, lx1 = x1, ly1 = y1;
    QuadNode? parent;
    var i = 0;
    while (node!.children != null) {
      final xm = (lx0 + lx1) / 2;
      final ym = (ly0 + ly1) / 2;
      final right = x >= xm;
      final bottom = y >= ym;
      if (right) {
        lx0 = xm;
      } else {
        lx1 = xm;
      }
      if (bottom) {
        ly0 = ym;
      } else {
        ly1 = ym;
      }
      parent = node;
      i = (bottom ? 2 : 0) | (right ? 1 : 0);
      final child = node.children![i];
      if (child == null) {
        node.children![i] = leaf;
        return;
      }
      node = child;
    }

    final exX = _cx(node.data!);
    final exY = _cy(node.data!);
    if (x == exX && y == exY) {
      leaf.next = node;
      if (parent != null) {
        parent.children![i] = leaf;
      } else {
        root = leaf;
      }
      return;
    }

    int j;
    var depth = 0;
    do {
      final created = List<QuadNode?>.filled(4, null);
      final internal = QuadNode()..children = created;
      if (parent != null) {
        parent.children![i] = internal;
      } else {
        root = internal;
      }
      parent = internal;
      final xm = (lx0 + lx1) / 2;
      final ym = (ly0 + ly1) / 2;
      final right = x >= xm;
      final bottom = y >= ym;
      if (right) {
        lx0 = xm;
      } else {
        lx1 = xm;
      }
      if (bottom) {
        ly0 = ym;
      } else {
        ly1 = ym;
      }
      i = (bottom ? 2 : 0) | (right ? 1 : 0);
      j = ((exY >= ym ? 2 : 0) | (exX >= xm ? 1 : 0));
      if (++depth > 64) {
        leaf.next = node;
        parent.children![i] = leaf;
        return;
      }
    } while (i == j);
    parent.children![j] = node;
    parent.children![i] = leaf;
  }

  void visitAfter(void Function(QuadNode, double, double, double, double) cb) {
    if (root == null) return;
    final stack = <_Quad>[_Quad(root!, x0, y0, x1, y1)];
    final ordered = <_Quad>[];
    while (stack.isNotEmpty) {
      final q = stack.removeLast();
      final node = q.node;
      if (node.children != null) {
        final xm = (q.x0 + q.x1) / 2, ym = (q.y0 + q.y1) / 2;
        final c = node.children!;
        if (c[0] != null) stack.add(_Quad(c[0]!, q.x0, q.y0, xm, ym));
        if (c[1] != null) stack.add(_Quad(c[1]!, xm, q.y0, q.x1, ym));
        if (c[2] != null) stack.add(_Quad(c[2]!, q.x0, ym, xm, q.y1));
        if (c[3] != null) stack.add(_Quad(c[3]!, xm, ym, q.x1, q.y1));
      }
      ordered.add(q);
    }
    for (var k = ordered.length - 1; k >= 0; k--) {
      final q = ordered[k];
      cb(q.node, q.x0, q.y0, q.x1, q.y1);
    }
  }

  void visit(QuadVisitor cb) {
    if (root == null) return;
    final stack = <_Quad>[_Quad(root!, x0, y0, x1, y1)];
    while (stack.isNotEmpty) {
      final q = stack.removeLast();
      final node = q.node;
      if (!cb(node, q.x0, q.y0, q.x1, q.y1) && node.children != null) {
        final xm = (q.x0 + q.x1) / 2, ym = (q.y0 + q.y1) / 2;
        final c = node.children!;
        if (c[3] != null) stack.add(_Quad(c[3]!, xm, ym, q.x1, q.y1));
        if (c[2] != null) stack.add(_Quad(c[2]!, q.x0, ym, xm, q.y1));
        if (c[1] != null) stack.add(_Quad(c[1]!, xm, q.y0, q.x1, ym));
        if (c[0] != null) stack.add(_Quad(c[0]!, q.x0, q.y0, xm, ym));
      }
    }
  }
}

class _Quad {
  _Quad(this.node, this.x0, this.y0, this.x1, this.y1);
  final QuadNode node;
  final double x0, y0, x1, y1;
}
