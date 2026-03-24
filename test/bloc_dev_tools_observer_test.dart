import 'package:bloc/bloc.dart';
import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late DevToolsStore store;
  late BlocDevToolsObserver observer;

  setUp(() {
    store = DevToolsStore();
    observer = BlocDevToolsObserver(store);
    Bloc.observer = observer;
  });

  group('Bloc lifecycle', () {
    test('onCreate records initial entry and lifecycle', () {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      expect(store.length, 1);
      expect(store.entries.first.blocType, 'TestBloc');
      expect(store.entries.first.isBloc, true);
      expect(store.entries.first.event, null);
      expect(store.entries.first.state, const TestState(0));

      expect(store.lifecycles.length, 1);
      expect(store.lifecycles.first.blocType, 'TestBloc');
      expect(store.lifecycles.first.isBloc, true);
      expect(store.lifecycles.first.isAlive, true);
    });

    test('onClose marks lifecycle as closed', () async {
      final bloc = TestBloc();
      await bloc.close();

      expect(store.lifecycles.first.isAlive, false);
      expect(store.canReplay('TestBloc'), false);
    });
  });

  group('Bloc transitions', () {
    test('records event and new state on transition', () async {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);

      expect(store.length, 2);

      final entry = store.entries[1];
      expect(entry.blocType, 'TestBloc');
      expect(entry.isBloc, true);
      expect(entry.event.toString(), 'TestIncrement');
      expect(entry.state, const TestState(1));
      expect(entry.previousState, const TestState(0));
    });

    test('records processing duration', () async {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);

      final entry = store.entries[1];
      expect(entry.processingDuration, isNotNull);
      expect(entry.processingDuration!.inMicroseconds, greaterThanOrEqualTo(0));
    });

    test('records multiple transitions in order', () async {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      bloc.add(TestIncrement());
      bloc.add(TestIncrement());
      bloc.add(TestDecrement());
      await Future.delayed(Duration.zero);

      expect(store.length, 4);
      expect(store.entries[1].state, const TestState(1));
      expect(store.entries[2].state, const TestState(2));
      expect(store.entries[3].state, const TestState(1));
      expect(store.entries[3].event.toString(), 'TestDecrement');
    });

    test('tracks previousState correctly across transitions', () async {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      bloc.add(TestIncrement());
      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);

      expect(store.entries[1].previousState, const TestState(0));
      expect(store.entries[2].previousState, const TestState(1));
    });

    test('updates lifecycle transition count', () async {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      bloc.add(TestIncrement());
      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);

      final record = store.lifecycles.first;
      expect(record.transitionCount, 2);
      expect(record.totalProcessingTime.inMicroseconds, greaterThan(0));
    });
  });

  group('Cubit changes', () {
    test('records initial entry for Cubit', () {
      final cubit = TestCubit();
      addTearDown(cubit.close);

      expect(store.length, 1);
      expect(store.entries.first.blocType, 'TestCubit');
      expect(store.entries.first.isBloc, false);
    });

    test('records Cubit state changes without event', () {
      final cubit = TestCubit();
      addTearDown(cubit.close);

      cubit.setLabel('hello');

      expect(store.length, 2);

      final entry = store.entries[1];
      expect(entry.blocType, 'TestCubit');
      expect(entry.isBloc, false);
      expect(entry.event, null);
      expect(entry.state, const TestCubitState(label: 'hello', count: 0));
      expect(entry.previousState,
          const TestCubitState(label: 'default', count: 0));
    });

    test('records multiple Cubit changes', () {
      final cubit = TestCubit();
      addTearDown(cubit.close);

      cubit.setLabel('a');
      cubit.increment();
      cubit.increment();

      expect(store.length, 4);
      expect(store.entries[3].state,
          const TestCubitState(label: 'a', count: 2));
    });

    test('Cubit transitions have no processingDuration', () {
      final cubit = TestCubit();
      addTearDown(cubit.close);

      cubit.increment();

      expect(store.entries[1].processingDuration, null);
    });

    test('increments transition count for Cubits', () {
      final cubit = TestCubit();
      addTearDown(cubit.close);

      cubit.increment();
      cubit.increment();
      cubit.increment();

      final record = store.lifecycles.first;
      expect(record.transitionCount, 3);
      expect(record.totalProcessingTime, Duration.zero);
    });
  });

  group('Bloc onChange is not double-recorded', () {
    test('Bloc transitions produce exactly one entry per event', () async {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);

      final testBlocEntries = store.entriesForBloc('TestBloc');
      expect(testBlocEntries.length, 2);
    });
  });

  group('multiple BLoC instances', () {
    test('tracks separate instances independently', () async {
      final bloc = TestBloc();
      final cubit = TestCubit();
      addTearDown(() async {
        await bloc.close();
        await cubit.close();
      });

      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);
      cubit.setLabel('x');

      expect(store.blocTypes, {'TestBloc', 'TestCubit'});
      expect(store.entriesForBloc('TestBloc').length, 2);
      expect(store.entriesForBloc('TestCubit').length, 2);

      expect(store.lifecycles.length, 2);
      expect(store.aliveBlocs.length, 2);
    });

    test('closing one does not affect the other', () async {
      final bloc = TestBloc();
      final cubit = TestCubit();
      addTearDown(cubit.close);

      await bloc.close();

      expect(store.aliveBlocs.length, 1);
      expect(store.aliveBlocs.first.blocType, 'TestCubit');
      expect(store.canReplay('TestBloc'), false);
      expect(store.canReplay('TestCubit'), true);
    });
  });

  group('replay', () {
    test('replayState pushes state onto live Bloc', () async {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      bloc.add(TestIncrement());
      bloc.add(TestIncrement());
      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);

      expect(bloc.state, const TestState(3));

      final entryAt1 = store.entries[1];
      final result = store.replayState(entryAt1);

      expect(result, true);
      expect(bloc.state, const TestState(1));
    });

    test('replayState returns false for closed Bloc', () async {
      final bloc = TestBloc();
      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);
      final entry = store.entries[1];

      await bloc.close();

      expect(store.replayState(entry), false);
    });

    test('canReplay returns true for alive instance', () {
      final bloc = TestBloc();
      addTearDown(bloc.close);

      expect(store.canReplay('TestBloc'), true);
    });

    test('canReplay returns false for unknown type', () {
      expect(store.canReplay('NonExistent'), false);
    });
  });

  group('innerObserver forwarding', () {
    test('forwards events to inner observer', () async {
      final inner = _TrackingObserver();
      final customStore = DevToolsStore();
      Bloc.observer = BlocDevToolsObserver(customStore, innerObserver: inner);

      final bloc = TestBloc();
      bloc.add(TestIncrement());
      await Future.delayed(Duration.zero);
      await bloc.close();

      expect(inner.creates, 1);
      expect(inner.events, 1);
      expect(inner.transitions, 1);
      expect(inner.changes, greaterThanOrEqualTo(1));
      expect(inner.closes, 1);
    });
  });
}

class _TrackingObserver extends BlocObserver {
  int creates = 0;
  int events = 0;
  int transitions = 0;
  int changes = 0;
  int closes = 0;

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    creates++;
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    events++;
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    transitions++;
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    changes++;
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    closes++;
  }
}