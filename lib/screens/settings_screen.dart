import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../services/flashcard_ai_store.dart';
import '../services/local_state_store.dart';
import '../services/remote_state_sync_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.auth,
    required this.localState,
    required this.studyStore,
    required this.sync,
    super.key,
  });

  final AuthService auth;
  final LocalStateStore localState;
  final FlashCardAiStore studyStore;
  final RemoteStateSyncService sync;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[auth, localState, sync]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: <Widget>[
            _buildHeader(context),
            const SizedBox(height: 22),
            _buildAccountCard(context),
            const SizedBox(height: 14),
            _buildPreferencesCard(context),
            const SizedBox(height: 14),
            _buildSyncCard(context),
            const SizedBox(height: 14),
            _buildAboutCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('SETTINGS', style: theme.textTheme.labelSmall),
        const SizedBox(height: 22),
        Text(
          'Çalışma alanını kontrol et.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Hesabın, senkronizasyonun ve yerel tercihlerin.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsCard(
      title: 'ACCOUNT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  auth.isSignedIn
                      ? Icons.person_outline
                      : Icons.person_off_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      auth.isSignedIn
                          ? auth.displayName ?? 'Signed-in learner'
                          : 'Local learner',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      auth.isSignedIn
                          ? auth.user?.email ?? 'Google account'
                          : 'İçerik cihazında çalışır',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (auth.isSignedIn)
            OutlinedButton.icon(
              onPressed: () => _runAuth(context, auth.signOut()),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Çıkış yap'),
            )
          else
            FilledButton.icon(
              onPressed: auth.isConfigured
                  ? () => _runAuth(context, auth.signInWithGoogle())
                  : null,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Google ile devam et'),
            ),
          if (!auth.isConfigured) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Supabase bağlantısı ayarlanmadığı için şu an local mode aktif.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsCard(
      title: 'PREFERENCES',
      child: Row(
        children: <Widget>[
          const Icon(Icons.dark_mode_outlined, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Görünüm', style: theme.textTheme.titleMedium),
                Text(
                  _themeLabel(localState.themeMode),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<ThemeMode>(
              value: localState.themeMode,
              onChanged: (value) {
                if (value != null) localState.setThemeMode(value);
              },
              items: const <DropdownMenuItem<ThemeMode>>[
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context) {
    final theme = Theme.of(context);
    final status = !auth.isSignedIn
        ? 'Hesap bağlayınca Library içeriğin hesabına senkronlanır.'
        : sync.isSyncing
        ? 'Senkronlanıyor…'
        : sync.hasError
        ? 'Senkronizasyon başarısız: ${sync.errorMessage ?? 'Tekrar dene.'}'
        : 'Hesabınla senkron hazır.';
    return _SettingsCard(
      title: 'CLOUD SYNC',
      child: Row(
        children: <Widget>[
          Icon(
            sync.hasError
                ? Icons.cloud_off_outlined
                : Icons.cloud_done_outlined,
            color: sync.hasError ? AppTheme.warning : AppTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(status, style: theme.textTheme.bodyMedium)),
          if (auth.isSignedIn)
            IconButton(
              tooltip: 'Şimdi senkronla',
              onPressed: sync.isSyncing ? null : () => _runSync(context),
              icon: const Icon(Icons.sync_rounded),
            ),
        ],
      ),
    );
  }

  Future<void> _runSync(BuildContext context) async {
    await sync.syncNow();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sync.hasError
              ? sync.errorMessage ?? 'Senkronizasyon başarısız.'
              : 'Senkronizasyon tamamlandı.',
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return _SettingsCard(
      title: 'FLASHCARD AI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Konu, kaynak ve hedeflerini konuşarak kişisel çalışma materyallerine dönüştür.',
          ),
          const SizedBox(height: 12),
          Text(
            '${studyStore.artifacts.length} library item · ${studyStore.messages.length} chat turns',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (auth.isSignedIn) ...<Widget>[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hesabı sil'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runAuth(
    BuildContext context,
    Future<AuthOperationResult> operation,
  ) async {
    final result = await operation;
    if (!context.mounted || result.isSuccess) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.errorMessage ?? 'Authentication failed.')),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabı sil?'),
        content: const Text(
          'Bu işlem hesabı ve hesabına bağlı cloud verisini kaldırır. Cihazındaki local kopya ayrıca durabilir.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await auth.deleteAccount();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Hesap silindi.'
              : result.errorMessage ?? 'Hesap silinemedi.',
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'Matrix dark',
      ThemeMode.light => 'Light',
      ThemeMode.system => 'Cihaz ayarı',
    };
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 15),
            child,
          ],
        ),
      ),
    );
  }
}
