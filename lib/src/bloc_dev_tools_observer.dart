import 'package:bloc/bloc.dart';

import 'dev_tools_entry.dart';
import 'dev_tools_store.dart';

/// A [BlocObserver] that records every state transition into a [DevToolsStore].
///
/// Attach this observer to `Bloc.observer` during development to enable
/// time-travel debugging in the dev tools panel.
///
/// ```dart
/// void main() {
///   final store = DevToolsStore();
///   Bloc.observer = BlocDevToolsObserver(store);
///   runApp(const MyApp());
/// }
/// ```
///
/// This observer captures:
/// - **Bloc transitions** (event → currentState → nextState) via [onTransition].
/// - **Cubit changes** (currentState → nextState) via [onChange], but only for
///   Cubits (not Blocs, since Blocs already report through onTransition).
/// - **Bloc creation** via [onCreate] to record the initial state.
/// - **Errors** via [onError] for optional error logging.
class BlocDevToolsObserver extends BlocObserver {
  /// Creates an observer that writes into the given [store].
  ///
  /// If [innerObserver] is provided, every callback is forwarded to it after
  /// recording. This lets you compose observers (e.g. keep your existing
  /// logging observer alongside the dev tools observer).
  BlocDevToolsObserver(
    this.store, {
    this.innerObserver,
  });

  /// The dev tools store where all entries are recorded.
  final DevToolsStore store;

  /// An optional inner observer to delegate to (decorator pattern).
  final BlocObserver? innerObserver;

  /// Tracks which BlocBase instances are Bloc (not Cubit) so that
  /// [onChange] can avoid double-recording for Blocs.
  final Set<int> _blocInstances = {};

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);

    // Track whether this is a Bloc (has events) vs. a Cubit.
    if (bloc is Bloc) {
      _blocInstances.add(bloc.hashCode);
    }

    // Record the initial state.
    store.addEntry(
      DevToolsEntry(
        blocType: bloc.runtimeType.toString(),
        state: bloc.state,
        timestamp: DateTime.now(),
      ),
    );

    innerObserver?.onCreate(bloc);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    _blocInstances.remove(bloc.hashCode);
    innerObserver?.onClose(bloc);
  }

  // ---------------------------------------------------------------------------
  // State changes
  // ---------------------------------------------------------------------------

  @override
  void onTransition(Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);

    store.addEntry(
      DevToolsEntry(
        blocType: bloc.runtimeType.toString(),
        state: transition.nextState,
        event: transition.event,
        timestamp: DateTime.now(),
      ),
    );

    innerObserver?.onTransition(bloc, transition);
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);

    // Blocs already report via onTransition — don't double-record.
    if (_blocInstances.contains(bloc.hashCode)) {
      innerObserver?.onChange(bloc, change);
      return;
    }

    // This is a Cubit change.
    store.addEntry(
      DevToolsEntry(
        blocType: bloc.runtimeType.toString(),
        state: change.nextState,
        timestamp: DateTime.now(),
      ),
    );

    innerObserver?.onChange(bloc, change);
  }

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    innerObserver?.onError(bloc, error, stackTrace);
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    innerObserver?.onEvent(bloc, event);
  }
}
