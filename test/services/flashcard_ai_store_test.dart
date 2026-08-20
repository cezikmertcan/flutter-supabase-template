import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flashcard_ai/models/study_models.dart';
import 'package:flashcard_ai/services/auth_service.dart';
import 'package:flashcard_ai/services/flashcard_ai_store.dart';
import 'package:flashcard_ai/services/study_assistant_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('guides a topic into a saved flashcard artifact', () async {
    final store = await FlashCardAiStore.load();

    await store.submitPrompt('Backend .NET öğreniyorum');
    await store.chooseAction(
      const StudyAction(id: 'flashcards', label: 'Flashcard oluştur'),
    );
    await store.chooseAction(
      const StudyAction(id: 'suggest_topics', label: 'Konuları sen öner'),
    );
    await store.chooseAction(
      const StudyAction(id: 'count_100', label: '15 konu · 100 kart'),
    );
    await store.chooseAction(
      const StudyAction(id: 'cards_mixed', label: 'Karışık kartlar'),
    );

    expect(store.topic, 'Backend .NET öğreniyorum');
    expect(store.artifacts, hasLength(1));
    expect(store.artifacts.single.type, 'flashcards');
    expect(store.artifacts.single.cards, hasLength(100));
    expect(store.artifacts.single.cards.first.type, 'qa');
  });

  test('starts in dark-first local mode', () async {
    final store = await FlashCardAiStore.load();

    expect(store.messages, isNotEmpty);
    expect(store.messages.first.isAssistant, isTrue);
  });

  test(
    'does not create an artifact before learning intent is confirmed',
    () async {
      final store = await FlashCardAiStore.load();

      await store.submitPrompt('SQL öğrenmeye başlamak istiyorum');

      expect(store.artifacts, isEmpty);
      expect(store.phase, 'level_check');
      expect(
        store.messages.last.actions.map((action) => action.id),
        contains('level_beginner'),
      );
    },
  );

  test('keeps quick action selections out of visible chat bubbles', () async {
    final store = await FlashCardAiStore.load();

    await store.submitPrompt('GTA 5 yarın quizim var');
    await store.chooseAction(
      const StudyAction(id: 'level_beginner', label: 'Sıfırdan başlıyorum'),
    );

    expect(
      store.visibleMessages.any(
        (message) => message.text == 'Sıfırdan başlıyorum',
      ),
      isFalse,
    );
    expect(
      store.messages.any(
        (message) => message.text == 'Sıfırdan başlıyorum' && message.isAction,
      ),
      isTrue,
    );
  });

  test(
    'keeps the chat moving when the remote assistant is unavailable',
    () async {
      final auth = AuthService.unconfigured();
      final assistant = StudyAssistantService(auth: auth);
      final store = await FlashCardAiStore.load(assistant: assistant);
      addTearDown(auth.dispose);

      await store.submitPrompt('GTA 5 sınavına hazırlanıyorum');

      expect(store.visibleMessages.last.isAssistant, isTrue);
      expect(store.errorMessage, contains('Supabase'));

      final visibleCount = store.visibleMessages.length;
      await store.retryLastTurn();
      expect(store.visibleMessages.length, visibleCount);
    },
  );

  test('keeps the current conversation active when a new one starts', () async {
    final store = await FlashCardAiStore.load();

    await store.submitPrompt('Kavramsal çalışma notları');
    store.newConversation();

    expect(store.conversations, hasLength(1));
    expect(store.conversations.single.topic, 'Kavramsal çalışma notları');
    expect(store.conversations.single.messages, isNotEmpty);
    expect(store.conversations.single.isArchived, isFalse);
    expect(store.messages.first.isAssistant, isTrue);
  });

  test('opens a saved conversation with its original context', () async {
    final store = await FlashCardAiStore.load();

    await store.submitPrompt('Döngüler ve koleksiyonlar');
    final conversationId = store.currentConversationId;
    store.newConversation();

    store.openConversation(conversationId);

    expect(store.currentConversationId, conversationId);
    expect(store.topic, 'Döngüler ve koleksiyonlar');
    expect(store.visibleMessages.last.text, contains('Döngüler'));
  });

  test('hard deletes a conversation and its linked artifacts', () async {
    final store = await FlashCardAiStore.load();

    await store.submitPrompt('Silinecek konu');
    await store.chooseAction(
      const StudyAction(id: 'flashcards', label: 'Flashcard oluştur'),
    );
    await store.chooseAction(
      const StudyAction(id: 'count_50', label: '15 konu · 50 kart'),
    );
    await store.chooseAction(
      const StudyAction(id: 'cards_qa', label: 'Soru-cevap'),
    );
    final conversationId = store.currentConversationId;
    final artifactId = store.artifacts.single.id;

    store.deleteConversation(conversationId);

    expect(store.conversationById(conversationId), isNull);
    expect(
      store.artifacts.any((artifact) => artifact.id == artifactId),
      isFalse,
    );
    expect(store.messages, hasLength(1));
    expect(store.messages.first.isAssistant, isTrue);
    expect(jsonEncode(store.toPayload()), isNot(contains(conversationId)));
    expect(jsonEncode(store.toPayload()), isNot(contains(artifactId)));
  });

  test('keeps a started conversation in the active Library list', () async {
    final store = await FlashCardAiStore.load();

    await store.submitPrompt('Anayasa hukuku çalışıyorum');

    expect(store.conversations, hasLength(1));
    expect(store.conversations.single.isArchived, isFalse);
    expect(store.conversations.single.messages.last.text, contains('Anayasa'));
  });

  test(
    'can archive and restore a conversation without losing its messages',
    () async {
      final store = await FlashCardAiStore.load();
      await store.submitPrompt('Veri yapıları');
      final id = store.conversations.single.id;

      store.setConversationArchived(id, true);
      expect(store.conversations.single.isArchived, isTrue);
      store.setConversationArchived(id, false);
      expect(store.conversations.single.isArchived, isFalse);
      expect(store.conversations.single.messages, isNotEmpty);
    },
  );

  test(
    'links generated content to its chat and creates a revision family',
    () async {
      final store = await FlashCardAiStore.load();
      await store.submitPrompt('İngilizce kelime çalışıyorum');
      await store.chooseAction(
        const StudyAction(id: 'flashcards', label: 'Flashcard oluştur'),
      );
      await store.chooseAction(
        const StudyAction(id: 'count_50', label: '15 konu · 50 kart'),
      );
      await store.chooseAction(
        const StudyAction(id: 'cards_qa', label: 'Soru-cevap'),
      );

      final original = store.artifacts.single;
      expect(original.conversationId, store.currentConversationId);
      await store.reviseArtifact(original.id, 'Daha kısa açıklamalar ekle');

      expect(store.artifacts, hasLength(2));
      expect(store.artifacts.first.revisedFromArtifactId, original.id);
      expect(store.artifacts.first.revisionNumber, 2);
      expect(store.artifacts.first.revisionGroupId, original.id);
      expect(
        store.conversations.single.artifactIds,
        containsAll(<String>[original.id, store.artifacts.first.id]),
      );
    },
  );
}
