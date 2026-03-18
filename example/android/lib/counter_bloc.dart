import 'package:bloc/bloc.dart';

// ─── Events ─────────────────────────────────────────────────────────────────

sealed class CounterEvent {}

final class Increment extends CounterEvent {
  @override
  String toString() => 'Increment';
}

final class Decrement extends CounterEvent {
  @override
  String toString() => 'Decrement';
}

final class Reset extends CounterEvent {
  @override
  String toString() => 'Reset';
}

// ─── State ──────────────────────────────────────────────────────────────────

class CounterState {
  const CounterState({required this.count});

  final int count;

  /// Provides a JSON-friendly representation for the dev tools inspector.
  Map<String, dynamic> toJson() => {'count': count};

  @override
  String toString() => 'CounterState(count: $count)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CounterState && other.count == count;

  @override
  int get hashCode => count.hashCode;
}

// ─── Bloc ───────────────────────────────────────────────────────────────────

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(count: 0)) {
    on<Increment>((event, emit) {
      emit(CounterState(count: state.count + 1));
    });

    on<Decrement>((event, emit) {
      emit(CounterState(count: state.count - 1));
    });

    on<Reset>((event, emit) {
      emit(const CounterState(count: 0));
    });
  }
}
