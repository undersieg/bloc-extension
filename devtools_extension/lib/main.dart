import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/entries_panel.dart';
import 'src/graph_panel.dart';
import 'src/performance_panel.dart';

void main() {
  runApp(const BlocDevToolsExtension());
}

class BlocDevToolsExtension extends StatelessWidget {
  const BlocDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: _ExtensionBody(),
    );
  }
}

class _ExtensionBody extends StatefulWidget {
  const _ExtensionBody();

  @override
  State<_ExtensionBody> createState() => _ExtensionBodyState();
}

class _ExtensionBodyState extends State<_ExtensionBody> {
  Timer? _pollTimer;

  // Fetched data from the running app.
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic>? _graphData;
  Map<String, dynamic>? _perfData;
  int _lastFetchedIndex = 0;

  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _pollTimer = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _fetchIncremental());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Action callbacks (sent to running app via VM service) ─────────────

  Future<void> _callJumpTo(int index) async {
    try {
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.bloc_devtools.jumpTo',
        args: {'index': '$index'},
      );
    } catch (_) {}
  }

  Future<void> _callToggleSkip(int index) async {
    try {
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.bloc_devtools.toggleSkip',
        args: {'index': '$index'},
      );
    } catch (_) {}
  }

  Future<void> _callReplay(int index) async {
    try {
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.bloc_devtools.replay',
        args: {'index': '$index'},
      );
    } catch (_) {}
  }

  // ── Data fetching ─────────────────────────────────────────────────────

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summaryResp =
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.bloc_devtools.getState',
      );
      _summary = summaryResp.json ?? {};

      final entriesResp =
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.bloc_devtools.getEntries',
        args: {'sinceIndex': '0'},
      );
      final entriesJson = entriesResp.json ?? {};
      _entries = List<Map<String, dynamic>>.from(
          (entriesJson['entries'] as List?) ?? []);
      _lastFetchedIndex = entriesJson['totalCount'] as int? ?? 0;

      final graphResp =
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.bloc_devtools.getGraph',
      );
      _graphData = graphResp.json;

      final perfResp =
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.bloc_devtools.getPerformance',
      );
      _perfData = perfResp.json;

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Fetches only new entries since _lastFetchedIndex for efficiency.
  Future<void> _fetchIncremental() async {
    try {
      final entriesResp =
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.bloc_devtools.getEntries',
        args: {'sinceIndex': '$_lastFetchedIndex'},
      );
      final entriesJson = entriesResp.json ?? {};
      final newEntries = List<Map<String, dynamic>>.from(
          (entriesJson['entries'] as List?) ?? []);
      final totalCount = entriesJson['totalCount'] as int? ?? 0;

      if (newEntries.isNotEmpty) {
        _entries.addAll(newEntries);
        _lastFetchedIndex = totalCount;

        // Also refresh graph & perf data when there are new entries.
        final graphResp =
        await serviceManager.callServiceExtensionOnMainIsolate(
          'ext.bloc_devtools.getGraph',
        );
        _graphData = graphResp.json;

        final perfResp =
        await serviceManager.callServiceExtensionOnMainIsolate(
          'ext.bloc_devtools.getPerformance',
        );
        _perfData = perfResp.json;

        final summaryResp =
        await serviceManager.callServiceExtensionOnMainIsolate(
          'ext.bloc_devtools.getState',
        );
        _summary = summaryResp.json;

        if (mounted) setState(() {});
      }
    } catch (_) {
      // Silently ignore poll errors — the app may have restarted.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Failed to connect to BLoC DevTools',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(_error!,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAll,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.bug_report, size: 20),
                const SizedBox(width: 8),
                Text('BLoC DevTools',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_entries.length} states',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh',
                  onPressed: _fetchAll,
                ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'History'),
              Tab(text: 'Graph'),
              Tab(text: 'Performance'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                EntriesPanel(
                  entries: _entries,
                  summary: _summary,
                  onJumpTo: _callJumpTo,
                  onToggleSkip: _callToggleSkip,
                  onReplay: _callReplay,
                ),
                GraphPanel(data: _graphData),
                PerformancePanel(data: _perfData),
              ],
            ),
          ),
        ],
      ),
    );
  }
}