import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:force_graph/force_graph.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

ForceNode _pinned(String id) => ForceNode(id: id, label: id.toUpperCase())
  ..fx = 0
  ..fy = 0;

ForceNode _bigPinned(String id) => ForceNode(id: id, val: 400)
  ..fx = 0
  ..fy = 0;

void main() {
  testWidgets('renders a CustomPaint and ticks', (tester) async {
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
    )));
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('auto-fits in two passes without leaving pending timers',
      (tester) async {
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [
        ForceNode(id: 'a', val: 2),
        ForceNode(id: 'b'),
        ForceNode(id: 'c'),
      ],
      links: [ForceLink('a', 'b'), ForceLink('a', 'c')],
    )));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('desktop tap fires onNodeTap; background tap fires onBackgroundTap',
      (tester) async {
    final tapped = <String>[];
    var background = 0;
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
      onNodeTap: (n) => tapped.add(n.id),
      onBackgroundTap: () => background++,
    )));
    await tester.pump();
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(tapped, ['a']);
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(background, 1);
  });

  testWidgets('hover reports the node then clears', (tester) async {
    final hovers = <String?>[];
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
      onNodeHover: (n) => hovers.add(n?.id),
    )));
    await tester.pump();
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: const Offset(40, 40));
    addTearDown(g.removePointer);
    await g.moveTo(const Offset(400, 300));
    await tester.pump();
    await g.moveTo(const Offset(40, 40));
    await tester.pump();
    expect(hovers, contains('a'));
    expect(hovers.last, isNull);
  });

  testWidgets('mobile uses double-tap to confirm a node', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tapped = <String>[];
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
      onNodeTap: (n) => tapped.add(n.id),
    )));
    await tester.pump();
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(tapped, isEmpty);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(tapped, ['a']);
  });

  testWidgets('dragging a node pins and moves it', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_bigPinned('a')],
      links: const [],
      autoFit: false,
      onNodeTap: (n) => tapped.add(n.id),
    )));
    await tester.pump();
    final g = await tester.startGesture(const Offset(400, 300));
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(tapped, isEmpty);
  });

  testWidgets('panning an empty area does not throw', (tester) async {
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
    )));
    await tester.pump();
    final g = await tester.startGesture(const Offset(40, 40));
    await g.moveBy(const Offset(60, 60));
    await tester.pump();
    await g.up();
    await tester.pump();
  });

  testWidgets('scroll wheel zooms', (tester) async {
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
    )));
    await tester.pump();
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pump();
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pump();
  });

  testWidgets('a second finger releases the drag and pans', (tester) async {
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_bigPinned('a')],
      links: const [],
      autoFit: false,
    )));
    await tester.pump();
    final g1 = await tester.startGesture(const Offset(400, 300));
    await g1.moveBy(const Offset(40, 0));
    await tester.pump();
    final g2 = await tester.startGesture(const Offset(360, 300));
    await tester.pump();
    await g1.moveBy(const Offset(5, 5));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pump();
  });

  testWidgets('focusId change animates to the node', (tester) async {
    final key = GlobalKey();
    Widget build(String? focus) => _host(ForceGraphView(
          key: key,
          nodes: [_pinned('a'), ForceNode(id: 'b')..x = 30..y = 30],
          links: const [],
          autoFit: false,
          focusId: focus,
        ));
    await tester.pumpWidget(build(null));
    await tester.pump();
    await tester.pumpWidget(build('a'));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('fitToken change re-fits', (tester) async {
    final key = GlobalKey();
    Widget build(int token) => _host(ForceGraphView(
          key: key,
          nodes: [_pinned('a'), ForceNode(id: 'b')..x = 50..y = 50],
          links: const [],
          autoFit: false,
          fitToken: token,
        ));
    await tester.pumpWidget(build(0));
    await tester.pump();
    await tester.pumpWidget(build(1));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('pausing then resuming wakes the loop', (tester) async {
    final key = GlobalKey();
    Widget build(bool paused) => _host(ForceGraphView(
          key: key,
          nodes: [_pinned('a')],
          links: const [],
          autoFit: false,
          paused: paused,
        ));
    await tester.pumpWidget(build(false));
    await tester.pump();
    await tester.pumpWidget(build(true));
    await tester.pump();
    await tester.pumpWidget(build(false));
    await tester.pump();
  });

  testWidgets('changing the node set rebuilds the controller', (tester) async {
    final key = GlobalKey();
    ForceGraphController? ready;
    await tester.pumpWidget(_host(ForceGraphView(
      key: key,
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
      onReady: (c) => ready = c,
    )));
    await tester.pump();
    final first = ready;
    await tester.pumpWidget(_host(ForceGraphView(
      key: key,
      nodes: [_pinned('x'), _pinned('y')],
      links: [ForceLink('x', 'y')],
      autoFit: false,
      onReady: (c) => ready = c,
    )));
    await tester.pump();
    expect(ready, isNot(same(first)));
    expect(ready!.nodes.length, 2);
  });

  testWidgets('settles into idle sleep and wakes on interaction',
      (tester) async {
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
    )));
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  });

  testWidgets('updates config in place when data identity is unchanged',
      (tester) async {
    final key = GlobalKey();
    final nodes = [_pinned('a')];
    final links = <ForceLink>[];
    Widget build({
      bool paused = false,
      ForceGraphConfig? mobileCfg,
      List<ForceLink>? lks,
    }) =>
        _host(ForceGraphView(
          key: key,
          nodes: nodes,
          links: lks ?? links,
          paused: paused,
          mobileConfig: mobileCfg,
          autoFit: false,
        ));
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pumpWidget(build(paused: true));
    await tester.pump();
    await tester.pumpWidget(build(mobileCfg: ForceGraphConfig.mobile()));
    await tester.pump();
    await tester.pumpWidget(build(lks: <ForceLink>[]));
    await tester.pump();
  });

  testWidgets('mouse exit clears the hover', (tester) async {
    final hovers = <String?>[];
    await tester.pumpWidget(_host(Center(
      child: SizedBox(
        width: 800,
        height: 400,
        child: ForceGraphView(
          nodes: [_pinned('a')],
          links: const [],
          autoFit: false,
          onNodeHover: (n) => hovers.add(n?.id),
        ),
      ),
    )));
    await tester.pump();
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: const Offset(5, 5));
    addTearDown(g.removePointer);
    await g.moveTo(const Offset(400, 300));
    await tester.pump();
    await g.moveTo(const Offset(400, 560));
    await tester.pump();
    expect(hovers.last, isNull);
  });

  testWidgets('disposes cleanly when removed', (tester) async {
    await tester.pumpWidget(_host(ForceGraphView(
      nodes: [_pinned('a')],
      links: const [],
      autoFit: false,
    )));
    await tester.pump();
    await tester.pumpWidget(_host(const SizedBox()));
    await tester.pump();
  });
}
