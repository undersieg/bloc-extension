import 'package:bloc/bloc.dart';

sealed class TestEvent {}

final class TestIncrement extends TestEvent {
  @override
  String toString() => 'TestIncrement';
}

final class TestDecrement extends TestEvent {
  @override
  String toString() => 'TestDecrement';
}

class TestState {
  const TestState(this.value);
  final int value;
  Map<String, dynamic> toJson() => {'value': value};
  @override
  String toString() => 'TestState($value)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TestState && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

class TestBloc extends Bloc<TestEvent, TestState> {
  TestBloc() : super(const TestState(0)) {
    on<TestIncrement>((event, emit) => emit(TestState(state.value + 1)));
    on<TestDecrement>((event, emit) => emit(TestState(state.value - 1)));
  }
}

class TestCubitState {
  const TestCubitState({this.label = 'default', this.count = 0});
  final String label;
  final int count;
  Map<String, dynamic> toJson() => {'label': label, 'count': count};
  @override
  String toString() => 'TestCubitState($label, $count)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestCubitState && other.label == label && other.count == count;
  @override
  int get hashCode => Object.hash(label, count);
}

class TestCubit extends Cubit<TestCubitState> {
  TestCubit() : super(const TestCubitState());

  void setLabel(String label) =>
      emit(TestCubitState(label: label, count: state.count));
  void increment() =>
      emit(TestCubitState(label: state.label, count: state.count + 1));
}
