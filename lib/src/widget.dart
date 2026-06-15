import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:force_graph/src/config.dart';
import 'package:force_graph/src/controller.dart';
import 'package:force_graph/src/models.dart';
import 'package:force_graph/src/painter.dart';

/// Called with the node that was tapped.
typedef NodeCallback = void Function(ForceNode node);

/// Called with the hovered node, or null when the hover ends.
typedef NodeHoverCallback = void Function(ForceNode? node);

/// An interactive force-directed graph.
///
/// Runs a [ForceGraphController] over [nodes] and [links], paints them, and
/// handles pan, zoom, drag-to-pin, hover, and tap. The layout auto-fits on first
/// render (until the user interacts) and, by default, sleeps once it settles to
/// save CPU. Supply [config]/[mobileConfig] to tune physics and [theme] to
/// restyle.
class ForceGraphView extends StatefulWidget {
  const ForceGraphView({
    super.key,
    required this.nodes,
    required this.links,
    this.config = const ForceGraphConfig(),
    this.mobileConfig,
    this.breakpoint = 768,
    this.theme = const ForceGraphTheme(),
    this.selectedId,
    this.focusId,
    this.paused = false,
    this.autoFit = true,
    this.fitToken = 0,
    this.semanticLabel,
    this.onNodeTap,
    this.onNodeHover,
    this.onBackgroundTap,
    this.onReady,
  });

  /// Graph data. Changing the list identity rebuilds the simulation.
  final List<ForceNode> nodes;
  final List<ForceLink> links;

  /// Physics/sizing for wide layouts, and the optional variant used below
  /// [breakpoint] (defaults to [ForceGraphConfig.mobile]).
  final ForceGraphConfig config;
  final ForceGraphConfig? mobileConfig;

  /// Width below which [mobileConfig] applies.
  final double breakpoint;

  /// Colours and font.
  final ForceGraphTheme theme;

  /// Node drawn with a selection ring, controlled by the host.
  final String? selectedId;

  /// Setting this to a new id pans/zooms to centre that node.
  final String? focusId;

  /// Pauses the simulation while still allowing pan/zoom.
  final bool paused;

  /// Whether to auto-fit the graph on first render.
  final bool autoFit;

  /// Bump this to any new value to re-fit the graph on demand.
  final int fitToken;

  /// Accessibility label for the canvas.
  final String? semanticLabel;

  /// Tap / hover / background-tap callbacks.
  final NodeCallback? onNodeTap;
  final NodeHoverCallback? onNodeHover;
  final VoidCallback? onBackgroundTap;

  /// Called once with the controller after it is created, for advanced control.
  final void Function(ForceGraphController controller)? onReady;

  @override
  State<ForceGraphView> createState() => _ForceGraphViewState();
}

