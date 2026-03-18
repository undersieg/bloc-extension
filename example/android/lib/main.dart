import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'counter_bloc.dart';

// ─── Dev tools store (global for the app) ───────────────────────────────────

final devToolsStore = DevToolsStore();

// ─── Entry point ────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Attach the dev tools observer so every BLoC/Cubit transition is recorded.
  Bloc.observer = BlocDevToolsObserver(devToolsStore);

  runApp(const CounterApp());
}

// ─── App ────────────────────────────────────────────────────────────────────

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLoC DevTools Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => CounterBloc(),
        child: const CounterPage(),
      ),
    );
  }
}

// ─── Counter page ───────────────────────────────────────────────────────────

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter'),
        actions: [
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

      // ── DevTools live in the end drawer ──────────────────────────────
      endDrawer: Drawer(
        width: 340,
        child: SafeArea(
          child: BlocDevToolsPanel(store: devToolsStore),
        ),
      ),

      // ── Counter display ──────────────────────────────────────────────
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
