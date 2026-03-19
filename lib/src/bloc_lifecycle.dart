/// Tracks the lifecycle of a single BLoC or Cubit instance.
class BlocLifecycleRecord {
  BlocLifecycleRecord({
    required this.blocType,
    required this.instanceId,
    required this.createdAt,
    required this.isBloc,
  });

  /// Runtime type name (e.g. "CounterBloc").
  final String blocType;

  /// Unique identifier (hashCode of the BlocBase instance).
  final int instanceId;

  /// Whether this is a Bloc (true) or Cubit (false).
  final bool isBloc;

  /// When the BLoC/Cubit was created.
  final DateTime createdAt;

  /// When it was closed (null if still alive).
  DateTime? closedAt;

  /// Number of state changes this instance has emitted.
  int transitionCount = 0;

  /// Total processing time across all transitions.
  Duration totalProcessingTime = Duration.zero;

  /// Whether this instance is currently alive.
  bool get isAlive => closedAt == null;

  /// How long this instance has been alive (or was alive).
  Duration get lifetime =>
      (closedAt ?? DateTime.now()).difference(createdAt);

  /// Average processing time per transition.
  Duration get avgProcessingTime => transitionCount > 0
      ? Duration(
          microseconds:
              totalProcessingTime.inMicroseconds ~/ transitionCount)
      : Duration.zero;
}

/// Describes a detected relationship between two BLoC types.
///
/// Relationships are inferred from temporal proximity: if BLoC A emits
/// a state change and BLoC B emits one within [correlationWindowMs],
/// they are considered related. The strength grows with each correlated pair.
class BlocRelationship {
  BlocRelationship({
    required this.sourceBlocType,
    required this.targetBlocType,
  });

  /// The BLoC that emitted first.
  final String sourceBlocType;

  /// The BLoC that emitted shortly after.
  final String targetBlocType;

  /// How many correlated event pairs have been observed.
  int correlationCount = 0;

  /// Strength of the relationship (0.0–1.0), derived from correlation count.
  double get strength => (correlationCount / (correlationCount + 3)).clamp(0.0, 1.0);

  /// Unique key for deduplication.
  String get key => '$sourceBlocType→$targetBlocType';
}
