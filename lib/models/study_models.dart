class StudyAction {
  const StudyAction({required this.id, required this.label, this.description});

  final String id;
  final String label;
  final String? description;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'description': description,
  };

  factory StudyAction.fromJson(Map<String, dynamic> json) {
    return StudyAction(
      id: json['id'] as String? ?? 'unknown',
      label: json['label'] as String? ?? 'Continue',
      description: json['description'] as String?,
    );
  }
}

class StudyLessonSection {
  StudyLessonSection({required this.title, required this.body, this.example});

  final String title;
  final String body;
  final String? example;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'body': body,
    'example': example,
  };

  factory StudyLessonSection.fromJson(Map<String, dynamic> json) {
    return StudyLessonSection(
      title: json['title'] as String? ?? 'Kavram',
      body: json['body'] as String? ?? '',
      example: json['example'] as String?,
    );
  }
}

class StudyLesson {
  StudyLesson({required this.title, required this.sections, this.takeaway});

  final String title;
  final List<StudyLessonSection> sections;
  final String? takeaway;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'sections': sections.map((section) => section.toJson()).toList(),
    'takeaway': takeaway,
  };

  factory StudyLesson.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return StudyLesson(
      title: json['title'] as String? ?? 'Kısa ders',
      sections: rawSections is List
          ? rawSections
                .whereType<Map>()
                .map(
                  (item) => StudyLessonSection.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <StudyLessonSection>[],
      takeaway: json['takeaway'] as String?,
    );
  }
}

class StudyCheckpoint {
  StudyCheckpoint({
    required this.prompt,
    this.options = const <String>[],
    this.hint,
    this.expectedAnswer,
  });

  final String prompt;
  final List<String> options;
  final String? hint;
  final String? expectedAnswer;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'prompt': prompt,
    'options': options,
    'hint': hint,
    'expectedAnswer': expectedAnswer,
  };

  factory StudyCheckpoint.fromJson(Map<String, dynamic> json) {
    return StudyCheckpoint(
      prompt: json['prompt'] as String? ?? '',
      options: json['options'] is List
          ? (json['options'] as List).whereType<String>().toList()
          : const <String>[],
      hint: json['hint'] as String?,
      expectedAnswer: json['expectedAnswer'] as String?,
    );
  }
}

class StudyMessage {
  StudyMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.actions = const <StudyAction>[],
    this.phase,
    this.lesson,
    this.checkpoint,
    this.feedback,
    this.shouldAskFollowUp = false,
    this.isAction = false,
  });

  final String id;
  final String role;
  final String text;
  final DateTime createdAt;
  final List<StudyAction> actions;
  final String? phase;
  final StudyLesson? lesson;
  final StudyCheckpoint? checkpoint;
  final String? feedback;
  final bool shouldAskFollowUp;
  final bool isAction;

  bool get isAssistant => role == 'assistant';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'role': role,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'actions': actions.map((action) => action.toJson()).toList(),
    'phase': phase,
    'lesson': lesson?.toJson(),
    'checkpoint': checkpoint?.toJson(),
    'feedback': feedback,
    'shouldAskFollowUp': shouldAskFollowUp,
    'isAction': isAction,
  };

  factory StudyMessage.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    final rawLesson = json['lesson'];
    final rawCheckpoint = json['checkpoint'];
    return StudyMessage(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      actions: rawActions is List
          ? rawActions
                .whereType<Map>()
                .map(
                  (item) =>
                      StudyAction.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const <StudyAction>[],
      phase: json['phase'] as String?,
      lesson: rawLesson is Map
          ? StudyLesson.fromJson(Map<String, dynamic>.from(rawLesson))
          : null,
      checkpoint: rawCheckpoint is Map
          ? StudyCheckpoint.fromJson(Map<String, dynamic>.from(rawCheckpoint))
          : null,
      feedback: json['feedback'] as String?,
      shouldAskFollowUp: json['shouldAskFollowUp'] as bool? ?? false,
      isAction: json['isAction'] as bool? ?? false,
    );
  }

  StudyMessage copyWith({
    String? id,
    String? role,
    String? text,
    DateTime? createdAt,
    List<StudyAction>? actions,
    String? phase,
    StudyLesson? lesson,
    StudyCheckpoint? checkpoint,
    String? feedback,
    bool? shouldAskFollowUp,
    bool? isAction,
  }) {
    return StudyMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      actions: actions ?? this.actions,
      phase: phase ?? this.phase,
      lesson: lesson ?? this.lesson,
      checkpoint: checkpoint ?? this.checkpoint,
      feedback: feedback ?? this.feedback,
      shouldAskFollowUp: shouldAskFollowUp ?? this.shouldAskFollowUp,
      isAction: isAction ?? this.isAction,
    );
  }
}

class StudyConversation {
  StudyConversation({
    required this.id,
    required this.title,
    required this.topic,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.artifactIds = const <String>[],
    this.sourceText,
    this.phase,
  });

