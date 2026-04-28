import 'dart:async';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/models/search_result_item.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _searchRecentQueriesKey = 'search_recent_queries';
const _searchRecentSelectionIdsKey = 'search_recent_selection_ids';
const _searchShowRecentKey = 'search_show_recent_queries';
const _searchDefaultModeKey = 'search_default_mode';

class SearchService extends ChangeNotifier {
  static const String searchModeLocalOverlay = 'local_overlay';
  static const String searchModeGoogleVoice = 'google_voice';
  static const String searchModeSystemAssist = 'system_assist';

  final SharedPreferences _sharedPreferences;
  final FLauncherChannel _channel;

  List<String> _recentQueries = const <String>[];
  List<String> _recentSelectionIds = const <String>[];
  String _defaultSearchMode = searchModeLocalOverlay;
  bool _showRecentSearches = true;
  List<Map<String, dynamic>> _tvInputs = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _searchableMedia = const <Map<String, dynamic>>[];
  bool _busy = false;

  List<String> get recentQueries => List<String>.unmodifiable(_recentQueries);
  String get defaultSearchMode => _defaultSearchMode;
  bool get showRecentSearches => _showRecentSearches;
  List<Map<String, dynamic>> get tvInputs =>
      List<Map<String, dynamic>>.unmodifiable(_tvInputs);
  List<Map<String, dynamic>> get searchableMedia =>
      List<Map<String, dynamic>>.unmodifiable(_searchableMedia);
  bool get busy => _busy;

  SearchService(this._sharedPreferences, this._channel) {
    _recentQueries =
        _sharedPreferences.getStringList(_searchRecentQueriesKey) ?? const [];
    _recentSelectionIds =
        _sharedPreferences.getStringList(_searchRecentSelectionIdsKey) ??
            const [];
    _defaultSearchMode = _sanitizeMode(
      _sharedPreferences.getString(_searchDefaultModeKey) ??
          searchModeLocalOverlay,
    );
    _showRecentSearches =
        _sharedPreferences.getBool(_searchShowRecentKey) ?? true;
  }

  Future<void> setShowRecentSearches(bool value) async {
    _showRecentSearches = value;
    await _sharedPreferences.setBool(_searchShowRecentKey, value);
    notifyListeners();
  }

  Future<void> setDefaultSearchMode(String value) async {
    _defaultSearchMode = _sanitizeMode(value);
    await _sharedPreferences.setString(
      _searchDefaultModeKey,
      _defaultSearchMode,
    );
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    _recentQueries = const <String>[];
    _recentSelectionIds = const <String>[];
    await Future.wait([
      _sharedPreferences.setStringList(_searchRecentQueriesKey, _recentQueries),
      _sharedPreferences.setStringList(
        _searchRecentSelectionIdsKey,
        _recentSelectionIds,
      ),
    ]);
    notifyListeners();
  }

