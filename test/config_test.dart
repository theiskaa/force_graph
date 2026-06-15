import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';

void main() {
  test('default config values', () {
    const c = ForceGraphConfig();
    expect(c.chargeStrength, -600);
    expect(c.chargeDistanceMax, 800);
    expect(c.linkDistance, 160);
    expect(c.linkStrength, 0.08);
    expect(c.alphaDecay, 0.008);
    expect(c.alphaTarget, 0.02);
    expect(c.dragAlphaTarget, 0.3);
    expect(c.velocityDecay, 0.4);
    expect(c.idleSleep, isTrue);
    expect(c.labelMinWorldFontSize, 1.5);
    expect(c.velocityRetain, closeTo(0.6, 1e-12));
  });

  test('mobile factory uses lighter values', () {
    final m = ForceGraphConfig.mobile();
    expect(m.chargeStrength, -250);
    expect(m.linkDistance, 80);
    expect(m.hitRadiusMin, 12);
    expect(m.hitRadiusMultiplier, 1.5);
  });

  test('baseRadius handles zero/negative val', () {
    const c = ForceGraphConfig();
    expect(c.baseRadius(ForceNode(id: 'z', val: 0)),
        c.baseRadius(ForceNode(id: 'o', val: 1)));
    expect(c.baseRadius(ForceNode(id: 'n', val: -4)),
        c.baseRadius(ForceNode(id: 'o', val: 1)));
    expect(c.baseRadius(ForceNode(id: 'f', val: 4)), closeTo(12.5, 1e-9));
  });

  test('zoomFactor clamps at both ends and varies in between', () {
    const c = ForceGraphConfig();
    expect(c.zoomFactor(1000), c.zoomFactorMin);
    expect(c.zoomFactor(0.0001), c.zoomFactorMax);
    final mid = c.zoomFactor(1);
    expect(mid, greaterThanOrEqualTo(c.zoomFactorMin));
    expect(mid, lessThanOrEqualTo(c.zoomFactorMax));
  });

  test('nodeRadius and collideRadius derive from baseRadius', () {
    const c = ForceGraphConfig();
    final n = ForceNode(id: 'a', val: 4);
    expect(c.nodeRadius(n, 1), c.baseRadius(n) * c.zoomFactor(1));
    expect(c.collideRadius(n),
        c.baseRadius(n) * c.zoomFactorMax + c.collidePadding);
  });

  test('copyWith with no args is an equal-valued copy', () {
    const c = ForceGraphConfig();
    final copy = c.copyWith();
    expect(copy.chargeStrength, c.chargeStrength);
    expect(copy.idleSleep, c.idleSleep);
    expect(copy.labelMinWorldFontSize, c.labelMinWorldFontSize);
  });

  test('copyWith overrides every field', () {
    const c = ForceGraphConfig();
    final o = c.copyWith(
      chargeStrength: 1,
      chargeDistanceMax: 2,
      linkDistance: 3,
      linkStrength: 4,
      linkIterations: 5,
      collidePadding: 6,
      collideIterations: 7,
      alphaDecay: 8,
      alphaTarget: 9,
      dragAlphaTarget: 10,
      velocityDecay: 11,
      recenterTicks: 12,
      idleSleep: false,
      sleepSpeedThreshold: 13,
      sleepFrames: 14,
      radiusScale: 15,
      radiusBase: 16,
      zoomK: 17,
      zoomFactorMin: 18,
      zoomFactorMax: 19,
      minZoom: 20,
      maxZoom: 21,
      labelFontSize: 22,
      labelMaxFontSize: 23,
      labelMinWorldFontSize: 24,
      hitRadiusMultiplier: 25,
      hitRadiusMin: 26,
    );
    expect(o.chargeStrength, 1);
    expect(o.idleSleep, isFalse);
    expect(o.sleepFrames, 14);
    expect(o.maxZoom, 21);
    expect(o.hitRadiusMin, 26);
  });

  test('theme defaults and light variant', () {
    const dark = ForceGraphTheme();
    expect(dark.background.toARGB32(), 0xFF262626);
    expect(dark.fontFamily, isNull);
    final light = ForceGraphTheme.light(fontFamily: 'Inter');
    expect(light.background, isNot(dark.background));
    expect(light.fontFamily, 'Inter');
  });
}
