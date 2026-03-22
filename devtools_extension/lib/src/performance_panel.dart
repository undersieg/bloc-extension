import 'package:flutter/material.dart';

/// Performance tab for the DevTools browser extension.
/// Shows summary cards, per-BLoC breakdown, and top 10 slowest transitions.
class PerformancePanel extends StatelessWidget {
  const PerformancePanel({super.key, this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Center(child: Text('No performance data available.'));
    }

    final avgUs = data!['avgProcessingUs'] as int? ?? 0;
    final count = data!['measuredCount'] as int? ?? 0;
    final slowest = data!['slowest'] as Map<String, dynamic>?;
    final perBloc = List<Map<String, dynamic>>.from(
        (data!['perBloc'] as List?) ?? []);
    final slowestList = List<Map<String, dynamic>>.from(
        (data!['slowestList'] as List?) ?? []);

    if (count == 0 && perBloc.isEmpty) {
      return const Center(
        child: Text(
          'No performance data yet.\n'
              'Timing is measured for Bloc transitions\n'
              '(event dispatch → state emission).\n'
              'Cubits appear in the breakdown once they emit.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
                child: _Card('Average', _fmtUs(avgUs), _perfColor(avgUs))),
            const SizedBox(width: 8),
            Expanded(child: _Card('Measured', '$count', Colors.blue)),
            const SizedBox(width: 8),
            if (slowest != null)
              Expanded(
                  child: _Card(
                      'Slowest',
                      _fmtUs(slowest['processingUs'] as int? ?? 0),
                      _perfColor(slowest['processingUs'] as int? ?? 0))),
          ],
        ),
        const SizedBox(height: 20),

        if (perBloc.isNotEmpty) ...[
          const Text('Per-BLoC breakdown',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          for (final b in perBloc) _BlocBar(bloc: b, maxUs: _maxAvg(perBloc)),
          const SizedBox(height: 20),
        ],

        if (slowestList.isNotEmpty) ...[
          const Text('Slowest transitions',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          for (int i = 0; i < slowestList.length; i++)
            _SlowestRow(index: i + 1, entry: slowestList[i]),
        ],
      ],
    );
  }

  int _maxAvg(List<Map<String, dynamic>> blocs) {
    int max = 1;
    for (final b in blocs) {
      final avg = b['avgProcessingUs'] as int? ?? 0;
      if (avg > max) max = avg;
    }
    return max;
  }

  String _fmtUs(int us) {
    if (us < 1000) return '${us}µs';
    return '${(us / 1000).toStringAsFixed(1)}ms';
  }

  Color _perfColor(int us) {
    if (us < 16000) return Colors.green;
    if (us < 100000) return Colors.orange;
    return Colors.red;
  }
}

class _Card extends StatelessWidget {
  const _Card(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _BlocBar extends StatelessWidget {
  const _BlocBar({required this.bloc, required this.maxUs});
  final Map<String, dynamic> bloc;
  final int maxUs;

  @override
  Widget build(BuildContext context) {
    final avgUs = bloc['avgProcessingUs'] as int? ?? 0;
    final isBloc = bloc['isBloc'] == true;
    final transitions = bloc['transitionCount'] as int? ?? 0;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                  color: isBloc ? Colors.blue : Colors.teal,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                  child: Text('${bloc['blocType']}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500))),
              Text(
                avgUs > 0
                    ? '${_fmtUs(avgUs)} avg · $transitions events'
                    : '$transitions events (no timing)',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: maxUs > 0 ? avgUs / maxUs : 0,
              minHeight: 4,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
              color: avgUs > 0 ? _perfColor(avgUs) : Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtUs(int us) {
    if (us < 1000) return '${us}µs';
    return '${(us / 1000).toStringAsFixed(1)}ms';
  }

  Color _perfColor(int us) {
    if (us < 16000) return Colors.green;
    if (us < 100000) return Colors.orange;
    return Colors.red;
  }
}

class _SlowestRow extends StatelessWidget {
  const _SlowestRow({required this.index, required this.entry});
  final int index;
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final procUs = entry['processingUs'] as int? ?? 0;
    final blocType = entry['blocType'] as String? ?? '';
    final event = entry['event'] as String? ?? '?';
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$index.',
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _perfColor(procUs).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _fmtUs(procUs),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _perfColor(procUs),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$blocType ← $event',
              style: TextStyle(fontSize: 10, color: cs.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtUs(int us) {
    if (us < 1000) return '${us}µs';
    return '${(us / 1000).toStringAsFixed(1)}ms';
  }

  Color _perfColor(int us) {
    if (us < 16000) return Colors.green;
    if (us < 100000) return Colors.orange;
    return Colors.red;
  }
}