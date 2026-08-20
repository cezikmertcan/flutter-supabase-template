import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'flashcard_ai_store.dart';

class RemoteStateSyncService extends ChangeNotifier {
  RemoteStateSyncService({required this.auth, required this.store}) {
    auth.addListener(_onAuthChanged);
    store.addListener(_onStoreChanged);
  }

  final AuthService auth;
  final FlashCardAiStore store;

  Timer? _debounce;
  bool _syncing = false;
  bool _applyingRemote = false;
  bool _disposed = false;
  int _localChangeVersion = 0;
  int _syncedChangeVersion = 0;
  DateTime? _lastSyncedAt;
  String? _lastError;

  SupabaseClient? get _client => auth.client;
  bool get isSyncing => _syncing;
  bool get hasError => _lastError != null;
  String? get errorMessage => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  void start() {
    if (auth.isSignedIn) unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (_disposed || _syncing) return;
    if (!auth.isSignedIn) {
      _lastError = 'Önce hesabına giriş yapmalısın.';
      notifyListeners();
      return;
    }

    final client = _client;
    final userId = auth.userId;
    if (client == null || userId == null) {
      _lastError = 'Supabase oturumu hazır değil.';
      notifyListeners();
      return;
    }

    _syncing = true;
    _lastError = null;
    notifyListeners();

    final syncVersion = _localChangeVersion;
    final hasPendingLocalChanges = syncVersion != _syncedChangeVersion;

    try {
      final remote = await client
          .from('user_state')
          .select('payload')
          .eq('user_id', userId)
          .maybeSingle();
      final payload = remote?['payload'];
      // A local action, especially "new conversation", must not be replaced
      // by an in-flight response containing the previous conversation. Pull
      // remote state only when there are no local changes waiting to sync and
      // nothing changed while this request was in flight.
      if (!hasPendingLocalChanges &&
          _localChangeVersion == syncVersion &&
          payload is Map) {
        _applyingRemote = true;
        try {
          store.mergeRemote(Map<String, dynamic>.from(payload));
        } finally {
          _applyingRemote = false;
        }
      }

      final nextPayload = store.toPayload();
      if (remote == null) {
        await client.from('user_state').insert(<String, dynamic>{
          'user_id': userId,
          'payload': nextPayload,
        });
      } else {
        await client
            .from('user_state')
            .update(<String, dynamic>{'payload': nextPayload})
            .eq('user_id', userId);
      }
      if (_localChangeVersion == syncVersion) {
        _syncedChangeVersion = syncVersion;
      }
      _lastSyncedAt = DateTime.now();
    } catch (error) {
      _lastError = _cleanError(error);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  void _onAuthChanged() {
    if (!auth.isSignedIn) {
      _debounce?.cancel();
      _lastSyncedAt = null;
      _lastError = null;
      notifyListeners();
      return;
    }
    _scheduleSync(const Duration(milliseconds: 100));
  }

  void _onStoreChanged() {
    if (_applyingRemote || !auth.isSignedIn) return;
    _localChangeVersion++;
    _scheduleSync(const Duration(seconds: 1));
  }

  void _scheduleSync(Duration delay) {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(syncNow()));
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    auth.removeListener(_onAuthChanged);
    store.removeListener(_onStoreChanged);
    super.dispose();
  }

  static String _cleanError(Object error) {
    if (error is PostgrestException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}
