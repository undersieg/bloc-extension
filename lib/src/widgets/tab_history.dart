import 'dart:convert';

import 'package:flutter/material.dart';

import '../dev_tools_entry.dart';
import '../dev_tools_store.dart';

/// The History tab: event timeline, time-travel slider, BLoC filter chips,
/// and a state inspector that shows JSON + diff highlights.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.store});
  final DevToolsStore store;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String? _filterBlocType;
  bool _showDiff = false;

  DevToolsStore get _s => widget.store;

  List<DevToolsEntry> get _filtered {
    if (_filterBlocType == null) return _s.entries;
    return _s.entriesForBloc(_filterBlocType!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // ── Filter chips ────────────────────────────────────────────────
        if (_s.blocTypes.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: cs.outlineVariant))),
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip('All', _filterBlocType == null,
                    () => setState(() => _filterBlocType = null)),
                for (final t in _s.blocTypes)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _Chip(t, _filterBlocType == t,
                        () => setState(() => _filterBlocType = t)),
                  ),
              ],
            ),
          ),

        // ── Slider ──────────────────────────────────────────────────────
        _Slider(store: _s),

        // ── Timeline list ───────────────────────────────────────────────
        Expanded(child: _buildTimeline(theme, cs)),

        // ── Inspector ───────────────────────────────────────────────────
        _Inspector(
          entry: _s.currentEntry,
          showDiff: _showDiff,
          onToggleDiff: () => setState(() => _showDiff = !_showDiff),
        ),
      ],
    );
  }

  Widget _buildTimeline(ThemeData theme, ColorScheme cs) {
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text('No states recorded yet.\nInteract with your app.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant)),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, i) {
        final entry = list[i];
        final realIdx = _s.entries.indexOf(entry);
        final isSelected = realIdx == _s.currentIndex;

        // Time gap from previous entry (for timeline spacing).
        Duration? gap;
        if (i > 0) {
          gap = entry.timestamp.difference(list[i - 1].timestamp);
        }

        return _TimelineTile(
          entry: entry,
          index: realIdx,
          isSelected: isSelected,
          gap: gap,
          onJump: () => _s.jumpTo(realIdx),
          onToggleSkip: () => _s.toggleSkip(realIdx),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.5)
                  : cs.outlineVariant),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? cs.onPrimaryContainer
                  : cs.onSurfaceVariant,
            )),
      ),
    );
  }
}

// ── Slider ──────────────────────────────────────────────────────────────────

class _Slider extends StatelessWidget {
  const _Slider({required this.store});
  final DevToolsStore store;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = store.activeEntries;
    final idx = store.activeIndex;
    final ok = active.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant))),
      child: Row(
        children: [
          _Btn(Icons.skip_previous, 'First',
              ok ? () => store.jumpToActive(0) : null),
          _Btn(Icons.chevron_left, 'Prev',
              ok && idx > 0 ? () => store.jumpToActive(idx - 1) : null),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: cs.primary,
                inactiveTrackColor: cs.outlineVariant,
                thumbColor: cs.primary,
              ),
              child: Slider(
                value: ok
                    ? idx
                        .toDouble()
                        .clamp(0, (active.length - 1).toDouble())
                    : 0,
                min: 0,
                max: ok
                    ? (active.length - 1)
                        .toDouble()
                        .clamp(1, double.infinity)
                    : 1,
                divisions:
                    ok && active.length > 1 ? active.length - 1 : null,
                onChanged:
                    ok ? (v) => store.jumpToActive(v.round()) : null,
              ),
            ),
          ),
          _Btn(Icons.chevron_right, 'Next',
              ok && idx < active.length - 1
                  ? () => store.jumpToActive(idx + 1)
                  : null),
          _Btn(Icons.skip_next, 'Last',
              ok ? () => store.jumpToActive(active.length - 1) : null),
        ],
      ),
    );
  }
}

