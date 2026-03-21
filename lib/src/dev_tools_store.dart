import 'package:bloc/bloc.dart' show BlocBase;
import 'package:flutter/foundation.dart';

import 'bloc_lifecycle.dart';
import 'dev_tools_entry.dart';

/// Centralized store for the BLoC dev tools extension.
///
/// Holds state history, BLoC lifecycle records, detected relationships,
/// performance metrics, and live BLoC references for state replay.
class DevToolsStore extends ChangeNotifier {
  DevToolsStore();

  // ── Singleton ─────────────────────────────────────────────────────────────

  static DevToolsStore? _instance;
  static DevToolsStore get instance => _instance ??= DevToolsStore();
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

  // ── Live BLoC instance registry (for state replay) ────────────────────────

  final Map<int, BlocBase<dynamic>> _liveInstances = {};

  /// Registers a live BlocBase so we can push state back to it.
  void registerBlocInstance(int instanceId, BlocBase<dynamic> bloc) {
    _liveInstances[instanceId] = bloc;
  }

  /// Removes a BlocBase reference when it closes.
  void unregisterBlocInstance(int instanceId) {
    _liveInstances.remove(instanceId);
  }

  /// Returns the live BlocBase for a given bloc type name, or null.
  BlocBase<dynamic>? _findLiveBloc(String blocType) {
    for (final bloc in _liveInstances.values) {
      if (bloc.runtimeType.toString() == blocType) return bloc;
    }
    return null;
  }

  /// Attempts to push a historical state onto a live BLoC/Cubit.
  ///
  /// Returns `true` if the state was successfully applied.
  /// This uses the `Emittable` interface — works for both Bloc and Cubit.
  bool replayState(DevToolsEntry entry) {
    final bloc = _findLiveBloc(entry.blocType);
    if (bloc == null || entry.state == null) return false;
    try {
      // BlocBase extends Emittable, which has emit().
      // In debug/dev mode this is accessible.
      (bloc as dynamic).emit(entry.state);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether a live instance exists for the given bloc type.
  bool canReplay(String blocType) => _findLiveBloc(blocType) != null;

  // ── BLoC lifecycle tracking ───────────────────────────────────────────────

  final Map<int, BlocLifecycleRecord> _lifecycles = {};

  List<BlocLifecycleRecord> get lifecycles => _lifecycles.values.toList();

  List<BlocLifecycleRecord> get aliveBlocs =>
      _lifecycles.values.where((r) => r.isAlive).toList();

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

  void recordClose(int instanceId) {
    _lifecycles[instanceId]?.closedAt = DateTime.now();
    notifyListeners();
  }

  void recordTransitionMetrics(int instanceId, Duration? processingTime) {
    final record = _lifecycles[instanceId];
    if (record == null) return;
    record.transitionCount++;
    if (processingTime != null) {
      record.totalProcessingTime += processingTime;
    }
  }

  // ── Relationship detection ────────────────────────────────────────────────

  static const int correlationWindowMs = 100;

  final Map<String, BlocRelationship> _relationships = {};

  List<BlocRelationship> get relationships => _relationships.values.toList();

  void _detectRelationships(DevToolsEntry newEntry) {
    for (int i = _entries.length - 1; i >= 0; i--) {
      final other = _entries[i];
      final gap =
          newEntry.timestamp.difference(other.timestamp).inMilliseconds;
      if (gap > correlationWindowMs) break;
      if (gap < 0) continue;
      if (other.blocType == newEntry.blocType) continue;

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
    // Don't clear _liveInstances — those blocs are still alive.
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

  List<DevToolsEntry> get entriesWithTiming =>
      _entries.where((e) => e.processingDuration != null).toList();

  Duration get avgProcessingTime {
    final timed = entriesWithTiming;
    if (timed.isEmpty) return Duration.zero;
    final totalUs = timed.fold<int>(
        0, (sum, e) => sum + e.processingDuration!.inMicroseconds);
    return Duration(microseconds: totalUs ~/ timed.length);
  }

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