import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/src/lcg.dart';

void main() {
  test('next stays in [0, 1) and is deterministic per seed', () {
    final a = Lcg();
    final b = Lcg();
    for (var i = 0; i < 100; i++) {
      final v = a.next();
      expect(v, greaterThanOrEqualTo(0));
      expect(v, lessThan(1));
      expect(v, b.next());
    }
  });

  test('next advances (not constant)', () {
    final g = Lcg();
    final first = g.next();
    final second = g.next();
    expect(first, isNot(second));
  });

  test('jiggle is a tiny symmetric perturbation', () {
    final g = Lcg();
    for (var i = 0; i < 100; i++) {
      final j = g.jiggle();
      expect(j.abs(), lessThan(0.5e-6));
    }
  });
}
