import 'dart:convert';
import 'dart:developer';

import 'dev_tools_store.dart';

/// Registers a Dart VM Service Extension that exposes [DevToolsStore] data
/// to the Flutter DevTools browser UI.
///
/// The DevTools extension (running as a Flutter web app in an iframe)
/// calls this service extension to retrieve the current state history,
/// lifecycle records, relationships, and performance data.
///
/// Call this once during app startup:
/// ```dart
/// registerBlocDevToolsServiceExtension(DevToolsStore.instance);
/// ```
void registerBlocDevToolsServiceExtension(DevToolsStore store) {
  // Register the service extension that the DevTools extension will call.
  // Extension name format: ext.bloc_devtools.<method>
  registerExtension('ext.bloc_devtools.getState', (method, params) async {
    final data = _serializeStore(store);
    return ServiceExtensionResponse.result(json.encode(data));
  });

  registerExtension('ext.bloc_devtools.getEntries', (method, params) async {
    final sinceIndex = int.tryParse(params['sinceIndex'] ?? '') ?? 0;
    final entries = store.entries;
    final slice = sinceIndex < entries.length
        ? entries.sublist(sinceIndex)
        : <dynamic>[];

    return ServiceExtensionResponse.result(json.encode({
      'totalCount': entries.length,
      'sinceIndex': sinceIndex,
      'entries': slice.map(_serializeEntry).toList(),
    }));
  });

  registerExtension('ext.bloc_devtools.getGraph', (method, params) async {
    return ServiceExtensionResponse.result(json.encode({
      'aliveBlocs': store.aliveBlocs.map((r) => {
        'blocType': r.blocType,
        'instanceId': r.instanceId,
        'isBloc': r.isBloc,
        'transitionCount': r.transitionCount,
        'createdAt': r.createdAt.toIso8601String(),
        'avgProcessingUs': r.avgProcessingTime.inMicroseconds,
      }).toList(),
      'relationships': store.relationships.map((r) => {
        'source': r.sourceBlocType,
        'target': r.targetBlocType,
        'correlationCount': r.correlationCount,
        'strength': r.strength,
      }).toList(),
    }));
  });

  registerExtension('ext.bloc_devtools.getPerformance',
          (method, params) async {
        final timed = store.entriesWithTiming;
        final slowest = store.slowestTransition;

        // Top 10 slowest transitions.
        final sortedTimed = List.of(timed)
          ..sort((a, b) => b.processingDuration!.inMicroseconds
              .compareTo(a.processingDuration!.inMicroseconds));
        final top10 = sortedTimed.take(10).toList();

        return ServiceExtensionResponse.result(json.encode({
          'avgProcessingUs': store.avgProcessingTime.inMicroseconds,
          'measuredCount': timed.length,
          'slowest': slowest != null ? _serializeEntry(slowest) : null,
          'slowestList': top10.map(_serializeEntry).toList(),
          'perBloc': store.lifecycles
              .where((r) => r.transitionCount > 0)
              .map((r) => {
            'blocType': r.blocType,
            'isBloc': r.isBloc,
            'transitionCount': r.transitionCount,
            'avgProcessingUs': r.avgProcessingTime.inMicroseconds,
            'totalProcessingUs':
            r.totalProcessingTime.inMicroseconds,
          })
              .toList(),
        }));
      });

  // Post an event so DevTools knows the extension is ready.
  postEvent('bloc_devtools.ready', {'version': '0.1.0'});

  // ── Action endpoints (called by DevTools to mutate state) ─────────────

  registerExtension('ext.bloc_devtools.jumpTo', (method, params) async {
    final index = int.tryParse(params['index'] ?? '') ?? -1;
    store.jumpTo(index);
    return ServiceExtensionResponse.result(
        json.encode({'ok': true, 'currentIndex': store.currentIndex}));
  });

  registerExtension('ext.bloc_devtools.toggleSkip', (method, params) async {
    final index = int.tryParse(params['index'] ?? '') ?? -1;
    store.toggleSkip(index);
    final entry = index >= 0 && index < store.entries.length
        ? store.entries[index]
        : null;
    return ServiceExtensionResponse.result(json.encode({
      'ok': true,
      'index': index,
      'isSkipped': entry?.isSkipped ?? false,
    }));
  });

  registerExtension('ext.bloc_devtools.replay', (method, params) async {
    final index = int.tryParse(params['index'] ?? '') ?? -1;
    if (index < 0 || index >= store.entries.length) {
      return ServiceExtensionResponse.result(
          json.encode({'ok': false, 'error': 'Invalid index'}));
    }
    final entry = store.entries[index];
    final success = store.replayState(entry);
    return ServiceExtensionResponse.result(
        json.encode({'ok': success, 'blocType': entry.blocType}));
  });
}

Map<String, dynamic> _serializeStore(DevToolsStore store) {
  return {
    'entryCount': store.length,
    'currentIndex': store.currentIndex,
    'blocTypes': store.blocTypes.toList(),
    'aliveBlocTypes':
    store.aliveBlocs.map((r) => r.blocType).toSet().toList(),
    'aliveBlocCount': store.aliveBlocs.length,
    'relationshipCount': store.relationships.length,
    'measuredTransitions': store.entriesWithTiming.length,
    'avgProcessingUs': store.avgProcessingTime.inMicroseconds,
  };
}

Map<String, dynamic> _serializeEntry(dynamic entry) {
  return {
    'blocType': entry.blocType,
    'event': entry.event?.toString(),
    'state': _tryToJson(entry.state),
    'previousState': _tryToJson(entry.previousState),
    'timestamp': entry.timestamp.toIso8601String(),
    'isSkipped': entry.isSkipped,
    'processingUs': entry.processingDuration?.inMicroseconds,
  };
}

dynamic _tryToJson(Object? obj) {
  if (obj == null) return null;
  try {
    // ignore: avoid_dynamic_calls
    return (obj as dynamic).toJson();
  } catch (_) {
    return obj.toString();
  }
}