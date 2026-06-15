import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:force_graph/src/config.dart';
import 'package:force_graph/src/controller.dart';

/// Paints the graph: links beneath nodes, with hover/selection highlighting, an
/// animated link-traversal effect, and labels.
///
/// Everything is drawn in screen space from the world-space node positions via
/// [scale] and [offset]. Hover and traversal animations are driven by
/// [hoverElapsedMs] (milliseconds since the current hover began).
class ForceGraphPainter extends CustomPainter {
  ForceGraphPainter({
    required this.controller,
    required this.config,
    required this.theme,
    required this.scale,
    required this.offset,
    required this.hoveredId,
    required this.selectedId,
    required this.hoverElapsedMs,
    required this.labelCache,
  });

  final ForceGraphController controller;
  final ForceGraphConfig config;
  final ForceGraphTheme theme;

  /// View zoom.
  final double scale;

  /// View pan, in screen pixels.
  final Offset offset;

  /// Currently hovered / selected node ids, or null.
  final String? hoveredId;
  final String? selectedId;

  /// Milliseconds since the current hover began; drives the fade animations.
  final double hoverElapsedMs;

  /// Cross-frame cache of laid-out label painters, owned by the widget state.
  final Map<String, TextPainter> labelCache;

  /// Returns a cached (or freshly laid-out) label painter for the given text,
  /// colour, and size.
  TextPainter _label(String text, Color color, double fontSize) {
    final key = '$text|${fontSize.toStringAsFixed(1)}|${color.toARGB32()}';
    final cached = labelCache[key];
    if (cached != null) return cached;
    if (labelCache.length > 600) labelCache.clear();
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: theme.fontFamily,
          fontWeight: FontWeight.w400,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    labelCache[key] = tp;
    return tp;
  }

  /// Maps a world-space point to screen-space.
  Offset _screen(double x, double y) =>
      Offset(x * scale + offset.dx, y * scale + offset.dy);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = theme.background);

    final hovered = hoveredId;
    final somethingHovered = hovered != null;

    final linkPaint = Paint()..style = PaintingStyle.stroke;
    for (final link in controller.links) {
      final src = link.sourceNode;
      final tgt = link.targetNode;
      final sp = _screen(src.x, src.y);
      final tp = _screen(tgt.x, tgt.y);

      final isHoveredLink =
          somethingHovered && (src.id == hovered || tgt.id == hovered);
      final isSelectedLink = selectedId != null &&
          (src.id == selectedId || tgt.id == selectedId);

      if (isHoveredLink) {
        final progress = math.min(hoverElapsedMs / 300, 1).toDouble();
        final eased = 1 - math.pow(1 - progress, 3).toDouble();

        final from = src.id == hovered ? sp : tp;
        final to = src.id == hovered ? tp : sp;
        final mid = Offset(
          from.dx + (to.dx - from.dx) * eased,
          from.dy + (to.dy - from.dy) * eased,
        );

        if (eased < 1) {
          linkPaint
            ..color = theme.traverseTrail
            ..strokeWidth = 0.5;
          canvas.drawLine(mid, to, linkPaint);
        }
        linkPaint
          ..color = theme.traverseHead
              .withValues(alpha: 0.2 + eased * 0.4)
          ..strokeWidth = 1.0 + eased * 0.6;
        canvas.drawLine(from, mid, linkPaint);
      } else if (isSelectedLink) {
        linkPaint
          ..color = theme.lineHover
          ..strokeWidth = 1.2;
        canvas.drawLine(sp, tp, linkPaint);
      } else if (somethingHovered) {
        linkPaint
          ..color = theme.lineDim
          ..strokeWidth = 0.6;
        canvas.drawLine(sp, tp, linkPaint);
      } else {
        linkPaint
          ..color = theme.line
          ..strokeWidth = 1.0;
        canvas.drawLine(sp, tp, linkPaint);
      }
    }

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke;

    for (final node in controller.nodes) {
      final isSelected = node.id == selectedId;
      final isHovered = node.id == hovered;
      final isNeighbor =
          hovered != null && controller.areNeighbors(hovered, node.id);
      final isDimmed = somethingHovered && !isHovered && !isNeighbor;

      final radius = config.nodeRadius(node, scale) * scale;
      final pos = _screen(node.x, node.y);

      var nodeAlpha = 1.0;
      if (somethingHovered && isNeighbor) {
        nodeAlpha = math.min(hoverElapsedMs / 350, 1).toDouble();
      }

      if (isDimmed) {
        fill.color = theme.nodeDim;
      } else if (node.phantom) {
        final a = isNeighbor && nodeAlpha < 1 ? 0.3 + nodeAlpha * 0.7 : 0.5;
        fill.color = node.color.withValues(alpha: a);
      } else {
        final a = isNeighbor && nodeAlpha < 1 ? 0.3 + nodeAlpha * 0.7 : 1.0;
        fill.color = node.color.withValues(alpha: a);
      }
      canvas.drawCircle(pos, radius, fill);

      if (node.phantom && !isDimmed) {
        stroke
          ..color = theme.ring
          ..strokeWidth = 0.8;
        _dashedCircle(canvas, pos, radius + 2 * scale, stroke);
      }

      if (isHovered || isSelected) {
        stroke
          ..color = theme.ring
          ..strokeWidth = 1.2;
        canvas.drawCircle(pos, radius + 2.5 * scale, stroke);
      }

      final worldFont = math.min(
          config.labelFontSize / scale, config.labelMaxFontSize);
      if (worldFont >= config.labelMinWorldFontSize && node.label.isNotEmpty) {
        final screenFont = worldFont * scale;
        Color labelColor;
        if (isDimmed) {
          labelColor = theme.labelDim;
        } else if (isHovered || isSelected) {
          labelColor = theme.labelHover;
        } else {
          labelColor = theme.label;
        }
        final tp = _label(node.label, labelColor, screenFont);
        tp.paint(
          canvas,
          Offset(pos.dx - tp.width / 2, pos.dy + radius + 4 * scale),
        );
      }
    }
  }

  /// Strokes a dashed circle, used for the phantom-node ring.
  void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dash = 2.0;
    if (radius <= 0) return;
    final circumference = 2 * math.pi * radius;
    final steps = (circumference / (dash * 2)).floor().clamp(1, 2000);
    final sweep = math.pi * 2 / steps;
    final path = ui.Path();
    for (var i = 0; i < steps; i++) {
      final start = i * sweep;
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep / 2,
      );
    }
    canvas.drawPath(path, paint);
  }

  // Always repaints: the widget only rebuilds this painter on ticker frames,
  // and node positions change every tick, so there is nothing to diff against.
  @override
  bool shouldRepaint(covariant ForceGraphPainter old) => true;
}
