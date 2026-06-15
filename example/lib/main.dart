import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:force_graph/force_graph.dart';

void main() {
  runApp(const ApeirronApp());
}

class ApeirronApp extends StatelessWidget {
  const ApeirronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Apeirron Graph',
      debugShowCheckedModeBanner: false,
      home: GraphScreen(),
    );
  }
}

class GraphData {
  GraphData(this.nodes, this.links);
  final List<ForceNode> nodes;
  final List<ForceLink> links;
}

Color _hex(String s) {
  final h = s.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

Future<GraphData> _loadGraph() async {
  final raw = await rootBundle.loadString('assets/graph.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;

  final nodes = <ForceNode>[];
  for (final n in (json['nodes'] as List).cast<Map<String, dynamic>>()) {
    nodes.add(ForceNode(
      id: n['id'] as String,
      label: n['title'] as String,
      color: _hex(n['color'] as String),
      val: (n['val'] as num).toDouble(),
      phantom: n['phantom'] == true,
    ));
  }

  final ids = {for (final n in nodes) n.id};
  final links = <ForceLink>[];
  for (final l in (json['links'] as List).cast<Map<String, dynamic>>()) {
    final s = l['source'] as String;
    final t = l['target'] as String;
    if (ids.contains(s) && ids.contains(t)) {
      links.add(ForceLink(s, t));
    }
  }

  return GraphData(nodes, links);
}

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  late final Future<GraphData> _future = _loadGraph();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      body: FutureBuilder<GraphData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final data = snap.data!;
          return ForceGraphView(
            nodes: data.nodes,
            links: data.links,
          );
        },
      ),
    );
  }
}
