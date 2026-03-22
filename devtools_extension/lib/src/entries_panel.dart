import 'dart:convert';

import 'package:flutter/material.dart';

/// Callback for actions sent to the running app via VM service.
typedef ServiceAction = Future<void> Function(int index);

/// History panel for the DevTools browser extension.
/// Filter chips, slider, diff/json toggle, replay — no skip/eye.
class EntriesPanel extends StatefulWidget {
  const EntriesPanel({
    super.key,
    required this.entries,
    this.summary,
    this.onJumpTo,
    this.onReplay,
  });

  final List<Map<String, dynamic>> entries;
  final Map<String, dynamic>? summary;
  final ServiceAction? onJumpTo;
  final ServiceAction? onReplay;

  @override
  State<EntriesPanel> createState() => _EntriesPanelState();
}

class _EntriesPanelState extends State<EntriesPanel> {
  int _selectedIndex = -1;
  String? _filterBlocType;
  bool _showDiff = false;

  List<Map<String, dynamic>> get _all => widget.entries;

  List<Map<String, dynamic>> get _filtered {
    if (_filterBlocType == null) return _all;
    return _all.where((e) => e['blocType'] == _filterBlocType).toList();
  }

  Set<String> get _blocTypes =>
      _all.map((e) => e['blocType'] as String? ?? '').toSet();

