import 'package:flutter/widgets.dart';

import '../dev_tools_store.dart';

/// An [InheritedWidget] that provides a [DevToolsStore] to the widget tree.
///
/// Wrap your app (or any subtree) with this provider so that any descendant
/// widget can access the store via [DevToolsStoreProvider.of(context)].
///
/// ```dart
/// // At the root of your app:
/// DevToolsStoreProvider(
///   store: DevToolsStore.instance,
///   child: MaterialApp(/* ... */),
/// )
///
/// // In any descendant widget:
/// final store = DevToolsStoreProvider.of(context);
/// ```
class DevToolsStoreProvider extends InheritedWidget {
  /// Creates a provider that exposes [store] to all descendants.
  const DevToolsStoreProvider({
    super.key,
    required this.store,
    required super.child,
  });

  /// The [DevToolsStore] exposed to this subtree.
  final DevToolsStore store;

  /// Retrieves the nearest [DevToolsStore] from the widget tree.
  ///
  /// Throws a descriptive error if no [DevToolsStoreProvider] is found
  /// above the given [context].
  static DevToolsStore of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<DevToolsStoreProvider>();
    assert(
      provider != null,
      'No DevToolsStoreProvider found in the widget tree. '
      'Wrap your app with DevToolsStoreProvider or use DevToolsStore.instance instead.',
    );
    return provider!.store;
  }

  /// Like [of], but returns `null` instead of throwing if no provider is found.
  static DevToolsStore? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DevToolsStoreProvider>()
        ?.store;
  }

  @override
  bool updateShouldNotify(DevToolsStoreProvider oldWidget) =>
      store != oldWidget.store;
}