  final String id;
  final String title;
  final String? topic;
  final List<StudyMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final List<String> artifactIds;
  final String? sourceText;
  final String? phase;

  StudyConversation copyWith({
    String? id,
    String? title,
    String? topic,
    List<StudyMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    List<String>? artifactIds,
    String? sourceText,
    String? phase,
  }) {
    return StudyConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      artifactIds: artifactIds ?? this.artifactIds,
      sourceText: sourceText ?? this.sourceText,
      phase: phase ?? this.phase,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'topic': topic,
    'messages': messages.map((message) => message.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isArchived': isArchived,
    'artifactIds': artifactIds,
    'sourceText': sourceText,
    'phase': phase,
  };

  factory StudyConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return StudyConversation(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Study session',
      topic: json['topic'] as String?,
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map(
                  (item) =>
                      StudyMessage.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const <StudyMessage>[],
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      // Older payloads only stored conversations when they were archived.
      isArchived: json['isArchived'] as bool? ?? true,
      artifactIds: json['artifactIds'] is List
          ? (json['artifactIds'] as List).whereType<String>().toList()
          : const <String>[],
      sourceText: json['sourceText'] as String?,
      phase: json['phase'] as String?,
    );
  }
}

class StudyCard {
  StudyCard({
    required this.id,
    required this.type,
    required this.prompt,
    required this.answer,
    this.options = const <String>[],
    this.explanation,
    this.mastered = false,
  });

  final String id;
  final String type;
  final String prompt;
  final String answer;
  final List<String> options;
  final String? explanation;
  bool mastered;

  StudyCard copyWith({
    String? id,
    String? type,
    String? prompt,
    String? answer,
    List<String>? options,
    String? explanation,
    bool? mastered,
  }) {
    return StudyCard(
      id: id ?? this.id,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      options: options ?? this.options,
      explanation: explanation ?? this.explanation,
      mastered: mastered ?? this.mastered,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'prompt': prompt,
    'answer': answer,
    'options': options,
    'explanation': explanation,
    'mastered': mastered,
  };

  factory StudyCard.fromJson(Map<String, dynamic> json) {
    return StudyCard(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['type'] as String? ?? 'qa',
      prompt: json['prompt'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      options: json['options'] is List
          ? (json['options'] as List).whereType<String>().toList()
          : const <String>[],
      explanation: json['explanation'] as String?,
      mastered: json['mastered'] as bool? ?? false,
    );
  }
}

class StudyArtifact {
  StudyArtifact({
    required this.id,
    required this.type,
    required this.title,
    required this.topic,
    required this.summary,
    required this.createdAt,
    this.cards = const <StudyCard>[],
    this.tags = const <String>[],
    this.conversationId,
    this.revisionGroupId,
    this.revisionNumber = 1,
    this.revisedFromArtifactId,
  });

  final String id;
  final String type;
  final String title;
  final String topic;
  final String summary;
  final DateTime createdAt;
  final List<StudyCard> cards;
  final List<String> tags;
  final String? conversationId;
  final String? revisionGroupId;
  final int revisionNumber;
  final String? revisedFromArtifactId;

  int get completedCards => cards.where((card) => card.mastered).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'title': title,
    'topic': topic,
    'summary': summary,
    'createdAt': createdAt.toIso8601String(),
    'cards': cards.map((card) => card.toJson()).toList(),
    'tags': tags,
    'conversationId': conversationId,
    'revisionGroupId': revisionGroupId,
    'revisionNumber': revisionNumber,
    'revisedFromArtifactId': revisedFromArtifactId,
  };

  StudyArtifact copyWith({
    String? id,
    String? type,
    String? title,
    String? topic,
    String? summary,
    DateTime? createdAt,
    List<StudyCard>? cards,
    List<String>? tags,
    String? conversationId,
    String? revisionGroupId,
    int? revisionNumber,
    String? revisedFromArtifactId,
  }) {
    return StudyArtifact(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      cards: cards ?? this.cards,
      tags: tags ?? this.tags,
      conversationId: conversationId ?? this.conversationId,
      revisionGroupId: revisionGroupId ?? this.revisionGroupId,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      revisedFromArtifactId:
          revisedFromArtifactId ?? this.revisedFromArtifactId,
    );
  }

  factory StudyArtifact.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'];
    return StudyArtifact(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['type'] as String? ?? 'flashcards',
      title: json['title'] as String? ?? 'Study set',
      topic: json['topic'] as String? ?? 'Untitled topic',
      summary: json['summary'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      cards: rawCards is List
          ? rawCards
                .whereType<Map>()
                .map(
                  (item) => StudyCard.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const <StudyCard>[],
      tags: json['tags'] is List
          ? (json['tags'] as List).whereType<String>().toList()
          : const <String>[],
      conversationId: json['conversationId'] as String?,
      revisionGroupId: json['revisionGroupId'] as String?,
      revisionNumber: (json['revisionNumber'] as num?)?.toInt() ?? 1,
      revisedFromArtifactId: json['revisedFromArtifactId'] as String?,
    );
  }
}
