import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_devtools_extension/bloc_devtools_extension.dart';

import 'counter_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = BlocDevToolsObserver(DevToolsStore.instance);
  registerBlocDevToolsServiceExtension(DevToolsStore.instance);
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DevToolsStoreProvider(
      store: DevToolsStore.instance,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CounterBloc()),
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => HistoryBloc()),
          BlocProvider(create: (_) => SettingsCubit()),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            final seedColors = {
              'purple': Colors.deepPurple,
              'blue': Colors.blue,
              'green': Colors.green,
              'red': Colors.red,
              'orange': Colors.orange,
            };
            return MaterialApp(
              title: 'BLoC DevTools Demo',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorSchemeSeed:
                    seedColors[themeState.seedColor] ?? Colors.deepPurple,
                brightness:
                    themeState.isDark ? Brightness.dark : Brightness.light,
                useMaterial3: true,
              ),
              home: const HomePage(),
            );
          },
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DevTools Demo'),
        actions: [
          IconButton(
            icon: BlocBuilder<ThemeCubit, ThemeState>(
              builder: (_, s) =>
                  Icon(s.isDark ? Icons.light_mode : Icons.dark_mode),
            ),
            tooltip: 'Toggle theme',
            onPressed: () => context.read<ThemeCubit>().toggleTheme(),
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Open DevTools',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: 360,
        child: SafeArea(
          child: BlocDevToolsPanel(store: DevToolsStore.instance),
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          CounterPage(),
          SettingsPage(),
          AboutPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline), label: 'Counter'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
        ],
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocListener<CounterBloc, CounterState>(
      // When counter changes, record a milestone in HistoryBloc.
      // This fires within ~ms of the counter transition, creating
      // a temporal correlation → visible edge in the Graph tab.
      listener: (context, state) {
        if (state.count != 0 && state.count % 5 == 0) {
          context.read<HistoryBloc>().add(RecordMilestone(state.count));
        }
      },
      child: Center(
        child: BlocBuilder<CounterBloc, CounterState>(
          builder: (context, state) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Counter', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '${state.count}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w700, color: cs.primary),
                ),
                const SizedBox(height: 8),
                BlocBuilder<HistoryBloc, HistoryState>(
                  builder: (context, histState) {
                    return Text(
                      '${histState.milestones.length} milestones recorded (every 5)',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'dec',
                      onPressed: () =>
                          context.read<CounterBloc>().add(Decrement()),
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      heroTag: 'inc',
                      onPressed: () =>
                          context.read<CounterBloc>().add(Increment()),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.small(
                      heroTag: 'inc5',
                      onPressed: () =>
                          context.read<CounterBloc>().add(IncrementBy(5)),
                      tooltip: '+5 (triggers milestone)',
                      child: const Text('+5',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.read<CounterBloc>().add(Reset()),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset counter'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<HistoryBloc>().add(ClearHistory()),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear history'),
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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Change settings and watch the Diff view in DevTools',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Font size'),
              subtitle: Slider(
                value: settings.fontSize,
                min: 10,
                max: 24,
                divisions: 14,
                label: '${settings.fontSize.round()}px',
                onChanged: (v) => context.read<SettingsCubit>().setFontSize(v),
              ),
              trailing: Text('${settings.fontSize.round()}px'),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              trailing: DropdownButton<String>(
                value: settings.language,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'pl', child: Text('Polish')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                ],
                onChanged: (v) {
                  if (v != null) context.read<SettingsCubit>().setLanguage(v);
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle:
                  Text(settings.notificationsEnabled ? 'Enabled' : 'Disabled'),
              value: settings.notificationsEnabled,
              onChanged: (_) =>
                  context.read<SettingsCubit>().toggleNotifications(),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.save_outlined),
              title: const Text('Auto-save'),
              subtitle: Text(settings.autoSave ? 'Enabled' : 'Disabled'),
              value: settings.autoSave,
              onChanged: (_) => context.read<SettingsCubit>().toggleAutoSave(),
            ),
            const Divider(height: 32),
            Text('Theme color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, theme) {
                final colors = {
                  'purple': Colors.deepPurple,
                  'blue': Colors.blue,
                  'green': Colors.green,
                  'red': Colors.red,
                  'orange': Colors.orange,
                };
                return Wrap(
                  spacing: 8,
                  children: colors.entries.map((e) {
                    final selected = theme.seedColor == e.key;
                    return GestureDetector(
                      onTap: () =>
                          context.read<ThemeCubit>().setSeedColor(e.key),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: e.value,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  width: 3)
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('About this demo', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _card(
          context,
          icon: Icons.add_circle,
          color: cs.primary,
          title: 'CounterBloc',
          subtitle: 'Event-driven Bloc with timing. '
              'Demonstrates performance metrics and the slowest transitions list.',
        ),
        _card(
          context,
          icon: Icons.history,
          color: cs.tertiary,
          title: 'HistoryBloc',
          subtitle: 'Records milestones every 5 counter steps. '
              'Connected to CounterBloc — creates an edge in the Graph tab.',
        ),
        _card(
          context,
          icon: Icons.palette,
          color: Colors.orange,
          title: 'ThemeCubit',
          subtitle: 'Simple Cubit for dark/light mode and seed color. '
              'Shows Cubit vs Bloc distinction in the graph.',
        ),
        _card(
          context,
          icon: Icons.settings,
          color: Colors.teal,
          title: 'SettingsCubit',
          subtitle: 'Multi-field state (font size, language, toggles). '
              'Best for testing the Diff view — change one field at a time.',
        ),
        const SizedBox(height: 16),
        Text('Try this:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _step('1. Tap +5 on the counter 3 times to trigger milestones'),
        _step(
            '2. Open DevTools → Graph tab to see the CounterBloc→HistoryBloc edge'),
        _step('3. Go to Settings, change language and toggle notifications'),
        _step(
            '4. Open DevTools → History tab, select the last entry, tap Diff'),
        _step('5. Check the Perf tab to see processing times per BLoC'),
        _step(
            '6. Tap Replay on any entry to push that state onto the live BLoC'),
      ],
    );
  }

  Widget _card(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _step(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('→ ', style: TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
