import 'package:bloc/bloc.dart';

sealed class CounterEvent {}

final class Increment extends CounterEvent {
  @override
  String toString() => 'Increment';
}

final class Decrement extends CounterEvent {
  @override
  String toString() => 'Decrement';
}

final class Reset extends CounterEvent {
  @override
  String toString() => 'Reset';
}

final class IncrementBy extends CounterEvent {
  IncrementBy(this.amount);
  final int amount;
  @override
  String toString() => 'IncrementBy($amount)';
}

class CounterState {
  const CounterState({required this.count});
  final int count;
  Map<String, dynamic> toJson() => {'count': count};
  @override
  String toString() => 'CounterState(count: $count)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CounterState && other.count == count;
  @override
  int get hashCode => count.hashCode;
}

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(count: 0)) {
    on<Increment>((event, emit) => emit(CounterState(count: state.count + 1)));
    on<Decrement>((event, emit) => emit(CounterState(count: state.count - 1)));
    on<Reset>((event, emit) => emit(const CounterState(count: 0)));
    on<IncrementBy>(
            (event, emit) => emit(CounterState(count: state.count + event.amount)));
  }
}

class ThemeState {
  const ThemeState({required this.isDark, this.seedColor = 'purple'});
  final bool isDark;
  final String seedColor;
  Map<String, dynamic> toJson() => {'isDark': isDark, 'seedColor': seedColor};
  @override
  String toString() => 'ThemeState(isDark: $isDark, seedColor: $seedColor)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ThemeState &&
              other.isDark == isDark &&
              other.seedColor == seedColor;
  @override
  int get hashCode => Object.hash(isDark, seedColor);
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState(isDark: false));

  void toggleTheme() => emit(ThemeState(
      isDark: !state.isDark, seedColor: state.seedColor));

  void setSeedColor(String color) =>
      emit(ThemeState(isDark: state.isDark, seedColor: color));
}

sealed class HistoryEvent {}

final class RecordMilestone extends HistoryEvent {
  RecordMilestone(this.value);
  final int value;
  @override
  String toString() => 'RecordMilestone($value)';
}

final class ClearHistory extends HistoryEvent {
  @override
  String toString() => 'ClearHistory';
}

class HistoryState {
  const HistoryState({this.milestones = const [], this.lastRecorded});
  final List<int> milestones;
  final DateTime? lastRecorded;

  Map<String, dynamic> toJson() => {
    'milestones': milestones,
    'count': milestones.length,
    'lastRecorded': lastRecorded?.toIso8601String(),
  };

  @override
  String toString() => 'HistoryState(${milestones.length} milestones)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HistoryState &&
              other.milestones.length == milestones.length;
  @override
  int get hashCode => milestones.length.hashCode;
}

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  HistoryBloc() : super(const HistoryState()) {
    on<RecordMilestone>((event, emit) {
      emit(HistoryState(
        milestones: [...state.milestones, event.value],
        lastRecorded: DateTime.now(),
      ));
    });

    on<ClearHistory>((event, emit) {
      emit(const HistoryState());
    });
  }
}

class SettingsState {
  const SettingsState({
    this.fontSize = 14.0,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.autoSave = false,
  });

  final double fontSize;
  final String language;
  final bool notificationsEnabled;
  final bool autoSave;

  SettingsState copyWith({
    double? fontSize,
    String? language,
    bool? notificationsEnabled,
    bool? autoSave,
  }) =>
      SettingsState(
        fontSize: fontSize ?? this.fontSize,
        language: language ?? this.language,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        autoSave: autoSave ?? this.autoSave,
      );

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'language': language,
    'notificationsEnabled': notificationsEnabled,
    'autoSave': autoSave,
  };

  @override
  String toString() => 'SettingsState($language, ${fontSize}px)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SettingsState &&
              other.fontSize == fontSize &&
              other.language == language &&
              other.notificationsEnabled == notificationsEnabled &&
              other.autoSave == autoSave;

  @override
  int get hashCode =>
      Object.hash(fontSize, language, notificationsEnabled, autoSave);
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void setFontSize(double size) => emit(state.copyWith(fontSize: size));
  void setLanguage(String lang) => emit(state.copyWith(language: lang));
  void toggleNotifications() =>
      emit(state.copyWith(notificationsEnabled: !state.notificationsEnabled));
  void toggleAutoSave() => emit(state.copyWith(autoSave: !state.autoSave));
}

class ProjectsState {
  const ProjectsState({
    required this.workspace,
    required this.projects,
    required this.teamMembers,
    this.lastSyncedAt,
    this.filters = const {},
  });

  final Map<String, dynamic> workspace;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> teamMembers;
  final String? lastSyncedAt;
  final Map<String, dynamic> filters;

  Map<String, dynamic> toJson() => {
    'workspace': workspace,
    'projects': projects,
    'teamMembers': teamMembers,
    'lastSyncedAt': lastSyncedAt,
    'filters': filters,
    'summary': {
      'totalProjects': projects.length,
      'totalTasks': projects.fold<int>(
          0, (sum, p) => sum + ((p['tasks'] as List?)?.length ?? 0)),
      'totalMembers': teamMembers.length,
    },
  };

