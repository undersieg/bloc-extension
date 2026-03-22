/// Time-travel dev tools for flutter_bloc — inspired by Redux DevTools.
///
/// Provides state history, BLoC connection graph, performance metrics,
/// state diff, event timeline, time-travel controls, and a Flutter
/// DevTools Extension tab.
///
/// ## Quick start
///
/// ```dart
/// import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';
///
/// void main() {
///   Bloc.observer = BlocDevToolsObserver(DevToolsStore.instance);
///   // Register the VM service extension for the DevTools browser tab:
///   registerBlocDevToolsServiceExtension(DevToolsStore.instance);
///   runApp(MyApp());
/// }
/// ```
library bloc_devtools_extension;

export 'src/dev_tools_entry.dart';
export 'src/dev_tools_store.dart';
export 'src/bloc_lifecycle.dart';
export 'src/bloc_dev_tools_observer.dart';
export 'src/service_extension.dart';
export 'src/widgets/bloc_dev_tools_panel.dart';
export 'src/widgets/dev_tools_store_provider.dart';