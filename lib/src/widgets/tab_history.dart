import 'dart:convert';

import 'package:flutter/material.dart';

import '../dev_tools_entry.dart';
import '../dev_tools_store.dart';

/// The History tab with timeline, slider, filter, inspector, diff, and replay.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.store});
  final DevToolsStore store;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab>
    with AutomaticKeepAliveClientMixin {
  String? _filterBlocType;
  bool _showDiff = false;

  @override
  bool get wantKeepAlive => true;

  DevToolsStore get _s => widget.store;

  @override
  void initState() {
    super.initState();
    _s.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant HistoryTab old) {
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

  List<DevToolsEntry> get _filtered {
    if (_filterBlocType == null) return _s.entries;
    return _s.entriesForBloc(_filterBlocType!);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // ── Filter chips (always visible) ───────────────────────────────
        _buildFilterRow(cs),

        // ── Slider ──────────────────────────────────────────────────────
        _buildSlider(cs),

        // ── Timeline list ───────────────────────────────────────────────
        Expanded(child: _buildTimeline(theme, cs)),

        // ── Inspector with diff + replay ────────────────────────────────
        _buildInspector(theme, cs),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Filter row
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterRow(ColorScheme cs) {
    final types = _s.blocTypes.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      height: 44,
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All (${_s.length})',
                  selected: _filterBlocType == null,
                  onTap: () => setState(() => _filterBlocType = null),
                ),
                for (final t in types)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _FilterChip(
                      label: '$t (${_s.entriesForBloc(t).length})',
                      selected: _filterBlocType == t,
                      onTap: () => setState(() => _filterBlocType = t),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Slider
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSlider(ColorScheme cs) {
    final active = _s.activeEntries;
    final idx = _s.activeIndex;
    final hasActive = active.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          _SmallBtn(Icons.skip_previous, 'First',
              hasActive ? () => _s.jumpToActive(0) : null),
          _SmallBtn(Icons.chevron_left, 'Previous',
              hasActive && idx > 0 ? () => _s.jumpToActive(idx - 1) : null),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: cs.primary,
                inactiveTrackColor: cs.outlineVariant,
                thumbColor: cs.primary,
              ),
              child: Slider(
                value: hasActive
                    ? idx
                    .toDouble()
                    .clamp(0, (active.length - 1).toDouble())
                    : 0,
                min: 0,
                max: hasActive
                    ? (active.length - 1)
                    .toDouble()
                    .clamp(1, double.infinity)
                    : 1,
                divisions:
                hasActive && active.length > 1 ? active.length - 1 : null,
                onChanged: hasActive
                    ? (v) => _s.jumpToActive(v.round())
                    : null,
              ),
            ),
          ),
          _SmallBtn(Icons.chevron_right, 'Next',
              hasActive && idx < active.length - 1
                  ? () => _s.jumpToActive(idx + 1)
                  : null),
          _SmallBtn(Icons.skip_next, 'Last',
              hasActive
                  ? () => _s.jumpToActive(active.length - 1)
                  : null),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Timeline list
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTimeline(ThemeData theme, ColorScheme cs) {
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _s.length == 0
                ? 'No states recorded yet.\nInteract with your app to start.'
                : 'No entries for "${_filterBlocType}".\nTap "All" to see everything.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, i) {
        final entry = list[i];
        final realIdx = _s.entries.indexOf(entry);
        final isSelected = realIdx == _s.currentIndex;

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Inspector with diff toggle and replay button
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInspector(ThemeData theme, ColorScheme cs) {
    final entry = _s.currentEntry;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: entry == null
          ? Center(
          child: Text('Tap an entry above to inspect',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toolbar ─────────────────────────────────────────────
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.data_object, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text(entry.blocType,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                // Diff toggle
                if (entry.previousState != null)
                  _ToolbarChip(
                    label: 'Diff',
                    icon: Icons.compare_arrows,
                    active: _showDiff,
                    onTap: () =>
                        setState(() => _showDiff = !_showDiff),
                  ),
                if (entry.previousState != null)
                  const SizedBox(width: 4),
                // JSON toggle (always available)
                _ToolbarChip(
                  label: 'JSON',
                  icon: Icons.code,
                  active: !_showDiff,
                  onTap: () => setState(() => _showDiff = false),
                ),
                const SizedBox(width: 8),
                // Replay button
                if (_s.canReplay(entry.blocType))
                  _ToolbarChip(
                    label: 'Replay',
                    icon: Icons.replay,
                    active: false,
                    color: Colors.orange,
                    onTap: () {
                      final ok = _s.replayState(entry);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'State applied to ${entry.blocType}'
                                : 'Failed to apply state'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: _showDiff && entry.previousState != null
                  ? _DiffView(entry: entry)
                  : _JsonView(entry: entry),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

// ── Toolbar chip ────────────────────────────────────────────────────────────

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? c.withValues(alpha: 0.5) : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? c : cs.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? c : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
                : cs.outlineVariant,
          ),
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

// ── Timeline tile with proper eye icon ──────────────────────────────────────

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
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gap indicator
        if (gap != null && gap!.inMilliseconds > 200)
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2, bottom: 2),
            child: Row(
              children: [
                Container(width: 1, height: 12, color: cs.outlineVariant),
                const SizedBox(width: 8),
                Text(_formatGap(gap!),
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        // Entry row
        Material(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          child: InkWell(
            onTap: onJump,
            child: Opacity(
              opacity: entry.isSkipped ? 0.4 : 1.0,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  children: [
                    // Timeline dot
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? cs.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? cs.primary : cs.outline,
                          width: isSelected ? 3 : 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Info column
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
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  )),
                              if (entry.processingDuration != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _perfColor(
                                        entry.processingDuration!, cs)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
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
                    // ── Eye icon (skip/unskip) ──────────────────────────
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: Icon(
                          entry.isSkipped
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: entry.isSkipped
                              ? cs.error.withValues(alpha: 0.6)
                              : cs.onSurfaceVariant,
                        ),
                        tooltip: entry.isSkipped ? 'Unskip' : 'Skip',
                        onPressed: onToggleSkip,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
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

// ── JSON view ───────────────────────────────────────────────────────────────

class _JsonView extends StatelessWidget {
  const _JsonView({required this.entry});
  final DevToolsEntry entry;

  @override
  Widget build(BuildContext context) {
    String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(entry.toDisplayMap());
    } catch (_) {
      text = entry.toDisplayMap().toString();
    }
    return SelectableText(text,
        style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurface));
  }
}

// ── Diff view ───────────────────────────────────────────────────────────────

class _DiffView extends StatelessWidget {
  const _DiffView({required this.entry});
  final DevToolsEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diff = entry.computeDiff();

    if (diff == null || diff.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('No field-level changes detected.\n'
            'Ensure your state class has a toJson() method.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in diff.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge (+, −, ~)
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _diffColor(d.type).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    d.type == DiffType.added
                        ? '+'
                        : d.type == DiffType.removed
                        ? '−'
                        : '~',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _diffColor(d.type)),
                  ),
                ),
                const SizedBox(width: 8),
                // Field name + values
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
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
                                  color: Colors.red.shade400,
                                  decoration: TextDecoration.lineThrough)),
                          const TextSpan(text: ' → '),
                          TextSpan(
                              text: '${d.newValue}',
                              style:
                              TextStyle(color: Colors.green.shade400)),
                        ] else if (d.type == DiffType.added)
                          TextSpan(
                              text: '${d.newValue}',
                              style:
                              TextStyle(color: Colors.green.shade400))
                        else
                          TextSpan(
                              text: '${d.oldValue}',
                              style:
                              TextStyle(color: Colors.red.shade400)),
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

  Color _diffColor(DiffType t) {
    switch (t) {
      case DiffType.added:
        return Colors.green;
      case DiffType.removed:
        return Colors.red;
      case DiffType.changed:
        return Colors.orange;
    }
  }
}

// ── Small icon button ───────────────────────────────────────────────────────

class _SmallBtn extends StatelessWidget {
  const _SmallBtn(this.icon, this.tooltip, this.onPressed);
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}