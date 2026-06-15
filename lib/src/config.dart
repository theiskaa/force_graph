import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:force_graph/src/models.dart';

/// Tunable physics, sizing, and interaction parameters for a [ForceGraphView].
///
/// The defaults mirror the Apeirron web graph (`components/Graph.tsx`) on
/// desktop; [ForceGraphConfig.mobile] supplies the lighter mobile variant. Pass
/// one as `config` and optionally another as `mobileConfig` and the widget
/// switches between them at the breakpoint.
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
    this.dragAlphaTarget = 0.3,
    this.velocityDecay = 0.4,
    this.recenterTicks = 300,
    this.idleSleep = true,
    this.sleepSpeedThreshold = 0.03,
    this.sleepFrames = 30,
    this.radiusScale = 4.5,
    this.radiusBase = 3.5,
    this.zoomK = 0.65,
    this.zoomFactorMin = 0.6,
    this.zoomFactorMax = 1.6,
    this.minZoom = 0.05,
    this.maxZoom = 8,
    this.labelFontSize = 11,
    this.labelMaxFontSize = 13,
    this.labelMinWorldFontSize = 1.5,
    this.hitRadiusMultiplier = 1,
    this.hitRadiusMin = 0,
  });

  /// The lighter parameter set used below the breakpoint: weaker charge, shorter
  /// links, smaller nodes, and a larger touch hit area.
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

  /// Many-body charge; negative repels.
  final double chargeStrength;

  /// Maximum charge interaction distance.
  final double chargeDistanceMax;

  /// Spring rest length for links.
  final double linkDistance;

  /// Spring stiffness for links, in `[0, 1]`.
  final double linkStrength;

  /// Link relaxation passes per tick.
  final int linkIterations;

  /// Extra gap added to each node's collision radius.
  final double collidePadding;

  /// Collision separation passes per tick.
  final int collideIterations;

  /// Fraction of the gap to [alphaTarget] closed each tick (cooling rate).
  final double alphaDecay;

  /// Resting heat floor; a small value keeps the layout gently alive.
  final double alphaTarget;

  /// Heat the layout is held at while a node is being dragged.
  final double dragAlphaTarget;

  /// Friction; the simulation retains `1 - velocityDecay` of velocity per tick.
  final double velocityDecay;

  /// Number of initial ticks during which the layout's centroid is pulled back
  /// to the origin (covers the chaotic spread-out phase).
  final int recenterTicks;

  /// When true the render loop halts once the layout settles and there is no
  /// interaction, and wakes again on input or data change.
  final bool idleSleep;

  /// Mean per-node kinetic energy below which the layout counts as settled.
  final double sleepSpeedThreshold;

  /// Consecutive settled frames required before the loop sleeps.
  final int sleepFrames;

  /// Node radius grows with `sqrt(val) * radiusScale`.
  final double radiusScale;

  /// Constant added to every node radius.
  final double radiusBase;

  /// Zoom damping exponent: drawn radius scales with `scale^zoomK`, keeping
  /// nodes readable at every zoom level.
  final double zoomK;

  /// Lower/upper clamps on the zoom-damping factor.
  final double zoomFactorMin;
  final double zoomFactorMax;

  /// Minimum and maximum view zoom.
  final double minZoom;
  final double maxZoom;

  /// Base label size (world units) and its upper clamp.
  final double labelFontSize;
  final double labelMaxFontSize;

  /// Labels are hidden when their world-space font drops below this (matching
  /// the web original, which hides labels only at extreme zoom-in).
  final double labelMinWorldFontSize;

  /// Touch hit-area is `max(radius * hitRadiusMultiplier, hitRadiusMin)`.
  final double hitRadiusMultiplier;
  final double hitRadiusMin;

  /// Base (unzoomed) radius of a node from its weight.
  double baseRadius(ForceNode node) {
    final connections = node.val <= 0 ? 1.0 : node.val;
    return math.sqrt(connections) * radiusScale + radiusBase;
  }

  /// Sub-linear zoom response so nodes stay readable; see [zoomK].
  double zoomFactor(double scale) {
    return math.min(
      zoomFactorMax,
      math.max(zoomFactorMin, math.pow(scale, zoomK - 1).toDouble()),
    );
  }

  /// World-space radius a node is drawn at for the given view [scale].
  double nodeRadius(ForceNode node, double scale) {
    return baseRadius(node) * zoomFactor(scale);
  }

  /// Collision radius (zoom-independent) used by the collide force.
  double collideRadius(ForceNode node) {
    return baseRadius(node) * zoomFactorMax + collidePadding;
  }

  /// Velocity multiplier per tick (d3 convention); see [velocityDecay].
  double get velocityRetain => 1 - velocityDecay;

  /// Returns a copy with the given fields replaced.
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
    double? dragAlphaTarget,
    double? velocityDecay,
    int? recenterTicks,
    bool? idleSleep,
    double? sleepSpeedThreshold,
    int? sleepFrames,
    double? radiusScale,
    double? radiusBase,
    double? zoomK,
    double? zoomFactorMin,
    double? zoomFactorMax,
    double? minZoom,
    double? maxZoom,
    double? labelFontSize,
    double? labelMaxFontSize,
    double? labelMinWorldFontSize,
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
      dragAlphaTarget: dragAlphaTarget ?? this.dragAlphaTarget,
      velocityDecay: velocityDecay ?? this.velocityDecay,
      recenterTicks: recenterTicks ?? this.recenterTicks,
      idleSleep: idleSleep ?? this.idleSleep,
      sleepSpeedThreshold: sleepSpeedThreshold ?? this.sleepSpeedThreshold,
      sleepFrames: sleepFrames ?? this.sleepFrames,
      radiusScale: radiusScale ?? this.radiusScale,
      radiusBase: radiusBase ?? this.radiusBase,
      zoomK: zoomK ?? this.zoomK,
      zoomFactorMin: zoomFactorMin ?? this.zoomFactorMin,
      zoomFactorMax: zoomFactorMax ?? this.zoomFactorMax,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      labelMaxFontSize: labelMaxFontSize ?? this.labelMaxFontSize,
      labelMinWorldFontSize:
          labelMinWorldFontSize ?? this.labelMinWorldFontSize,
      hitRadiusMultiplier: hitRadiusMultiplier ?? this.hitRadiusMultiplier,
      hitRadiusMin: hitRadiusMin ?? this.hitRadiusMin,
    );
  }
}

