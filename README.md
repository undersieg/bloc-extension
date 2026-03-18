# bloc_devtools_extension

Time-travel dev tools for `flutter_bloc` — inspired by [Redux DevTools](https://pub.dev/packages/redux_dev_tools).

Inspect BLoC & Cubit states, events, and transitions with an in-app UI. Supports state history, time-travel slider, skip, jump, reset, and JSON inspection.

## Features

| Feature | Description |
|---------|-------------|
| **State history** | Every BLoC/Cubit state change is recorded with a timestamp. |
| **Time-travel slider** | Scrub through your app's state history. Skipped entries are excluded. |
| **Jump to state** | Tap any entry to jump to that point in time. |
| **Skip state** | Toggle entries as "skipped" so the slider passes over them. |
| **State inspector** | View the JSON representation of the selected state. States with a `toJson()` method are displayed as formatted JSON. |
| **BLoC type filter** | When multiple BLoCs are active, filter the history by type. |
| **Reset** | Clear all recorded history. |
| **Cubit + Bloc support** | Works with both `Cubit` and `Bloc`. |
| **Composable observer** | Chain with your existing `BlocObserver` via the `innerObserver` parameter. |

## Architecture

This package follows the same architectural philosophy as `redux_dev_tools`:

```
┌─────────────────────────────────────────────────────┐
│                  Your Flutter App                    │
│                                                     │
│  ┌──────────────┐   ┌──────────────────────────┐   │
│  │ CounterBloc   │   │  BlocDevToolsObserver     │   │
│  │ (or Cubit)    │──▶│  (extends BlocObserver)   │   │
│  └──────────────┘   └────────────┬─────────────┘   │
│                                  │ records          │
│                                  ▼                  │
│                     ┌──────────────────────────┐   │
│                     │  DevToolsStore            │   │
│                     │  (ChangeNotifier)         │   │
│                     │  - entries[]              │   │
│                     │  - currentIndex           │   │
│                     │  - jumpTo / skip / reset  │   │
│                     └────────────┬─────────────┘   │
│                                  │ notifies         │
│                                  ▼                  │
│                     ┌──────────────────────────┐   │
│                     │  BlocDevToolsPanel        │   │
│                     │  (Flutter Widget)         │   │
│                     └──────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

- **DevToolsStore** ≈ Redux's `DevToolsStore` — holds state history and time-travel cursor.
- **BlocDevToolsObserver** ≈ Redux's middleware — intercepts every state change and records it.
- **BlocDevToolsPanel** ≈ `flutter_redux_dev_tools`'s `ReduxDevTools` widget — the UI.

## Installation

Add to your `pubspec.yaml` as a **dev dependency** (you don't want this in production):

```yaml
dev_dependencies:
  bloc_devtools_extension:
    path: ./packages/bloc_devtools_extension  # or from pub once published
```

## Quick start (3 steps)

### Step 1 — Create the store and attach the observer

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';

// Create a global DevToolsStore instance.
final devToolsStore = DevToolsStore();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Attach the observer to Bloc.observer.
  // Every BLoC and Cubit in your app will now be recorded.
  Bloc.observer = BlocDevToolsObserver(devToolsStore);

  runApp(const MyApp());
}
```

### Step 2 — Add the panel to your UI

The recommended approach is an `endDrawer` on your `Scaffold`:

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('My App'),
    actions: [
      Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.bug_report),
          tooltip: 'DevTools',
          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
        ),
      ),
    ],
  ),
  endDrawer: Drawer(
    width: 340,
    child: SafeArea(
      child: BlocDevToolsPanel(store: devToolsStore),
    ),
  ),
  body: // your app content...
)
```

### Step 3 — (Optional) Make your states JSON-inspectable

If your state classes implement a `toJson()` method, the state inspector will display formatted JSON. Otherwise it falls back to `toString()`.

```dart
class CounterState {
  const CounterState({required this.count});
  final int count;

  Map<String, dynamic> toJson() => {'count': count};

  @override
  String toString() => 'CounterState(count: $count)';
}
```

That's it! Run your app, tap the bug icon, and start exploring your state history.

## Advanced usage

### Composing with an existing BlocObserver

If you already have a custom `BlocObserver`, pass it as `innerObserver`:

```dart
final myLoggingObserver = MyLoggingObserver();
Bloc.observer = BlocDevToolsObserver(
  devToolsStore,
  innerObserver: myLoggingObserver,
);
```

Every callback is forwarded to your inner observer after recording.

### Conditional dev-only setup

Wrap the dev tools setup in a `kDebugMode` check so it's stripped in release builds:

```dart
import 'package:flutter/foundation.dart';

