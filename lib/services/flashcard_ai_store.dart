import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_models.dart';
import 'study_assistant_service.dart';

class FlashCardAiStore extends ChangeNotifier {
  FlashCardAiStore._(this._preferences, {this.assistant}) {
    _conversationId = _id();
    _restore();
    if (_messages.isEmpty) _seedConversation();
    if (_messages.isNotEmpty && hasStarted) {
      _commit(notify: false);
    }
  }

  static const _stateKey = 'flashcard_ai_state_v1';

  final SharedPreferences _preferences;
  final StudyAssistantService? assistant;
  late String _conversationId;
  final List<StudyMessage> _messages = <StudyMessage>[];
  final List<StudyConversation> _conversations = <StudyConversation>[];
  final List<StudyArtifact> _artifacts = <StudyArtifact>[];
  String? _topic;
  String? _sourceText;
  String _phase = 'intake';
  String? _awaitingInput;
  bool _conversationArchived = false;
  bool _isProcessing = false;
  String? _errorMessage;
  int _pendingCardCount = 20;

  static Future<FlashCardAiStore> load({
    StudyAssistantService? assistant,
  }) async {
    return FlashCardAiStore._(
      await SharedPreferences.getInstance(),
      assistant: assistant,
    );
  }

  List<StudyMessage> get messages => List<StudyMessage>.unmodifiable(_messages);
  List<StudyMessage> get visibleMessages => List<StudyMessage>.unmodifiable(
    _messages.where((message) => !message.isAction),
  );
  List<StudyConversation> get conversations =>
      List<StudyConversation>.unmodifiable(_conversations);
  List<StudyArtifact> get artifacts =>
      List<StudyArtifact>.unmodifiable(_artifacts);
  String? get topic => _topic;
  String get phase => _phase;
  String get currentConversationId => _conversationId;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  bool get hasStarted => _messages.any((message) => message.role == 'user');
  bool get isAwaitingInput => _awaitingInput != null;
  String? get inputHint {
    return switch (_awaitingInput) {
      'topics' => 'Konuları virgülle ayırarak yaz…',
      'source' => 'Notlarını veya kaynak metnini yapıştır…',
      'count' => 'Kart sayısını yaz, örn. 75…',
      'quiz_count' => 'Soru sayısını yaz, örn. 20…',
      'custom' => 'Nasıl bir çalışma paketi istiyorsun?…',
      'lesson_answer' => 'Cevabını kendi cümlelerinle yaz…',
      'new_topic' => 'Yeni konunu yaz…',
      _ => null,
    };
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  StudyConversation? conversationById(String id) {
    for (final conversation in _conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  void deleteConversation(String id) {
    final conversation = conversationById(id);
    if (conversation == null) return;

    _errorMessage = null;

    final linkedArtifactIds = <String>{
      ...conversation.artifactIds,
      ..._artifacts
          .where((artifact) => artifact.conversationId == id)
          .map((artifact) => artifact.id),
    };
    _conversations.removeWhere((item) => item.id == id);
    _artifacts.removeWhere(
      (artifact) => linkedArtifactIds.contains(artifact.id),
    );

    if (id == _conversationId) {
      _messages.clear();
      _conversationId = _id();
      _topic = null;
      _sourceText = null;
      _phase = 'intake';
      _awaitingInput = null;
      _conversationArchived = false;
      _seedConversation();
    }
    _commit();
  }

  void setConversationArchived(String id, bool archived) {
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == id,
    );
    if (index == -1) return;
    if (id == _conversationId) _conversationArchived = archived;
    _conversations[index] = _conversations[index].copyWith(
      isArchived: archived,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void openConversation(String id) {
    final conversation = conversationById(id);
    if (conversation == null) return;

    _conversationId = conversation.id;
    _messages
      ..clear()
      ..addAll(conversation.messages);
    _topic = conversation.topic;
    _sourceText = conversation.sourceText;
    _phase =
        conversation.phase ??
        _messages
            .lastWhere(
              (message) => message.isAssistant && message.phase != null,
              orElse: () => _messages.isEmpty
                  ? StudyMessage(
                      id: '',
                      role: 'assistant',
                      text: '',
                      createdAt: DateTime.now(),
                    )
                  : _messages.last,
            )
            .phase ??
        'intake';
    _awaitingInput = null;
    _conversationArchived = conversation.isArchived;
    _errorMessage = null;
    _commit();
  }

  Future<void> submitPrompt(String rawPrompt) {
    if (rawPrompt.trim().isEmpty) return Future<void>.value();
    return _runBusy(() => _submitPromptInternal(rawPrompt));
  }

  Future<void> _submitPromptInternal(String rawPrompt) async {
    final prompt = rawPrompt.trim();
    _errorMessage = null;

    if (_awaitingInput != null) {
      _conversationArchived = false;
      final pendingInput = _awaitingInput;
      _awaitingInput = null;
      if (pendingInput == 'new_topic') {
        _topic = prompt;
        _phase = 'intake';
      }
      _addUserMessage(prompt);
      _commit();
      if (await _tryRemoteTurn()) return;
      if (assistant != null) {
        _addRemoteFailure();
        if (_requiresRemoteArtifactInput(pendingInput)) return;
      }
      _handleFreeFormInput(prompt, mode: pendingInput, userAlreadyAdded: true);
      _commit();
      return;
    }

    _conversationArchived = false;
    _removeWelcomeMessage();
    _topic = prompt;
    _addUserMessage(prompt);
    _commit();
    if (await _tryRemoteTurn()) return;
    if (assistant != null) _addRemoteFailure();
    _phase = 'level_check';
    _addAssistantMessage(
      'Süper. “${_shortTopic(prompt)}” için önce seviyeni anlayalım; sonra kısa bir ders ve kontrol sorusuyla ilerleyeceğiz. Bu konuda kendini nasıl görüyorsun?',
      actions: const <StudyAction>[
        StudyAction(
          id: 'level_beginner',
          label: 'Sıfırdan başlıyorum',
          description: 'Temel kavramları ve örnekleri önce öğrenmek istiyorum',
        ),
        StudyAction(
          id: 'level_intermediate',
          label: 'Temelleri biliyorum',
          description: 'Eksiklerimi kapatıp uygulama yapmak istiyorum',
        ),
        StudyAction(
          id: 'level_advanced',
          label: 'İleri seviyedeyim',
          description: 'Zor sorular ve sınav/uygulama odaklı ilerleyelim',
        ),
      ],
      phase: _phase,
    );
    _commit();
  }

  Future<void> chooseAction(StudyAction action) {
    return _runBusy(() => _chooseActionInternal(action));
  }

  Future<void> _chooseActionInternal(StudyAction action) async {
    _errorMessage = null;
    _conversationArchived = false;
    _removeWelcomeMessage();
    if (action.id == 'retry_ai') {
      await _retryLastTurnInternal();
      return;
    }
    _addUserMessage(action.label, isAction: true);
    _commit();
    if (await _tryRemoteTurn()) return;
    if (assistant != null) {
      _addRemoteFailure();
      if (_requiresRemoteArtifactAction(action.id)) return;
    }

    switch (action.id) {
      case 'level_beginner':
      case 'level_intermediate':
      case 'level_advanced':
        _phase = 'lesson';
        _addAssistantMessage(
          'Seviyeni not ettim. Önce konunun temel çerçevesini anlatacağım; ardından tek bir kontrol sorusuyla nerede olduğunu göreceğiz.',
          actions: const <StudyAction>[
            StudyAction(id: 'continue_lesson', label: 'Kısa derse başla'),
            StudyAction(id: 'new_topic', label: 'Konuyu değiştir'),
          ],
          phase: _phase,
        );
      case 'continue_lesson':
        _phase = 'checkpoint';
        _addAssistantMessage(
          'Bu bölümde önce temel kavramı netleştiriyoruz. Şimdi kendi cümlelerinle bir örnek vermeyi dene; cevabına göre bir sonraki açıklamayı ayarlayacağım.',
          actions: const <StudyAction>[
            StudyAction(id: 'continue_practice', label: 'Cevabımı yazacağım'),
          ],
          phase: _phase,
        );
      case 'continue_practice':
        _awaitingInput = 'lesson_answer';
        _phase = 'checkpoint';
        _addAssistantMessage(
          'Cevabını mesaj alanına yaz. Doğru ya da eksik olması sorun değil; birlikte düzelteceğiz.',
          phase: _phase,
        );
      case 'flashcards':
        _addAssistantMessage(
          'Kart setini birkaç seçimle netleştirelim. Konuları ben önerebilirim veya kaynağını temel alabilirim.',
          actions: const <StudyAction>[
            StudyAction(id: 'suggest_topics', label: 'Konuları sen öner'),
            StudyAction(id: 'choose_topics', label: 'Konuları ben seçeyim'),
            StudyAction(id: 'from_source', label: 'Not/PDF metninden oluştur'),
            StudyAction(id: 'custom_cards', label: 'Özel ayar yazacağım'),
            StudyAction(id: 'new_topic', label: 'Geri dön'),
          ],
        );
      case 'example_backend':
        _topic = 'Backend .NET öğreniyorum';
        _addAssistantMessage(
          '“Backend .NET öğreniyorum” iyi bir başlangıç. Ne üretelim?',
          actions: const <StudyAction>[
            StudyAction(id: 'flashcards', label: 'Flashcard oluştur'),
            StudyAction(id: 'quiz', label: 'Test hazırla'),
            StudyAction(id: 'topic_map', label: 'Konu haritası çıkar'),
          ],
        );
      case 'example_exam':
        _topic = 'KPSS’ye hazırlanıyorum';
        _addAssistantMessage(
          '“KPSS’ye hazırlanıyorum” için bir çalışma akışı kuralım. Ne üretelim?',
          actions: const <StudyAction>[
            StudyAction(id: 'flashcards', label: 'Flashcard oluştur'),
            StudyAction(id: 'quiz', label: 'Test hazırla'),
            StudyAction(id: 'study_plan', label: 'Çalışma planı oluştur'),
          ],
        );
      case 'suggest_topics':
        _addAssistantMessage(
          'Kaç kartlık bir ilk set istersin? İstersen önce 15 başlık önerip her başlığa dengeli kart dağıtabilirim.',
          actions: const <StudyAction>[
            StudyAction(id: 'count_50', label: '15 konu · 50 kart'),
            StudyAction(id: 'count_100', label: '15 konu · 100 kart'),
            StudyAction(id: 'custom_count', label: 'Özel sayı'),
            StudyAction(id: 'back_to_flashcards', label: 'Geri dön'),
          ],
        );
      case 'choose_topics':
        _awaitingInput = 'topics';
        _addAssistantMessage(
          'Tamam. Çalışmak istediğin başlıkları virgülle ayırarak yaz. Sonra kart sayısını ve tipini seçeriz.',
          actions: const <StudyAction>[
            StudyAction(
              id: 'suggest_topics',
              label: 'Vazgeç · konuları sen öner',
            ),
            StudyAction(id: 'cancel_input', label: 'İptal et'),
          ],
        );
      case 'from_source':
        _awaitingInput = 'source';
        _addAssistantMessage(
          'Kaynak metnini buraya yapıştırabilirsin. PDF yükleme akışını da aynı kaynak adımına bağlayacağız; şimdilik metinle başlayalım.',
          actions: const <StudyAction>[
            StudyAction(id: 'cancel_input', label: 'İptal et'),
          ],
        );
      case 'custom_cards':
        _awaitingInput = 'custom';
        _addAssistantMessage(
          'Nasıl bir set istediğini yazabilirsin. Örneğin: “80 adet, mülakat odaklı, cevap açıklamalı ve zor seviye.”',
          actions: const <StudyAction>[
            StudyAction(id: 'cancel_input', label: 'İptal et'),
          ],
        );
      case 'count_50':
        _pendingCardCount = 50;
        _askCardType();
      case 'count_100':
        _pendingCardCount = 100;
        _askCardType();
      case 'custom_count':
        _awaitingInput = 'count';
        _addAssistantMessage(
          'Kaç kart istediğini yaz. Sonraki adımda kart tipini seçebilirsin.',
          actions: const <StudyAction>[
            StudyAction(id: 'cancel_input', label: 'İptal et'),
          ],
        );
      case 'cards_mixed':
        _createFlashcardArtifact('mixed');
      case 'cards_qa':
        _createFlashcardArtifact('qa');
      case 'cards_mcq':
        _createFlashcardArtifact('multiple_choice');
      case 'cards_true_false':
        _createFlashcardArtifact('true_false');
      case 'quiz':
        _addAssistantMessage(
          'Testi nasıl kuralım?',
          actions: const <StudyAction>[
            StudyAction(id: 'quiz_10', label: '10 soru'),
            StudyAction(id: 'quiz_25', label: '25 soru'),
            StudyAction(id: 'quiz_custom', label: 'Özel sayı'),
            StudyAction(id: 'new_topic', label: 'Geri dön'),
          ],
        );
      case 'quiz_10':
        _createQuizArtifact(10);
      case 'quiz_25':
        _createQuizArtifact(25);
      case 'quiz_custom':
        _awaitingInput = 'quiz_count';
        _addAssistantMessage(
          'Kaç soruluk bir test istiyorsun?',
          actions: const <StudyAction>[
            StudyAction(id: 'cancel_input', label: 'İptal et'),
          ],
        );
      case 'topic_map':
        _createTopicMapArtifact();
      case 'study_plan':
        _createStudyPlanArtifact();
      case 'suggest_15_topics':
        _awaitingInput = null;
        _pendingCardCount = 50;
        _addAssistantMessage(
          '15 başlık önereceğim. İlk deneme için kaç kartlık bir set hazırlayayım?',
          actions: const <StudyAction>[
            StudyAction(id: 'count_50', label: '50 kart'),
            StudyAction(id: 'count_100', label: '100 kart'),
            StudyAction(id: 'custom_count', label: 'Özel sayı'),
          ],
        );
      case 'back_to_flashcards':
        _showFlashcardOptions();
      case 'new_topic':
        _awaitingInput = 'new_topic';
        _phase = 'intake';
        _addAssistantMessage(
          'Yeni konunu yaz, önce hedefini ve seviyeni birlikte netleştirelim.',
          phase: _phase,
        );
      case 'open_artifact':
        _addAssistantMessage(
          'İçeriği Library’ye kaydettim. Oradan kartları tek tek açıp çalışabilirsin.',
          actions: const <StudyAction>[
            StudyAction(id: 'library', label: 'Library’yi aç'),
            StudyAction(id: 'new_topic', label: 'Yeni içerik'),
          ],
        );
      case 'library':
        _addAssistantMessage(
          'Tüm içeriklerin Library sekmesinde. Bir set seçtiğinde kaldığın yerden devam edebilirsin.',
        );
      case 'cancel_input':
        _awaitingInput = null;
        _addAssistantMessage(
          'İptal edildi. Başka bir içerik türü seçebilirsin.',
          actions: const <StudyAction>[
            StudyAction(id: 'flashcards', label: 'Flashcard oluştur'),
            StudyAction(id: 'quiz', label: 'Test hazırla'),
            StudyAction(id: 'new_topic', label: 'Yeni konu'),
          ],
        );
      default:
        _addAssistantMessage('Bu seçenek için akışı birazdan genişleteceğiz.');
    }

    _commit();
  }

  static bool _requiresRemoteArtifactAction(String id) {
    return switch (id) {
      'cards_mixed' ||
      'cards_qa' ||
      'cards_mcq' ||
      'cards_true_false' ||
      'quiz_10' ||
      'quiz_25' ||
      'topic_map' ||
      'study_plan' => true,
      _ => false,
    };
  }

  static bool _requiresRemoteArtifactInput(String? mode) {
    return mode == 'quiz_count';
  }

  void markCard(String artifactId, String cardId, bool mastered) {
    final artifactIndex = _artifacts.indexWhere(
      (item) => item.id == artifactId,
    );
    if (artifactIndex == -1) return;
    final cardIndex = _artifacts[artifactIndex].cards.indexWhere(
      (item) => item.id == cardId,
    );
    if (cardIndex == -1) return;
    _artifacts[artifactIndex].cards[cardIndex].mastered = mastered;
    _commit();
  }

  Future<void> reviseArtifact(String artifactId, String rawInstruction) {
    if (rawInstruction.trim().isEmpty) return Future<void>.value();
    return _runBusy(() => _reviseArtifactInternal(artifactId, rawInstruction));
  }

  Future<void> _reviseArtifactInternal(
    String artifactId,
    String rawInstruction,
  ) async {
    final instruction = rawInstruction.trim();
    final artifactIndex = _artifacts.indexWhere(
      (artifact) => artifact.id == artifactId,
    );
    if (artifactIndex == -1) return;

    final original = _artifacts[artifactIndex];
    _conversationArchived = false;
    _topic = original.topic;
    _addUserMessage('Revizyon isteği: $instruction');
    _commit();
    if (await _tryRemoteTurn(revisionOf: original)) return;
    if (assistant != null) {
      _addRemoteFailure();
      return;
    }

    final revisionNumber = _nextRevisionNumber(original);
    final revisionId = _id();
    final revision = original.copyWith(
      id: revisionId,
      title: '${original.title} · Revizyon $revisionNumber',
      summary: '${original.summary} · Revizyon: $instruction',
      createdAt: DateTime.now(),
      cards: original.cards.map((card) => card.copyWith(id: _id())).toList(),
      tags: <String>[...original.tags, 'revision-$revisionNumber'],
      conversationId: original.conversationId ?? _conversationId,
      revisionGroupId: original.revisionGroupId ?? original.id,
      revisionNumber: revisionNumber,
      revisedFromArtifactId: original.id,
    );
    _artifacts.insert(0, revision);
    _addAssistantMessage(
      'Aynı içeriğin $revisionNumber. revizyonunu hazırladım. İstersen bu sürüm üzerinden tekrar düzenleyebiliriz.',
      actions: const <StudyAction>[
        StudyAction(id: 'open_artifact', label: 'Revizyonu aç'),
        StudyAction(id: 'library', label: 'Library’ye git'),
      ],
    );
    _commit();
  }

  Future<bool> _tryRemoteTurn({StudyArtifact? revisionOf}) async {
    final service = assistant;
    if (service == null) return false;
    final remote = await service.createTurn(
      messages: _messages,
      topic: _topic,
      sourceText: _sourceText,
      phase: _phase,
    );
    if (remote == null) return false;
    _errorMessage = null;
    _phase = remote.phase ?? _phase;
    if (remote.shouldPersistArtifact && remote.artifact != null) {
      final artifact = remote.artifact!;
      final revisionNumber = revisionOf == null
          ? artifact.revisionNumber
          : _nextRevisionNumber(revisionOf);
      _artifacts.insert(
        0,
        artifact.copyWith(
          conversationId: revisionOf?.conversationId ?? _conversationId,
          revisionGroupId: revisionOf?.revisionGroupId ?? revisionOf?.id,
          revisionNumber: revisionNumber,
          revisedFromArtifactId: revisionOf?.id,
        ),
      );
    }
    _addAssistantMessage(
      remote.message,
      actions: remote.actions,
      phase: remote.phase,
      lesson: remote.lesson,
      checkpoint: remote.checkpoint,
      feedback: remote.feedback,
      shouldAskFollowUp: remote.shouldAskFollowUp,
    );
    _commit();
    return true;
  }

  Future<void> retryLastTurn() {
    return _runBusy(_retryLastTurnInternal);
  }

  Future<void> _retryLastTurnInternal() async {
    _errorMessage = null;
    if (!_messages.any((message) => message.role == 'user')) {
      if (assistant != null) _addRemoteFailure();
      return;
    }
    if (await _tryRemoteTurn()) return;
    if (assistant != null) {
      _addRemoteFailure();
      _addLocalFallbackForLastTurn();
      _commit();
    }
  }

  void _addLocalFallbackForLastTurn() {
    if (_messages.isNotEmpty && _messages.last.isAssistant) return;

    final userMessageCount = _messages
        .where((message) => message.role == 'user' && !message.isAction)
        .length;
    if (userMessageCount <= 1) {
      _phase = 'level_check';
      _addAssistantMessage(
        'Mesajını aldım. AI servisine şu an ulaşılamadığı için akışı yerel olarak sürdürüyorum; önce seviyeni seçelim, bağlantı düzeldiğinde dersi burada zenginleştirebiliriz.',
        actions: const <StudyAction>[
          StudyAction(id: 'level_beginner', label: 'Sıfırdan başlıyorum'),
          StudyAction(id: 'level_intermediate', label: 'Temelleri biliyorum'),
          StudyAction(id: 'level_advanced', label: 'İleri seviyedeyim'),
        ],
        phase: _phase,
      );
      return;
    }

    _addAssistantMessage(
      'Mesajını korudum. AI bağlantısı düzelince aynı adımdan devam edebilirsin; istersen şimdi cevabını biraz daha açarak tekrar gönder.',
      actions: const <StudyAction>[
        StudyAction(id: 'retry_ai', label: 'Tekrar dene'),
        StudyAction(id: 'new_topic', label: 'Yeni konu'),
      ],
      phase: _phase,
    );
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void newConversation() {
    _saveCurrentConversation();
    _messages.clear();
    _conversationId = _id();
    _topic = null;
    _sourceText = null;
    _phase = 'intake';
    _awaitingInput = null;
    _conversationArchived = false;
    _errorMessage = null;
    _seedConversation();
    _commit();
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'version': 1,
    'currentConversationId': _conversationId,
    'currentConversationArchived': _conversationArchived,
    'topic': _topic,
    'sourceText': _sourceText,
    'phase': _phase,
    'messages': _messages.map((item) => item.toJson()).toList(),
    'conversations': _conversations.map((item) => item.toJson()).toList(),
    'artifacts': _artifacts.map((item) => item.toJson()).toList(),
  };

  void mergeRemote(Map<String, dynamic> payload) {
    final rawMessages = payload['messages'];
    final rawArtifacts = payload['artifacts'];
    if (rawMessages is List) {
      _messages
        ..clear()
        ..addAll(
          rawMessages.whereType<Map>().map(
            (item) => StudyMessage.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
    }
    final rawConversations = payload['conversations'];
    if (rawConversations is List) {
      _conversations
        ..clear()
        ..addAll(
          rawConversations.whereType<Map>().map(
            (item) =>
                StudyConversation.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
    }
    if (rawArtifacts is List) {
      _artifacts
        ..clear()
        ..addAll(
          rawArtifacts.whereType<Map>().map(
            (item) => StudyArtifact.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
    }
    _conversationId =
        payload['currentConversationId'] as String? ?? _conversationId;
    _conversationArchived =
        payload['currentConversationArchived'] as bool? ?? false;
    _topic = payload['topic'] as String?;
    _sourceText = payload['sourceText'] as String?;
    _phase = payload['phase'] as String? ?? _phase;
    _normalizeLegacyMessages();
    _restorePendingError();
    _removeWelcomeMessage();
    _linkLegacyArtifacts();
    final current = conversationById(_conversationId);
    if (current != null) _conversationArchived = current.isArchived;
    if (_messages.isEmpty) _seedConversation();
    _commit(notify: true);
  }

  void _handleFreeFormInput(
    String input, {
    String? mode,
    bool userAlreadyAdded = false,
  }) {
    mode ??= _awaitingInput;
    _awaitingInput = null;
    if (!userAlreadyAdded) _addUserMessage(input);

    switch (mode) {
      case 'topics':
        _topic = input;
        _addAssistantMessage(
          'Başlıklarını aldım. Bu başlıklardan dengeli bir set hazırlayabiliriz.',
          actions: const <StudyAction>[
            StudyAction(id: 'count_50', label: '50 kart'),
            StudyAction(id: 'count_100', label: '100 kart'),
            StudyAction(id: 'custom_count', label: 'Özel sayı'),
          ],
        );
      case 'source':
        _sourceText = input;
        _topic ??= _shortTopic(input);
        _addAssistantMessage(
          'Kaynağı çalışma bağlamına aldım. Önce kart mı, test mi üretelim?',
          actions: const <StudyAction>[
            StudyAction(id: 'count_50', label: 'Kart seti oluştur'),
            StudyAction(id: 'quiz_10', label: '10 soruluk test'),
          ],
        );
      case 'count':
        _pendingCardCount = _parseCount(input);
        _addAssistantMessage(
          '$_pendingCardCount kartlık set hazır. Kart biçimini seçelim.',
          actions: const <StudyAction>[
            StudyAction(id: 'cards_mixed', label: 'Karışık'),
            StudyAction(id: 'cards_qa', label: 'Soru-cevap'),
            StudyAction(id: 'cards_mcq', label: 'Çoktan seçmeli'),
            StudyAction(id: 'cards_true_false', label: 'Doğru / yanlış'),
          ],
        );
      case 'quiz_count':
        _createQuizArtifact(_parseCount(input).clamp(5, 100).toInt());
      case 'custom':
        _pendingCardCount = _parseCount(input, fallback: 20);
        _addAssistantMessage(
          'İsteğini aldım. $_pendingCardCount kartlık karışık bir ilk taslak hazırlayabilirim.',
          actions: const <StudyAction>[
            StudyAction(id: 'cards_mixed', label: 'Taslağı oluştur'),
            StudyAction(id: 'cancel_input', label: 'Vazgeç'),
          ],
        );
      case 'new_topic':
        _topic = input;
        _phase = 'level_check';
        _addAssistantMessage(
          'Konuyu aldım. Önce seviyeni ve hedefini netleştirelim; sonra kısa bir dersle başlayacağım.',
          actions: const <StudyAction>[
            StudyAction(
              id: 'level_beginner',
              label: 'Sıfırdan başlıyorum',
              description: 'Temel kavramları adım adım öğrenmek istiyorum',
            ),
            StudyAction(
              id: 'level_intermediate',
              label: 'Temelleri biliyorum',
              description: 'Eksiklerimi kapatıp uygulama yapmak istiyorum',
            ),
            StudyAction(
              id: 'level_advanced',
              label: 'İleri seviyedeyim',
              description: 'Zor sorular ve sınav/uygulama odaklı ilerleyelim',
            ),
          ],
          phase: _phase,
        );
      case 'lesson_answer':
        _phase = 'feedback';
        _addAssistantMessage(
          'Cevabını değerlendirdim. Ana fikri büyük ölçüde yakaladın; şimdi bunu yeni bir örnek üzerinde birlikte uygulayalım.',
          actions: const <StudyAction>[
            StudyAction(id: 'continue_practice', label: 'Bir örnek daha çöz'),
            StudyAction(
              id: 'flashcards',
              label: 'Daha sonra kart seti hazırla',
            ),
          ],
          phase: _phase,
        );
      default:
        _topic ??= input;
        _addAssistantMessage('Bunu çalışma bağlamına ekledim.');
    }
  }

  void _askCardType() {
    _addAssistantMessage(
      'Kartların biçimi nasıl olsun?',
      actions: const <StudyAction>[
        StudyAction(id: 'cards_mixed', label: 'Karışık kartlar'),
        StudyAction(id: 'cards_qa', label: 'Soru-cevap'),
        StudyAction(id: 'cards_mcq', label: 'Çoktan seçmeli'),
        StudyAction(id: 'cards_true_false', label: 'Doğru / yanlış'),
        StudyAction(id: 'back_to_flashcards', label: 'Geri dön'),
      ],
    );
  }

  void _showFlashcardOptions() {
    _addAssistantMessage(
      'Flashcard setini nasıl oluşturalım?',
      actions: const <StudyAction>[
        StudyAction(id: 'suggest_topics', label: 'Konuları sen öner'),
        StudyAction(id: 'choose_topics', label: 'Konuları ben seçeyim'),
        StudyAction(id: 'from_source', label: 'Not/PDF metninden oluştur'),
        StudyAction(id: 'custom_cards', label: 'Özel ayar'),
      ],
    );
  }

  void _createFlashcardArtifact(String type) {
    final topic = _topic ?? 'Yeni çalışma konusu';
    final count = _pendingCardCount.clamp(5, 100).toInt();
    final artifact = StudyArtifact(
      id: _id(),
      type: 'flashcards',
      title: '${_shortTopic(topic)} · ${_typeLabel(type)}',
      topic: topic,
      summary: '$count kartlık kişisel tekrar seti',
      createdAt: DateTime.now(),
      tags: <String>['flashcards', type],
      conversationId: _conversationId,
      cards: _buildCards(topic, count, type),
    );
    _artifacts.insert(0, artifact);
    _addAssistantMessage(
      'İlk taslağı hazırladım ve Library’ye kaydettim. İstersen şimdi çalışmaya başlayabilir veya seti daha sonra açabilirsin.',
      actions: const <StudyAction>[
        StudyAction(id: 'open_artifact', label: 'İçeriği aç'),
        StudyAction(id: 'library', label: 'Library’ye git'),
        StudyAction(id: 'new_topic', label: 'Yeni içerik'),
      ],
    );
  }

  void _createQuizArtifact(int count) {
    final topic = _topic ?? 'Yeni çalışma konusu';
    final artifact = StudyArtifact(
      id: _id(),
      type: 'quiz',
      title: '${_shortTopic(topic)} · Test',
      topic: topic,
      summary: '$count soruluk karışık test',
      createdAt: DateTime.now(),
      tags: const <String>['quiz', 'practice'],
      conversationId: _conversationId,
      cards: _buildCards(topic, count.clamp(5, 100).toInt(), 'multiple_choice'),
    );
    _artifacts.insert(0, artifact);
    _addAssistantMessage(
      'Test taslağı hazır ve Library’ye kaydedildi. Sonuç ekranında yanlışlardan yeni kartlar üreteceğiz.',
      actions: const <StudyAction>[
        StudyAction(id: 'open_artifact', label: 'Teste git'),
        StudyAction(id: 'library', label: 'Library’ye git'),
        StudyAction(id: 'new_topic', label: 'Yeni içerik'),
      ],
    );
  }

  void _createTopicMapArtifact() {
    final topic = _topic ?? 'Yeni çalışma konusu';
    _artifacts.insert(
      0,
      StudyArtifact(
        id: _id(),
        type: 'topic_map',
        title: '${_shortTopic(topic)} · Konu haritası',
        topic: topic,
        summary: 'Temel kavramlardan uygulamaya uzanan başlangıç rotası',
        createdAt: DateTime.now(),
        tags: const <String>['map', 'outline'],
        conversationId: _conversationId,
        cards: _buildCards(topic, 8, 'qa'),
      ),
    );
    _addAssistantMessage(
      'Konu haritasını Library’ye kaydettim. Bu haritadan daha sonra kart veya test üretebiliriz.',
      actions: const <StudyAction>[
        StudyAction(id: 'library', label: 'Konu haritasını aç'),
        StudyAction(id: 'flashcards', label: 'Bu konudan kart üret'),
      ],
    );
  }

  void _createStudyPlanArtifact() {
    final topic = _topic ?? 'Yeni çalışma konusu';
    _artifacts.insert(
      0,
      StudyArtifact(
        id: _id(),
        type: 'study_plan',
        title: '${_shortTopic(topic)} · Çalışma planı',
        topic: topic,
        summary: 'Kısa, ölçülebilir ve tekrar odaklı çalışma rotası',
        createdAt: DateTime.now(),
        tags: const <String>['plan'],
        conversationId: _conversationId,
        cards: _buildCards(topic, 5, 'qa'),
      ),
    );
    _addAssistantMessage(
      'Çalışma planını Library’ye ekledim. Her gün için kart ve test adımı ekleyebiliriz.',
      actions: const <StudyAction>[
        StudyAction(id: 'library', label: 'Planı aç'),
        StudyAction(id: 'flashcards', label: 'İlk kart setini oluştur'),
      ],
    );
  }

  List<StudyCard> _buildCards(String topic, int count, String type) {
    final cards = <StudyCard>[];
    final topicName = _shortTopic(topic);
    for (var index = 0; index < count; index++) {
      final number = index + 1;
      final cardType = type == 'mixed'
          ? <String>['qa', 'multiple_choice', 'true_false'][index % 3]
          : type;
      final prompt = switch (cardType) {
        'multiple_choice' =>
          '$topicName · Soru $number: Bu başlıkta önce hangi kavramı netleştirmek gerekir?',
        'true_false' =>
          '$topicName · Soru $number: Bu ifadeyi doğru veya yanlış olarak değerlendir.',
        _ =>
          '$topicName · Kart $number: Bu konuyu kendi cümlelerinle nasıl açıklarsın?',
      };
      cards.add(
        StudyCard(
          id: _id(),
          type: cardType,
          prompt: prompt,
          answer:
              'Bu kart, seçtiğin kaynak ve hedef doğrultusunda AI tarafından doldurulacak kişisel cevap alanıdır.',
          options: cardType == 'multiple_choice'
              ? const <String>[
                  'Temel kavram',
                  'İleri örnek',
                  'İlgisiz detay',
                  'Hepsi',
                ]
              : const <String>[],
          explanation:
              'Cevabı kaynağınla karşılaştır, gerekirse kartı düzenle ve tekrar kuyruğuna al.',
        ),
      );
    }
    return cards;
  }

  void _seedConversation() {
    _phase = 'intake';
    _addAssistantMessage(
      'Merhaba, ben FlashCard AI. Bir konu, hedef veya belge yaz; sana adım adım çalışma materyali hazırlayayım.',
      actions: const <StudyAction>[
        StudyAction(id: 'example_backend', label: 'Backend .NET dene'),
        StudyAction(id: 'example_exam', label: 'KPSS dene'),
        StudyAction(id: 'new_topic', label: 'Kendi konumu yazacağım'),
      ],
      phase: _phase,
    );
  }

  void _addRemoteFailure() {
    _errorMessage =
        assistant?.lastError ??
        'AI yanıtı alınamadı. Mesajın korunuyor; tekrar deneyebilirsin.';
    notifyListeners();
  }

  void _addUserMessage(String text, {bool isAction = false}) {
    _messages.add(
      StudyMessage(
        id: _id(),
        role: 'user',
        text: text,
        createdAt: DateTime.now(),
        isAction: isAction,
      ),
    );
  }

  void _addAssistantMessage(
    String text, {
    List<StudyAction> actions = const <StudyAction>[],
    String? phase,
    StudyLesson? lesson,
    StudyCheckpoint? checkpoint,
    String? feedback,
    bool shouldAskFollowUp = false,
  }) {
    _messages.add(
      StudyMessage(
        id: _id(),
        role: 'assistant',
        text: text,
        createdAt: DateTime.now(),
        actions: actions,
        phase: phase ?? _phase,
        lesson: lesson,
        checkpoint: checkpoint,
        feedback: feedback,
        shouldAskFollowUp: shouldAskFollowUp,
      ),
    );
  }

  void _restore() {
    final raw = _preferences.getString(_stateKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final payload = Map<String, dynamic>.from(decoded);
        final messages = payload['messages'];
        final conversations = payload['conversations'];
        final artifacts = payload['artifacts'];
        _conversationId =
            payload['currentConversationId'] as String? ?? _conversationId;
        _conversationArchived =
            payload['currentConversationArchived'] as bool? ?? false;
        _sourceText = payload['sourceText'] as String?;
        _phase = payload['phase'] as String? ?? _phase;
        if (messages is List) {
          _messages.addAll(
            messages.whereType<Map>().map(
              (item) => StudyMessage.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
        if (conversations is List) {
          _conversations.addAll(
            conversations.whereType<Map>().map(
              (item) =>
                  StudyConversation.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
        if (artifacts is List) {
          _artifacts.addAll(
            artifacts.whereType<Map>().map(
              (item) => StudyArtifact.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
        _topic = payload['topic'] as String?;
        _normalizeLegacyMessages();
        _restorePendingError();
        _removeWelcomeMessage();
        final current = conversationById(_conversationId);
        if (current != null) _conversationArchived = current.isArchived;
        _linkLegacyArtifacts();
      }
    } catch (_) {
      _messages.clear();
      _artifacts.clear();
    }
  }

  void _saveCurrentConversation() {
    final hasUserMessage = _messages.any((message) => message.role == 'user');
    if (!hasUserMessage) return;
    _upsertCurrentConversation();
  }

  void _normalizeLegacyMessages() {
    const legacyActionLabels = <String>{
      'Kendi konumu yazacağım',
      'Tekrar dene',
      'Flashcard oluştur',
      'Test hazırla',
      'Konu haritası çıkar',
      'Çalışma planı oluştur',
      'Sıfırdan başlıyorum',
      'Temelleri biliyorum',
      'İleri seviyedeyim',
      'Kısa derse başla',
      'Cevabımı yazacağım',
      'Yeni konu',
      'Yeni içerik',
    };
    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      if (message.role == 'user' &&
          legacyActionLabels.contains(message.text.trim()) &&
          !message.isAction) {
        _messages[index] = message.copyWith(isAction: true);
      }
    }
    _messages.removeWhere(
      (message) =>
          message.isAssistant &&
          message.text.startsWith('AI öğretmen yanıtını alamadım.'),
    );
  }

  void _restorePendingError() {
    final lastMessage = _messages.isEmpty ? null : _messages.last;
    if (lastMessage?.role == 'user') {
      _errorMessage =
          'Bu mesaj için AI yanıtı alınamadı. Mesajın korunuyor; tekrar deneyebilirsin.';
    }
  }

  void _commit({bool notify = true}) {
    _upsertCurrentConversation();
    unawaited(_preferences.setString(_stateKey, jsonEncode(toPayload())));
    if (notify) notifyListeners();
  }

  void _upsertCurrentConversation() {
    if (!hasStarted) return;

    final now = DateTime.now();
    final conversation = StudyConversation(
      id: _conversationId,
      title: _shortTopic(_topic ?? _messages.first.text),
      topic: _topic,
      messages: List<StudyMessage>.from(_messages),
      createdAt: _messages.first.createdAt,
      updatedAt: now,
      isArchived: _conversationArchived,
      artifactIds: _artifacts
          .where((artifact) => artifact.conversationId == _conversationId)
          .map((artifact) => artifact.id)
          .toList(),
      sourceText: _sourceText,
      phase: _phase,
    );
    final existingIndex = _conversations.indexWhere(
      (item) => item.id == _conversationId,
    );
    if (existingIndex == -1) {
      _conversations.insert(0, conversation);
    } else {
      _conversations[existingIndex] = conversation;
      if (existingIndex > 0) {
        _conversations
          ..removeAt(existingIndex)
          ..insert(0, conversation);
      }
    }
  }

  void _removeWelcomeMessage() {
    if (_messages.isEmpty) return;
    final welcome = _messages.first;
    if (welcome.isAssistant &&
        welcome.actions.any((action) => action.id == 'example_backend') &&
        (_messages.length == 1 ||
            _messages.skip(1).any((message) => message.role == 'user'))) {
      if (_messages.length == 1) {
        _messages.clear();
      } else {
        _messages.removeAt(0);
      }
    }
  }

  void _linkLegacyArtifacts() {
    if (_topic == null) return;
    for (var index = 0; index < _artifacts.length; index++) {
      final artifact = _artifacts[index];
      if (artifact.conversationId == null && artifact.topic == _topic) {
        _artifacts[index] = artifact.copyWith(conversationId: _conversationId);
      }
    }
  }

  int _nextRevisionNumber(StudyArtifact original) {
    final groupId = original.revisionGroupId ?? original.id;
    final highest = _artifacts
        .where(
          (artifact) => (artifact.revisionGroupId ?? artifact.id) == groupId,
        )
        .fold<int>(
          original.revisionNumber,
          (current, artifact) => artifact.revisionNumber > current
              ? artifact.revisionNumber
              : current,
        );
    return highest + 1;
  }

  static int _parseCount(String value, {int fallback = 20}) {
    final match = RegExp(r'\d+').firstMatch(value);
    final parsed = int.tryParse(match?.group(0) ?? '');
    if (parsed == null) return fallback;
    return parsed.clamp(5, 100).toInt();
  }

  static String _shortTopic(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length <= 46 ? clean : '${clean.substring(0, 43)}…';
  }

  static String _typeLabel(String type) {
    return switch (type) {
      'multiple_choice' => 'Çoktan seçmeli',
      'true_false' => 'Doğru / yanlış',
      'qa' => 'Soru-cevap',
      _ => 'Karışık kartlar',
    };
  }

  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}
