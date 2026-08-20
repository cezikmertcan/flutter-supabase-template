import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/study_models.dart';
import '../services/auth_service.dart';
import '../services/flashcard_ai_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.auth,
    required this.studyStore,
    required this.onOpenLibrary,
    super.key,
  });

  final AuthService auth;
  final FlashCardAiStore studyStore;
  final VoidCallback onOpenLibrary;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  final _promptFocusNode = FocusNode();
  int _lastVisibleMessageCount = 0;
  String? _lastConversationId;
  int _scrollRequest = 0;

  @override
  void initState() {
    super.initState();
    _lastVisibleMessageCount = widget.studyStore.visibleMessages.length;
    _lastConversationId = widget.studyStore.currentConversationId;
    widget.studyStore.addListener(_handleStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.studyStore.hasStarted) return;
      _jumpToLatest();
    });
  }

  @override
  void dispose() {
    widget.studyStore.removeListener(_handleStoreChanged);
    _promptController.dispose();
    _scrollController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final header = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[widget.auth, widget.studyStore]),
      builder: (context, _) => Container(
        width: double.infinity,
        color: background,
        child: _buildHeader(context),
      ),
    );
    return ColoredBox(
      color: background,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          SafeArea(
            child: Column(
              children: <Widget>[
                // Reserve the same space as the fixed header without mounting
                // a second copy of its interactive content.
                AnimatedBuilder(
                  animation: widget.studyStore,
                  builder: (context, _) =>
                      SizedBox(height: _headerHeight(context)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: widget.studyStore,
                      builder: (context, _) {
                        final showWelcomeMetrics =
                            !widget.studyStore.hasStarted;
                        final visibleMessages =
                            widget.studyStore.visibleMessages;
                        final messageOffset = showWelcomeMetrics ? 1 : 0;
                        return ListView.builder(
                          controller: _scrollController,
                          clipBehavior: Clip.hardEdge,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                          itemCount: visibleMessages.length + messageOffset + 1,
                          itemBuilder: (context, index) {
                            if (showWelcomeMetrics && index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildMetrics(context),
                              );
                            }
                            final messageIndex = index - messageOffset;
                            if (messageIndex == visibleMessages.length) {
                              return _buildLibraryHint(context);
                            }
                            return _buildMessage(
                              context,
                              visibleMessages[messageIndex],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                _buildComposer(context),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ColoredBox(
                color: background,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[header, const SizedBox(height: 12)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _headerHeight(BuildContext context) {
    // The header uses a fixed single-line topic once a conversation starts;
    // the larger value leaves room for the two-line welcome copy.
    return widget.studyStore.hasStarted ? 104 : 190;
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final topic = widget.studyStore.topic;
    final started = widget.studyStore.hasStarted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 17,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              Text('FLASHCARD AI', style: theme.textTheme.labelSmall),
              const Spacer(),
              _StatusPill(
                label: widget.auth.isSignedIn ? 'SYNCED' : 'LOCAL MODE',
                color: widget.auth.isSignedIn
                    ? AppTheme.primary
                    : AppTheme.warning,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Yeni konuşma',
                onPressed: () => _confirmNewConversation(context),
                icon: const Icon(Icons.add_comment_outlined, size: 20),
              ),
            ],
          ),
          if (!started) ...<Widget>[
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Öğrenme alanını kur.',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bir konu, hedef veya belgeyle başla. Sonraki adımları AI seçeneklere dönüştürsün.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ] else if (topic != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _topicLabel(topic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _phaseLabel(widget.studyStore.phase),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _topicLabel(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = clean.split(' ');
    if (words.length <= 4) return clean;
    final stopWords = <String>{
      'de',
      'da',
      'için',
      'bana',
      'öğreniyorum',
      'öğrenmek',
      'öğretmen',
      'lazım',
      'yarın',
      'quizim',
      'sınavım',
      'var',
    };
    final topicWords = <String>[];
    for (final word in words) {
      if (topicWords.length >= 3 || stopWords.contains(word.toLowerCase())) {
        break;
      }
      topicWords.add(word);
    }
    return topicWords.isEmpty ? words.take(3).join(' ') : topicWords.join(' ');
  }

  static String _phaseLabel(String phase) {
    return switch (phase) {
      'level_check' => 'SEVİYE',
      'lesson' => 'DERS',
      'checkpoint' => 'KONTROL',
      'feedback' => 'GERİ BİLDİRİM',
      'guided_practice' => 'PRATİK',
      'content_confirmation' => 'ONAY',
      'artifact_generation' => 'ÜRETİM',
      'review' => 'İNCELEME',
      _ => 'BAŞLANGIÇ',
    };
  }

  Widget _buildMetrics(BuildContext context) {
    final topic = widget.studyStore.topic;
    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricTile(
            label: 'LIBRARY',
            value: '${widget.studyStore.artifacts.length}'.padLeft(2, '0'),
            icon: Icons.grid_view_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'CONTEXT',
            value: topic == null ? '—' : 'ON',
            icon: Icons.track_changes_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(BuildContext context, StudyMessage message) {
    final theme = Theme.of(context);
    final isAssistant = message.isAssistant;
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: EdgeInsets.only(
          left: isAssistant ? 0 : 32,
          right: isAssistant ? 32 : 0,
          bottom: 14,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
        decoration: BoxDecoration(
          color: isAssistant
              ? AppTheme.surface
              : AppTheme.primary.withValues(alpha: 0.11),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAssistant ? 5 : 20),
            bottomRight: Radius.circular(isAssistant ? 20 : 5),
          ),
          border: Border.all(
            color: isAssistant
                ? AppTheme.line
                : AppTheme.primary.withValues(alpha: 0.34),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  isAssistant ? 'AI / GUIDE' : 'YOU',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isAssistant ? AppTheme.primary : AppTheme.secondary,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(message.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(message.text, style: theme.textTheme.bodyLarge),
            if (message.lesson != null) ...<Widget>[
              const SizedBox(height: 14),
              _LessonBlock(lesson: message.lesson!),
            ],
            if (message.feedback != null &&
                message.feedback!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _FeedbackBlock(text: message.feedback!),
            ],
            if (message.checkpoint != null) ...<Widget>[
              const SizedBox(height: 14),
              _CheckpointBlock(
                checkpoint: message.checkpoint!,
                onOptionSelected: (option) =>
                    unawaited(widget.studyStore.submitPrompt(option)),
              ),
            ],
            if (message.actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              ...message.actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActionButton(
                    action: action,
                    onPressed: () => _handleAction(action),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryHint(BuildContext context) {
    if (widget.studyStore.artifacts.isEmpty) return const SizedBox(height: 8);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onOpenLibrary,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.grid_view_rounded,
                color: AppTheme.primary,
                size: 19,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  '${widget.studyStore.artifacts.length} içerik Library’de hazır.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final errorMessage = widget.studyStore.errorMessage;
    final isProcessing = widget.studyStore.isProcessing;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: AppTheme.line.withValues(alpha: 0.7)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isProcessing)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: AppTheme.line,
              color: AppTheme.primary,
            ),
          if (errorMessage != null) ...<Widget>[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 8, 7, 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 17,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: isProcessing
                        ? null
                        : () => unawaited(widget.studyStore.retryLastTurn()),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _promptController,
                  focusNode: _promptFocusNode,
                  enabled: !isProcessing,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText:
                        widget.studyStore.inputHint ??
                        'Ne öğrenmek istiyorsun?',
                    prefixIcon: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.primary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: isProcessing ? 'AI yanıtlıyor' : 'Gönder',
                onPressed: isProcessing ? null : _submit,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.background,
                  disabledBackgroundColor: AppTheme.line,
                  minimumSize: const Size(52, 52),
                ),
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (widget.studyStore.isProcessing) return;
    final prompt = _promptController.text;
    if (prompt.trim().isEmpty) return;
    unawaited(widget.studyStore.submitPrompt(prompt));
    _promptController.clear();
  }

  void _handleAction(StudyAction action) {
    if (action.id == 'new_topic') {
      widget.studyStore.newConversation();
      _focusPrompt();
    } else if (action.id == 'retry_ai') {
      unawaited(widget.studyStore.retryLastTurn());
    } else if (action.id == 'example_backend') {
      unawaited(widget.studyStore.submitPrompt('Backend .NET öğreniyorum'));
    } else if (action.id == 'example_exam') {
      unawaited(widget.studyStore.submitPrompt('KPSS’ye hazırlanıyorum'));
    } else if (action.id == 'open_artifact' || action.id == 'library') {
      widget.onOpenLibrary();
    } else {
      unawaited(widget.studyStore.chooseAction(action));
    }
  }

  Future<void> _confirmNewConversation(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yeni konuşma başlat?'),
        content: const Text(
          'Library’deki içeriklerin korunur; yalnızca bu sohbet akışı temizlenir.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yeni konuşma'),
          ),
        ],
      ),
    );
    if (shouldReset == true) {
      widget.studyStore.newConversation();
      _focusPrompt();
    }
  }

  void _focusPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _promptFocusNode.requestFocus();
    });
  }

  void _handleStoreChanged() {
    final conversationId = widget.studyStore.currentConversationId;
    final messageCount = widget.studyStore.visibleMessages.length;
    final conversationChanged = conversationId != _lastConversationId;
    final messagesChanged = messageCount != _lastVisibleMessageCount;
    _lastConversationId = conversationId;
    _lastVisibleMessageCount = messageCount;

    if (!mounted) return;
    if (conversationChanged) {
      _resetScrollForNewConversation();
    } else if (messagesChanged) {
      _scrollToLatest();
    }
  }

  void _resetScrollForNewConversation() {
    final request = ++_scrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _scrollRequest) return;
      if (!_scrollController.hasClients) return;
      if (widget.studyStore.hasStarted) {
        _jumpToLatest();
      } else {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _scrollToLatest() {
    final request = ++_scrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _scrollRequest) return;
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 17, color: AppTheme.primary),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 8),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onPressed});

  final StudyAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                _iconFor(action.id),
                size: 15,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    action.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (action.description != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(action.description!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String id) {
    if (id.contains('flash') || id.contains('card')) {
      return Icons.style_outlined;
    }
    if (id.contains('quiz') || id.contains('count')) {
      return Icons.fact_check_outlined;
    }
    if (id.contains('topic') || id.contains('map')) {
      return Icons.account_tree_outlined;
    }
    if (id.contains('plan')) return Icons.route_outlined;
    if (id.contains('source') || id.contains('pdf')) {
      return Icons.upload_file_outlined;
    }
    if (id.contains('library') || id.contains('artifact')) {
      return Icons.grid_view_rounded;
    }
    if (id.contains('back') || id.contains('cancel')) return Icons.undo_rounded;
    return Icons.arrow_forward_rounded;
  }
}

class _LessonBlock extends StatelessWidget {
  const _LessonBlock({required this.lesson});

  final StudyLesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('DERS', style: theme.textTheme.labelSmall),
          const SizedBox(height: 5),
          Text(
            lesson.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          ...lesson.sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    section.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(section.body, style: theme.textTheme.bodyMedium),
                  if (section.example != null &&
                      section.example!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 7),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Örnek: ${section.example}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (lesson.takeaway != null && lesson.takeaway!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Özet: ${lesson.takeaway}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedbackBlock extends StatelessWidget {
  const _FeedbackBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Geri bildirim\n$text',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _CheckpointBlock extends StatelessWidget {
  const _CheckpointBlock({
    required this.checkpoint,
    required this.onOptionSelected,
  });

  final StudyCheckpoint checkpoint;
  final ValueChanged<String> onOptionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('KONTROL NOKTASI', style: theme.textTheme.labelSmall),
          const SizedBox(height: 7),
          Text(
            checkpoint.prompt,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (checkpoint.hint != null && checkpoint.hint!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'İpucu: ${checkpoint.hint}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (checkpoint.options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            ...checkpoint.options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onOptionSelected(option),
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Text(option, style: theme.textTheme.bodyMedium),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
