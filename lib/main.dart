import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/local_state_store.dart';
import 'services/remote_state_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localState = await LocalStateStore.load();
  final auth = await AuthService.initialize();
  final sync = RemoteStateSyncService(auth: auth, localState: localState)
    ..start();

  runApp(
    SupabaseFlutterTemplateApp(auth: auth, localState: localState, sync: sync),
  );
}

class SupabaseFlutterTemplateApp extends StatelessWidget {
  const SupabaseFlutterTemplateApp({
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
    return AnimatedBuilder(
      animation: localState,
      builder: (context, _) => MaterialApp(
        title: 'Supabase Flutter Template',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: localState.themeMode,
        home: HomeScreen(auth: auth, localState: localState, sync: sync),
      ),
    );
  }
}