/// Colours and font used to paint the graph. Defaults reproduce the Apeirron
/// dark theme; [ForceGraphTheme.light] is a ready-made light variant.
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

  /// A light-background variant for use on light app themes.
  factory ForceGraphTheme.light({String? fontFamily}) => ForceGraphTheme(
        background: const Color(0xFFF7F7F5),
        line: const Color(0x2E5A5A69),
        lineHover: const Color(0x8C44444F),
        lineDim: const Color(0x0F8A8A95),
        nodeDim: const Color(0x40A0A0AA),
        label: const Color(0x99454552),
        labelHover: const Color(0xF21A1A22),
        labelDim: const Color(0x1A454552),
        ring: const Color(0x66333340),
        traverseTrail: const Color(0x148A8A95),
        traverseHead: const Color(0xFF55556A),
        fontFamily: fontFamily,
      );

  /// Canvas background colour.
  final Color background;

  /// Default link colour, and its hovered/dimmed variants.
  final Color line;
  final Color lineHover;
  final Color lineDim;

  /// Fill applied to nodes dimmed while another node is focused.
  final Color nodeDim;

  /// Default label colour, and its hovered/dimmed variants.
  final Color label;
  final Color labelHover;
  final Color labelDim;

  /// Outline ring drawn around hovered, selected, and phantom nodes.
  final Color ring;

  /// Colours of the animated link-traversal highlight (faint trail and head).
  final Color traverseTrail;
  final Color traverseHead;

  /// Optional font family for labels; null uses the platform default.
  final String? fontFamily;
}
