import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Graph panel for the DevTools browser extension.
/// Uses [Listener] for drag (works inside iframe), with search + type filters.
class GraphPanel extends StatefulWidget {
  const GraphPanel({super.key, this.data});
  final Map<String, dynamic>? data;

  @override
  State<GraphPanel> createState() => _GraphPanelState();
}

class _GraphPanelState extends State<GraphPanel> {
  final Map<String, Offset> _positions = {};
  final TextEditingController _search = TextEditingController();
  bool _showBlocs = true;
  bool _showCubits = true;
  String? _draggingType;

  List<Map<String, dynamic>> get _allAlive =>
      List<Map<String, dynamic>>.from(
          (widget.data?['aliveBlocs'] as List?) ?? []);

  List<Map<String, dynamic>> get _filtered {
    var list = _allAlive.toList();
    if (!_showBlocs) {
      list = list.where((b) => b['isBloc'] != true).toList();
    }
    if (!_showCubits) {
      list = list.where((b) => b['isBloc'] == true).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((b) =>
          (b['blocType'] as String? ?? '').toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _rels =>
      List<Map<String, dynamic>>.from(
          (widget.data?['relationships'] as List?) ?? []);

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _ensurePositions(List<Map<String, dynamic>> alive, Size size) {
    if (size == Size.zero) return;
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
    final alive = _filtered;
    final rels = _rels;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Search + filters ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 34,
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    hintStyle:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, size: 16,
                        color: cs.onSurfaceVariant),
                    suffixIcon: _search.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, size: 14,
                          color: cs.onSurfaceVariant),
                      onPressed: () => _search.clear(),
                      padding: EdgeInsets.zero,
                    )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _ToggleChip('Bloc', Colors.blue, _showBlocs,
                          () => setState(() => _showBlocs = !_showBlocs)),
                  const SizedBox(width: 6),
                  _ToggleChip('Cubit', Colors.teal, _showCubits,
                          () => setState(() => _showCubits = !_showCubits)),
                  const Spacer(),
                  Text(
                    '${alive.length}/${_allAlive.length} shown · drag to move',
                    style: TextStyle(
                        fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high, size: 14),
                    tooltip: 'Reset positions',
                    onPressed: () => setState(() => _positions.clear()),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Canvas ──────────────────────────────────────────────────────
        Expanded(
          child: alive.isEmpty
              ? Center(
            child: Text(
              _allAlive.isEmpty
                  ? 'No active BLoCs/Cubits.'
                  : 'No matches.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                  constraints.maxWidth, constraints.maxHeight);
              _ensurePositions(alive, size);

              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerMove: (event) {
                  if (_draggingType == null) return;
                  if (!_positions.containsKey(_draggingType)) return;
                  setState(() {
                    final old = _positions[_draggingType]!;
                    _positions[_draggingType!] = Offset(
                      (old.dx + event.delta.dx)
                          .clamp(0, size.width),
                      (old.dy + event.delta.dy)
                          .clamp(0, size.height),
                    );
                  });
                },
                onPointerUp: (_) => _draggingType = null,
                onPointerCancel: (_) => _draggingType = null,
                child: CustomPaint(
                  size: size,
                  painter: _EdgePainter(
                    positions: _positions,
                    relationships: rels,
                  ),
                  child: Stack(
                    children: [
                      for (final b in alive)
                        if (_positions
                            .containsKey(b['blocType'] as String))
                          _buildNode(b, size),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // ── Detail table ────────────────────────────────────────────────
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: cs.outlineVariant)),
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
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: b['isBloc'] == true
                              ? Colors.blue : Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('${b['blocType']}',
                              style: const TextStyle(fontSize: 11))),
                      Text('${b['transitionCount']} trans.',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Text(
                        (b['avgProcessingUs'] as int? ?? 0) > 0
                            ? '${((b['avgProcessingUs'] as int) / 1000).toStringAsFixed(1)}ms'
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

  Widget _buildNode(Map<String, dynamic> b, Size canvasSize) {
    final type = b['blocType'] as String;
    final pos = _positions[type]!;
    final isBloc = b['isBloc'] == true;
    final color = isBloc ? Colors.blue : Colors.teal;

    return Positioned(
      left: pos.dx - 50,
      top: pos.dy - 24,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _draggingType = type,
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
                Text(type,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                Text('${b['transitionCount']} states',
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
  _EdgePainter({required this.positions, required this.relationships});

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

      // Correlation count label at midpoint.
      final count = rel['correlationCount'] as int? ?? 0;
      if (count > 0) {
        final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: '$count',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

// ── Toggle chip ─────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  const _ToggleChip(this.label, this.color, this.active, this.onTap);
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? color : Colors.grey)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? color : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}