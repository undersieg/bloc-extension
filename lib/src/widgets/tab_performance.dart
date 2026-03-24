import 'package:flutter/material.dart';

import '../dev_tools_entry.dart';
import '../dev_tools_store.dart';

/// Performance tab with selectable metrics.
/// Tap a BLoC in the breakdown or a slow transition to see details.
class PerformanceTab extends StatefulWidget {
  const PerformanceTab({super.key, required this.store});
  final DevToolsStore store;

  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab>
    with AutomaticKeepAliveClientMixin {
  String? _selectedBloc;
  int? _selectedSlowestIdx;

  @override
  bool get wantKeepAlive => true;
  DevToolsStore get _s => widget.store;

  @override
  void initState() {
    super.initState();
    _s.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant PerformanceTab old) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timed = _s.entriesWithTiming;

    if (timed.isEmpty && _s.lifecycles.every((r) => r.transitionCount == 0)) {
      return Center(
        child: Text(
          'No performance data yet.\n'
          'Interact with your app to generate transitions.',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    final records = _s.lifecycles.where((r) => r.transitionCount > 0).toList()
      ..sort((a, b) => b.transitionCount - a.transitionCount);

    final sorted = List<DevToolsEntry>.from(timed)
      ..sort((a, b) => b.processingDuration!.inMicroseconds
          .compareTo(a.processingDuration!.inMicroseconds));
    final top10 = sorted.take(10).toList();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSummary(cs, timed),
              const SizedBox(height: 16),
              Text('Per-BLoC breakdown',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildBlocBreakdown(cs, records),
              const SizedBox(height: 16),
              Text('Slowest transitions',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildSlowest(cs, top10),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: cs.outlineVariant),
        Expanded(
          flex: 2,
          child: _buildDetailPanel(cs, records, top10),
        ),
      ],
    );
  }

  Widget _buildSummary(ColorScheme cs, List<DevToolsEntry> timed) {
    final avg = _s.avgProcessingTime;
    final slowest = _s.slowestTransition;
    final fastest = timed.isNotEmpty
        ? timed.reduce((a, b) => a.processingDuration!.inMicroseconds <=
                b.processingDuration!.inMicroseconds
            ? a
            : b)
        : null;

    return Row(
      children: [
        if (timed.isNotEmpty)
          Expanded(child: _Card('Avg', _fmtDur(avg), _perfColor(avg, cs), cs)),
        if (fastest != null) ...[
          const SizedBox(width: 8),
          Expanded(
              child: _Card('Fastest', _fmtDur(fastest.processingDuration!),
                  Colors.green, cs)),
        ],
        if (slowest != null) ...[
          const SizedBox(width: 8),
          Expanded(
              child: _Card('Slowest', _fmtDur(slowest.processingDuration!),
                  _perfColor(slowest.processingDuration!, cs), cs)),
        ],
        const SizedBox(width: 8),
        Expanded(
            child: _Card(
                'Total events',
                '${_s.lifecycles.fold<int>(0, (s, r) => s + r.transitionCount)}',
                cs.primary,
                cs)),
      ],
    );
  }

  Widget _buildBlocBreakdown(ColorScheme cs, List<dynamic> records) {
    if (records.isEmpty) {
      return Text('No data yet.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant));
    }
    final maxCount = (records.first as dynamic).transitionCount as int;

    return Column(
      children: [
        for (final r in records) ...[
          Material(
            color: _selectedBloc == r.blocType
                ? cs.primaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() {
                _selectedBloc = _selectedBloc == r.blocType ? null : r.blocType;
                _selectedSlowestIdx = null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: r.isBloc ? cs.primary : cs.tertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(r.blocType,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          r.avgProcessingTime.inMicroseconds > 0
                              ? '${_fmtDur(r.avgProcessingTime)} avg · ${r.transitionCount} events'
                              : '${r.transitionCount} events',
                          style: TextStyle(
                              fontSize: 10, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? r.transitionCount / maxCount : 0,
                        minHeight: 4,
                        backgroundColor:
                            cs.outlineVariant.withValues(alpha: 0.3),
                        color: r.isBloc ? cs.primary : cs.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildSlowest(ColorScheme cs, List<DevToolsEntry> top10) {
    if (top10.isEmpty) {
      return Text('No timing data yet.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant));
    }

    return Column(
      children: [
        for (int i = 0; i < top10.length; i++) ...[
          Material(
            color: _selectedSlowestIdx == i
                ? cs.primaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => setState(() {
                _selectedSlowestIdx = _selectedSlowestIdx == i ? null : i;
                _selectedBloc = null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text('${i + 1}.',
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _perfColor(top10[i].processingDuration!, cs)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _fmtDur(top10[i].processingDuration!),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _perfColor(top10[i].processingDuration!, cs),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${top10[i].blocType} ← ${top10[i].event ?? "?"}',
                        style: TextStyle(fontSize: 10, color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailPanel(
      ColorScheme cs, List<dynamic> records, List<DevToolsEntry> top10) {
    if (_selectedBloc != null) {
      final r = records.where((r) => r.blocType == _selectedBloc).firstOrNull;
      if (r != null) return _blocDetail(cs, r);
    }

    if (_selectedSlowestIdx != null && _selectedSlowestIdx! < top10.length) {
      return _transitionDetail(cs, top10[_selectedSlowestIdx!]);
    }

    return Center(
      child: Text('Tap a BLoC or transition\nto see details',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
    );
  }

  Widget _blocDetail(ColorScheme cs, dynamic r) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: r.isBloc ? cs.primary : cs.tertiary,
                ),
              ),
              const SizedBox(width: 8),
              Text(r.blocType,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _row('Type', r.isBloc ? 'Bloc' : 'Cubit', cs),
          _row('Transitions', '${r.transitionCount}', cs),
          _row('Total time', _fmtDur(r.totalProcessingTime), cs),
          _row('Avg time', _fmtDur(r.avgProcessingTime), cs),
          _row('Alive for', _fmtDur(r.lifetime), cs),
        ],
      ),
    );
  }

  Widget _transitionDetail(ColorScheme cs, DevToolsEntry entry) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Slow transition',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: cs.error)),
          const SizedBox(height: 12),
          _row('BLoC', entry.blocType, cs),
          _row('Event', entry.event?.toString() ?? '–', cs),
          _row('Processing', _fmtDur(entry.processingDuration!), cs),
          _row(
              'State',
              DevToolsEntry.tryToJson(entry.state)?.toString() ??
                  entry.state.toString(),
              cs),
          _row(
              'Timestamp',
              '${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}',
              cs),
        ],
      ),
    );
  }

  Widget _row(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _fmtDur(Duration d) {
    final us = d.inMicroseconds;
    if (us < 1000) return '${us}µs';
    return '${(us / 1000).toStringAsFixed(1)}ms';
  }

  Color _perfColor(Duration d, ColorScheme cs) {
    if (d.inMilliseconds < 16) return Colors.green;
    if (d.inMilliseconds < 100) return Colors.orange;
    return cs.error;
  }
}

class _Card extends StatelessWidget {
  const _Card(this.label, this.value, this.color, this.cs);
  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
