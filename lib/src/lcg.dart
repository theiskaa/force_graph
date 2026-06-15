class Lcg {
  static const int _a = 1664525;
  static const int _c = 1013904223;
  static const int _m = 4294967296;
  int _s = 1;

  double next() {
    _s = (_a * _s + _c) % _m;
    return _s / _m;
  }

  double jiggle() => (next() - 0.5) * 1e-6;
}
