import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders any JSON-compatible value as a collapsible tree with
/// Expand All / Collapse All controls.
class JsonTreeView extends StatefulWidget {
  const JsonTreeView({super.key, required this.data, this.rootLabel});
  final dynamic data;
  final String? rootLabel;

  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  final ValueNotifier<bool?> _expandSignal = ValueNotifier(null);

  @override
  void dispose() {
    _expandSignal.dispose();
    super.dispose();
  }

  void _expandAll() {
    _expandSignal.value = true;
    _expandSignal.value = null;
  }

  void _collapseAll() {
    _expandSignal.value = false;
    _expandSignal.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _ActionChip(
              icon: Icons.unfold_more,
              label: 'Expand all',
              onTap: _expandAll,
              cs: cs,
            ),
            const SizedBox(width: 4),
            _ActionChip(
              icon: Icons.unfold_less,
              label: 'Collapse all',
              onTap: _collapseAll,
              cs: cs,
            ),
          ],
        ),
        const SizedBox(height: 4),
        _JsonNode(
          keyName: widget.rootLabel ?? 'state',
          value: widget.data,
          depth: 0,
          initiallyExpanded: true,
          expandSignal: _expandSignal,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: cs.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _JsonNode extends StatefulWidget {
  const _JsonNode({
    required this.keyName,
    required this.value,
    required this.depth,
    required this.expandSignal,
    this.initiallyExpanded = false,
  });

  final String keyName;
  final dynamic value;
  final int depth;
  final bool initiallyExpanded;
  final ValueNotifier<bool?> expandSignal;

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    widget.expandSignal.addListener(_onSignal);
  }

  @override
  void dispose() {
    widget.expandSignal.removeListener(_onSignal);
    super.dispose();
  }

  void _onSignal() {
    final val = widget.expandSignal.value;
    if (val != null && _isExpandable) {
      setState(() => _expanded = val);
    }
  }

  bool get _isExpandable =>
      widget.value is Map || widget.value is List;

  String get _typeHint {
    final v = widget.value;
    if (v is Map) {
      return '{${v.length}}';
    }
    if (v is List) {
      return '[${v.length}]';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_isExpandable) {
      return _leafRow(cs);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _expandableHeader(cs),
        if (_expanded) _buildChildren(cs),
      ],
    );
  }

  Widget _expandableHeader(ColorScheme cs) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.depth * 16.0,
          top: 3,
          bottom: 3,
          right: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _expanded ? Icons.expand_more : Icons.chevron_right,
              size: 14,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              widget.keyName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.primary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _typeHint,
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildren(ColorScheme cs) {
    final v = widget.value;
    if (v is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in v.entries)
            _JsonNode(
              keyName: entry.key.toString(),
              value: entry.value,
              depth: widget.depth + 1,
              expandSignal: widget.expandSignal,
            ),
        ],
      );
    }
    if (v is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < v.length; i++)
            _JsonNode(
              keyName: '[$i]',
              value: v[i],
              depth: widget.depth + 1,
              expandSignal: widget.expandSignal,
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _leafRow(ColorScheme cs) {
    return InkWell(
      onTap: () {
        final text = _formatValue(widget.value);
        Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied: ${widget.keyName}'),
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.depth * 16.0 + 18,
          top: 2,
          bottom: 2,
          right: 4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.keyName}: ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            Flexible(
              child: Text(
                _formatValue(widget.value),
                style: TextStyle(
                  fontSize: 11,
                  color: _valueColor(widget.value, cs),
                  fontFamily: 'monospace',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      return '"$value"';
    }
    if (value is bool || value is num) {
      return value.toString();
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Color _valueColor(dynamic value, ColorScheme cs) {
    if (value == null) {
      return cs.onSurfaceVariant;
    }
    if (value is String) {
      return Colors.green.shade400;
    }
    if (value is num) {
      return Colors.blue.shade400;
    }
    if (value is bool) {
      return Colors.orange.shade400;
    }
    return cs.onSurface;
  }
}