  @override
  String toString() =>
      'ProjectsState(${projects.length} projects, ${teamMembers.length} members)';
}

class ProjectsCubit extends Cubit<ProjectsState> {
  ProjectsCubit() : super(_initialState());

  void refresh() => emit(_initialState(
    syncTime: DateTime.now().toIso8601String(),
  ));

  void toggleStarred(int projectIndex) {
    final updated = List<Map<String, dynamic>>.from(state.projects);
    final project = Map<String, dynamic>.from(updated[projectIndex]);
    project['isStarred'] = !(project['isStarred'] as bool? ?? false);
    updated[projectIndex] = project;
    emit(ProjectsState(
      workspace: state.workspace,
      projects: updated,
      teamMembers: state.teamMembers,
      lastSyncedAt: state.lastSyncedAt,
      filters: state.filters,
    ));
  }

  void setFilter(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(state.filters);
    updated[key] = value;
    emit(ProjectsState(
      workspace: state.workspace,
      projects: state.projects,
      teamMembers: state.teamMembers,
      lastSyncedAt: state.lastSyncedAt,
      filters: updated,
    ));
  }

  static ProjectsState _initialState({String? syncTime}) {
    return ProjectsState(
      lastSyncedAt: syncTime,
      workspace: {
        'id': 'ws-7284',
        'name': 'Acme Engineering',
        'plan': 'enterprise',
        'seats': 25,
        'billing': {
          'cycle': 'annual',
          'currency': 'USD',
          'monthlyRate': 49.99,
          'nextInvoice': '2026-04-01',
          'paymentMethod': {
            'type': 'card',
            'last4': '4242',
            'brand': 'visa',
            'expiresAt': '2028-12',
          },
        },
        'integrations': ['slack', 'github', 'jira', 'figma'],
        'ssoEnabled': true,
      },
      filters: {
        'status': 'all',
        'assignee': null,
        'sortBy': 'updatedAt',
        'sortOrder': 'desc',
      },
      projects: [
        {
          'id': 'proj-001',
          'name': 'Mobile App Redesign',
          'status': 'in_progress',
          'isStarred': true,
          'createdAt': '2025-11-15T09:00:00Z',
          'updatedAt': '2026-03-20T14:32:00Z',
          'owner': {'id': 'usr-101', 'name': 'Alice Chen', 'role': 'lead'},
          'tags': ['mobile', 'ui/ux', 'q1-priority', 'client-facing'],
          'budget': {
            'allocated': 120000,
            'spent': 87450,
            'currency': 'USD',
            'breakdown': {
              'engineering': 62000,
              'design': 18450,
              'testing': 7000,
            },
          },
          'tasks': [
            {
              'id': 'task-001',
              'title': 'Design new onboarding flow',
              'status': 'done',
              'priority': 'high',
              'assignee': {'id': 'usr-103', 'name': 'Carlos Ruiz'},
              'estimateHours': 24,
              'loggedHours': 28.5,
              'subtasks': [
                {'title': 'User research', 'done': true},
                {'title': 'Wireframes', 'done': true},
                {'title': 'Hi-fi mockups', 'done': true},
                {'title': 'Prototype', 'done': true},
              ],
              'comments': 12,
              'attachments': 5,
            },
            {
              'id': 'task-002',
              'title': 'Implement auth module',
              'status': 'in_progress',
              'priority': 'critical',
              'assignee': {'id': 'usr-102', 'name': 'Bob Park'},
              'estimateHours': 40,
              'loggedHours': 15.0,
              'subtasks': [
                {'title': 'OAuth2 provider setup', 'done': true},
                {'title': 'Token refresh logic', 'done': true},
                {'title': 'Biometric login', 'done': false},
                {'title': 'Session management', 'done': false},
                {'title': 'E2E tests', 'done': false},
              ],
              'comments': 8,
              'attachments': 2,
            },
            {
              'id': 'task-003',
              'title': 'Migrate to new design system tokens',
              'status': 'todo',
              'priority': 'medium',
              'assignee': null,
              'estimateHours': 16,
              'loggedHours': 0,
              'subtasks': [],
              'comments': 3,
              'attachments': 0,
            },
            {
              'id': 'task-004',
              'title': 'Performance audit & optimization',
              'status': 'todo',
              'priority': 'high',
              'assignee': {'id': 'usr-105', 'name': 'Eva Novak'},
              'estimateHours': 32,
              'loggedHours': 0,
              'subtasks': [
                {'title': 'Profile startup time', 'done': false},
                {'title': 'Optimize image loading', 'done': false},
                {'title': 'Reduce bundle size', 'done': false},
              ],
              'comments': 1,
              'attachments': 0,
            },
          ],
          'activityLog': [
            {'action': 'task_completed', 'actor': 'Carlos Ruiz', 'target': 'Design new onboarding flow', 'at': '2026-03-18T16:20:00Z'},
            {'action': 'comment_added', 'actor': 'Bob Park', 'target': 'Implement auth module', 'at': '2026-03-19T11:05:00Z'},
            {'action': 'budget_updated', 'actor': 'Alice Chen', 'target': 'Mobile App Redesign', 'at': '2026-03-20T14:32:00Z'},
          ],
        },
        {
          'id': 'proj-002',
          'name': 'Backend API v3',
          'status': 'in_progress',
          'isStarred': false,
          'createdAt': '2026-01-08T10:00:00Z',
          'updatedAt': '2026-03-22T09:15:00Z',
          'owner': {'id': 'usr-102', 'name': 'Bob Park', 'role': 'lead'},
          'tags': ['backend', 'api', 'infrastructure'],
          'budget': {
            'allocated': 85000,
            'spent': 34200,
            'currency': 'USD',
            'breakdown': {
              'engineering': 30000,
              'devops': 4200,
            },
          },
          'tasks': [
            {
              'id': 'task-010',
              'title': 'GraphQL schema migration',
              'status': 'done',
              'priority': 'critical',
              'assignee': {'id': 'usr-104', 'name': 'Diana Lee'},
              'estimateHours': 60,
              'loggedHours': 54.0,
              'subtasks': [
                {'title': 'Schema design', 'done': true},
                {'title': 'Resolver implementation', 'done': true},
                {'title': 'DataLoader optimization', 'done': true},
                {'title': 'Deprecation notices', 'done': true},
              ],
              'comments': 23,
              'attachments': 7,
            },
            {
              'id': 'task-011',
              'title': 'Rate limiting & throttling',
              'status': 'in_progress',
              'priority': 'high',
              'assignee': {'id': 'usr-106', 'name': 'Frank Muller'},
              'estimateHours': 20,
              'loggedHours': 12.0,
              'subtasks': [
                {'title': 'Token bucket implementation', 'done': true},
                {'title': 'Redis integration', 'done': true},
                {'title': 'Dashboard metrics', 'done': false},
              ],
              'comments': 5,
              'attachments': 1,
            },
            {
              'id': 'task-012',
              'title': 'Webhook delivery system',
              'status': 'todo',
              'priority': 'medium',
              'assignee': null,
              'estimateHours': 30,
              'loggedHours': 0,
              'subtasks': [],
              'comments': 0,
              'attachments': 0,
            },
          ],
          'activityLog': [
            {'action': 'task_completed', 'actor': 'Diana Lee', 'target': 'GraphQL schema migration', 'at': '2026-03-15T17:00:00Z'},
            {'action': 'member_added', 'actor': 'Bob Park', 'target': 'Frank Muller', 'at': '2026-03-10T09:30:00Z'},
          ],
        },
        {
          'id': 'proj-003',
          'name': 'Internal Analytics Dashboard',
          'status': 'planning',
          'isStarred': false,
          'createdAt': '2026-03-01T08:00:00Z',
          'updatedAt': '2026-03-21T11:00:00Z',
          'owner': {'id': 'usr-105', 'name': 'Eva Novak', 'role': 'lead'},
          'tags': ['internal', 'data', 'visualization'],
          'budget': {
            'allocated': 45000,
            'spent': 0,
            'currency': 'USD',
            'breakdown': {},
          },
          'tasks': [],
          'activityLog': [],
        },
      ],
      teamMembers: [
        {'id': 'usr-101', 'name': 'Alice Chen', 'email': 'alice@acme.dev', 'role': 'engineering_manager', 'department': 'mobile', 'joinedAt': '2023-06-15', 'activeProjects': ['proj-001']},
        {'id': 'usr-102', 'name': 'Bob Park', 'email': 'bob@acme.dev', 'role': 'senior_engineer', 'department': 'backend', 'joinedAt': '2024-01-10', 'activeProjects': ['proj-001', 'proj-002']},
        {'id': 'usr-103', 'name': 'Carlos Ruiz', 'email': 'carlos@acme.dev', 'role': 'designer', 'department': 'design', 'joinedAt': '2024-03-22', 'activeProjects': ['proj-001']},
        {'id': 'usr-104', 'name': 'Diana Lee', 'email': 'diana@acme.dev', 'role': 'senior_engineer', 'department': 'backend', 'joinedAt': '2024-08-01', 'activeProjects': ['proj-002']},
        {'id': 'usr-105', 'name': 'Eva Novak', 'email': 'eva@acme.dev', 'role': 'tech_lead', 'department': 'data', 'joinedAt': '2023-11-20', 'activeProjects': ['proj-001', 'proj-003']},
        {'id': 'usr-106', 'name': 'Frank Muller', 'email': 'frank@acme.dev', 'role': 'engineer', 'department': 'backend', 'joinedAt': '2026-03-10', 'activeProjects': ['proj-002']},
      ],
    );
  }
}