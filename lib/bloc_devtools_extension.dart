/// Time-travel dev tools for flutter_bloc — inspired by Redux DevTools.
///
/// This library provides:
/// - [DevToolsStore] — centralized state/history manager for the dev tools.
/// - [BlocDevToolsObserver] — a [BlocObserver] that records transitions.
/// - [BlocDevToolsPanel] — a ready-to-use Flutter widget for the UI.
/// - [DevToolsEntry] — the data model for a single recorded state change.
///
/// ## Quick start
///
/// ```dart
/// import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';
///
/// void main() {
///   final devToolsStore = DevToolsStore();
///   Bloc.observer = BlocDevToolsObserver(devToolsStore);
///
///   runApp(MyApp(devToolsStore: devToolsStore));
/// }
/// ```
///
/// Then place [BlocDevToolsPanel] wherever makes sense — a drawer, an overlay,
/// or a dedicated debug route.
library bloc_devtools_extension;

export 'src/dev_tools_entry.dart';
export 'src/dev_tools_store.dart';
export 'src/bloc_lifecycle.dart';
export 'src/bloc_dev_tools_observer.dart';
export 'src/widgets/bloc_dev_tools_panel.dart';
export 'src/widgets/dev_tools_store_provider.dart';
