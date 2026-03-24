# bloc_devtools_extension

[![pub package](https://img.shields.io/pub/v/bloc_devtools_extension.svg)](https://pub.dev/packages/bloc_devtools_extension)
[![CI](https://github.com/undersieg/bloc-devtools-extension/actions/workflows/ci.yml/badge.svg)](https://github.com/undersieg/bloc-devtools-extension/actions/workflows/ci.yml)
[![License: BSD-3](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

Time-travel dev tools for [flutter_bloc](https://pub.dev/packages/flutter_bloc), inspired by [Redux DevTools](https://pub.dev/packages/redux_dev_tools).

**Two ways to use:**

1. **In-app widget** — drop `BlocDevToolsPanel` into a drawer or overlay.
2. **Flutter DevTools extension** — a custom tab in the browser-based DevTools, right next to the Inspector and Profiler.

Both provide the same three tabs: **History**, **Graph**, and **Performance**.

## Features

### History tab

- Event timeline with elapsed-time gap indicators between entries
- Processing-time badges on each transition (green < 16 ms, orange < 100 ms, red)
- Time-travel slider with first / prev / next / last controls
- BLoC-type filter chips with entry counts
- State inspector with toggleable **diff view** highlighting added, removed, and changed fields
- **State replay** — push any historical state onto a live BLoC or Cubit

### Graph tab

- Live connection map of all active Bloc and Cubit instances
- **Drag-to-reposition** nodes (in-app and browser DevTools)
- Relationship detection via temporal correlation (100 ms window)
- Edge thickness and correlation count grow with each correlated event pair
- Search bar and Bloc / Cubit type toggles
- Tap a node for a detail panel showing transitions, lifetime, avg processing time, and connections

### Performance tab

- Summary cards: average, fastest, slowest processing time, total events
- Per-BLoC breakdown with bar chart, ranked by event count
- Top 10 slowest transitions with BLoC name and event
- Tap any row for a detail panel

## Quick start

### 1. Install

```yaml
dependencies:
  bloc_devtools_extension: ^0.1.0
```

### 2. Wire up

```dart
import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';

void main() {
  Bloc.observer = BlocDevToolsObserver(DevToolsStore.instance);

  // Optional: enable the browser DevTools tab.
  registerBlocDevToolsServiceExtension(DevToolsStore.instance);

  runApp(const MyApp());
}
```

### 3. Add the panel

```dart
Scaffold(
  endDrawer: Drawer(
    width: 360,
    child: SafeArea(
      child: BlocDevToolsPanel(store: DevToolsStore.instance),
    ),
  ),
)
```

### 4. (Optional) Enable diff view

Add a `toJson()` method to your state classes:

```dart
class CounterState {
  const CounterState({required this.count});
  final int count;

  Map<String, dynamic> toJson() => {'count': count};
}
```

## Global access

```dart
// Singleton — works from any file, zero wiring:
DevToolsStore.instance

// Or use the InheritedWidget provider:
DevToolsStoreProvider(
  store: DevToolsStore.instance,
  child: MaterialApp(/* ... */),
)

// Then in any descendant:
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
    registerBlocDevToolsServiceExtension(DevToolsStore.instance);
  }
  runApp(const MyApp());
}
```

## API reference

### Core classes

| Class | Purpose |
|-------|---------|
| `DevToolsStore` | State history, lifecycle tracking, relationship detection, performance metrics, state replay |
| `DevToolsStore.instance` | Global singleton |
| `BlocDevToolsObserver` | `BlocObserver` that records transitions, timing, and lifecycle |
| `BlocDevToolsPanel` | In-app Flutter widget with three tabs |
| `DevToolsStoreProvider` | `InheritedWidget` for widget-tree access |
| `DevToolsEntry` | Data model for a single state change, with `computeDiff()` |
| `BlocLifecycleRecord` | Per-instance lifecycle: created, closed, transition count, timing |
| `BlocRelationship` | Detected connection between two BLoC types |

### Service extension (for the browser DevTools tab)

| Function | Purpose |
|----------|---------|
| `registerBlocDevToolsServiceExtension(store)` | Registers VM service endpoints |

| Endpoint | Returns |
|----------|---------|
| `ext.bloc_devtools.getState` | Summary: counts, alive blocs, avg timing |
| `ext.bloc_devtools.getEntries` | State history with `sinceIndex` for incremental fetch |
| `ext.bloc_devtools.getGraph` | Alive blocs and detected relationships |
| `ext.bloc_devtools.getPerformance` | Timing metrics, per-BLoC breakdown, top 10 slowest |
| `ext.bloc_devtools.jumpTo` | Move the cursor to a specific entry |
| `ext.bloc_devtools.replay` | Push a historical state onto a live BLoC |

## Flutter DevTools extension setup

The package ships with a pre-built DevTools extension in `extension/devtools/`.
When users add this package as a dependency, the extension tab appears
automatically in Flutter DevTools.

### Building the extension from source

If you're contributing or need to rebuild:

```bash
cd devtools_extension
flutter pub get
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=../extension/devtools

dart run devtools_extensions validate --package=..
```

### Publishing checklist

```bash
# Make scripts executable (once)
chmod +x build_extension.sh publish.sh

# Dry-run first — builds, commits, validates, but doesn't publish
./publish.sh --dry-run

# Publish for real
./publish.sh
```

The `publish.sh` script handles the full flow: builds the DevTools extension,
commits the compiled output to git (so the validator sees a clean state),
and runs `flutter pub publish`.

## Acknowledgments

This package is built for and depends on the
[BLoC](https://bloclibrary.dev/) state management ecosystem created by
[Felix Angelov](https://github.com/felangel):

- [bloc](https://pub.dev/packages/bloc) — the core BLoC library
- [flutter_bloc](https://pub.dev/packages/flutter_bloc) — Flutter widgets for BLoC
- [BLoC documentation](https://bloclibrary.dev/) — comprehensive guides and examples

The architecture and feature set are inspired by
[redux_dev_tools](https://pub.dev/packages/redux_dev_tools) and
[flutter_redux_dev_tools](https://pub.dev/packages/flutter_redux_dev_tools)
by [Brian Egan](https://github.com/brianegan), as well as the original
[Redux DevTools](https://github.com/reduxjs/redux-devtools) from the
JavaScript ecosystem.

The DevTools extension integration follows the
[devtools_extensions](https://pub.dev/packages/devtools_extensions) framework
by the Flutter team.

## Contributing

Created by Daniel Jasiński.

Contributions are welcome. Please file issues and pull requests on the
[GitHub repository](https://github.com/undersieg/bloc-devtools-extension).

## License

BSD 3-Clause. See [LICENSE](LICENSE) for details.