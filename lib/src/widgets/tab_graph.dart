import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bloc_lifecycle.dart';
import '../dev_tools_store.dart';

/// The Graph tab: shows all active BLoC/Cubit instances as nodes
/// and draws edges between related ones (detected via temporal correlation).
class GraphTab extends StatelessWidget {
  const GraphTab({super.key, required this.store});
  final DevToolsStore store;

  @override
  Widget build(BuildContext context) {
    final alive = store.aliveBlocs;
    final rels = store.relationships;
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
        // ── Legend ─────────────────────────────────────────────────────
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
            ],
          ),
        ),
        // ── Graph canvas ──────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _GraphPainter(
                  alive: alive,
                  relationships: rels,
                  colorScheme: cs,
                  textDirection: Directionality.of(context),
                ),
                child: Stack(
                  children: _buildNodeWidgets(
                      context, alive, constraints, rels, cs),
                ),
              );
            },
          ),
        ),
        // ── Details table ─────────────────────────────────────────────
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final r in alive) _BlocDetailRow(record: r),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNodeWidgets(
    BuildContext context,
    List<BlocLifecycleRecord> alive,
    BoxConstraints constraints,
    List<BlocRelationship> rels,
    ColorScheme cs,
  ) {
    final positions = _layoutNodes(alive, constraints);
    final widgets = <Widget>[];

    for (int i = 0; i < alive.length; i++) {
      final r = alive[i];
      final pos = positions[i];
      final isBloc = r.isBloc;

      widgets.add(Positioned(
        left: pos.dx - 45,
        top: pos.dy - 24,
        child: _NodeChip(
          label: r.blocType,
          isBloc: isBloc,
          transitionCount: r.transitionCount,
          colorScheme: cs,
        ),
      ));
    }

    return widgets;
  }

  /// Arranges nodes in a circle layout.
  static List<Offset> _layoutNodes(
      List<BlocLifecycleRecord> nodes, BoxConstraints c) {
    final cx = c.maxWidth / 2;
    final cy = c.maxHeight / 2;
    final radius = math.min(cx, cy) * 0.6;

    if (nodes.length == 1) return [Offset(cx, cy)];

    return List.generate(nodes.length, (i) {
      final angle = (2 * math.pi * i / nodes.length) - math.pi / 2;
      return Offset(cx + radius * math.cos(angle),
          cy + radius * math.sin(angle));
    });
  }
}

// ── Graph painter (draws edges) ─────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.alive,
    required this.relationships,
    required this.colorScheme,
    required this.textDirection,
  });

  final List<BlocLifecycleRecord> alive;
  final List<BlocRelationship> relationships;
  final ColorScheme colorScheme;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final positions = GraphTab._layoutNodes(
        alive, BoxConstraints.tight(size));

    // Build a map from blocType → position index.
    final typeToIndex = <String, int>{};
    for (int i = 0; i < alive.length; i++) {
      typeToIndex[alive[i].blocType] = i;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final rel in relationships) {
      final si = typeToIndex[rel.sourceBlocType];
      final ti = typeToIndex[rel.targetBlocType];
      if (si == null || ti == null) continue;

      final from = positions[si];
      final to = positions[ti];

      paint
        ..color = colorScheme.outline.withValues(alpha: (0.3 + rel.strength * 0.5))
        ..strokeWidth = 1.0 + rel.strength * 2.0;

      canvas.drawLine(from, to, paint);

      // Draw arrowhead.
      _drawArrow(canvas, from, to, paint);

      // Draw correlation count label at the midpoint.
      final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: '${rel.correlationCount}',
          style: TextStyle(
            fontSize: 9,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: textDirection,
      )..layout();
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const arrowLen = 8.0;
    const arrowAngle = 0.5;
    // Stop a bit before the target node.
    final stop = Offset(
      to.dx - 45 * math.cos(angle),
      to.dy - 45 * math.sin(angle),
    );
    final p1 = Offset(
      stop.dx - arrowLen * math.cos(angle - arrowAngle),
      stop.dy - arrowLen * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      stop.dx - arrowLen * math.cos(angle + arrowAngle),
      stop.dy - arrowLen * math.sin(angle + arrowAngle),
    );
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(stop.dx, stop.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}

// ── Node chip widget ────────────────────────────────────────────────────────

class _NodeChip extends StatelessWidget {
  const _NodeChip({
    required this.label,
    required this.isBloc,
    required this.transitionCount,
    required this.colorScheme,
  });

  final String label;
  final bool isBloc;
  final int transitionCount;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final color = isBloc ? colorScheme.primary : colorScheme.tertiary;
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text('$transitionCount states',
              style: TextStyle(
                  fontSize: 8, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Details row ─────────────────────────────────────────────────────────────

class _BlocDetailRow extends StatelessWidget {
  const _BlocDetailRow({required this.record});
  final BlocLifecycleRecord record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avgMs =
        record.avgProcessingTime.inMicroseconds / 1000;

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

// ── Legend dot ───────────────────────────────────────────────────────────────

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
