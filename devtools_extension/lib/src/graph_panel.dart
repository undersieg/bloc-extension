import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Graph panel for the DevTools browser extension with draggable nodes.
class GraphPanel extends StatefulWidget {
  const GraphPanel({super.key, this.data});
  final Map<String, dynamic>? data;

  @override
  State<GraphPanel> createState() => _GraphPanelState();
}

class _GraphPanelState extends State<GraphPanel> {
  final Map<String, Offset> _positions = {};
  Size _lastSize = Size.zero;

  List<Map<String, dynamic>> get _alive =>
      List<Map<String, dynamic>>.from(
          (widget.data?['aliveBlocs'] as List?) ?? []);

  List<Map<String, dynamic>> get _rels =>
      List<Map<String, dynamic>>.from(
          (widget.data?['relationships'] as List?) ?? []);

  void _ensurePositions(Size size) {
    if (size == Size.zero) return;
    _lastSize = size;
    final alive = _alive;

    _positions.removeWhere(
            (key, _) => !alive.any((b) => b['blocType'] == key));

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) * 0.45;
    final total = alive.length;

    for (int i = 0; i < alive.length; i++) {
      final type = alive[i]['blocType'] as String;
      if (_positions.containsKey(type)) continue;
      if (total == 1) {
        _positions[type] = Offset(cx, cy);
      } else {
        final angle = (2 * math.pi * i / total) - math.pi / 2;
        _positions[type] = Offset(
            cx + radius * math.cos(angle), cy + radius * math.sin(angle));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alive = _alive;
    final rels = _rels;
    final cs = Theme.of(context).colorScheme;

    if (alive.isEmpty) {
      return const Center(child: Text('No active BLoCs/Cubits.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Dot(Colors.blue, 'Bloc'),
              const SizedBox(width: 16),
              _Dot(Colors.teal, 'Cubit'),
              const Spacer(),
              Text('${alive.length} active · drag to reposition',
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.auto_fix_high, size: 16),
                tooltip: 'Reset positions',
                onPressed: () => setState(() => _positions.clear()),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size =
              Size(constraints.maxWidth, constraints.maxHeight);
              _ensurePositions(size);

              return CustomPaint(
                size: size,
                painter: _EdgePainter(
                  positions: _positions,
                  relationships: rels,
                ),
                child: Stack(
                  children: [
                    for (final b in alive)
                      if (_positions.containsKey(b['blocType']))
                        _DraggableNode(
                          bloc: b,
                          position: _positions[b['blocType'] as String]!,
                          onDrag: (delta) {
                            setState(() {
                              final key = b['blocType'] as String;
                              final old = _positions[key]!;
                              _positions[key] = Offset(
                                (old.dx + delta.dx)
                                    .clamp(0, size.width),
                                (old.dy + delta.dy)
                                    .clamp(0, size.height),
                              );
                            });
                          },
                        ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: cs.outlineVariant)),
          ),
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final b in alive)
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
}

// ── Draggable node ──────────────────────────────────────────────────────────

class _DraggableNode extends StatelessWidget {
  const _DraggableNode({
    required this.bloc,
    required this.position,
    required this.onDrag,
  });

  final Map<String, dynamic> bloc;
  final Offset position;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    final isBloc = bloc['isBloc'] == true;
    final color = isBloc ? Colors.blue : Colors.teal;

    return Positioned(
      left: position.dx - 50,
      top: position.dy - 24,
      child: GestureDetector(
        onPanUpdate: (d) => onDrag(d.delta),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Container(
            width: 100,
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: color.withValues(alpha: 0.4), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${bloc['blocType']}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                Text('${bloc['transitionCount']} states',
                    style:
                    const TextStyle(fontSize: 8, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Edge painter ────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.positions,
    required this.relationships,
  });

  final Map<String, Offset> positions;
  final List<Map<String, dynamic>> relationships;

  @override
  void paint(Canvas canvas, Size size) {
    for (final rel in relationships) {
      final from = positions[rel['source']];
      final to = positions[rel['target']];
      if (from == null || to == null) continue;

      final strength = (rel['strength'] as num?)?.toDouble() ?? 0.3;
      final paint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.3 + strength * 0.4)
        ..strokeWidth = 1.0 + strength * 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(from, to, paint);

      // Arrowhead
      final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
      final stop = Offset(
          to.dx - 50 * math.cos(angle), to.dy - 50 * math.sin(angle));
      final p1 = Offset(stop.dx - 8 * math.cos(angle - 0.5),
          stop.dy - 8 * math.sin(angle - 0.5));
      final p2 = Offset(stop.dx - 8 * math.cos(angle + 0.5),
          stop.dy - 8 * math.sin(angle + 0.5));
      canvas.drawPath(
        Path()
          ..moveTo(stop.dx, stop.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close(),
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
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
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}