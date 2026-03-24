import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';

void main() {
  late DevToolsStore store;
  final now = DateTime(2026, 1, 1, 12, 0, 0);

  DevToolsEntry _entry({
    String blocType = 'TestBloc',
    int stateValue = 0,
    Object? event,
    bool isBloc = true,
    Duration? processingDuration,
    DateTime? timestamp,
  }) {
    return DevToolsEntry(
      blocType: blocType,
      state: stateValue,
      event: event,
      isBloc: isBloc,
      timestamp: timestamp ?? now,
      processingDuration: processingDuration,
    );
  }

  setUp(() {
    store = DevToolsStore();
  });

  group('entry management', () {
    test('starts empty', () {
      expect(store.length, 0);
      expect(store.entries, isEmpty);
      expect(store.currentIndex, -1);
      expect(store.currentEntry, null);
    });

    test('addEntry appends and moves cursor to last', () {
      store.addEntry(_entry(stateValue: 1));
      store.addEntry(_entry(stateValue: 2));

      expect(store.length, 2);
      expect(store.currentIndex, 1);
      expect(store.currentEntry!.state, 2);
    });

    test('entries list is unmodifiable', () {
      store.addEntry(_entry());
      expect(
        () => (store.entries as List).add(_entry()),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('navigation', () {
    setUp(() {
      store.addEntry(_entry(stateValue: 0));
      store.addEntry(_entry(stateValue: 1));
      store.addEntry(_entry(stateValue: 2));
    });

    test('jumpTo moves cursor to valid index', () {
      store.jumpTo(0);
      expect(store.currentIndex, 0);
      expect(store.currentEntry!.state, 0);
    });

    test('jumpTo ignores negative index', () {
      store.jumpTo(1);
      store.jumpTo(-1);
      expect(store.currentIndex, 1);
    });

    test('jumpTo ignores out-of-range index', () {
      store.jumpTo(1);
      store.jumpTo(999);
      expect(store.currentIndex, 1);
    });
  });

  group('toggleSkip', () {
    test('toggles isSkipped on valid index', () {
      store.addEntry(_entry());
      expect(store.entries[0].isSkipped, false);

      store.toggleSkip(0);
      expect(store.entries[0].isSkipped, true);

      store.toggleSkip(0);
      expect(store.entries[0].isSkipped, false);
    });

    test('ignores invalid index', () {
      store.addEntry(_entry());
      store.toggleSkip(-1);
      store.toggleSkip(100);
      expect(store.entries[0].isSkipped, false);
    });
  });

  group('activeEntries', () {
    test('excludes skipped entries', () {
      store.addEntry(_entry(stateValue: 0));
      store.addEntry(_entry(stateValue: 1));
      store.addEntry(_entry(stateValue: 2));
      store.toggleSkip(1);

      expect(store.activeEntries.length, 2);
      expect(store.activeEntries[0].state, 0);
      expect(store.activeEntries[1].state, 2);
    });
  });

  group('filtering', () {
    test('blocTypes returns unique types', () {
      store.addEntry(_entry(blocType: 'A'));
      store.addEntry(_entry(blocType: 'B'));
      store.addEntry(_entry(blocType: 'A'));

      expect(store.blocTypes, {'A', 'B'});
    });

    test('entriesForBloc filters by type', () {
      store.addEntry(_entry(blocType: 'A', stateValue: 1));
      store.addEntry(_entry(blocType: 'B', stateValue: 2));
      store.addEntry(_entry(blocType: 'A', stateValue: 3));

      final aEntries = store.entriesForBloc('A');
      expect(aEntries.length, 2);
      expect(aEntries[0].state, 1);
      expect(aEntries[1].state, 3);
    });

    test('entriesForBloc returns empty for unknown type', () {
      store.addEntry(_entry(blocType: 'A'));
      expect(store.entriesForBloc('Z'), isEmpty);
    });
  });

  group('lifecycle tracking', () {
    test('recordCreate registers a lifecycle', () {
      store.recordCreate(blocType: 'TestBloc', instanceId: 1, isBloc: true);

      expect(store.lifecycles.length, 1);
      expect(store.lifecycles.first.blocType, 'TestBloc');
      expect(store.lifecycles.first.isBloc, true);
      expect(store.lifecycles.first.isAlive, true);
    });

    test('recordClose marks lifecycle as closed', () {
      store.recordCreate(blocType: 'TestBloc', instanceId: 1, isBloc: true);
      store.recordClose(1);

      expect(store.lifecycles.first.isAlive, false);
      expect(store.lifecycles.first.closedAt, isNotNull);
    });

    test('aliveBlocs returns only alive instances', () {
      store.recordCreate(blocType: 'A', instanceId: 1, isBloc: true);
      store.recordCreate(blocType: 'B', instanceId: 2, isBloc: false);
      store.recordClose(1);

      expect(store.aliveBlocs.length, 1);
      expect(store.aliveBlocs.first.blocType, 'B');
    });

    test('recordTransitionMetrics increments count and timing', () {
      store.recordCreate(blocType: 'A', instanceId: 1, isBloc: true);

      store.recordTransitionMetrics(1, const Duration(microseconds: 100));
      store.recordTransitionMetrics(1, const Duration(microseconds: 200));

      final record = store.lifecycles.first;
      expect(record.transitionCount, 2);
      expect(record.totalProcessingTime, const Duration(microseconds: 300));
    });

    test('recordTransitionMetrics with null duration increments count only',
        () {
      store.recordCreate(blocType: 'A', instanceId: 1, isBloc: false);

      store.recordTransitionMetrics(1, null);
      store.recordTransitionMetrics(1, null);

      final record = store.lifecycles.first;
      expect(record.transitionCount, 2);
      expect(record.totalProcessingTime, Duration.zero);
    });

    test('recordTransitionMetrics ignores unknown instanceId', () {
      store.recordTransitionMetrics(999, const Duration(seconds: 1));
      expect(store.lifecycles, isEmpty);
    });
  });

  group('relationship detection', () {
    test('detects relationship between entries within 100ms', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);
      final t1 = DateTime(2026, 1, 1, 12, 0, 0, 50);

      store.addEntry(_entry(blocType: 'A', timestamp: t0));
      store.addEntry(_entry(blocType: 'B', timestamp: t1));

      expect(store.relationships.length, 1);
      expect(store.relationships.first.sourceBlocType, 'A');
      expect(store.relationships.first.targetBlocType, 'B');
      expect(store.relationships.first.correlationCount, 1);
    });

    test('does not detect relationship beyond 100ms', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);
      final t1 = DateTime(2026, 1, 1, 12, 0, 0, 150);

      store.addEntry(_entry(blocType: 'A', timestamp: t0));
      store.addEntry(_entry(blocType: 'B', timestamp: t1));

      expect(store.relationships, isEmpty);
    });

    test('does not create self-relationships', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);
      final t1 = DateTime(2026, 1, 1, 12, 0, 0, 10);

      store.addEntry(_entry(blocType: 'A', timestamp: t0));
      store.addEntry(_entry(blocType: 'A', timestamp: t1));

      expect(store.relationships, isEmpty);
    });

    test('increments correlation count for repeated pairs', () {
      final base = DateTime(2026, 1, 1, 12, 0, 0, 0);

      for (int i = 0; i < 3; i++) {
        final t0 = base.add(Duration(seconds: i * 2));
        final t1 = t0.add(const Duration(milliseconds: 20));
        store.addEntry(_entry(blocType: 'A', timestamp: t0));
        store.addEntry(_entry(blocType: 'B', timestamp: t1));
      }

      expect(store.relationships.length, 1);
      expect(store.relationships.first.correlationCount, 3);
    });
  });

  group('performance metrics', () {
    test('entriesWithTiming returns only entries with duration', () {
      store.addEntry(_entry(
        processingDuration: const Duration(microseconds: 100),
      ));
      store.addEntry(_entry());
      store.addEntry(_entry(
        processingDuration: const Duration(microseconds: 200),
      ));

      expect(store.entriesWithTiming.length, 2);
    });

    test('avgProcessingTime computes average', () {
      store.addEntry(_entry(
        processingDuration: const Duration(microseconds: 100),
      ));
      store.addEntry(_entry(
        processingDuration: const Duration(microseconds: 300),
      ));

      expect(store.avgProcessingTime, const Duration(microseconds: 200));
    });

    test('avgProcessingTime returns zero when no timed entries', () {
      store.addEntry(_entry());
      expect(store.avgProcessingTime, Duration.zero);
    });

    test('slowestTransition returns entry with longest duration', () {
      store.addEntry(_entry(
        stateValue: 1,
        processingDuration: const Duration(microseconds: 100),
      ));
      store.addEntry(_entry(
        stateValue: 2,
        processingDuration: const Duration(microseconds: 500),
      ));
      store.addEntry(_entry(
        stateValue: 3,
        processingDuration: const Duration(microseconds: 200),
      ));

      expect(store.slowestTransition!.state, 2);
    });

    test('slowestTransition returns null when no timed entries', () {
      store.addEntry(_entry());
      expect(store.slowestTransition, null);
    });
  });

  group('reset', () {
    test('clears entries, lifecycles, and relationships', () {
      store.addEntry(_entry());
      store.recordCreate(blocType: 'A', instanceId: 1, isBloc: true);

      store.reset();

      expect(store.length, 0);
      expect(store.currentIndex, -1);
      expect(store.lifecycles, isEmpty);
      expect(store.relationships, isEmpty);
    });
  });

  group('notifications', () {
    test('addEntry notifies listeners', () {
      int count = 0;
      store.addListener(() => count++);

      store.addEntry(_entry());
      expect(count, 1);
    });

    test('jumpTo notifies listeners', () {
      store.addEntry(_entry());
      store.addEntry(_entry());

      int count = 0;
      store.addListener(() => count++);

      store.jumpTo(0);
      expect(count, 1);
    });

    test('reset notifies listeners', () {
      store.addEntry(_entry());

      int count = 0;
      store.addListener(() => count++);

      store.reset();
      expect(count, 1);
    });

    test('recordCreate notifies listeners', () {
      int count = 0;
      store.addListener(() => count++);

      store.recordCreate(blocType: 'A', instanceId: 1, isBloc: true);
      expect(count, 1);
    });
  });

  group('singleton', () {
    test('DevToolsStore.instance returns same instance', () {
      final a = DevToolsStore.instance;
      final b = DevToolsStore.instance;
      expect(identical(a, b), true);
    });

    test('DevToolsStore.instance can be overridden', () {
      final custom = DevToolsStore();
      DevToolsStore.instance = custom;
      expect(identical(DevToolsStore.instance, custom), true);
    });
  });
}