void main() {
  DevToolsStore? devToolsStore;

  if (kDebugMode) {
    devToolsStore = DevToolsStore();
    Bloc.observer = BlocDevToolsObserver(devToolsStore);
  }

  runApp(MyApp(devToolsStore: devToolsStore));
}
```

Then conditionally show the panel:

```dart
endDrawer: devToolsStore != null
    ? Drawer(child: SafeArea(child: BlocDevToolsPanel(store: devToolsStore)))
    : null,
```

### Alternative placements

The `BlocDevToolsPanel` is a regular widget. You can place it:

- In a **bottom sheet**: `showModalBottomSheet(builder: (_) => BlocDevToolsPanel(store: s))`
- On a **dedicated route**: `Navigator.push(..., MaterialPageRoute(builder: (_) => Scaffold(body: BlocDevToolsPanel(store: s))))`
- As an **overlay**: wrap in `OverlayEntry` for a floating inspector.
- In a **split view**: alongside your main content on tablets.

### Accessing the store programmatically

The `DevToolsStore` exposes a full API for scripted inspection:

```dart
// Jump to state #3
devToolsStore.jumpTo(3);

// Get the current entry's state
final state = devToolsStore.currentEntry?.state;

// List all recorded BLoC types
final types = devToolsStore.blocTypes; // {'CounterBloc', 'AuthBloc'}

// Get entries for a specific BLoC
final counterEntries = devToolsStore.entriesForBloc('CounterBloc');

// Clear everything
devToolsStore.reset();
```

## API reference

### DevToolsStore

| Member | Description |
|--------|-------------|
| `entries` | Unmodifiable list of all recorded `DevToolsEntry` objects. |
| `currentIndex` | Index of the time-travel cursor (-1 if empty). |
| `currentEntry` | The entry at the cursor, or `null`. |
| `activeEntries` | Entries that are NOT skipped (used by the slider). |
| `blocTypes` | Set of distinct BLoC runtime type names. |
| `addEntry(entry)` | Record a new state change. |
| `jumpTo(index)` | Move the cursor to an absolute index. |
| `jumpToActive(index)` | Move the cursor within the active (non-skipped) entries. |
| `toggleSkip(index)` | Toggle the "skipped" flag on an entry. |
| `reset()` | Clear all history. |

### BlocDevToolsObserver

| Constructor param | Description |
|-------------------|-------------|
| `store` | The `DevToolsStore` to write into. |
| `innerObserver` | Optional inner `BlocObserver` to delegate to. |

### BlocDevToolsPanel

| Constructor param | Description |
|-------------------|-------------|
| `store` | The `DevToolsStore` to read from. |

### DevToolsEntry

| Field | Type | Description |
|-------|------|-------------|
| `blocType` | `String` | Runtime type name of the BLoC/Cubit. |
| `state` | `Object?` | The state snapshot. |
| `event` | `Object?` | The event (null for Cubits / initial state). |
| `timestamp` | `DateTime` | When this entry was recorded. |
| `isSkipped` | `bool` | Whether this entry is skipped in the slider. |

## Running the example

```bash
cd example
flutter run
```

Tap the bug icon in the app bar to open the DevTools drawer. Press +/−/reset and watch the state history populate in real time.

## How it compares to redux_dev_tools

| Concept | redux_dev_tools | bloc_devtools_extension |
|---------|----------------|----------------------|
| Store wrapper | `DevToolsStore<S>` replaces `Store<S>` | `DevToolsStore` (standalone, doesn't wrap your BLoC) |
| Recording mechanism | Internal reducer/middleware | `BlocDevToolsObserver` (standard `BlocObserver`) |
| Actions | `DevToolsAction.perform`, `.recompute`, `.reset` | `jumpTo`, `toggleSkip`, `reset` on `DevToolsStore` |
| UI widget | `ReduxDevTools<S>` | `BlocDevToolsPanel` |
| Time travel | Replays actions through the reducer | Cursor-based (inspects recorded states) |
| Multi-store | One `DevToolsStore` per Redux store | Single `DevToolsStore` captures ALL BLoCs/Cubits |

## License

MIT