class _ForceGraphViewState extends State<ForceGraphView>
    with SingleTickerProviderStateMixin {
  late ForceGraphController _controller;
  late Ticker _ticker;
  late ForceGraphConfig _mobileConfig;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final Map<String, TextPainter> _labelCache = {};

  Size _size = Size.zero;
  bool _initialized = false;

  double _scale = 1;
  Offset _offset = Offset.zero;

  String? _hoveredId;
  String? _tappedId;
  double _hoverStartMs = 0;

  bool _userTookOver = false;

  int _quietFrames = 0;

  double _startScale = 1;
  Offset _startWorldFocal = Offset.zero;
  ForceNode? _dragNode;

  bool _fitRequested = false;
  bool _fitActive = false;
  Duration _fitStart = Duration.zero;
  static const Duration _fitDuration = Duration(milliseconds: 500);
  double _fitFromScale = 1, _fitToScale = 1;
  Offset _fitFromOffset = Offset.zero, _fitToOffset = Offset.zero;

  bool get _isMobile => _size.width > 0 && _size.width < widget.breakpoint;

  ForceGraphConfig get _effectiveConfig =>
      _isMobile ? _mobileConfig : widget.config;

  @override
  void initState() {
    super.initState();
    _mobileConfig = widget.mobileConfig ?? ForceGraphConfig.mobile();
    _controller = ForceGraphController(
      nodes: widget.nodes,
      links: widget.links,
      config: widget.config,
    );
    widget.onReady?.call(_controller);
    _ticker = createTicker(_onFrame)..start();
  }

  @override
  void didUpdateWidget(covariant ForceGraphView old) {
    super.didUpdateWidget(old);
    if (!identical(widget.mobileConfig, old.mobileConfig)) {
      _mobileConfig = widget.mobileConfig ?? ForceGraphConfig.mobile();
    }
    final dataChanged = !identical(widget.nodes, old.nodes) ||
        !identical(widget.links, old.links);
    if (dataChanged) {
      _rebuildController();
    } else {
      _controller.updateConfig(_effectiveConfig);
    }
    if (widget.focusId != null && widget.focusId != old.focusId) {
      _focusOn(widget.focusId!);
    }
    if (widget.fitToken != old.fitToken) {
      fitView();
    }
    if (widget.paused != old.paused && !widget.paused) {
      _wake();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// Recreates the controller after the node/link set changes and re-fits.
  void _rebuildController() {
    _controller = ForceGraphController(
      nodes: widget.nodes,
      links: widget.links,
      config: _effectiveConfig,
    );
    widget.onReady?.call(_controller);
    _userTookOver = false;
    _hoveredId = null;
    _tappedId = null;
    _dragNode = null;
    _labelCache.clear();
    _requestAutoFit();
    _wake();
  }

  /// The render loop: ticks the simulation, advances any fit animation, and —
  /// when [ForceGraphConfig.idleSleep] is on — stops the ticker once the layout
  /// has been settled and idle for [ForceGraphConfig.sleepFrames] frames.
  void _onFrame(Duration elapsed) {
    if (!widget.paused) _controller.tick();

    if (_fitRequested) {
      _fitRequested = false;
      _beginFit(elapsed);
    }
    if (_fitActive) {
      final t = ((elapsed - _fitStart).inMicroseconds /
              _fitDuration.inMicroseconds)
          .clamp(0.0, 1.0);
      final e = _easeInOutCubic(t);
      _scale = _fitFromScale + (_fitToScale - _fitFromScale) * e;
      _offset = Offset.lerp(_fitFromOffset, _fitToOffset, e)!;
      if (t >= 1) _fitActive = false;
    }

    final cfg = _effectiveConfig;
    if (cfg.idleSleep) {
      final active = _dragNode != null ||
          _fitActive ||
          _fitRequested ||
          (_hoveredId != null && _nowMs() - _hoverStartMs < 700);
      if (!active &&
          _controller.meanKineticEnergy < cfg.sleepSpeedThreshold) {
        if (++_quietFrames >= cfg.sleepFrames) {
          _frame.value++;
          _ticker.stop();
          return;
        }
      } else {
        _quietFrames = 0;
      }
    }

    _frame.value++;
  }

  /// Restarts the render loop if it has slept; called on any input or change.
  void _wake() {
    _quietFrames = 0;
    if (!_ticker.isActive) _ticker.start();
  }

  static double _easeInOutCubic(double t) {
    return t < 0.5
        ? 4 * t * t * t
        : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
  }

  /// Screen-to-world and world-to-screen transforms for the current view.
  Offset _toWorld(Offset screen) =>
      Offset((screen.dx - _offset.dx) / _scale, (screen.dy - _offset.dy) / _scale);

  Offset _toScreen(double x, double y) =>
      Offset(x * _scale + _offset.dx, y * _scale + _offset.dy);

  /// Returns the topmost node under a local point, or null. The hit area is
  /// enlarged on touch via [ForceGraphConfig.hitRadiusMultiplier]/`hitRadiusMin`.
  ForceNode? _hitTest(Offset local) {
    final cfg = _effectiveConfig;
    ForceNode? best;
    for (final n in _controller.nodes) {
      if (n.x.isNaN) continue;
      final pos = _toScreen(n.x, n.y);
      final wr = cfg.nodeRadius(n, _scale);
      final hit = math.max(wr * cfg.hitRadiusMultiplier, cfg.hitRadiusMin) * _scale;
      if ((local - pos).distance <= hit) best = n;
    }
    return best;
  }

  /// Marks that the user has taken control, cancelling auto-fit.
  void _takeOver() {
    _userTookOver = true;
    _fitActive = false;
    _fitRequested = false;
  }

  /// A single pointer landing on a node starts a drag (pinning it and heating
  /// the layout); otherwise the gesture pans/zooms the view.
  void _onScaleStart(ScaleStartDetails d) {
    _wake();
    _takeOver();
    _startScale = _scale;
    _startWorldFocal = _toWorld(d.localFocalPoint);
    if (d.pointerCount == 1) {
      final n = _hitTest(d.localFocalPoint);
      if (n != null) {
        _dragNode = n;
        n.fx = n.x;
        n.fy = n.y;
        _controller.simulation.alphaTarget = _effectiveConfig.dragAlphaTarget;
        _controller.reheat();
        return;
      }
    }
    _dragNode = null;
  }

  /// Drags the pinned node with a single pointer; a second finger releases the
  /// drag and the gesture becomes a pan/zoom that keeps the focal point fixed.
  void _onScaleUpdate(ScaleUpdateDetails d) {
    _wake();
    if (_dragNode != null) {
      if (d.pointerCount == 1) {
        final w = _toWorld(d.localFocalPoint);
        _dragNode!
          ..fx = w.dx
          ..fy = w.dy;
        return;
      }
      _releaseDrag();
    }
    final cfg = _effectiveConfig;
    final newScale =
        (_startScale * d.scale).clamp(cfg.minZoom, cfg.maxZoom).toDouble();
    _scale = newScale;
    _offset = d.localFocalPoint -
        Offset(_startWorldFocal.dx * newScale, _startWorldFocal.dy * newScale);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _releaseDrag();
  }

  /// Unpins the dragged node and restores the resting heat floor.
  void _releaseDrag() {
    if (_dragNode == null) return;
    _dragNode!
      ..fx = null
      ..fy = null;
    _dragNode = null;
    _controller.simulation.alphaTarget = _effectiveConfig.alphaTarget;
    _controller.reheat();
  }

  /// Taps a node (or the background). On touch, the first tap selects/hovers and
  /// a second tap on the same node fires [ForceGraphView.onNodeTap].
  void _onTapUp(TapUpDetails d) {
    _wake();
    _takeOver();
    final n = _hitTest(d.localPosition);
    if (n == null) {
      _setHovered(null);
      _tappedId = null;
      widget.onBackgroundTap?.call();
      return;
    }
    if (_isMobile) {
      if (_tappedId == n.id) {
        widget.onNodeTap?.call(n);
        _tappedId = null;
        _setHovered(null);
      } else {
        _tappedId = n.id;
        _setHovered(n.id);
      }
    } else {
      _setHovered(null);
      widget.onNodeTap?.call(n);
    }
  }

  void _onHover(PointerHoverEvent e) {
    if (_isMobile) return;
    final n = _hitTest(e.localPosition);
    _setHovered(n?.id);
  }

  /// Updates the hovered node (restarting the hover animation clock) and
  /// notifies the host.
  void _setHovered(String? id) {
    if (_hoveredId == id) return;
    _hoveredId = id;
    if (id != null) _hoverStartMs = _nowMs();
    _wake();
    widget.onNodeHover?.call(id == null ? null : _controller.nodeById(id));
  }

  double _nowMs() => DateTime.now().microsecondsSinceEpoch / 1000.0;

  /// Pans/zooms to centre the node with the given [id].
  void _focusOn(String id) {
    final n = _controller.nodeById(id);
    if (n == null || n.x.isNaN) return;
    _takeOver();
    final cfg = _effectiveConfig;
    final target = 3.0.clamp(cfg.minZoom, cfg.maxZoom).toDouble();
    _animateTo(
        target,
        Offset(_size.width / 2, _size.height / 2) -
            Offset(n.x * target, n.y * target));
    _setHovered(id);
  }

  /// Schedules the initial fit in two passes (early, then after the warmup
  /// spread settles), each skipped if the user has already taken over.
  void _requestAutoFit() {
    if (!widget.autoFit) return;
    for (final ms in const [300, 1200]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted || _userTookOver) return;
        fitView();
      });
    }
  }

  /// Animates the view to frame all nodes with the given [padding].
  void fitView({double? padding}) {
    if (_controller.nodes.isEmpty || _size == Size.zero) return;
    var minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;
    for (final n in _controller.nodes) {
      if (n.x.isNaN) continue;
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.y > maxY) maxY = n.y;
    }
    if (minX > maxX) return;
    final pad = padding ?? (_isMobile ? 40.0 : 120.0);
    final bboxW = math.max(maxX - minX, 1);
    final bboxH = math.max(maxY - minY, 1);
    final cfg = _effectiveConfig;
    final scale = math
        .min((_size.width - 2 * pad) / bboxW, (_size.height - 2 * pad) / bboxH)
        .clamp(cfg.minZoom, cfg.maxZoom)
        .toDouble();
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final offset = Offset(_size.width / 2, _size.height / 2) -
        Offset(cx * scale, cy * scale);
    _animateTo(scale, offset);
  }

  /// Queues a fit/focus animation from the current view to the target; the
  /// render loop starts it on the next frame so it has a frame-time origin.
  void _animateTo(double scale, Offset offset) {
    _fitFromScale = _scale;
    _fitToScale = scale;
    _fitFromOffset = _offset;
    _fitToOffset = offset;
    _fitActive = false;
    _fitRequested = true;
    _wake();
  }

  void _beginFit(Duration elapsed) {
    _fitStart = elapsed;
    _fitActive = true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _size) {
          _size = size;
          if (!_initialized && size.width > 0) {
            _initialized = true;
            _scale = 1;
            _offset = Offset(size.width / 2, size.height / 2);
            _controller.updateConfig(_effectiveConfig);
            _requestAutoFit();
          }
        }
        return Semantics(
          image: true,
          label: widget.semanticLabel ?? 'Force-directed graph',
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: MouseRegion(
              onHover: _onHover,
              onExit: (_) => _setHovered(null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                onTapUp: _onTapUp,
                child: AnimatedBuilder(
                  animation: _frame,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: ForceGraphPainter(
                        controller: _controller,
                        config: _effectiveConfig,
                        theme: widget.theme,
                        scale: _scale,
                        offset: _offset,
                        hoveredId: _hoveredId,
                        selectedId: widget.selectedId,
                        hoverElapsedMs: _nowMs() - _hoverStartMs,
                        labelCache: _labelCache,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Mouse-wheel / trackpad zoom centred on the pointer.
  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    _wake();
    _takeOver();
    final cfg = _effectiveConfig;
    final delta = -e.scrollDelta.dy;
    final factor = math.exp(delta * 0.0015);
    final newScale =
        (_scale * factor).clamp(cfg.minZoom, cfg.maxZoom).toDouble();
    final world = _toWorld(e.localPosition);
    _scale = newScale;
    _offset = e.localPosition -
        Offset(world.dx * newScale, world.dy * newScale);
  }
}
