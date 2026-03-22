import 'package:flutter/material.dart';

import '../dev_tools_store.dart';
import 'tab_graph.dart';
import 'tab_history.dart';
import 'tab_performance.dart';

/// The main dev tools panel widget with three tabs:
/// **History** (timeline + slider + state inspector),
/// **Graph** (live BLoC connection map),
/// **Performance** (processing metrics).
class BlocDevToolsPanel extends StatefulWidget {
  const BlocDevToolsPanel({super.key, required this.store});

  final DevToolsStore store;

  @override
  State<BlocDevToolsPanel> createState() => _BlocDevToolsPanelState();
}

class _BlocDevToolsPanelState extends State<BlocDevToolsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('BLoC DevTools',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${widget.store.length} states',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.restart_alt, size: 18),
                    tooltip: 'Reset all',
                    onPressed:
                    widget.store.length > 0 ? widget.store.reset : null,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TabBar(
                controller: _tabController,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        const Text('History'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_tree, size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        const Text('Graph'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed, size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        const Text('Perf'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            // Disable swipe-to-switch — prevents conflict with graph node
            // dragging on mobile. Users tap tab headers to switch instead.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              HistoryTab(store: widget.store),
              GraphTab(store: widget.store),
              PerformanceTab(store: widget.store),
            ],
          ),
        ),
      ],
    );
  }
}