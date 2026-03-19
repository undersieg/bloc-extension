import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Displays the BLoC connection graph in the DevTools extension.
class GraphPanel extends StatelessWidget {
  const GraphPanel({super.key, this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Center(child: Text('No graph data available.'));
    }

    final aliveBlocs = List<Map<String, dynamic>>.from(
        (data!['aliveBlocs'] as List?) ?? []);
    final relationships = List<Map<String, dynamic>>.from(
        (data!['relationships'] as List?) ?? []);

    if (aliveBlocs.isEmpty) {
      return const Center(child: Text('No active BLoCs/Cubits.'));
    }

    return Column(
      children: [
        // ── Legend ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Dot(Colors.blue, 'Bloc'),
              const SizedBox(width: 16),
              _Dot(Colors.teal, 'Cubit'),
              const Spacer(),
              Text('${aliveBlocs.length} active',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        // ── Graph ─────────────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final positions =
                  _layoutCircle(aliveBlocs.length, constraints);
              return CustomPaint(
                painter: _EdgePainter(
                  aliveBlocs: aliveBlocs,
                  relationships: relationships,
                  positions: positions,
                ),
                child: Stack(
                  children: [
                    for (int i = 0; i < aliveBlocs.length; i++)
                      Positioned(
                        left: positions[i].dx - 50,
                        top: positions[i].dy - 24,
                        child: _NodeWidget(bloc: aliveBlocs[i]),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        // ── Detail table ──────────────────────────────────────────────
        Container(
          height: 140,
          decoration: BoxDecoration(
            border:
                Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          ),
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final b in aliveBlocs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: b['isBloc'] == true
                              ? Colors.blue
                              : Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('${b['blocType']}',
                              style: const TextStyle(fontSize: 11))),
                      Text('${b['transitionCount']} transitions',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Text(
                        (b['avgProcessingUs'] as int? ?? 0) > 0
                            ? '${((b['avgProcessingUs'] as int) / 1000).toStringAsFixed(1)}ms avg'
                            : '–',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static List<Offset> _layoutCircle(int count, BoxConstraints c) {
    final cx = c.maxWidth / 2;
    final cy = c.maxHeight / 2;
    final r = math.min(cx, cy) * 0.55;
    if (count == 1) return [Offset(cx, cy)];
    return List.generate(count, (i) {
      final a = (2 * math.pi * i / count) - math.pi / 2;
      return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
    });
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.aliveBlocs,
    required this.relationships,
    required this.positions,
  });

  final List<Map<String, dynamic>> aliveBlocs;
  final List<Map<String, dynamic>> relationships;
  final List<Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final typeToIdx = <String, int>{};
    for (int i = 0; i < aliveBlocs.length; i++) {
      typeToIdx[aliveBlocs[i]['blocType'] as String] = i;
    }

    for (final rel in relationships) {
      final si = typeToIdx[rel['source']];
      final ti = typeToIdx[rel['target']];
      if (si == null || ti == null) continue;

      final strength = (rel['strength'] as num?)?.toDouble() ?? 0.3;
      final paint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.3 + strength * 0.4)
        ..strokeWidth = 1.0 + strength * 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(positions[si], positions[ti], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({required this.bloc});
  final Map<String, dynamic> bloc;

  @override
  Widget build(BuildContext context) {
    final isBloc = bloc['isBloc'] == true;
    final color = isBloc ? Colors.blue : Colors.teal;
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${bloc['blocType']}',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          Text('${bloc['transitionCount']} states',
              style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
