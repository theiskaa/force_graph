import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:force_graph/src/models.dart';

@immutable
class ForceGraphConfig {
  const ForceGraphConfig({
    this.chargeStrength = -600,
    this.chargeDistanceMax = 800,
    this.linkDistance = 160,
    this.linkStrength = 0.08,
    this.linkIterations = 1,
    this.collidePadding = 2,
    this.collideIterations = 3,
    this.alphaDecay = 0.008,
    this.alphaTarget = 0.02,
    this.velocityDecay = 0.4,
    this.recenterTicks = 300,
    this.radiusScale = 4.5,
    this.radiusBase = 3.5,
    this.zoomK = 0.65,
    this.zoomFactorMin = 0.6,
    this.zoomFactorMax = 1.6,
    this.minZoom = 0.05,
    this.maxZoom = 8,
    this.labelFontSize = 11,
    this.labelMaxFontSize = 13,
    this.labelMinScreenFontSize = 1.5,
    this.hitRadiusMultiplier = 1,
    this.hitRadiusMin = 0,
  });

  factory ForceGraphConfig.mobile() => const ForceGraphConfig(
        chargeStrength: -250,
        chargeDistanceMax: 400,
        linkDistance: 80,
        linkStrength: 0.2,
        collidePadding: 1.5,
        radiusScale: 3,
        radiusBase: 2.5,
        labelFontSize: 9,
        labelMaxFontSize: 11,
        hitRadiusMultiplier: 1.5,
        hitRadiusMin: 12,
      );

  final double chargeStrength;
  final double chargeDistanceMax;
  final double linkDistance;
  final double linkStrength;
  final int linkIterations;
  final double collidePadding;
  final int collideIterations;
  final double alphaDecay;
  final double alphaTarget;
  final double velocityDecay;
  final int recenterTicks;
  final double radiusScale;
  final double radiusBase;
  final double zoomK;
  final double zoomFactorMin;
  final double zoomFactorMax;
  final double minZoom;
  final double maxZoom;
  final double labelFontSize;
  final double labelMaxFontSize;
  final double labelMinScreenFontSize;
  final double hitRadiusMultiplier;
  final double hitRadiusMin;

  double baseRadius(ForceNode node) {
    final connections = node.val <= 0 ? 1.0 : node.val;
    return math.sqrt(connections) * radiusScale + radiusBase;
  }

  double zoomFactor(double scale) {
    return math.min(
      zoomFactorMax,
      math.max(zoomFactorMin, math.pow(scale, zoomK - 1).toDouble()),
    );
  }

  double nodeRadius(ForceNode node, double scale) {
    return baseRadius(node) * zoomFactor(scale);
  }

  double collideRadius(ForceNode node) {
    return baseRadius(node) * zoomFactorMax + collidePadding;
  }

  double get velocityRetain => 1 - velocityDecay;

  ForceGraphConfig copyWith({
    double? chargeStrength,
    double? chargeDistanceMax,
    double? linkDistance,
    double? linkStrength,
    int? linkIterations,
    double? collidePadding,
    int? collideIterations,
    double? alphaDecay,
    double? alphaTarget,
    double? velocityDecay,
    int? recenterTicks,
    double? radiusScale,
    double? radiusBase,
    double? zoomK,
    double? zoomFactorMin,
    double? zoomFactorMax,
    double? minZoom,
    double? maxZoom,
    double? labelFontSize,
    double? labelMaxFontSize,
    double? labelMinScreenFontSize,
    double? hitRadiusMultiplier,
    double? hitRadiusMin,
  }) {
    return ForceGraphConfig(
      chargeStrength: chargeStrength ?? this.chargeStrength,
      chargeDistanceMax: chargeDistanceMax ?? this.chargeDistanceMax,
      linkDistance: linkDistance ?? this.linkDistance,
      linkStrength: linkStrength ?? this.linkStrength,
      linkIterations: linkIterations ?? this.linkIterations,
      collidePadding: collidePadding ?? this.collidePadding,
      collideIterations: collideIterations ?? this.collideIterations,
      alphaDecay: alphaDecay ?? this.alphaDecay,
      alphaTarget: alphaTarget ?? this.alphaTarget,
      velocityDecay: velocityDecay ?? this.velocityDecay,
      recenterTicks: recenterTicks ?? this.recenterTicks,
      radiusScale: radiusScale ?? this.radiusScale,
      radiusBase: radiusBase ?? this.radiusBase,
      zoomK: zoomK ?? this.zoomK,
      zoomFactorMin: zoomFactorMin ?? this.zoomFactorMin,
      zoomFactorMax: zoomFactorMax ?? this.zoomFactorMax,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      labelMaxFontSize: labelMaxFontSize ?? this.labelMaxFontSize,
      labelMinScreenFontSize:
          labelMinScreenFontSize ?? this.labelMinScreenFontSize,
      hitRadiusMultiplier: hitRadiusMultiplier ?? this.hitRadiusMultiplier,
      hitRadiusMin: hitRadiusMin ?? this.hitRadiusMin,
    );
  }
}

@immutable
class ForceGraphTheme {
  const ForceGraphTheme({
    this.background = const Color(0xFF262626),
    this.line = const Color(0x2E5A5A69),
    this.lineHover = const Color(0x8C9696A5),
    this.lineDim = const Color(0x0F464650),
    this.nodeDim = const Color(0x40505A5A),
    this.label = const Color(0x80A0A0AF),
    this.labelHover = const Color(0xE6D2D2DC),
    this.labelDim = const Color(0x14A0A0AF),
    this.ring = const Color(0x4CDCDCE6),
    this.traverseTrail = const Color(0x145A5A69),
    this.traverseHead = const Color(0xFFA0A0B4),
    this.fontFamily,
  });

  final Color background;
  final Color line;
  final Color lineHover;
  final Color lineDim;
  final Color nodeDim;
  final Color label;
  final Color labelHover;
  final Color labelDim;
  final Color ring;
  final Color traverseTrail;
  final Color traverseHead;
  final String? fontFamily;
}
