import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

class AuthOperationResult {
  const AuthOperationResult({this.errorMessage});

  const AuthOperationResult.success() : errorMessage = null;

  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

class AuthService extends ChangeNotifier {
  AuthService._({required this._client, this.initializationError});

  factory AuthService.unconfigured() => AuthService._(client: null);

  static SupabaseClient? _sharedClient;

  static Future<AuthService> initialize() async {
    if (!AppConfig.isConfigured) {
      return AuthService.unconfigured();
    }

    try {
      if (_sharedClient == null) {
        try {
          await Supabase.initialize(
            url: AppConfig.supabaseUrl,
            publishableKey: AppConfig.supabasePublishableKey,
          );
        } catch (_) {
          // Supabase can already be initialized after a hot restart or test.
        }
        _sharedClient = Supabase.instance.client;
      }

      final service = AuthService._(client: _sharedClient);
      service._session = _sharedClient!.auth.currentSession;
      service._authSubscription = _sharedClient!.auth.onAuthStateChange.listen(
        service._handleAuthState,
      );
      unawaited(service.ensureProfile());
      return service;
    } catch (error) {
      return AuthService._(
        client: null,
        initializationError: _cleanError(error),
      );
    }
  }

  final SupabaseClient? _client;
  final String? initializationError;
  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;

  SupabaseClient? get client => _client;
  bool get isConfigured => _client != null;
  bool get isSignedIn => _session != null;
  Session? get session => _session;
  User? get user => _session?.user;
  String? get userId => user?.id;

  String? get displayName {
    final metadata = user?.userMetadata;
    final name = metadata?['full_name'] ?? metadata?['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return user?.email?.split('@').first;
  }

  Future<AuthOperationResult> signInWithProvider(OAuthProvider provider) async {
    if (!isConfigured) {
      return const AuthOperationResult(
        errorMessage: 'Add Supabase dart defines before signing in.',
      );
    }

    try {
      await _client!.auth.signInWithOAuth(
        provider,
        redirectTo: AppConfig.redirectUri,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return const AuthOperationResult.success();
    } catch (error) {
      return AuthOperationResult(errorMessage: _cleanError(error));
    }
  }

  Future<AuthOperationResult> signOut() async {
    if (!isConfigured) return const AuthOperationResult.success();

    try {
      await _client!.auth.signOut();
      _session = null;
      notifyListeners();
      return const AuthOperationResult.success();
    } catch (error) {
      return AuthOperationResult(errorMessage: _cleanError(error));
    }
  }

  Future<AuthOperationResult> deleteAccount() async {
    if (!isConfigured || user == null) {
      return const AuthOperationResult(
        errorMessage: 'No authenticated account is available.',
      );
    }

    try {
      final response = await _client!.functions.invoke('delete-account');
      if (response.status < 200 || response.status >= 300) {
        return AuthOperationResult(
          errorMessage: 'Account deletion failed (${response.status}).',
        );
      }
      await _client.auth.signOut();
      _session = null;
      notifyListeners();
      return const AuthOperationResult.success();
    } catch (error) {
      return AuthOperationResult(errorMessage: _cleanError(error));
    }
  }

  Future<void> ensureProfile() async {
    final currentUser = user;
    if (!isConfigured || currentUser == null) return;

    try {
      await _client!.from('profiles').upsert(<String, dynamic>{
        'id': currentUser.id,
        'display_name': displayName,
        'avatar_url': currentUser.userMetadata?['avatar_url'],
      }, onConflict: 'id');
    } catch (_) {
      // Profile creation is best effort and must not block the app.
    }
  }

  void _handleAuthState(AuthState state) {
    _session = state.session;
    notifyListeners();
    if (_session != null) unawaited(ensureProfile());
  }

  static String _cleanError(Object error) {
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
