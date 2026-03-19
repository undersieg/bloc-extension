# bloc_devtools_extension

Time-travel dev tools for `flutter_bloc` — inspired by Redux DevTools.

Two ways to use it:
1. **In-app widget** — `BlocDevToolsPanel` in a drawer (works immediately)
2. **Flutter DevTools Extension** — a custom tab in the browser-based DevTools (requires a build step)

## Quick start — in-app widget

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
endDrawer: Drawer(
width: 360,
child: SafeArea(
child: BlocDevToolsPanel(store: DevToolsStore.instance),
),
),
)
```

Done. Open the drawer and you get three tabs: History, Graph, Performance.

---

## Flutter DevTools Extension (browser tab)

This puts a **bloc_devtools_extension** tab directly in Flutter DevTools, right next to the Inspector, Profiler, etc.

### How it works

```
Your running app (device/emulator)          Flutter DevTools (browser)
┌──────────────────────────────┐           ┌──────────────────────────────┐
│ BlocDevToolsObserver         │           │ Flutter Inspector, Profiler   │
│         ↓                    │           │ ─────────────────────────────│
│ DevToolsStore                │──VM svc──▶│ bloc_devtools_extension tab  │
│         ↓                    │           │ (Flutter web app in iframe)  │
│ registerBlocDevToolsService  │           │                              │
│   Extension()                │           │                              │
└──────────────────────────────┘           └──────────────────────────────┘
```

### Step 1 — Register the VM service extension in your app

Add one line to `main()`:

```dart
void main() {
  Bloc.observer = BlocDevToolsObserver(DevToolsStore.instance);
  registerBlocDevToolsServiceExtension(DevToolsStore.instance);  // ← add this
  runApp(const MyApp());
}
```

This registers `ext.bloc_devtools.*` endpoints that the DevTools web app queries.

### Step 2 — Build the DevTools extension web app

```bash
cd bloc_devtools_extension/devtools_extension
flutter pub get
flutter build web --release --no-tree-shake-icons
```

### Step 3 — Copy the build output into the extension directory

```bash
# From the bloc_devtools_extension root:
cp -r devtools_extension/build/web/* extension/devtools/build/
```

The final package structure should look like:

```
bloc_devtools_extension/
  extension/
    devtools/
      config.yaml          ← extension metadata
      build/               ← compiled Flutter web app
        index.html
        main.dart.js
        ...
  lib/                     ← the library (observer, store, widgets)
  pubspec.yaml
```

### Step 4 — Run your app and open DevTools

```bash
cd your_app
flutter pub get
flutter run
```

Open Flutter DevTools in your browser (the URL printed in the terminal). You'll see a new **bloc_devtools_extension** tab. Enable it when prompted.

### Automating the build

Add a script to your workflow:

```bash
#!/bin/bash
# build_devtools_extension.sh
cd bloc_devtools_extension/devtools_extension
flutter build web --release --no-tree-shake-icons
rm -rf ../extension/devtools/build
cp -r build/web ../extension/devtools/build
echo "DevTools extension built successfully"
```

---

## Features

### History tab
- Event timeline with elapsed-time gap indicators
- Processing time badges (green < 16ms, orange < 100ms, red)
- Time-travel slider with skip/jump controls
- BLoC type filter chips
- State inspector with toggleable diff view

### Graph tab
- Live BLoC/Cubit connection map
- Relationship detection via temporal correlation (100ms window)
- Edge strength grows with each correlated event pair
- Per-instance detail table

### Performance tab
- Summary cards (avg / fastest / slowest / count)
- Per-BLoC breakdown with bar charts
- Top 10 slowest transitions

---

## API summary

### In your app (lib/)

| Class | Purpose |
|-------|---------|
| `DevToolsStore` | State history, lifecycle, relationships, performance data |
| `DevToolsStore.instance` | Global singleton |
| `BlocDevToolsObserver` | BlocObserver that records everything |
| `BlocDevToolsPanel` | In-app widget (3 tabs) |
| `DevToolsStoreProvider` | InheritedWidget for widget-tree access |
| `registerBlocDevToolsServiceExtension()` | VM service bridge for DevTools browser tab |

### VM service endpoints (used by the DevTools extension)

| Endpoint | Returns |
|----------|---------|
| `ext.bloc_devtools.getState` | Summary: entry count, alive blocs, avg timing |
| `ext.bloc_devtools.getEntries` | State history (supports `sinceIndex` for incremental fetching) |
| `ext.bloc_devtools.getGraph` | Alive blocs + detected relationships |
| `ext.bloc_devtools.getPerformance` | Timing metrics, per-BLoC breakdown |

## License

MIT