  Future<void> refreshRemoteSources() async {
    _busy = true;
    notifyListeners();
    try {
      final tvInputMap = await _channel.getTvInputs();
      final mediaMap = await _channel.querySearchableMedia();
      _tvInputs = ((tvInputMap['inputs'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
      _searchableMedia = ((mediaMap['videos'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> startSpeechRecognizer() =>
      _channel.startSpeechRecognizer();

  Future<bool> launchTvInput(String inputId) => _channel.launchTvInput(inputId);

  Future<bool> launchMediaUri(String uri) => _channel.launchMediaUri(uri);

  List<SearchResultItem> rankResults({
    required String query,
    required List<SearchResultItem> items,
    String filter = 'all',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = items.where((item) {
      if (filter == 'all') {
        return item.enabled;
      }
      return item.enabled && item.kind.name == filter;
    });

    if (normalizedQuery.isEmpty) {
      return filtered.toList(growable: false)
        ..sort((left, right) => _compareForEmptyQuery(left, right));
    }

    final scored = filtered
        .map((item) => MapEntry(item, _scoreItem(item, normalizedQuery)))
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    scored.sort((left, right) {
      final scoreCompare = right.value.compareTo(left.value);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      if (left.key.kind != right.key.kind) {
        return _kindPriority(left.key.kind).compareTo(
          _kindPriority(right.key.kind),
        );
      }
      return left.key.title.toLowerCase().compareTo(
            right.key.title.toLowerCase(),
          );
    });
    return scored.map((entry) => entry.key).toList(growable: false);
  }

  Future<void> recordSelection(SearchResultItem item, {String query = ''}) async {
    if (query.trim().isNotEmpty) {
      _recentQueries = <String>[
        query.trim(),
        ..._recentQueries.where((entry) => entry != query.trim()),
      ].take(10).toList(growable: false);
    }
    _recentSelectionIds = <String>[
      item.id,
      ..._recentSelectionIds.where((entry) => entry != item.id),
    ].take(20).toList(growable: false);
    await Future.wait([
      _sharedPreferences.setStringList(_searchRecentQueriesKey, _recentQueries),
      _sharedPreferences.setStringList(
        _searchRecentSelectionIdsKey,
        _recentSelectionIds,
      ),
    ]);
    notifyListeners();
  }

  Map<String, dynamic> toBackupMap() => <String, dynamic>{
        'defaultSearchMode': _defaultSearchMode,
        'showRecentSearches': _showRecentSearches,
        'recentQueries': _recentQueries,
        'recentSelectionIds': _recentSelectionIds,
      };

  Future<void> applyBackupMap(Map<String, dynamic> data) async {
    _defaultSearchMode = _sanitizeMode(
      data['defaultSearchMode']?.toString() ?? searchModeLocalOverlay,
    );
    _showRecentSearches = data['showRecentSearches'] != false;
    _recentQueries = _readStringList(data['recentQueries'], maxLength: 10);
    _recentSelectionIds =
        _readStringList(data['recentSelectionIds'], maxLength: 20);
    await Future.wait([
      _sharedPreferences.setString(_searchDefaultModeKey, _defaultSearchMode),
      _sharedPreferences.setBool(_searchShowRecentKey, _showRecentSearches),
      _sharedPreferences.setStringList(_searchRecentQueriesKey, _recentQueries),
      _sharedPreferences.setStringList(
        _searchRecentSelectionIdsKey,
        _recentSelectionIds,
      ),
    ]);
    notifyListeners();
  }

  String _sanitizeMode(String value) {
    switch (value) {
      case searchModeGoogleVoice:
      case searchModeSystemAssist:
        return value;
      default:
        return searchModeLocalOverlay;
    }
  }

  int _scoreItem(SearchResultItem item, String query) {
    final title = item.title.toLowerCase();
    final subtitle = item.subtitle.toLowerCase();
    final keywords = item.keywords.toLowerCase();
    var score = 0;
    if (title == query) {
      score += 400;
    } else if (title.startsWith(query)) {
      score += 280;
    } else if (title.contains(query)) {
      score += 200;
    }

    if (subtitle.startsWith(query)) {
      score += 120;
    } else if (subtitle.contains(query)) {
      score += 80;
    }

    if (keywords.startsWith(query)) {
      score += 90;
    } else if (keywords.contains(query)) {
      score += 60;
    }

    final selectionIndex = _recentSelectionIds.indexOf(item.id);
    if (selectionIndex >= 0) {
      score += (100 - selectionIndex).clamp(20, 100);
    }

    score += switch (item.kind) {
      SearchResultKind.app => 30,
      SearchResultKind.settings => 20,
      SearchResultKind.action => 15,
      SearchResultKind.input => 10,
      SearchResultKind.media => 5,
    };

    return score;
  }

  int _compareForEmptyQuery(SearchResultItem left, SearchResultItem right) {
    final leftIndex = _recentSelectionIds.indexOf(left.id);
    final rightIndex = _recentSelectionIds.indexOf(right.id);
    final normalizedLeft = leftIndex < 0 ? 999 : leftIndex;
    final normalizedRight = rightIndex < 0 ? 999 : rightIndex;
    if (normalizedLeft != normalizedRight) {
      return normalizedLeft.compareTo(normalizedRight);
    }
    if (left.kind != right.kind) {
      return _kindPriority(left.kind).compareTo(_kindPriority(right.kind));
    }
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }

  int _kindPriority(SearchResultKind kind) => switch (kind) {
        SearchResultKind.app => 0,
        SearchResultKind.settings => 1,
        SearchResultKind.action => 2,
        SearchResultKind.input => 3,
        SearchResultKind.media => 4,
      };

  static List<String> _readStringList(dynamic value, {required int maxLength}) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .take(maxLength)
        .toList(growable: false);
  }
}
