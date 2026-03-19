# bloc_devtools_extension

Time-travel dev tools for `flutter_bloc` — inspired by [Redux DevTools](https://pub.dev/packages/redux_dev_tools).

## Features

### History tab
- **Event timeline** with elapsed-time gap indicators between entries
- **Processing time badges** on each transition (color-coded: green < 16ms, orange < 100ms, red > 100ms)
- **Time-travel slider** with skip/jump controls
- **BLoC type filter chips** when multiple BLoCs are active
- **State inspector** with JSON view and toggleable **diff view** that highlights added/removed/changed fields

### Graph tab
- **Live BLoC connection map** showing all active Bloc and Cubit instances
- **Relationship detection** via temporal correlation — if two BLoCs emit within 100ms, an edge is drawn between them
- **Edge strength** grows with each correlated event pair (thicker line = stronger connection)
- **Detail table** showing per-instance transition count and average processing time
- **Color-coded legend** distinguishing Bloc (primary) from Cubit (tertiary)

### Performance tab
- **Summary cards**: average, fastest, slowest processing time, and total measured count
- **Per-BLoC breakdown** with bar chart ranking by average processing time
- **Top 10 slowest transitions** with event name and timing

## Architecture

```
Your App
  ├── CounterBloc ──┐
  ├── AuthCubit  ───┤──▶ BlocDevToolsObserver
  └── CartBloc   ───┘         │
                              │ records transitions, lifecycle, timing
                              ▼
                        DevToolsStore
                        ├── entries[]           (state history)
                        ├── lifecycles{}        (create/close tracking)
                        ├── relationships{}     (detected connections)
                        └── performance helpers
                              │
                              │ notifies
                              ▼
                        BlocDevToolsPanel
                        ├── History tab  (timeline + slider + diff inspector)
                        ├── Graph tab    (connection map + detail table)
                        └── Perf tab     (metrics + breakdown + slowest list)
```

## Quick start

### 1. Add the dependency

```yaml
dependencies:
  bloc_devtools_extension:
    path: ./bloc_devtools_extension
```

### 2. Wire up in main.dart

```dart
import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';

void main() {
  Bloc.observer = BlocDevToolsObserver(DevToolsStore.instance);
  runApp(const MyApp());
}
```

### 3. Add the panel

```dart
Scaffold(
  appBar: AppBar(
    actions: [
      Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.bug_report),
          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
        ),
      ),
    ],
  ),
  endDrawer: Drawer(
    width: 360,
    child: SafeArea(
      child: BlocDevToolsPanel(store: DevToolsStore.instance),
    ),
  ),
)
```

### 4. (Optional) Make states JSON-inspectable

Add `toJson()` to enable the diff view and formatted JSON inspector:

```dart
class CounterState {
  const CounterState({required this.count});
  final int count;
  Map<String, dynamic> toJson() => {'count': count};
}
```

## Global access

**Singleton** (zero wiring):
```dart
// Anywhere in your app
DevToolsStore.instance
```

**InheritedWidget provider** (explicit DI):
```dart
// At root
DevToolsStoreProvider(
  store: DevToolsStore.instance,
  child: MaterialApp(...),
)

// In any descendant
DevToolsStoreProvider.of(context)
```

## Composing with existing observers

```dart
Bloc.observer = BlocDevToolsObserver(
  DevToolsStore.instance,
  innerObserver: MyLoggingObserver(),
);
```

## Debug-only setup

```dart
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    Bloc.observer = BlocDevToolsObserver(DevToolsStore.instance);
  }
  runApp(MyApp());
}
```

## Running the example

```bash
cd bloc_devtools_extension/example
flutter create .
flutter pub get
flutter run
```

Tap +/−/reset and toggle the theme, then tap the bug icon to explore all three tabs.

## License

MIT
