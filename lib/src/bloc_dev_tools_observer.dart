import 'package:bloc/bloc.dart';

import 'dev_tools_entry.dart';
import 'dev_tools_store.dart';

/// A [BlocObserver] that records transitions, lifecycle events,
/// performance timing, and keeps live BLoC references for state replay.
class BlocDevToolsObserver extends BlocObserver {
  BlocDevToolsObserver(
      this.store, {
        this.innerObserver,
      });

  final DevToolsStore store;
  final BlocObserver? innerObserver;

  /// Tracks Bloc (not Cubit) instances to avoid double-recording in onChange.
  final Set<int> _blocInstances = {};

  /// Maps instanceId → latest state for previousState capture.
  final Map<int, Object?> _latestStates = {};

  /// Maps instanceId → most recent onEvent timestamp for processing time.
  final Map<int, DateTime> _eventTimestamps = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);

    final id = bloc.hashCode;
    final isBloc = bloc is Bloc;
    if (isBloc) _blocInstances.add(id);

    // Register the live reference so the store can push state back.
    store.registerBlocInstance(id, bloc);

    store.recordCreate(
      blocType: bloc.runtimeType.toString(),
      instanceId: id,
      isBloc: isBloc,
    );

    _latestStates[id] = bloc.state;
    store.addEntry(DevToolsEntry(
      blocType: bloc.runtimeType.toString(),
      state: bloc.state,
      timestamp: DateTime.now(),
    ));

    innerObserver?.onCreate(bloc);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    final id = bloc.hashCode;
    _blocInstances.remove(id);
    _latestStates.remove(id);
    _eventTimestamps.remove(id);
    store.unregisterBlocInstance(id);
    store.recordClose(id);
    innerObserver?.onClose(bloc);
  }

  // ── Events (for timing) ───────────────────────────────────────────────────

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    _eventTimestamps[bloc.hashCode] = DateTime.now();
    innerObserver?.onEvent(bloc, event);
  }

  // ── Transitions (Bloc) ────────────────────────────────────────────────────

  @override
  void onTransition(
      Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);

    final id = bloc.hashCode;
    final now = DateTime.now();

    Duration? processing;
    final eventTime = _eventTimestamps.remove(id);
    if (eventTime != null) {
      processing = now.difference(eventTime);
    }

    final previousState = _latestStates[id];
    _latestStates[id] = transition.nextState;

    store.recordTransitionMetrics(id, processing);

    store.addEntry(DevToolsEntry(
      blocType: bloc.runtimeType.toString(),
      state: transition.nextState,
      previousState: previousState,
      event: transition.event,
      timestamp: now,
      processingDuration: processing,
    ));

    innerObserver?.onTransition(bloc, transition);
  }

  // ── Changes (Cubit only) ──────────────────────────────────────────────────

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);

    final id = bloc.hashCode;

    if (_blocInstances.contains(id)) {
      innerObserver?.onChange(bloc, change);
      return;
    }

    final previousState = _latestStates[id];
    _latestStates[id] = change.nextState;

    // Record metrics for Cubits too (no timing data, but count matters).
    store.recordTransitionMetrics(id, null);

    store.addEntry(DevToolsEntry(
      blocType: bloc.runtimeType.toString(),
      state: change.nextState,
      previousState: previousState,
      timestamp: DateTime.now(),
    ));

    innerObserver?.onChange(bloc, change);
  }

  // ── Errors ────────────────────────────────────────────────────────────────

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    innerObserver?.onError(bloc, error, stackTrace);
  }
}