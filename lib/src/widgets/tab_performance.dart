import 'package:flutter/material.dart';

import '../dev_tools_entry.dart';
import '../dev_tools_store.dart';

/// The Performance tab: processing-time metrics, per-BLoC stats,
/// and a ranked list of slowest transitions.
class PerformanceTab extends StatelessWidget {
  const PerformanceTab({super.key, required this.store});
  final DevToolsStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timed = store.entriesWithTiming;

    if (timed.isEmpty) {
      return Center(
        child: Text(
          'No performance data yet.\n'
          'Timing is measured for Bloc transitions\n'
          '(event dispatch → state emission).',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Summary cards ───────────────────────────────────────────────
        _buildSummary(theme, cs, timed),
        const SizedBox(height: 16),

        // ── Per-BLoC breakdown ──────────────────────────────────────────
        Text('Per-BLoC breakdown',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildBlocBreakdown(theme, cs),
        const SizedBox(height: 16),

        // ── Slowest transitions ─────────────────────────────────────────
        Text('Slowest transitions',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildSlowest(theme, cs, timed),
      ],
    );
  }

  // ── Summary row ───────────────────────────────────────────────────────────

  Widget _buildSummary(
      ThemeData theme, ColorScheme cs, List<DevToolsEntry> timed) {
    final avg = store.avgProcessingTime;
    final slowest = store.slowestTransition;
    final fastest = timed.reduce((a, b) =>
        a.processingDuration!.inMicroseconds <=
                b.processingDuration!.inMicroseconds
            ? a
            : b);

    return Row(
      children: [
        Expanded(
            child: _MetricCard(
                label: 'Avg',
                value: _fmtDur(avg),
                color: _perfColor(avg, cs),
                cs: cs)),
        const SizedBox(width: 8),
        Expanded(
            child: _MetricCard(
                label: 'Fastest',
                value: _fmtDur(fastest.processingDuration!),
                color: Colors.green,
                cs: cs)),
        const SizedBox(width: 8),
        Expanded(
            child: _MetricCard(
                label: 'Slowest',
                value: _fmtDur(slowest!.processingDuration!),
                color: _perfColor(slowest.processingDuration!, cs),
                cs: cs)),
        const SizedBox(width: 8),
        Expanded(
            child: _MetricCard(
                label: 'Measured',
                value: '${timed.length}',
                color: cs.primary,
                cs: cs)),
      ],
    );
  }

  // ── Per-BLoC breakdown ────────────────────────────────────────────────────

  Widget _buildBlocBreakdown(ThemeData theme, ColorScheme cs) {
    final records = store.lifecycles
        .where((r) => r.transitionCount > 0)
        .toList()
      ..sort((a, b) =>
          b.avgProcessingTime.inMicroseconds -
          a.avgProcessingTime.inMicroseconds);

    if (records.isEmpty) {
      return Text('No per-BLoC data available.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant));
    }

    // Find the max avg time for the bar scale.
    final maxUs = records.first.avgProcessingTime.inMicroseconds;

    return Column(
      children: [
        for (final r in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
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
                              fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${_fmtDur(r.avgProcessingTime)} avg · '
                      '${r.transitionCount} events',
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: maxUs > 0
                        ? r.avgProcessingTime.inMicroseconds / maxUs
                        : 0,
                    minHeight: 4,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                    color: _perfColor(r.avgProcessingTime, cs),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Slowest transitions list ──────────────────────────────────────────────

  Widget _buildSlowest(
      ThemeData theme, ColorScheme cs, List<DevToolsEntry> timed) {
    final sorted = List<DevToolsEntry>.from(timed)
      ..sort((a, b) =>
          b.processingDuration!.inMicroseconds -
          a.processingDuration!.inMicroseconds);
    final top = sorted.take(10).toList();

    return Column(
      children: [
        for (int i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
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
                    color: _perfColor(top[i].processingDuration!, cs)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _fmtDur(top[i].processingDuration!),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _perfColor(top[i].processingDuration!, cs),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${top[i].blocType} ← ${top[i].event ?? "?"}',
                    style: TextStyle(fontSize: 10, color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

// ── Metric card ─────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
  });

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
