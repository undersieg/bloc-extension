import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';

import 'helpers.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);

  DevToolsEntry _entry({
    String blocType = 'TestBloc',
    Object? state = const TestState(1),
    Object? previousState,
    Object? event,
    bool isBloc = true,
    bool isSkipped = false,
    Duration? processingDuration,
  }) {
    return DevToolsEntry(
      blocType: blocType,
      state: state,
      previousState: previousState,
      event: event,
      isBloc: isBloc,
      timestamp: now,
      isSkipped: isSkipped,
      processingDuration: processingDuration,
    );
  }

  group('DevToolsEntry', () {
    test('stores all fields', () {
      final entry = _entry(
        event: TestIncrement(),
        previousState: const TestState(0),
        processingDuration: const Duration(microseconds: 500),
      );

      expect(entry.blocType, 'TestBloc');
      expect(entry.state, const TestState(1));
      expect(entry.previousState, const TestState(0));
      expect(entry.event.toString(), 'TestIncrement');
      expect(entry.isBloc, true);
      expect(entry.isSkipped, false);
      expect(entry.timestamp, now);
      expect(entry.processingDuration, const Duration(microseconds: 500));
    });

    test('copyWith replaces only specified fields', () {
      final original = _entry();
      final copied = original.copyWith(isSkipped: true, isBloc: false);

      expect(copied.blocType, original.blocType);
      expect(copied.state, original.state);
      expect(copied.timestamp, original.timestamp);
      expect(copied.isSkipped, true);
      expect(copied.isBloc, false);
    });

    test('copyWith preserves all fields when no arguments given', () {
      final original = _entry(
        event: TestIncrement(),
        isBloc: true,
        isSkipped: true,
        processingDuration: const Duration(milliseconds: 1),
      );
      final copied = original.copyWith();

      expect(copied.blocType, original.blocType);
      expect(copied.event, original.event);
      expect(copied.isBloc, original.isBloc);
      expect(copied.isSkipped, original.isSkipped);
      expect(copied.processingDuration, original.processingDuration);
    });
  });

  group('toDisplayMap', () {
    test('includes blocType, event, state, and timestamp', () {
      final entry = _entry(event: TestIncrement());
      final map = entry.toDisplayMap();

      expect(map['blocType'], 'TestBloc');
      expect(map['event'], 'TestIncrement');
      expect(map['timestamp'], now.toIso8601String());
      expect(map.containsKey('state'), true);
    });

    test('event defaults to (initial) when null', () {
      final entry = _entry();
      expect(entry.toDisplayMap()['event'], '(initial)');
    });

    test('includes processingMs only when duration is set', () {
      final withDuration = _entry(
        processingDuration: const Duration(microseconds: 1500),
      );
      final withoutDuration = _entry();

      expect(withDuration.toDisplayMap()['processingMs'], 1.5);
      expect(withoutDuration.toDisplayMap().containsKey('processingMs'), false);
    });
  });

  group('tryToJson', () {
    test('returns null for null input', () {
      expect(DevToolsEntry.tryToJson(null), null);
    });

    test('calls toJson() on objects that support it', () {
      final result = DevToolsEntry.tryToJson(const TestState(42));
      expect(result, {'value': 42});
    });

    test('falls back to toString() for objects without toJson()', () {
      final result = DevToolsEntry.tryToJson(12345);
      expect(result, '12345');
    });

    test('works with TestCubitState', () {
      final result =
          DevToolsEntry.tryToJson(const TestCubitState(label: 'x', count: 3));
      expect(result, {'label': 'x', 'count': 3});
    });
  });

  group('computeDiff', () {
    test('returns null when previousState is null', () {
      final entry = _entry(previousState: null);
      expect(entry.computeDiff(), null);
    });

    test('returns null when states have no toJson()', () {
      final entry = _entry(
        state: 'plain string',
        previousState: 'other string',
      );
      expect(entry.computeDiff(), null);
    });

    test('returns null when states are identical', () {
      final entry = _entry(
        state: const TestState(5),
        previousState: const TestState(5),
      );
      expect(entry.computeDiff(), null);
    });

    test('detects changed fields', () {
      final entry = _entry(
        state: const TestState(2),
        previousState: const TestState(1),
      );
      final diff = entry.computeDiff()!;

      expect(diff.length, 1);
      expect(diff['value']!.type, DiffType.changed);
      expect(diff['value']!.oldValue, 1);
      expect(diff['value']!.newValue, 2);
    });

    test('detects added fields', () {
      final entry = _entry(
        state: const TestCubitState(label: 'a', count: 1),
        previousState: const TestState(1),
      );
      final diff = entry.computeDiff()!;

      expect(diff.containsKey('label'), true);
      expect(diff['label']!.type, DiffType.added);
    });

    test('detects removed fields', () {
      final entry = _entry(
        state: const TestState(1),
        previousState: const TestCubitState(label: 'a', count: 1),
      );
      final diff = entry.computeDiff()!;

      expect(diff.containsKey('label'), true);
      expect(diff['label']!.type, DiffType.removed);
    });

    test('handles multi-field changes', () {
      final entry = _entry(
        state: const TestCubitState(label: 'new', count: 5),
        previousState: const TestCubitState(label: 'old', count: 3),
      );
      final diff = entry.computeDiff()!;

      expect(diff.length, 2);
      expect(diff['label']!.type, DiffType.changed);
      expect(diff['count']!.type, DiffType.changed);
      expect(diff['label']!.oldValue, 'old');
      expect(diff['label']!.newValue, 'new');
    });
  });

  group('toString', () {
    test('includes bloc type, event, and state', () {
      final entry = _entry(event: TestIncrement());
      final s = entry.toString();

      expect(s, contains('TestBloc'));
      expect(s, contains('TestIncrement'));
      expect(s, contains('TestState'));
    });
  });
}
