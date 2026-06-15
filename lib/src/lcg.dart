/// A deterministic linear congruential generator, ported from d3-force's
/// internal `lcg`.
///
/// d3-force uses a seeded generator (rather than `Math.random`) so layouts are
/// reproducible run to run; matching its constants keeps the jiggle sequence in
/// step with the reference implementation.
class Lcg {
  static const int _a = 1664525;
  static const int _c = 1013904223;
  static const int _m = 4294967296;
  int _s = 1;

  /// Returns the next pseudo-random value in the range `[0, 1)`.
  double next() {
    _s = (_a * _s + _c) % _m;
    return _s / _m;
  }

  /// A tiny symmetric perturbation (magnitude `1e-6`) used to break ties when
  /// two bodies share the exact same coordinate, avoiding a divide-by-zero.
  double jiggle() => (next() - 0.5) * 1e-6;
}
