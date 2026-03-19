import 'package:bloc/bloc.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Counter Bloc (event-driven — demonstrates performance timing)
// ═════════════════════════════════════════════════════════════════════════════

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

class CounterState {
  const CounterState({required this.count});
  final int count;

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

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(count: 0)) {
    on<Increment>((event, emit) => emit(CounterState(count: state.count + 1)));
    on<Decrement>((event, emit) => emit(CounterState(count: state.count - 1)));
    on<Reset>((event, emit) => emit(const CounterState(count: 0)));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Theme Cubit (simple Cubit — shows Cubit support + graph connections)
// ═════════════════════════════════════════════════════════════════════════════

class ThemeState {
  const ThemeState({required this.isDark});
  final bool isDark;

  Map<String, dynamic> toJson() => {'isDark': isDark};

  @override
  String toString() => 'ThemeState(isDark: $isDark)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ThemeState && other.isDark == isDark;

  @override
  int get hashCode => isDark.hashCode;
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState(isDark: false));

  void toggleTheme() => emit(ThemeState(isDark: !state.isDark));
}
