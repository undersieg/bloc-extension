import 'package:flutter/foundation.dart';

import 'bloc_lifecycle.dart';
import 'dev_tools_entry.dart';

/// Centralized store for the BLoC dev tools extension.
///
/// Holds state history, BLoC lifecycle records, detected relationships,
/// and performance metrics. Notifies listeners (the UI) on every change.
class DevToolsStore extends ChangeNotifier {
  DevToolsStore();

  // ── Singleton ─────────────────────────────────────────────────────────────

  static DevToolsStore? _instance;

  /// Lazily-created global instance accessible from anywhere.
  static DevToolsStore get instance => _instance ??= DevToolsStore();

  /// Replaces the singleton (useful in tests).
  static set instance(DevToolsStore store) => _instance = store;

  // ── History ───────────────────────────────────────────────────────────────

  final List<DevToolsEntry> _entries = [];

  List<DevToolsEntry> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;

  // ── Time-travel cursor ────────────────────────────────────────────────────

  int _currentIndex = -1;

  int get currentIndex => _currentIndex;

  DevToolsEntry? get currentEntry =>
      _currentIndex >= 0 && _currentIndex < _entries.length
          ? _entries[_currentIndex]
          : null;

  // ── BLoC lifecycle tracking ───────────────────────────────────────────────

  final Map<int, BlocLifecycleRecord> _lifecycles = {};

  /// All lifecycle records (active + closed).
  List<BlocLifecycleRecord> get lifecycles => _lifecycles.values.toList();

  /// Only the currently alive BLoC/Cubit instances.
  List<BlocLifecycleRecord> get aliveBlocs =>
      _lifecycles.values.where((r) => r.isAlive).toList();

  /// Records a new BLoC/Cubit creation.
  void recordCreate({
    required String blocType,
    required int instanceId,
    required bool isBloc,
  }) {
    _lifecycles[instanceId] = BlocLifecycleRecord(
      blocType: blocType,
      instanceId: instanceId,
      createdAt: DateTime.now(),
      isBloc: isBloc,
    );
    notifyListeners();
  }

  /// Records a BLoC/Cubit closing.
  void recordClose(int instanceId) {
    _lifecycles[instanceId]?.closedAt = DateTime.now();
    notifyListeners();
  }

  /// Increments the transition counter and accumulates processing time
  /// for the given instance.
  void recordTransitionMetrics(int instanceId, Duration? processingTime) {
    final record = _lifecycles[instanceId];
    if (record == null) return;
    record.transitionCount++;
    if (processingTime != null) {
      record.totalProcessingTime += processingTime;
    }
  }

  // ── Relationship detection ────────────────────────────────────────────────

  /// Window (in ms) within which two BLoC transitions are considered correlated.
  static const int correlationWindowMs = 100;

  final Map<String, BlocRelationship> _relationships = {};

  /// All detected relationships.
  List<BlocRelationship> get relationships => _relationships.values.toList();

  /// Attempts to correlate a new entry with recent entries from other BLoCs.
  void _detectRelationships(DevToolsEntry newEntry) {
    // Look backwards through recent entries for events from *other* BLoCs
    // that happened within the correlation window.
    for (int i = _entries.length - 1; i >= 0; i--) {
      final other = _entries[i];
      final gap =
          newEntry.timestamp.difference(other.timestamp).inMilliseconds;
      if (gap > correlationWindowMs) break; // Too old
      if (gap < 0) continue; // Shouldn't happen
      if (other.blocType == newEntry.blocType) continue; // Same BLoC

      // Source = the older entry, target = the newer entry.
      final key = '${other.blocType}→${newEntry.blocType}';
      _relationships.putIfAbsent(
        key,
            () => BlocRelationship(
          sourceBlocType: other.blocType,
          targetBlocType: newEntry.blocType,
        ),
      );
      _relationships[key]!.correlationCount++;
    }
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  /// Adds a new entry, detects relationships, and advances the cursor.
  void addEntry(DevToolsEntry entry) {
    _detectRelationships(entry);
    _entries.add(entry);
    _currentIndex = _entries.length - 1;
    notifyListeners();
  }

  // ── Time-travel actions ───────────────────────────────────────────────────

  void jumpTo(int index) {
    if (index < 0 || index >= _entries.length) return;
    _currentIndex = index;
    notifyListeners();
  }

  void toggleSkip(int index) {
    if (index < 0 || index >= _entries.length) return;
    _entries[index] = _entries[index].copyWith(
      isSkipped: !_entries[index].isSkipped,
    );
    notifyListeners();
  }

  void reset() {
    _entries.clear();
    _currentIndex = -1;
    _lifecycles.clear();
    _relationships.clear();
    notifyListeners();
  }

  // ── Slider helpers ────────────────────────────────────────────────────────

  List<DevToolsEntry> get activeEntries =>
      _entries.where((e) => !e.isSkipped).toList();

  int get activeIndex {
    if (_currentIndex < 0) return -1;
    final current = currentEntry;
    if (current == null || current.isSkipped) return -1;
    return activeEntries.indexOf(current);
  }

  void jumpToActive(int activeIdx) {
    if (activeIdx < 0 || activeIdx >= activeEntries.length) return;
    final target = activeEntries[activeIdx];
    final realIndex = _entries.indexOf(target);
    if (realIndex >= 0) jumpTo(realIndex);
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  Set<String> get blocTypes => _entries.map((e) => e.blocType).toSet();

  List<DevToolsEntry> entriesForBloc(String blocType) =>
      _entries.where((e) => e.blocType == blocType).toList();

  // ── Performance helpers ───────────────────────────────────────────────────

  /// Returns entries that have processingDuration data, for performance charts.
  List<DevToolsEntry> get entriesWithTiming =>
      _entries.where((e) => e.processingDuration != null).toList();

  /// Average processing time across all measured transitions.
  Duration get avgProcessingTime {
    final timed = entriesWithTiming;
    if (timed.isEmpty) return Duration.zero;
    final totalUs = timed.fold<int>(
        0, (sum, e) => sum + e.processingDuration!.inMicroseconds);
    return Duration(microseconds: totalUs ~/ timed.length);
  }

  /// Slowest recorded transition.
  DevToolsEntry? get slowestTransition {
    final timed = entriesWithTiming;
    if (timed.isEmpty) return null;
    return timed.reduce((a, b) =>
    a.processingDuration!.inMicroseconds >=
        b.processingDuration!.inMicroseconds
        ? a
        : b);
  }
}
