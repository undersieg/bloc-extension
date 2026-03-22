import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bloc_lifecycle.dart';
import '../dev_tools_store.dart';

/// Graph tab: draggable + selectable BLoC/Cubit nodes, search, type filter.
class GraphTab extends StatefulWidget {
  const GraphTab({super.key, required this.store});
  final DevToolsStore store;

  @override
  State<GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<GraphTab>
    with AutomaticKeepAliveClientMixin {
  final Map<String, Offset> _positions = {};
  final TextEditingController _search = TextEditingController();
  bool _showBlocs = true;
  bool _showCubits = true;
  int? _draggingId;
  String? _selectedType; // currently selected node

  @override
  bool get wantKeepAlive => true;
  DevToolsStore get _s => widget.store;

  @override
  void initState() {
    super.initState();
    _s.addListener(_rebuild);
    _search.addListener(_rebuild);
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
    _search.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  List<BlocLifecycleRecord> get _allAlive => _s.aliveBlocs;

  List<BlocLifecycleRecord> get _filtered {
    var list = _allAlive.toList();
    if (!_showBlocs) list = list.where((r) => !r.isBloc).toList();
    if (!_showCubits) list = list.where((r) => r.isBloc).toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((r) => r.blocType.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  BlocLifecycleRecord? get _selectedRecord {
    if (_selectedType == null) return null;
    try {
      return _allAlive.firstWhere((r) => r.blocType == _selectedType);
    } catch (_) {
      return null;
    }
  }

  void _ensurePositions(List<BlocLifecycleRecord> alive, Size size) {
    if (size == Size.zero) return;
    _positions.removeWhere(
            (key, _) => !alive.any((r) => r.blocType == key));
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
        _positions[type] = Offset(
            cx + radius * math.cos(angle), cy + radius * math.sin(angle));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final alive = _filtered;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        _buildToolbar(cs),
        Expanded(
          child: alive.isEmpty
              ? Center(
            child: Text(
              _allAlive.isEmpty
                  ? 'No active BLoCs/Cubits.'
                  : 'No matches for "${_search.text}"',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              final size =
              Size(constraints.maxWidth, constraints.maxHeight);
              _ensurePositions(alive, size);
              // GestureDetector claims pan gestures in the arena,
              // preventing the Drawer from interpreting them as
              // a close swipe. Listener handles the actual movement.
              return GestureDetector(
                onPanStart: (_) {},
                onPanUpdate: (_) {},
                onPanEnd: (_) {},
                onTap: () =>
                    setState(() => _selectedType = null),
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerMove: (event) {
                    if (_draggingId == null) return;
                    final type = alive
                        .where((r) => r.instanceId == _draggingId)
                        .map((r) => r.blocType)
                        .firstOrNull;
                    if (type == null ||
                        !_positions.containsKey(type)) return;
                    setState(() {
                      final old = _positions[type]!;
                      _positions[type] = Offset(
                        (old.dx + event.delta.dx).clamp(0, size.width),
                        (old.dy + event.delta.dy).clamp(0, size.height),
                      );
                    });
                  },
                  onPointerUp: (_) => _draggingId = null,
                  child: CustomPaint(
                    size: size,
                    painter: _EdgePainter(
                      positions: _positions,
                      relationships: _s.relationships,
                      colorScheme: cs,
                      textDirection: Directionality.of(context),
                      selectedType: _selectedType,
                    ),
                    child: Stack(
                      children: [
                        for (final r in alive)
                          if (_positions.containsKey(r.blocType))
                            _buildNode(r, cs, size),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildDetailPanel(cs),
      ],
    );
  }

  Widget _buildToolbar(ColorScheme cs) {
    return Container(
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
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outlineVariant)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outlineVariant)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Toggle('Bloc', cs.primary, _showBlocs,
                      () => setState(() => _showBlocs = !_showBlocs)),
              const SizedBox(width: 6),
              _Toggle('Cubit', cs.tertiary, _showCubits,
                      () => setState(() => _showCubits = !_showCubits)),
              const Spacer(),
              Text('${_filtered.length}/${_allAlive.length}',
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
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
    );
  }

  Widget _buildNode(
      BlocLifecycleRecord r, ColorScheme cs, Size canvasSize) {
    final pos = _positions[r.blocType]!;
    final color = r.isBloc ? cs.primary : cs.tertiary;
    final isSel = _selectedType == r.blocType;

    return Positioned(
      left: pos.dx - 52,
      top: pos.dy - 26,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          _draggingId = r.instanceId;
          setState(() => _selectedType = r.blocType);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Container(
            width: 104,
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isSel ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel ? color : color.withValues(alpha: 0.4),
                width: isSel ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.blocType,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('${r.transitionCount} states',
                    style: TextStyle(
                        fontSize: 8, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(ColorScheme cs) {
    final sel = _selectedRecord;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: BoxConstraints(
        maxHeight: sel != null ? 140 : 40,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: sel == null
          ? Center(
          child: Text('Tap a node to see details',
              style: TextStyle(
                  fontSize: 11, color: cs.onSurfaceVariant)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel.isBloc ? cs.primary : cs.tertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(sel.blocType,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (sel.isBloc ? cs.primary : cs.tertiary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(sel.isBloc ? 'Bloc' : 'Cubit',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: sel.isBloc
                              ? cs.primary
                              : cs.tertiary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _detailRow('Transitions', '${sel.transitionCount}', cs),
            _detailRow('Alive for',
                _fmtDur(sel.lifetime), cs),
            _detailRow(
                'Avg processing',
                sel.avgProcessingTime.inMicroseconds > 0
                    ? '${(sel.avgProcessingTime.inMicroseconds / 1000).toStringAsFixed(1)}ms'
                    : '–',
                cs),
            _detailRow(
                'Connected to',
                _connectedTo(sel.blocType).isEmpty
                    ? 'none detected'
                    : _connectedTo(sel.blocType).join(', '),
                cs),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 10, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  List<String> _connectedTo(String blocType) {
    final result = <String>{};
    for (final r in _s.relationships) {
      if (r.sourceBlocType == blocType) result.add(r.targetBlocType);
      if (r.targetBlocType == blocType) result.add(r.sourceBlocType);
    }
    return result.toList();
  }

  String _fmtDur(Duration d) {
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    if (d.inSeconds > 0) return '${d.inSeconds}s';
    return '${d.inMilliseconds}ms';
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.positions,
    required this.relationships,
    required this.colorScheme,
    required this.textDirection,
    this.selectedType,
  });

  final Map<String, Offset> positions;
  final List<BlocRelationship> relationships;
  final ColorScheme colorScheme;
  final TextDirection textDirection;
  final String? selectedType;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final rel in relationships) {
      final from = positions[rel.sourceBlocType];
      final to = positions[rel.targetBlocType];
      if (from == null || to == null) continue;

      final isHighlighted = selectedType != null &&
          (rel.sourceBlocType == selectedType ||
              rel.targetBlocType == selectedType);

      paint
        ..color = isHighlighted
            ? colorScheme.primary.withValues(alpha: 0.7)
            : colorScheme.outline
            .withValues(alpha: 0.2 + rel.strength * 0.3)
        ..strokeWidth = isHighlighted
            ? 2.5
            : 1.0 + rel.strength * 2.0;

      canvas.drawLine(from, to, paint);

      final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
      final stop = Offset(
          to.dx - 52 * math.cos(angle), to.dy - 52 * math.sin(angle));
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

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.color, this.active, this.onTap);
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
              color: active
                  ? color.withValues(alpha: 0.5)
                  : cs.outlineVariant),
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