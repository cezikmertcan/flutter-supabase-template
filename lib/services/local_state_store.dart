import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStateStore extends ChangeNotifier {
  LocalStateStore._(this._preferences) {
    _actionCount = _preferences.getInt(_actionCountKey) ?? 0;
    _lastActionAt = _preferences.getString(_lastActionAtKey);
  }

  static const _actionCountKey = 'sample_action_count';
  static const _lastActionAtKey = 'sample_last_action_at';

  final SharedPreferences _preferences;
  late int _actionCount;
  String? _lastActionAt;

  static Future<LocalStateStore> load() async {
    return LocalStateStore._(await SharedPreferences.getInstance());
  }

  int get actionCount => _actionCount;
  String? get lastActionAt => _lastActionAt;

  void recordAction() {
    _actionCount += 1;
    _lastActionAt = DateTime.now().toIso8601String();
    _persist();
    notifyListeners();
  }

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'version': 1,
      'actionCount': _actionCount,
      'lastActionAt': _lastActionAt,
    };
  }

  void mergeRemote(Map<String, dynamic> payload) {
    final remoteCount = payload['actionCount'];
    if (remoteCount is num) {
      _actionCount = remoteCount.toInt().clamp(0, 1000000).toInt();
    }

    final remoteLastAction = payload['lastActionAt'];
    if (remoteLastAction is String && remoteLastAction.isNotEmpty) {
      _lastActionAt = remoteLastAction;
    }

    _persist();
    notifyListeners();
  }

  void _persist() {
    unawaited(_preferences.setInt(_actionCountKey, _actionCount));
    if (_lastActionAt == null) {
      unawaited(_preferences.remove(_lastActionAtKey));
    } else {
      unawaited(_preferences.setString(_lastActionAtKey, _lastActionAt!));
    }
  }
}
