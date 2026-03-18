/// Represents a single recorded entry in the BLoC dev tools history.
///
/// Each entry captures a state snapshot along with the event that triggered
/// the state change (if available — Cubits emit states without events).
class DevToolsEntry {
  /// Creates a new [DevToolsEntry].
  const DevToolsEntry({
    required this.blocType,
    required this.state,
    required this.timestamp,
    this.event,
    this.isSkipped = false,
  });

  /// The runtime type name of the BLoC or Cubit that produced this entry.
  final String blocType;

  /// The state object at this point in time.
  final Object? state;

  /// The event that triggered this state change.
  /// Will be `null` for Cubit changes or for the initial state.
  final Object? event;

  /// The time this entry was recorded.
  final DateTime timestamp;

  /// Whether this entry has been "skipped" in the time-travel slider.
  /// Skipped entries are excluded from the slider playback but remain
  /// visible in the history list.
  final bool isSkipped;

  /// Creates a copy of this entry with the given fields replaced.
  DevToolsEntry copyWith({
    String? blocType,
    Object? state,
    Object? event,
    DateTime? timestamp,
    bool? isSkipped,
  }) {
    return DevToolsEntry(
      blocType: blocType ?? this.blocType,
      state: state ?? this.state,
      event: event ?? this.event,
      timestamp: timestamp ?? this.timestamp,
      isSkipped: isSkipped ?? this.isSkipped,
    );
  }

  /// Returns a JSON-compatible map of this entry for inspection.
  Map<String, dynamic> toDisplayMap() {
    return {
      'blocType': blocType,
      'event': event?.toString() ?? '(initial)',
      'state': _tryToJson(state),
      'timestamp': timestamp.toIso8601String(),
      'isSkipped': isSkipped,
    };
  }

  /// Attempts to call `toJson()` on the state if available,
  /// otherwise falls back to `toString()`.
  static dynamic _tryToJson(Object? obj) {
    if (obj == null) return null;
    try {
      // ignore: avoid_dynamic_calls
      return (obj as dynamic).toJson();
    } catch (_) {
      return obj.toString();
    }
  }

  @override
  String toString() =>
      'DevToolsEntry(bloc: $blocType, event: $event, state: $state)';
}
