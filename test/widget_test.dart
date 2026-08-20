import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flashcard_ai/main.dart';
import 'package:flashcard_ai/services/auth_service.dart';
import 'package:flashcard_ai/services/flashcard_ai_store.dart';
import 'package:flashcard_ai/services/local_state_store.dart';
import 'package:flashcard_ai/services/remote_state_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows a usable guided study studio', (tester) async {
    final localState = await LocalStateStore.load();
    final studyStore = await FlashCardAiStore.load();
    final auth = AuthService.unconfigured();
    final sync = RemoteStateSyncService(auth: auth, store: studyStore);
    addTearDown(sync.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FlashCardAiApp(
        auth: auth,
        localState: localState,
        studyStore: studyStore,
        sync: sync,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FLASHCARD AI'), findsOneWidget);
    expect(find.text('Öğrenme alanını kur.'), findsOneWidget);
    expect(find.text('Backend .NET dene'), findsOneWidget);
    expect(find.text('KPSS dene'), findsOneWidget);
  });

  testWidgets('deletes a conversation from the Library UI', (tester) async {
    final localState = await LocalStateStore.load();
    final studyStore = await FlashCardAiStore.load();
    await studyStore.submitPrompt('Silinecek UI konuşması');
    final auth = AuthService.unconfigured();
    final sync = RemoteStateSyncService(auth: auth, store: studyStore);
    addTearDown(sync.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FlashCardAiApp(
        auth: auth,
        localState: localState,
        studyStore: studyStore,
        sync: sync,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konuşmalar'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Konuşmayı sil'), findsOneWidget);
    await tester.tap(find.byTooltip('Konuşmayı sil'));
    await tester.pumpAndSettle();
    expect(find.text('Konuşma silinsin mi?'), findsOneWidget);

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(studyStore.conversations, isEmpty);
    expect(find.byTooltip('Konuşmayı sil'), findsNothing);
  });

  testWidgets('starts a new topic by focusing the composer', (tester) async {
    final localState = await LocalStateStore.load();
    final studyStore = await FlashCardAiStore.load();
    final auth = AuthService.unconfigured();
    final sync = RemoteStateSyncService(auth: auth, store: studyStore);
    addTearDown(sync.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FlashCardAiApp(
        auth: auth,
        localState: localState,
        studyStore: studyStore,
        sync: sync,
      ),
    );
    await tester.pumpAndSettle();

    final newTopicAction = find.text('Kendi konumu yazacağım');
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(newTopicAction);
    await tester.pumpAndSettle();

    expect(tester.binding.focusManager.primaryFocus, isNotNull);
    expect(studyStore.visibleMessages, hasLength(1));
  });

  testWidgets('header new conversation keeps the previous chat', (
    tester,
  ) async {
    final localState = await LocalStateStore.load();
    final studyStore = await FlashCardAiStore.load();
    await studyStore.submitPrompt('Korunacak eski sohbet');
    final oldConversationId = studyStore.currentConversationId;
    final auth = AuthService.unconfigured();
    final sync = RemoteStateSyncService(auth: auth, store: studyStore);
    addTearDown(sync.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FlashCardAiApp(
        auth: auth,
        localState: localState,
        studyStore: studyStore,
        sync: sync,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Yeni konuşma'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni konuşma başlat?'), findsOneWidget);
    await tester.tap(find.text('Yeni konuşma'));
    await tester.pumpAndSettle();

    expect(studyStore.currentConversationId, isNot(oldConversationId));
    expect(studyStore.topic, isNull);
    expect(studyStore.conversationById(oldConversationId), isNotNull);
    expect(tester.binding.focusManager.primaryFocus, isNotNull);
  });

  testWidgets('opens a conversation from the Library list', (tester) async {
    final localState = await LocalStateStore.load();
    final studyStore = await FlashCardAiStore.load();
    await studyStore.submitPrompt('Library detayına gireceğim konu');
    final auth = AuthService.unconfigured();
    final sync = RemoteStateSyncService(auth: auth, store: studyStore);
    addTearDown(sync.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FlashCardAiApp(
        auth: auth,
        localState: localState,
        studyStore: studyStore,
        sync: sync,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konuşmalar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library detayına gireceğim konu').first);
    await tester.pumpAndSettle();

    expect(find.text('Konuşma'), findsOneWidget);
    expect(find.text('Library detayına gireceğim konu'), findsWidgets);
    expect(find.byTooltip('Studio’da devam et'), findsOneWidget);
  });
}
