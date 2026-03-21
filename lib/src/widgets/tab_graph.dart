import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bloc_lifecycle.dart';
import '../dev_tools_store.dart';

/// Graph tab with draggable BLoC/Cubit nodes and relationship edges.
class GraphTab extends StatefulWidget {
  const GraphTab({super.key, required this.store});
  final DevToolsStore store;

  @override
  State<GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<GraphTab> {
  /// User-positioned offsets keyed by blocType.
  /// Null means "use default circle layout position".
  final Map<String, Offset> _positions = {};

  /// Tracks the canvas size for initial layout.
  Size _canvasSize = Size.zero;

  DevToolsStore get _s => widget.store;

  @override
  void initState() {
    super.initState();
    _s.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant GraphTab old) {
    super.didUpdateWidget(old);
    if (old.store != widget.store) {
      old.store.removeListener(_rebuild);
      widget.store.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _s.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Ensures every alive bloc has a position. New blocs get circle layout.
  void _ensurePositions(List<BlocLifecycleRecord> alive, Size size) {
    if (size == Size.zero) return;
    _canvasSize = size;

    // Remove positions for blocs that are no longer alive.
    _positions.removeWhere(
            (key, _) => !alive.any((r) => r.blocType == key));

    // Assign default positions for new blocs.
    final unpositioned =
    alive.where((r) => !_positions.containsKey(r.blocType)).toList();
    if (unpositioned.isEmpty) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) * 0.5;
    final total = alive.length;

    for (int i = 0; i < alive.length; i++) {
      final type = alive[i].blocType;
      if (_positions.containsKey(type)) continue;
      if (total == 1) {
        _positions[type] = Offset(cx, cy);
      } else {
        final angle = (2 * math.pi * i / total) - math.pi / 2;
        _positions[type] =
            Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alive = _s.aliveBlocs;
    final rels = _s.relationships;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (alive.isEmpty) {
      return Center(
        child: Text('No active BLoCs/Cubits.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant)),
      );
    }

    return Column(
      children: [
        // Legend + reset
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _LegendDot(color: cs.primary, label: 'Bloc'),
              const SizedBox(width: 16),
              _LegendDot(color: cs.tertiary, label: 'Cubit'),
              const Spacer(),
              Text('${alive.length} active',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
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
        // Canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size =
              Size(constraints.maxWidth, constraints.maxHeight);
              _ensurePositions(alive, size);

              return GestureDetector(
                // Absorb taps on canvas background
                onTap: () {},
                child: CustomPaint(
                  size: size,
                  painter: _EdgePainter(
                    positions: _positions,
                    relationships: rels,
                    colorScheme: cs,
                    textDirection: Directionality.of(context),
                  ),
                  child: Stack(
                    children: [
                      for (final r in alive)
                        if (_positions.containsKey(r.blocType))
                          _DraggableNode(
                            record: r,
                            position: _positions[r.blocType]!,
                            colorScheme: cs,
                            onDrag: (delta) {
                              setState(() {
                                final old = _positions[r.blocType]!;
                                _positions[r.blocType] = Offset(
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
                ),
              );
            },
          ),
        ),
        // Detail table
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [for (final r in alive) _DetailRow(record: r)],
          ),
        ),
      ],
    );
  }
}

// ── Draggable node ──────────────────────────────────────────────────────────

class _DraggableNode extends StatelessWidget {
  const _DraggableNode({
    required this.record,
    required this.position,
    required this.colorScheme,
    required this.onDrag,
  });

  final BlocLifecycleRecord record;
  final Offset position;
  final ColorScheme colorScheme;
  final ValueChanged<Offset> onDrag;

  static const double _nodeW = 100;
  static const double _nodeH = 48;

  @override
  Widget build(BuildContext context) {
    final color =
    record.isBloc ? colorScheme.primary : colorScheme.tertiary;

    return Positioned(
      left: position.dx - _nodeW / 2,
      top: position.dy - _nodeH / 2,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Container(
            width: _nodeW,
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border:
              Border.all(color: color.withValues(alpha: 0.4), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(record.blocType,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('${record.transitionCount} states',
                    style: TextStyle(
                        fontSize: 8,
                        color: colorScheme.onSurfaceVariant)),
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
    required this.colorScheme,
    required this.textDirection,
  });

  final Map<String, Offset> positions;
  final List<BlocRelationship> relationships;
  final ColorScheme colorScheme;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final rel in relationships) {
      final from = positions[rel.sourceBlocType];
      final to = positions[rel.targetBlocType];
      if (from == null || to == null) continue;

      paint
        ..color = colorScheme.outline
            .withValues(alpha: 0.3 + rel.strength * 0.5)
        ..strokeWidth = 1.0 + rel.strength * 2.0;

      canvas.drawLine(from, to, paint);
      _drawArrow(canvas, from, to, paint);

      // Correlation count label
      final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: '${rel.correlationCount}',
          style: TextStyle(
              fontSize: 9,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600),
        ),
        textDirection: textDirection,
      )..layout();
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const len = 8.0;
    const spread = 0.5;
    final stop = Offset(
        to.dx - 50 * math.cos(angle), to.dy - 50 * math.sin(angle));
    final p1 = Offset(stop.dx - len * math.cos(angle - spread),
        stop.dy - len * math.sin(angle - spread));
    final p2 = Offset(stop.dx - len * math.cos(angle + spread),
        stop.dy - len * math.sin(angle + spread));
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

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

// ── Detail row ──────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.record});
  final BlocLifecycleRecord record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avgMs = record.avgProcessingTime.inMicroseconds / 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: record.isBloc ? cs.primary : cs.tertiary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(record.blocType,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text('${record.transitionCount} transitions',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(width: 12),
          Text(avgMs > 0 ? '${avgMs.toStringAsFixed(1)}ms avg' : '–',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
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
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}