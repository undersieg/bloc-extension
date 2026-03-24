import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlocLifecycleRecord', () {
    late BlocLifecycleRecord record;

    setUp(() {
      record = BlocLifecycleRecord(
        blocType: 'CounterBloc',
        instanceId: 42,
        createdAt: DateTime(2026, 1, 1, 12, 0, 0),
        isBloc: true,
      );
    });

    test('initial state is alive with zero transitions', () {
      expect(record.isAlive, true);
      expect(record.closedAt, null);
      expect(record.transitionCount, 0);
      expect(record.totalProcessingTime, Duration.zero);
    });

    test('isAlive becomes false after close', () {
      record.closedAt = DateTime(2026, 1, 1, 12, 5, 0);
      expect(record.isAlive, false);
    });

    test('lifetime returns duration since creation when alive', () {
      final lifetime = record.lifetime;
      expect(lifetime.inSeconds, greaterThan(0));
    });

    test('lifetime returns fixed duration after close', () {
      record.closedAt = DateTime(2026, 1, 1, 12, 0, 30);
      expect(record.lifetime, const Duration(seconds: 30));
    });

    test('avgProcessingTime is zero with no transitions', () {
      expect(record.avgProcessingTime, Duration.zero);
    });

    test('avgProcessingTime computes correctly', () {
      record.transitionCount = 4;
      record.totalProcessingTime = const Duration(microseconds: 1000);
      expect(record.avgProcessingTime, const Duration(microseconds: 250));
    });

    test('avgProcessingTime rounds down (integer division)', () {
      record.transitionCount = 3;
      record.totalProcessingTime = const Duration(microseconds: 100);
      expect(record.avgProcessingTime, const Duration(microseconds: 33));
    });

    test('stores isBloc flag correctly', () {
      expect(record.isBloc, true);

      final cubitRecord = BlocLifecycleRecord(
        blocType: 'ThemeCubit',
        instanceId: 99,
        createdAt: DateTime.now(),
        isBloc: false,
      );
      expect(cubitRecord.isBloc, false);
    });
  });

  group('BlocRelationship', () {
    late BlocRelationship rel;

    setUp(() {
      rel = BlocRelationship(
        sourceBlocType: 'CounterBloc',
        targetBlocType: 'HistoryBloc',
      );
    });

    test('initial state has zero correlations', () {
      expect(rel.correlationCount, 0);
    });

    test('key is formatted as source→target', () {
      expect(rel.key, 'CounterBloc→HistoryBloc');
    });

    test('strength is 0 with zero correlations', () {
      expect(rel.strength, 0.0);
    });

    test('strength grows with correlations', () {
      rel.correlationCount = 1;
      final s1 = rel.strength;

      rel.correlationCount = 5;
      final s5 = rel.strength;

      rel.correlationCount = 100;
      final s100 = rel.strength;

      expect(s1, greaterThan(0.0));
      expect(s5, greaterThan(s1));
      expect(s100, greaterThan(s5));
    });

    test('strength is clamped to 1.0', () {
      rel.correlationCount = 1000000;
      expect(rel.strength, closeTo(1.0, 0.001));
    });

    test('strength formula: count / (count + 3)', () {
      rel.correlationCount = 3;
      expect(rel.strength, closeTo(0.5, 0.001));

      rel.correlationCount = 6;
      expect(rel.strength, closeTo(6 / 9, 0.001));
    });
  });
}