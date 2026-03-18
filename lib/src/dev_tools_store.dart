import 'package:flutter/foundation.dart';

import 'dev_tools_entry.dart';

/// Centralized store that holds the entire history of BLoC state transitions
/// and supports time-travel operations (jump, skip, reset).
///
/// Inspired by Redux DevTools' `DevToolsStore`, this class maintains:
/// - A chronological list of [DevToolsEntry] records.
/// - A `currentIndex` pointer for time travel.
/// - Streams that notify the UI of changes.
///
/// The store does NOT directly mutate BLoC state. Instead, it exposes
/// the [currentEntry] that the UI widget reads to display which state
/// is "active" in the dev tools panel.
class DevToolsStore extends ChangeNotifier {
  DevToolsStore();

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  final List<DevToolsEntry> _entries = [];

  /// Unmodifiable view of every recorded entry.
  List<DevToolsEntry> get entries => List.unmodifiable(_entries);

  /// The number of recorded entries.
  int get length => _entries.length;

  // ---------------------------------------------------------------------------
  // Current position (time-travel cursor)
  // ---------------------------------------------------------------------------

  int _currentIndex = -1;

  /// The index of the currently "selected" entry (for time-travel).
  /// Returns `-1` when there are no entries.
  int get currentIndex => _currentIndex;

  /// The entry at the current cursor position, or `null` if empty.
  DevToolsEntry? get currentEntry =>
      _currentIndex >= 0 && _currentIndex < _entries.length
          ? _entries[_currentIndex]
          : null;

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Adds a new entry to the history and advances the cursor.
  ///
  /// If the cursor was rewound (via [jumpTo]), adding a new entry does NOT
  /// discard future entries — it appends to the full history. This preserves
  /// the complete audit trail, which is the primary purpose of the tool.
  void addEntry(DevToolsEntry entry) {
    _entries.add(entry);
    _currentIndex = _entries.length - 1;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Time-travel actions (modeled after Redux DevTools actions)
  // ---------------------------------------------------------------------------

  /// Jump to a specific index in the history.
  void jumpTo(int index) {
    if (index < 0 || index >= _entries.length) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Toggle the "skipped" flag on an entry.
  /// Skipped entries are excluded from the slider playback.
  void toggleSkip(int index) {
    if (index < 0 || index >= _entries.length) return;
    _entries[index] = _entries[index].copyWith(
      isSkipped: !_entries[index].isSkipped,
    );
    notifyListeners();
  }

  /// Resets the store — clears all recorded history.
  void reset() {
    _entries.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Slider helpers
  // ---------------------------------------------------------------------------

  /// Returns only the entries that have NOT been skipped.
  /// Useful for the slider which should skip over "skipped" entries.
  List<DevToolsEntry> get activeEntries =>
      _entries.where((e) => !e.isSkipped).toList();

  /// The index within [activeEntries] that corresponds to [currentIndex].
  /// Returns -1 if the current entry is skipped or there are no active entries.
  int get activeIndex {
    if (_currentIndex < 0) return -1;
    final current = currentEntry;
    if (current == null || current.isSkipped) return -1;
    return activeEntries.indexOf(current);
  }

  /// Jumps to the entry at the given index within [activeEntries].
  void jumpToActive(int activeIdx) {
    if (activeIdx < 0 || activeIdx >= activeEntries.length) return;
    final target = activeEntries[activeIdx];
    final realIndex = _entries.indexOf(target);
    if (realIndex >= 0) jumpTo(realIndex);
  }

  // ---------------------------------------------------------------------------
  // Filter helpers
  // ---------------------------------------------------------------------------

  /// Returns the set of distinct BLoC type names that appear in the history.
  Set<String> get blocTypes => _entries.map((e) => e.blocType).toSet();

  /// Returns entries filtered to a specific BLoC type.
  List<DevToolsEntry> entriesForBloc(String blocType) =>
      _entries.where((e) => e.blocType == blocType).toList();
}
