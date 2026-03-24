## 0.2.0

* **Collapsible JSON tree view** — replaced flat JSON dump in the state
  inspector with `JsonTreeView`, a recursive tree widget with:
  * Expandable/collapsible Map and List nodes.
  * **Expand All / Collapse All** buttons.
  * Syntax coloring (strings green, numbers blue, booleans orange, null grey).
  * Tap any leaf value to copy it to clipboard.
  * Type hints showing `{5}` for Maps and `[12]` for Lists.
* **Improved timeline rows** — each entry now shows:
  * BLoC type name (bold) with a colored Bloc/Cubit badge.
  * `← EventName` for Bloc events, state class name for Cubits.
  * Timestamp and processing time badge on a separate line.
* **`isBloc` field on `DevToolsEntry`** — Bloc/Cubit badge is now determined
  from the observer rather than guessing from the presence of an event.
* **Search field for filter chips** — appears automatically when there are
  more than 3 BLoC types; filters the chip list by name. Added to both the
  in-app widget and the DevTools extension.
* **Cubit performance tracking** — `onChange` now calls
  `recordTransitionMetrics` so Cubits appear in the Performance tab breakdown.
* **Slowest transitions list** — added to both the in-app Performance tab and
  the DevTools extension, showing the top 10 with ranked rows.
* **Draggable graph nodes** — uses `Listener`-based pointer handling that works
  in both the in-app drawer and the DevTools iframe. Includes a reset-positions
  button.
* **Graph node selection** — tap a node to see a detail panel with transition
  count, lifetime, avg processing time, and connected BLoCs. Connected edges
  highlight on selection.
* **Performance tab selection** — tap a BLoC row or a slow transition to see
  details in a side panel. Performance tab is now a `StatefulWidget` with its
  own store listener.
* **Graph search and type filters** — search bar and Bloc/Cubit toggle chips
  in both the in-app and DevTools Graph tabs.
* **Correlation count on graph edges** — the number label now renders in the
  DevTools extension (was missing before).
* **Mobile gesture fixes:**
  * `TabBarView` swipe disabled (`NeverScrollableScrollPhysics`) to prevent
    conflict with graph node dragging.
  * `GestureDetector` with pan handlers absorbs drag gestures so the drawer
    does not close while dragging nodes.
* **Graph detail panel overflow fix** — uses `SingleChildScrollView` with
  `maxHeight` constraint instead of fixed height.
* **Removed skip/eye feature** — the confusing eye icon toggle was removed
  from the timeline. Slider now operates on all entries directly.
* **CI workflow** — GitHub Actions runs `flutter analyze` and `flutter test`
  on every push and PR.
* **86 unit tests** across 4 test files covering `DevToolsEntry`,
  `BlocLifecycleRecord`, `BlocRelationship`, `DevToolsStore`, and
  `BlocDevToolsObserver` integration.
* **pub.dev compliance** — topics, platforms, `.pubignore`, `CHANGELOG.md`,
  BSD 3-Clause license, `publish.sh` build-and-publish script, and
  `devtools_extensions validate` integration.
* **Example app expanded** to 5 BLoCs across 4 tabs:
  * `ProjectsCubit` — large deeply-nested state with workspace, projects,
    tasks, subtasks, team members, budgets, and activity logs. Demonstrates
    the collapsible JSON tree view.
  * Projects tab with star toggle, filters, and refresh actions.
  * About tab updated with all BLoC descriptions and usage guide.

## 0.1.0

* Initial release.
* **In-app widget** (`BlocDevToolsPanel`) with three tabs:
  * **History** — event timeline with gap indicators, time-travel slider, BLoC
    type filter chips, state inspector with JSON and diff views, state replay.
  * **Graph** — live BLoC/Cubit connection map with draggable nodes, search
    filter, Bloc/Cubit type toggle, relationship detection via temporal
    correlation, and a detail panel.
  * **Performance** — summary cards (avg/fastest/slowest), per-BLoC breakdown
    with bar charts, top 10 slowest transitions list, selectable rows with
    detail panel.
* **Flutter DevTools extension** — custom browser tab with the same three
  panels, communicating with the running app via VM service extensions.
* `BlocDevToolsObserver` — records transitions, lifecycle events, and
  event-to-transition processing time for Blocs and Cubits.
* `DevToolsStore` — centralized ChangeNotifier with state history, lifecycle
  tracking, relationship detection, performance metrics, and state replay.
* `DevToolsStoreProvider` — InheritedWidget for widget-tree access.
* `registerBlocDevToolsServiceExtension()` — registers VM service endpoints
  for the DevTools browser tab.