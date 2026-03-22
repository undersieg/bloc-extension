import 'package:bloc/bloc.dart';

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

final class IncrementBy extends CounterEvent {
  IncrementBy(this.amount);
  final int amount;
  @override
  String toString() => 'IncrementBy($amount)';
}

class CounterState {
  const CounterState({required this.count});
  final int count;
  Map<String, dynamic> toJson() => {'count': count};
  @override
  String toString() => 'CounterState(count: $count)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CounterState && other.count == count;
  @override
  int get hashCode => count.hashCode;
}

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(count: 0)) {
    on<Increment>((event, emit) => emit(CounterState(count: state.count + 1)));
    on<Decrement>((event, emit) => emit(CounterState(count: state.count - 1)));
    on<Reset>((event, emit) => emit(const CounterState(count: 0)));
    on<IncrementBy>(
            (event, emit) => emit(CounterState(count: state.count + event.amount)));
  }
}

class ThemeState {
  const ThemeState({required this.isDark, this.seedColor = 'purple'});
  final bool isDark;
  final String seedColor;
  Map<String, dynamic> toJson() => {'isDark': isDark, 'seedColor': seedColor};
  @override
  String toString() => 'ThemeState(isDark: $isDark, seedColor: $seedColor)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ThemeState &&
              other.isDark == isDark &&
              other.seedColor == seedColor;
  @override
  int get hashCode => Object.hash(isDark, seedColor);
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState(isDark: false));

  void toggleTheme() => emit(ThemeState(
      isDark: !state.isDark, seedColor: state.seedColor));

  void setSeedColor(String color) =>
      emit(ThemeState(isDark: state.isDark, seedColor: color));
}

sealed class HistoryEvent {}

final class RecordMilestone extends HistoryEvent {
  RecordMilestone(this.value);
  final int value;
  @override
  String toString() => 'RecordMilestone($value)';
}

final class ClearHistory extends HistoryEvent {
  @override
  String toString() => 'ClearHistory';
}

class HistoryState {
  const HistoryState({this.milestones = const [], this.lastRecorded});
  final List<int> milestones;
  final DateTime? lastRecorded;

  Map<String, dynamic> toJson() => {
    'milestones': milestones,
    'count': milestones.length,
    'lastRecorded': lastRecorded?.toIso8601String(),
  };

  @override
  String toString() => 'HistoryState(${milestones.length} milestones)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HistoryState &&
              other.milestones.length == milestones.length;
  @override
  int get hashCode => milestones.length.hashCode;
}

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  HistoryBloc() : super(const HistoryState()) {
    on<RecordMilestone>((event, emit) {
      emit(HistoryState(
        milestones: [...state.milestones, event.value],
        lastRecorded: DateTime.now(),
      ));
    });

    on<ClearHistory>((event, emit) {
      emit(const HistoryState());
    });
  }
}

class SettingsState {
  const SettingsState({
    this.fontSize = 14.0,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.autoSave = false,
  });

  final double fontSize;
  final String language;
  final bool notificationsEnabled;
  final bool autoSave;

  SettingsState copyWith({
    double? fontSize,
    String? language,
    bool? notificationsEnabled,
    bool? autoSave,
  }) =>
      SettingsState(
        fontSize: fontSize ?? this.fontSize,
        language: language ?? this.language,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        autoSave: autoSave ?? this.autoSave,
      );

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'language': language,
    'notificationsEnabled': notificationsEnabled,
    'autoSave': autoSave,
  };

  @override
  String toString() => 'SettingsState($language, ${fontSize}px)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SettingsState &&
              other.fontSize == fontSize &&
              other.language == language &&
              other.notificationsEnabled == notificationsEnabled &&
              other.autoSave == autoSave;

  @override
  int get hashCode =>
      Object.hash(fontSize, language, notificationsEnabled, autoSave);
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void setFontSize(double size) => emit(state.copyWith(fontSize: size));
  void setLanguage(String lang) => emit(state.copyWith(language: lang));
  void toggleNotifications() =>
      emit(state.copyWith(notificationsEnabled: !state.notificationsEnabled));
  void toggleAutoSave() => emit(state.copyWith(autoSave: !state.autoSave));
}