import 'dart:ui' show Color;

class ForceNode {
  ForceNode({
    required this.id,
    this.label = '',
    this.color = const Color(0xFF888888),
    this.val = 1,
    this.phantom = false,
    this.data,
  });

  final String id;
  final String label;
  final Color color;
  final double val;
  final bool phantom;
  final Object? data;

  double x = double.nan;
  double y = double.nan;
  double vx = 0;
  double vy = 0;
  double? fx;
  double? fy;
  int index = 0;
}

class ForceLink {
  ForceLink(this.source, this.target, {this.reason = ''});

  final String source;
  final String target;
  final String reason;

  late ForceNode sourceNode;
  late ForceNode targetNode;
  late double bias;
  late double strengthValue;
  late double distanceValue;
}
