import 'dart:convert';

import 'package:flutter/material.dart';

import '../dev_tools_entry.dart';
import '../dev_tools_store.dart';

/// A ready-to-use widget that displays the BLoC dev tools panel.
///
/// Place this widget in your app's debug drawer, a separate route, or
/// anywhere else that makes sense for your development workflow.
///
/// ```dart
/// Scaffold(
///   endDrawer: Drawer(
///     child: BlocDevToolsPanel(store: devToolsStore),
///   ),
///   // ...
/// )
/// ```
///
/// Features inspired by Redux DevTools:
/// - **History list**: chronological list of all state changes.
/// - **Time-travel slider**: scrub through history (skipped entries excluded).
/// - **Skip**: mark an entry as skipped so the slider passes over it.
/// - **Jump**: tap an entry to jump to that point in time.
/// - **State inspector**: view the JSON representation of the selected state.
/// - **Filter by BLoC type**: when multiple BLoCs are active.
/// - **Reset**: clear all recorded history.
class BlocDevToolsPanel extends StatefulWidget {
  /// Creates a dev tools panel connected to the given [store].
  const BlocDevToolsPanel({
    super.key,
    required this.store,
  });

  /// The [DevToolsStore] to read history from and dispatch actions to.
  final DevToolsStore store;

  @override
  State<BlocDevToolsPanel> createState() => _BlocDevToolsPanelState();
}

class _BlocDevToolsPanelState extends State<BlocDevToolsPanel> {
  String? _filterBlocType;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant BlocDevToolsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      widget.store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  DevToolsStore get _store => widget.store;

  List<DevToolsEntry> get _filteredEntries {
    if (_filterBlocType == null) return _store.entries;
    return _store.entriesForBloc(_filterBlocType!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        _buildHeader(theme, colorScheme),

        // ── Filter chips ────────────────────────────────────────────────
        if (_store.blocTypes.length > 1) _buildFilterRow(colorScheme),

        // ── Slider ──────────────────────────────────────────────────────
        _buildSlider(colorScheme),

        // ── History list ────────────────────────────────────────────────
        Expanded(child: _buildHistoryList(theme, colorScheme)),

        // ── State inspector ─────────────────────────────────────────────
        _buildStateInspector(theme, colorScheme),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Header
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'BLoC DevTools',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_store.length} states',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.restart_alt,
            tooltip: 'Reset history',
            onPressed: _store.length > 0
                ? () {
                    _filterBlocType = null;
                    _store.reset();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Filter row
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterRow(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            selected: _filterBlocType == null,
            onTap: () => setState(() => _filterBlocType = null),
          ),
          for (final type in _store.blocTypes)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _FilterChip(
                label: type,
                selected: _filterBlocType == type,
                onTap: () => setState(() => _filterBlocType = type),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Slider
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSlider(ColorScheme colorScheme) {
    final active = _store.activeEntries;
    final activeIdx = _store.activeIndex;
    final hasActive = active.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.skip_previous,
            tooltip: 'First state',
            onPressed: hasActive ? () => _store.jumpToActive(0) : null,
          ),
          _IconBtn(
            icon: Icons.chevron_left,
            tooltip: 'Previous state',
            onPressed: hasActive && activeIdx > 0
                ? () => _store.jumpToActive(activeIdx - 1)
                : null,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.outlineVariant,
                thumbColor: colorScheme.primary,
              ),
              child: Slider(
                value: hasActive ? activeIdx.toDouble().clamp(0, (active.length - 1).toDouble()) : 0,
                min: 0,
                max: hasActive ? (active.length - 1).toDouble().clamp(1, double.infinity) : 1,
                divisions: hasActive && active.length > 1 ? active.length - 1 : null,
                onChanged: hasActive
                    ? (v) => _store.jumpToActive(v.round())
                    : null,
              ),
            ),
          ),
          _IconBtn(
            icon: Icons.chevron_right,
            tooltip: 'Next state',
            onPressed: hasActive && activeIdx < active.length - 1
                ? () => _store.jumpToActive(activeIdx + 1)
                : null,
          ),
          _IconBtn(
            icon: Icons.skip_next,
            tooltip: 'Last state',
            onPressed: hasActive
                ? () => _store.jumpToActive(active.length - 1)
                : null,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // History list
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHistoryList(ThemeData theme, ColorScheme colorScheme) {
    final filtered = _filteredEntries;

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No states recorded yet.\nInteract with your app to start.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final entry = filtered[index];
        // Find the *real* index in the store (needed for jumpTo/toggleSkip).
        final realIndex = _store.entries.indexOf(entry);
        final isSelected = realIndex == _store.currentIndex;

        return _HistoryTile(
          entry: entry,
          index: realIndex,
          isSelected: isSelected,
          onJump: () => _store.jumpTo(realIndex),
          onToggleSkip: () => _store.toggleSkip(realIndex),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // State inspector
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStateInspector(ThemeData theme, ColorScheme colorScheme) {
    final entry = _store.currentEntry;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 180,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: entry == null
          ? Center(
              child: Text(
                'Select a state to inspect',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.data_object,
                          size: 14, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'State inspector',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        entry.blocType,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SelectableText(
                      _prettyPrint(entry.toDisplayMap()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _prettyPrint(Map<String, dynamic> map) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(map);
    } catch (_) {
      return map.toString();
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

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
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.index,
    required this.isSelected,
    required this.onJump,
    required this.onToggleSkip,
  });

  final DevToolsEntry entry;
  final int index;
  final bool isSelected;
  final VoidCallback onJump;
  final VoidCallback onToggleSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSkipped = entry.isSkipped;
    final time = entry.timestamp;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${(time.millisecond ~/ 10).toString().padLeft(2, '0')}';

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: onJump,
        child: Opacity(
          opacity: isSkipped ? 0.45 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Index badge
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Entry info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.event?.toString() ?? '(initial state)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration:
                              isSkipped ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.blocType} · $timeStr',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                // Skip button
                _IconBtn(
                  icon:
                      isSkipped ? Icons.visibility_off : Icons.visibility,
                  tooltip: isSkipped ? 'Unskip' : 'Skip',
                  onPressed: onToggleSkip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
