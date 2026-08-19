import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'local_state_store.dart';

class RemoteStateSyncService extends ChangeNotifier {
  RemoteStateSyncService({required this.auth, required this.localState}) {
    auth.addListener(_onAuthChanged);
    localState.addListener(_onLocalStateChanged);
  }

  final AuthService auth;
  final LocalStateStore localState;

  Timer? _debounce;
  bool _syncing = false;
  bool _applyingRemote = false;
  bool _disposed = false;
  DateTime? _lastSyncedAt;
  String? _lastError;

  SupabaseClient? get _client => auth.client;
  bool get isSyncing => _syncing;
  bool get hasError => _lastError != null;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  void start() {
    if (auth.isSignedIn) unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (_disposed || _syncing || !auth.isSignedIn) return;

    final client = _client;
    final userId = auth.userId;
    if (client == null || userId == null) return;

    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final remote = await client
          .from('user_state')
          .select('payload')
          .eq('user_id', userId)
          .maybeSingle();
      final payload = remote?['payload'];
      if (payload is Map) {
        _applyingRemote = true;
        try {
          localState.mergeRemote(Map<String, dynamic>.from(payload));
        } finally {
          _applyingRemote = false;
        }
      }

      await client.from('user_state').upsert(<String, dynamic>{
        'user_id': userId,
        'payload': localState.toPayload(),
      }, onConflict: 'user_id');
      _lastSyncedAt = DateTime.now();
    } catch (error) {
      _lastError = error.toString();
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

  void _onLocalStateChanged() {
    if (_applyingRemote || !auth.isSignedIn) return;
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
    localState.removeListener(_onLocalStateChanged);
    super.dispose();
  }
}
