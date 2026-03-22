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
