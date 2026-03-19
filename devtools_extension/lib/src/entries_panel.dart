import 'dart:convert';

import 'package:flutter/material.dart';

/// Displays the state history timeline in the DevTools extension.
class EntriesPanel extends StatefulWidget {
  const EntriesPanel({super.key, required this.entries, this.summary});
  final List<Map<String, dynamic>> entries;
  final Map<String, dynamic>? summary;

  @override
  State<EntriesPanel> createState() => _EntriesPanelState();
}

class _EntriesPanelState extends State<EntriesPanel> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const Center(
          child: Text('No states recorded yet. Interact with your app.'));
    }

    return Row(
      children: [
        // ── Entry list (left) ─────────────────────────────────────────
        Expanded(
          flex: 3,
          child: ListView.builder(
            itemCount: widget.entries.length,
            itemBuilder: (context, i) {
              final e = widget.entries[i];
              final isSelected = _selectedIndex == i;
              final event = e['event']?.toString() ?? '(initial state)';
              final blocType = e['blocType'] ?? '';
              final procUs = e['processingUs'] as int?;

              return Material(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.4)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(blocType,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (procUs != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: _perfColor(procUs).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${(procUs / 1000).toStringAsFixed(1)}ms',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _perfColor(procUs)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const VerticalDivider(width: 1),

        // ── Inspector (right) ─────────────────────────────────────────
        Expanded(
          flex: 2,
          child: _selectedIndex != null &&
                  _selectedIndex! < widget.entries.length
              ? _buildInspector(widget.entries[_selectedIndex!])
              : const Center(
                  child: Text('Select an entry to inspect',
                      style: TextStyle(color: Colors.grey))),
        ),
      ],
    );
  }

  Widget _buildInspector(Map<String, dynamic> entry) {
    String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(entry);
    } catch (_) {
      text = entry.toString();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('State inspector',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),

          // Show diff if previousState exists.
          if (entry['previousState'] != null &&
              entry['state'] is Map &&
              entry['previousState'] is Map) ...[
            Text('Changes:',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            _buildDiff(
              entry['previousState'] as Map<String, dynamic>,
              entry['state'] as Map<String, dynamic>,
            ),
            const Divider(height: 16),
          ],

          SelectableText(text,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 11, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildDiff(Map<String, dynamic> prev, Map<String, dynamic> curr) {
    final allKeys = {...prev.keys, ...curr.keys};
    final diffs = <Widget>[];

    for (final key in allKeys) {
      final oldVal = prev[key];
      final newVal = curr[key];
      if ('$oldVal' != '$newVal') {
        final isAdded = !prev.containsKey(key);
        final isRemoved = !curr.containsKey(key);
        diffs.add(Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (isAdded
                          ? Colors.green
                          : isRemoved
                              ? Colors.red
                              : Colors.orange)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  isAdded ? '+' : isRemoved ? '−' : '~',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isAdded
                          ? Colors.green
                          : isRemoved
                              ? Colors.red
                              : Colors.orange),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAdded
                      ? '$key: $newVal'
                      : isRemoved
                          ? '$key: $oldVal'
                          : '$key: $oldVal → $newVal',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ],
          ),
        ));
      }
    }

    if (diffs.isEmpty) {
      return const Text('No changes', style: TextStyle(fontSize: 10));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: diffs);
  }

  Color _perfColor(int us) {
    if (us < 16000) return Colors.green;
    if (us < 100000) return Colors.orange;
    return Colors.red;
  }
}
