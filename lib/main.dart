import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';
import 'services/flashcard_ai_store.dart';
import 'services/local_state_store.dart';
import 'services/remote_state_sync_service.dart';
import 'services/study_assistant_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localState = await LocalStateStore.load();
  final auth = await AuthService.initialize();
  final assistant = StudyAssistantService(auth: auth);
  final studyStore = await FlashCardAiStore.load(assistant: assistant);
  final sync = RemoteStateSyncService(auth: auth, store: studyStore)..start();

  runApp(
    FlashCardAiApp(
      auth: auth,
      localState: localState,
      studyStore: studyStore,
      sync: sync,
    ),
  );
}

class FlashCardAiApp extends StatelessWidget {
  const FlashCardAiApp({
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
    return AnimatedBuilder(
      // Theme changes need to rebuild MaterialApp. Screen-level state is
      // observed by the individual screens so dialogs and scroll layers do
      // not get rebuilt from the application root.
      animation: localState,
      builder: (context, _) {
        return MaterialApp(
          title: 'FlashCard AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: localState.themeMode,
          home: AppShell(
            auth: auth,
            localState: localState,
            studyStore: studyStore,
            sync: sync,
          ),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
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
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        auth: widget.auth,
        studyStore: widget.studyStore,
        onOpenLibrary: () => setState(() => _selectedIndex = 1),
      ),
      LibraryScreen(
        studyStore: widget.studyStore,
        onResumeConversation: (conversationId) {
          widget.studyStore.openConversation(conversationId);
          setState(() => _selectedIndex = 0);
        },
      ),
      SettingsScreen(
        auth: widget.auth,
        localState: widget.localState,
        studyStore: widget.studyStore,
        sync: widget.sync,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) =>
            setState(() => _selectedIndex = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
