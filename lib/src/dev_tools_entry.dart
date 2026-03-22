import 'dart:convert';

/// Represents a single recorded entry in the BLoC dev tools history.
class DevToolsEntry {
  const DevToolsEntry({
    required this.blocType,
    required this.state,
    required this.timestamp,
    this.previousState,
    this.event,
    this.isSkipped = false,
    this.processingDuration,
  });

  /// Runtime type name of the BLoC or Cubit.
  final String blocType;

  /// The state snapshot at this point.
  final Object? state;

  /// The state *before* this transition (for diff).
  final Object? previousState;

  /// The event that triggered this change (null for Cubits / initial).
  final Object? event;

  /// When this entry was recorded.
  final DateTime timestamp;

  /// Whether this entry is "skipped" in the slider.
  final bool isSkipped;

  /// Time between event dispatch and state emission (for performance).
  /// Only available for Bloc transitions where we can measure onEvent→onTransition.
  final Duration? processingDuration;

  DevToolsEntry copyWith({
    String? blocType,
    Object? state,
    Object? previousState,
    Object? event,
    DateTime? timestamp,
    bool? isSkipped,
    Duration? processingDuration,
  }) {
    return DevToolsEntry(
      blocType: blocType ?? this.blocType,
      state: state ?? this.state,
      previousState: previousState ?? this.previousState,
      event: event ?? this.event,
      timestamp: timestamp ?? this.timestamp,
      isSkipped: isSkipped ?? this.isSkipped,
      processingDuration: processingDuration ?? this.processingDuration,
    );
  }

  /// JSON-friendly map for inspector display.
  Map<String, dynamic> toDisplayMap() {
    return {
      'blocType': blocType,
      'event': event?.toString() ?? '(initial)',
      'state': tryToJson(state),
      'timestamp': timestamp.toIso8601String(),
      if (processingDuration != null)
        'processingMs': processingDuration!.inMicroseconds / 1000.0,
    };
  }

  /// Computes a field-by-field diff between [previousState] and [state].
  /// Returns null if both states are identical or can't be compared.
  Map<String, StateDiffEntry>? computeDiff() {
    final prev = tryToJson(previousState);
    final curr = tryToJson(state);
    if (prev is! Map<String, dynamic> || curr is! Map<String, dynamic>) {
      return null;
    }
    final diff = <String, StateDiffEntry>{};
    final allKeys = {...prev.keys, ...curr.keys};
    for (final key in allKeys) {
      final oldVal = prev[key];
      final newVal = curr[key];
      final oldStr = _encode(oldVal);
      final newStr = _encode(newVal);
      if (oldStr != newStr) {
        diff[key] = StateDiffEntry(
          field: key,
          oldValue: oldVal,
          newValue: newVal,
          type: !prev.containsKey(key)
              ? DiffType.added
              : !curr.containsKey(key)
              ? DiffType.removed
              : DiffType.changed,
        );
      }
    }
    return diff.isEmpty ? null : diff;
  }

  static String _encode(dynamic val) {
    try {
      return const JsonEncoder().convert(val);
    } catch (_) {
      return val.toString();
    }
  }

  /// Attempts to call `toJson()` on an object; falls back to `toString()`.
  static dynamic tryToJson(Object? obj) {
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

/// Result of diffing a single field between two states.
class StateDiffEntry {
  const StateDiffEntry({
    required this.field,
    required this.type,
    this.oldValue,
    this.newValue,
  });

  final String field;
  final DiffType type;
  final dynamic oldValue;
  final dynamic newValue;
}

enum DiffType { added, removed, changed }