// ── Timeline tile ───────────────────────────────────────────────────────────

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.index,
    required this.isSelected,
    required this.onJump,
    required this.onToggleSkip,
    this.gap,
  });

  final DevToolsEntry entry;
  final int index;
  final bool isSelected;
  final VoidCallback onJump;
  final VoidCallback onToggleSkip;
  final Duration? gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = entry.timestamp;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gap indicator — shows elapsed time between entries.
        if (gap != null && gap!.inMilliseconds > 200)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2, bottom: 2),
            child: Row(
              children: [
                Container(
                    width: 1, height: 12, color: cs.outlineVariant),
                const SizedBox(width: 8),
                Text(_formatGap(gap!),
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        // The entry row.
        Material(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.4)
              : Colors.transparent,
          child: InkWell(
            onTap: onJump,
            child: Opacity(
              opacity: entry.isSkipped ? 0.45 : 1.0,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    // Timeline dot.
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? cs.primary
                            : cs.outlineVariant,
                        border: isSelected
                            ? Border.all(color: cs.primary, width: 2)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.event?.toString() ?? '(initial state)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              decoration: entry.isSkipped
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text('${entry.blocType} · $timeStr',
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 10)),
                              if (entry.processingDuration != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _perfColor(
                                            entry.processingDuration!, cs)
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${(entry.processingDuration!.inMicroseconds / 1000).toStringAsFixed(1)}ms',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: _perfColor(
                                          entry.processingDuration!, cs),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    _Btn(
                      entry.isSkipped
                          ? Icons.visibility_off
                          : Icons.visibility,
                      entry.isSkipped ? 'Unskip' : 'Skip',
                      onToggleSkip,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatGap(Duration d) {
    if (d.inSeconds >= 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    if (d.inMilliseconds >= 1000) {
      return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${d.inMilliseconds}ms';
  }

  Color _perfColor(Duration d, ColorScheme cs) {
    if (d.inMilliseconds < 16) return Colors.green;
    if (d.inMilliseconds < 100) return Colors.orange;
    return cs.error;
  }
}

// ── State inspector with diff ───────────────────────────────────────────────

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.entry,
    required this.showDiff,
    required this.onToggleDiff,
  });

  final DevToolsEntry? entry;
  final bool showDiff;
  final VoidCallback onToggleDiff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 180,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: entry == null
          ? Center(
              child: Text('Select a state to inspect',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.data_object, size: 14, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('State inspector',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      // Diff toggle
                      if (entry!.previousState != null)
                        GestureDetector(
                          onTap: onToggleDiff,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: showDiff
                                  ? cs.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Text('Diff',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: showDiff
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant)),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(entry!.blocType,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: showDiff ? _buildDiff(cs) : _buildJson(theme, cs),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildJson(ThemeData theme, ColorScheme cs) {
    String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(entry!.toDisplayMap());
    } catch (_) {
      text = entry!.toDisplayMap().toString();
    }
    return SelectableText(text,
        style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.5,
            color: cs.onSurface));
  }

  Widget _buildDiff(ColorScheme cs) {
    final diff = entry!.computeDiff();
    if (diff == null) {
      return Text('No field-level changes detected.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in diff.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _diffColor(d.type, cs).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    d.type == DiffType.added
                        ? '+'
                        : d.type == DiffType.removed
                            ? '−'
                            : '~',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _diffColor(d.type, cs)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                          color: cs.onSurface),
                      children: [
                        TextSpan(
                            text: '${d.field}: ',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        if (d.type == DiffType.changed) ...[
                          TextSpan(
                              text: '${d.oldValue}',
                              style: TextStyle(
                                  color: cs.error,
                                  decoration: TextDecoration.lineThrough)),
                          const TextSpan(text: ' → '),
                          TextSpan(
                              text: '${d.newValue}',
                              style: TextStyle(
                                  color: Colors.green.shade700)),
                        ] else if (d.type == DiffType.added)
                          TextSpan(
                              text: '${d.newValue}',
                              style: TextStyle(
                                  color: Colors.green.shade700))
                        else
                          TextSpan(
                              text: '${d.oldValue}',
                              style: TextStyle(color: cs.error)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _diffColor(DiffType t, ColorScheme cs) {
    switch (t) {
      case DiffType.added:
        return Colors.green;
      case DiffType.removed:
        return cs.error;
      case DiffType.changed:
        return Colors.orange;
    }
  }
}

// ── Shared icon button ──────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  const _Btn(this.icon, this.tooltip, this.onPressed);
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