  List<String> get _aliveBlocTypes =>
      List<String>.from((widget.summary?['aliveBlocTypes'] as List?) ?? []);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_all.isEmpty) {
      return const Center(
          child: Text('No states recorded yet. Interact with your app.'));
    }

    return Column(
      children: [
        _buildFilterRow(cs),
        _buildSlider(cs),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 3, child: _buildTimeline(cs)),
              VerticalDivider(width: 1, color: cs.outlineVariant),
              Expanded(flex: 2, child: _buildInspector(cs)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      height: 40,
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('All (${_all.length})', _filterBlocType == null,
                        () => setState(() => _filterBlocType = null), cs),
                for (final t in _blocTypes)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _chip(
                      '$t (${_all.where((e) => e['blocType'] == t).length})',
                      _filterBlocType == t,
                          () => setState(() => _filterBlocType = t),
                      cs,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, ColorScheme cs) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: sel ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            )),
      ),
    );
  }

  Widget _buildSlider(ColorScheme cs) {
    final total = _all.length;
    final idx = _selectedIndex.clamp(0, total - 1);
    final ok = total > 0;

    void jump(int i) {
      setState(() => _selectedIndex = i);
      widget.onJumpTo?.call(i);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          _btn(Icons.skip_previous, ok ? () => jump(0) : null),
          _btn(Icons.chevron_left,
              ok && idx > 0 ? () => jump(idx - 1) : null),
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
                value: ok ? idx.toDouble() : 0,
                min: 0,
                max: ok ? (total - 1).toDouble().clamp(1, double.infinity) : 1,
                divisions: total > 1 ? total - 1 : null,
                onChanged: ok ? (v) => jump(v.round()) : null,
              ),
            ),
          ),
          _btn(Icons.chevron_right,
              ok && idx < total - 1 ? () => jump(idx + 1) : null),
          _btn(Icons.skip_next, ok ? () => jump(total - 1) : null),
        ],
      ),
    );
  }

  Widget _buildTimeline(ColorScheme cs) {
    final list = _filtered;

    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, i) {
        final entry = list[i];
        final realIdx = _all.indexOf(entry);
        final isSelected = realIdx == _selectedIndex;
        final event = entry['event']?.toString() ?? '(initial state)';
        final blocType = entry['blocType'] as String? ?? '';
        final procUs = entry['processingUs'] as int?;
        final ts = entry['timestamp'] as String? ?? '';

        Duration? gap;
        if (i > 0) {
          final prevTs = list[i - 1]['timestamp'] as String?;
          if (prevTs != null && ts.isNotEmpty) {
            try {
              gap = DateTime.parse(ts).difference(DateTime.parse(prevTs));
            } catch (_) {}
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gap != null && gap.inMilliseconds > 200)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 2, bottom: 2),
                child: Row(
                  children: [
                    Container(width: 1, height: 12, color: cs.outlineVariant),
                    const SizedBox(width: 8),
                    Text(_fmtGap(gap),
                        style: TextStyle(
                            fontSize: 9, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            Material(
              color: isSelected
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() => _selectedIndex = realIdx);
                  widget.onJumpTo?.call(realIdx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                          isSelected ? cs.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? cs.primary : cs.outline,
                            width: isSelected ? 3 : 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(blocType,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: cs.onSurfaceVariant)),
                                if (procUs != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _perfColor(procUs)
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                      BorderRadius.circular(4),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInspector(ColorScheme cs) {
    if (_selectedIndex < 0 || _selectedIndex >= _all.length) {
      return Center(
          child: Text('Select an entry to inspect',
              style: TextStyle(color: cs.onSurfaceVariant)));
    }

    final entry = _all[_selectedIndex];
    final blocType = entry['blocType'] as String? ?? '';
    final hasPrev = entry['previousState'] != null &&
        entry['state'] is Map &&
        entry['previousState'] is Map;
    final canReplay = _aliveBlocTypes.contains(blocType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.data_object, size: 14, color: cs.primary),
              Text(blocType,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (hasPrev)
                _toolbarChip('Diff', Icons.compare_arrows, _showDiff,
                        () => setState(() => _showDiff = true), cs),
              _toolbarChip('JSON', Icons.code, !_showDiff,
                      () => setState(() => _showDiff = false), cs),
              if (canReplay)
                _toolbarChip('Replay', Icons.replay, false, () {
                  widget.onReplay?.call(_selectedIndex);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Replayed state to $blocType'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }, cs, color: Colors.orange),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: _showDiff && hasPrev
                ? _buildDiff(
                entry['previousState'] as Map<String, dynamic>,
                entry['state'] as Map<String, dynamic>,
                cs)
                : _buildJson(entry, cs),
          ),
        ),
      ],
    );
  }

  Widget _toolbarChip(String label, IconData icon, bool active,
      VoidCallback onTap, ColorScheme cs,
      {Color? color}) {
    final c = color ?? cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? c.withValues(alpha: 0.5) : cs.outlineVariant),
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

  Widget _buildJson(Map<String, dynamic> entry, ColorScheme cs) {
    String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(entry);
    } catch (_) {
      text = entry.toString();
    }
    return SelectableText(text,
        style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.5,
            color: cs.onSurface));
  }

  Widget _buildDiff(
      Map<String, dynamic> prev, Map<String, dynamic> curr, ColorScheme cs) {
    final allKeys = {...prev.keys, ...curr.keys};
    final diffs = <Widget>[];

    for (final key in allKeys) {
      final oldVal = prev[key];
      final newVal = curr[key];
      if ('$oldVal' != '$newVal') {
        final isAdded = !prev.containsKey(key);
        final isRemoved = !curr.containsKey(key);
        final diffColor = isAdded
            ? Colors.green
            : isRemoved
            ? Colors.red
            : Colors.orange;

        diffs.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAdded ? '+' : isRemoved ? '−' : '~',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: diffColor),
                ),
              ),
              const SizedBox(width: 8),
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
                          text: '$key: ',
                          style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                      if (!isAdded && !isRemoved) ...[
                        TextSpan(
                            text: '$oldVal',
                            style: TextStyle(
                                color: Colors.red.shade400,
                                decoration: TextDecoration.lineThrough)),
                        const TextSpan(text: ' → '),
                        TextSpan(
                            text: '$newVal',
                            style:
                            TextStyle(color: Colors.green.shade400)),
                      ] else if (isAdded)
                        TextSpan(
                            text: '$newVal',
                            style:
                            TextStyle(color: Colors.green.shade400))
                      else
                        TextSpan(
                            text: '$oldVal',
                            style: TextStyle(color: Colors.red.shade400)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
      }
    }

    if (diffs.isEmpty) {
      return Text('No field-level changes detected.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: diffs);
  }

  Widget _btn(IconData icon, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  String _fmtGap(Duration d) {
    if (d.inSeconds >= 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    if (d.inMilliseconds >= 1000) {
      return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${d.inMilliseconds}ms';
  }

  Color _perfColor(int us) {
    if (us < 16000) return Colors.green;
    if (us < 100000) return Colors.orange;
    return Colors.red;
  }
}