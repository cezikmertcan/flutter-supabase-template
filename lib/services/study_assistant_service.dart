import 'dart:async';

import '../models/study_models.dart';
import 'auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssistantTurn {
  const AssistantTurn({
    required this.message,
    required this.actions,
    this.phase,
    this.lesson,
    this.checkpoint,
    this.feedback,
    this.shouldAskFollowUp = false,
    this.shouldPersistArtifact = false,
    this.artifact,
  });

  final String message;
  final List<StudyAction> actions;
  final String? phase;
  final StudyLesson? lesson;
  final StudyCheckpoint? checkpoint;
  final String? feedback;
  final bool shouldAskFollowUp;
  final bool shouldPersistArtifact;
  final StudyArtifact? artifact;
}

class StudyAssistantService {
  StudyAssistantService({required this.auth});

  final AuthService auth;
  String? _lastError;

  String? get lastError => _lastError;

  Future<AssistantTurn?> createTurn({
    required List<StudyMessage> messages,
    required String? topic,
    String? sourceText,
    String? phase,
  }) async {
    final client = auth.client;
    if (client == null) {
      _lastError = 'Supabase bağlantısı hazır değil.';
      return null;
    }
    if (!auth.isSignedIn) {
      _lastError = 'AI yanıtı için hesabına giriş yapmalısın.';
      return null;
    }
    _lastError = null;

    try {
      final response = await client.functions
          .invoke(
            'study-assistant',
            body: <String, dynamic>{
              'topic': topic,
              'sourceText': sourceText,
              'phase': phase,
              'messages': messages
                  .map(
                    (message) => <String, dynamic>{
                      'role': message.role,
                      'content': message.text,
                    },
                  )
                  .toList(),
            },
          )
          .timeout(const Duration(seconds: 60));
      if (response.status < 200 || response.status >= 300) {
        _lastError = _friendlyError(response.status, response.data);
        return null;
      }
      final data = response.data;
      if (data is! Map) {
        _lastError = 'AI yanıtı beklenen biçimde dönmedi.';
        return null;
      }
      final parsed = _parse(Map<String, dynamic>.from(data));
      if (parsed == null) _lastError = 'AI yanıtı okunamadı.';
      return parsed;
    } on FunctionException catch (error) {
      _lastError = _friendlyError(error.status, error.details);
      return null;
    } on TimeoutException {
      _lastError =
          'AI yanıtı çok uzun sürdü. Mesajın korundu; tekrar deneyebilirsin.';
      return null;
    } catch (_) {
      _lastError =
          'AI bağlantısı kurulamadı. İnternet bağlantını kontrol edip tekrar dene.';
      return null;
    }
  }

  String _friendlyError(int status, dynamic data) {
    final detail = data is Map
        ? <String>[
            data['detail']?.toString() ?? '',
            data['error']?.toString() ?? '',
            data['message']?.toString() ?? '',
            data['upstreamStatus']?.toString() ?? '',
          ].join(' ')
        : data?.toString() ?? '';
    final normalized = detail.toLowerCase();
    if (status == 429 ||
        normalized.contains('429') ||
        normalized.contains('quota') ||
        normalized.contains('resource_exhausted')) {
      return 'AI kullanım kotası doldu. Biraz sonra tekrar deneyebilirsin.';
    }
    if (status == 401 || status == 403) {
      return 'AI oturumu geçersiz. Hesabını yeniden bağlamayı dene.';
    }
    if (status == 503 && normalized.contains('not_configured')) {
      return 'AI servisi henüz yapılandırılmamış. Gemini ayarlarını kontrol et.';
    }
    if (status >= 500) {
      return 'AI servisi şu anda yanıt vermedi. Biraz sonra tekrar deneyebilirsin.';
    }
    return 'AI yanıtı alınamadı. Mesajın korunuyor; tekrar deneyebilirsin.';
  }

  AssistantTurn? _parse(Map<String, dynamic> data) {
    final message = data['message'];
    if (message is! String || message.trim().isEmpty) return null;

    final rawActions = data['nextActions'] ?? data['actions'];
    final actions = rawActions is List
        ? rawActions
              .whereType<Map>()
              .map(
                (item) => StudyAction.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <StudyAction>[];

    final rawLesson = data['lesson'];
    final rawCheckpoint = data['checkpoint'];
    final lesson = rawLesson is Map
        ? StudyLesson.fromJson(Map<String, dynamic>.from(rawLesson))
        : null;
    final checkpoint = rawCheckpoint is Map
        ? StudyCheckpoint.fromJson(Map<String, dynamic>.from(rawCheckpoint))
        : null;
    final phase = data['phase'] as String?;
    final feedback = data['feedback'] as String?;
    final shouldAskFollowUp = data['shouldAskFollowUp'] as bool? ?? false;
    final shouldPersistArtifact =
        data['shouldPersistArtifact'] as bool? ?? false;

    StudyArtifact? artifact;
    final rawArtifact = data['artifact'];
    if (shouldPersistArtifact && rawArtifact is Map) {
      final source = Map<String, dynamic>.from(rawArtifact);
      final payload = source['payload'];
      final payloadMap = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      final rawCards = payloadMap['cards'];
      if (rawCards is! List || rawCards.isEmpty) {
        // Do not persist a successful-looking but unusable Library item when
        // the provider omits the actual study cards.
        return AssistantTurn(
          message: message,
          actions: actions,
          phase: phase,
          lesson: lesson,
          checkpoint: checkpoint,
          feedback: feedback,
          shouldAskFollowUp: shouldAskFollowUp,
          shouldPersistArtifact: false,
        );
      }
      artifact = StudyArtifact.fromJson(<String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'type': source['kind'] as String? ?? 'flashcards',
        'title': source['title'] as String? ?? 'AI study set',
        'topic': source['topic'] as String? ?? 'Untitled topic',
        'summary': source['summary'] as String? ?? '',
        'createdAt': DateTime.now().toIso8601String(),
        'cards': rawCards,
        'tags': <String>['ai-generated'],
      });
    }

    return AssistantTurn(
      message: message,
      actions: actions,
      phase: phase,
      lesson: lesson,
      checkpoint: checkpoint,
      feedback: feedback,
      shouldAskFollowUp: shouldAskFollowUp,
      shouldPersistArtifact: shouldPersistArtifact,
      artifact: artifact,
    );
  }
}
