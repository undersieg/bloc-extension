import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';

import 'counter_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = BlocDevToolsObserver(DevToolsStore.instance);
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DevToolsStoreProvider(
      store: DevToolsStore.instance,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CounterBloc()),
          BlocProvider(create: (_) => ThemeCubit()),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp(
              title: 'BLoC DevTools Demo',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorSchemeSeed: Colors.deepPurple,
                brightness:
                themeState.isDark ? Brightness.dark : Brightness.light,
                useMaterial3: true,
              ),
              home: const CounterPage(),
            );
          },
        ),
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter'),
        actions: [
          // Theme toggle — exercises the ThemeCubit so the graph shows
          // two live BLoCs and the timeline captures Cubit changes.
          IconButton(
            icon: BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) => Icon(
                  state.isDark ? Icons.light_mode : Icons.dark_mode),
            ),
            tooltip: 'Toggle theme',
            onPressed: () => context.read<ThemeCubit>().toggleTheme(),
          ),
          // Open the DevTools drawer.
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Open DevTools',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),

      // DevTools panel in the end drawer.
      endDrawer: Drawer(
        width: 360,
        child: SafeArea(
          child: BlocDevToolsPanel(
            store: DevToolsStore.instance,
          ),
        ),
      ),

      body: Center(
        child: BlocBuilder<CounterBloc, CounterState>(
          builder: (context, state) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Counter value:'),
                const SizedBox(height: 8),
                Text(
                  '${state.count}',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'dec',
                      onPressed: () =>
                          context.read<CounterBloc>().add(Decrement()),
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'reset',
                      onPressed: () =>
                          context.read<CounterBloc>().add(Reset()),
                      child: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'inc',
                      onPressed: () =>
                          context.read<CounterBloc>().add(Increment()),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
