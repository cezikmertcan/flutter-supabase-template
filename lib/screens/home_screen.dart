import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/local_state_store.dart';
import '../services/remote_state_sync_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.auth,
    required this.localState,
    required this.sync,
    super.key,
  });

  final AuthService auth;
  final LocalStateStore localState;
  final RemoteStateSyncService sync;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Starter dashboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(auth: auth),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[auth, localState, sync]),
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: sync.syncNow,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: <Widget>[
                _buildIntro(context),
                const SizedBox(height: 16),
                _buildAuthCard(context),
                const SizedBox(height: 16),
                _buildLocalStateCard(context),
                const SizedBox(height: 16),
                _buildSyncCard(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.layers_outlined,
              color: theme.colorScheme.onPrimary,
              size: 30,
            ),
            const SizedBox(height: 18),
            Text(
              'Build the product layer here.',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A small, safe starting point for a Flutter app with Supabase Auth and local-first state.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = auth.isSignedIn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Authentication', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (signedIn) ...<Widget>[
              Text(
                auth.displayName ?? 'Authenticated user',
                style: theme.textTheme.titleMedium,
              ),
              if (auth.user?.email != null)
                Text(auth.user!.email!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _runAuthAction(context, auth.signOut()),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ] else ...<Widget>[
              Text(
                auth.isConfigured
                    ? 'Sign in to enable the example remote state sync.'
                    : 'Supabase is not configured; the local demo remains usable.',
                style: theme.textTheme.bodyMedium,
              ),
              if (auth.initializationError != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Initialization issue: ${auth.initializationError}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: auth.isConfigured
                          ? () => _runAuthAction(
                              context,
                              auth.signInWithProvider(OAuthProvider.google),
                            )
                          : null,
                      icon: const Icon(Icons.login),
                      label: const Text('Google'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: auth.isConfigured
                          ? () => _runAuthAction(
                              context,
                              auth.signInWithProvider(OAuthProvider.github),
                            )
                          : null,
                      icon: const Icon(Icons.code),
                      label: const Text('GitHub'),
                    ),
                  ),
                ],
              ),
              if (!auth.isConfigured) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Run with --dart-define-from-file=config/dart-defines.json after adding your project values.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocalStateCard(BuildContext context) {
    final theme = Theme.of(context);
    final countLabel = localState.actionCount == 1
        ? '1 action'
        : '${localState.actionCount} actions';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Local-first state', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'This sample value is stored on the device immediately and can sync after sign-in.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Text(countLabel, style: theme.textTheme.displaySmall),
            if (localState.lastActionAt != null)
              Text(
                'Last action: ${_formatDate(localState.lastActionAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: localState.recordAction,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Record local action'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context) {
    final theme = Theme.of(context);
    final status = !auth.isSignedIn
        ? 'Sign in to sync this state with Supabase.'
        : sync.isSyncing
        ? 'Syncing your state…'
        : sync.hasError
        ? 'Sync is unavailable; local state is still safe.'
        : sync.lastSyncedAt == null
        ? 'Ready to sync.'
        : 'Last synced ${_formatDate(sync.lastSyncedAt!.toIso8601String())}';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
        leading: Icon(
          sync.hasError ? Icons.cloud_off_outlined : Icons.cloud_queue_outlined,
          color: sync.hasError
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
        title: const Text('Remote state sync'),
        subtitle: Text(status),
        trailing: IconButton(
          tooltip: 'Sync now',
          onPressed: auth.isSignedIn && !sync.isSyncing
              ? () => unawaited(sync.syncNow())
              : null,
          icon: const Icon(Icons.sync),
        ),
      ),
    );
  }

  Future<void> _runAuthAction(
    BuildContext context,
    Future<AuthOperationResult> operation,
  ) async {
    final result = await operation;
    if (!context.mounted || result.isSuccess) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
  }

  static String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final iso = date.toIso8601String();
    return iso.substring(0, 16).replaceFirst('T', ' ');
  }
}
