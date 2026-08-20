import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/study_models.dart';
import '../services/flashcard_ai_store.dart';

enum _LibrarySection { artifacts, conversations }

enum _ConversationFilter { active, archived }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.studyStore,
    this.onResumeConversation,
    super.key,
  });

  final FlashCardAiStore studyStore;
  final ValueChanged<String>? onResumeConversation;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _LibrarySection _section = _LibrarySection.artifacts;
  _ConversationFilter _conversationFilter = _ConversationFilter.active;

  @override
  void initState() {
    super.initState();
    if (widget.studyStore.conversations.isNotEmpty) {
      _section = _LibrarySection.conversations;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingArtifacts = _section == _LibrarySection.artifacts;
    return SafeArea(
      child: AnimatedBuilder(
        animation: widget.studyStore,
        builder: (context, _) {
          final conversations = widget.studyStore.conversations
              .where(
                (conversation) =>
                    conversation.isArchived ==
                    (_conversationFilter == _ConversationFilter.archived),
              )
              .toList();
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _header(context)),
              if (showingArtifacts && widget.studyStore.artifacts.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyLibrary(),
                )
              else if (!showingArtifacts && conversations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyConversations(
                    archived:
                        _conversationFilter == _ConversationFilter.archived,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList.builder(
                    itemCount: showingArtifacts
                        ? widget.studyStore.artifacts.length
                        : conversations.length,
                    itemBuilder: (context, index) {
                      if (showingArtifacts) {
                        final artifact = widget.studyStore.artifacts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ArtifactTile(
                            artifact: artifact,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ArtifactDetailScreen(
                                  artifact: artifact,
                                  studyStore: widget.studyStore,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final filteredConversation = conversations[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: ValueKey(filteredConversation.id),
                          direction: DismissDirection.endToStart,
                          background: _ConversationSwipeBackground(
                            archived: filteredConversation.isArchived,
                          ),
                          onDismissed: (_) =>
                              widget.studyStore.setConversationArchived(
                                filteredConversation.id,
                                !filteredConversation.isArchived,
                              ),
                          child: _ConversationTile(
                            conversation: filteredConversation,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ConversationDetailScreen(
                                  conversationId: filteredConversation.id,
                                  studyStore: widget.studyStore,
                                  onResume: widget.onResumeConversation == null
                                      ? null
                                      : () {
                                          Navigator.of(context).pop();
                                          widget.onResumeConversation!.call(
                                            filteredConversation.id,
                                          );
                                        },
                                ),
                              ),
                            ),
                            onDelete: () => _confirmDeleteConversation(
                              context,
                              filteredConversation,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final showingArtifacts = _section == _LibrarySection.artifacts;
    final activeChats = widget.studyStore.conversations
        .where((conversation) => !conversation.isArchived)
        .length;
    final archivedChats = widget.studyStore.conversations
        .where((conversation) => conversation.isArchived)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('LIBRARY', style: theme.textTheme.labelSmall),
              const Spacer(),
              Text(
                showingArtifacts
                    ? '${widget.studyStore.artifacts.length.toString().padLeft(2, '0')} SETS'
                    : '${(activeChats + archivedChats).toString().padLeft(2, '0')} CHATS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Kendi bilgi\narşivin.', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Konuşmalardan doğan kartlar, testler ve çalışma rotaları burada kalır.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_LibrarySection>(
              segments: const <ButtonSegment<_LibrarySection>>[
                ButtonSegment<_LibrarySection>(
                  value: _LibrarySection.artifacts,
                  label: Text('İçerikler'),
                  icon: Icon(Icons.grid_view_rounded),
                ),
                ButtonSegment<_LibrarySection>(
                  value: _LibrarySection.conversations,
                  label: Text('Konuşmalar'),
                  icon: Icon(Icons.forum_outlined),
                ),
              ],
              selected: <_LibrarySection>{_section},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  setState(() => _section = selection.first);
                }
              },
            ),
          ),
          if (!showingArtifacts) ...<Widget>[
            const SizedBox(height: 12),
            SegmentedButton<_ConversationFilter>(
              segments: <ButtonSegment<_ConversationFilter>>[
                ButtonSegment<_ConversationFilter>(
                  value: _ConversationFilter.active,
                  label: Text('Aktif $activeChats'),
                ),
                ButtonSegment<_ConversationFilter>(
                  value: _ConversationFilter.archived,
                  label: Text('Arşiv $archivedChats'),
                ),
              ],
              selected: <_ConversationFilter>{_conversationFilter},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  setState(() => _conversationFilter = selection.first);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteConversation(
    BuildContext context,
    StudyConversation conversation,
  ) async {
    final shouldDelete = await _showDeleteConversationDialog(
      context,
      conversation.title,
    );
    if (!context.mounted || shouldDelete != true) return;
    widget.studyStore.deleteConversation(conversation.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konuşma ve bağlı içerikleri silindi.')),
    );
  }
}

class _ArtifactTile extends StatelessWidget {
  const _ArtifactTile({required this.artifact, required this.onTap});

  final StudyArtifact artifact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = artifact.cards.isEmpty
        ? 0.0
        : artifact.completedCards / artifact.cards.length;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Badge(type: artifact.type),
                const Spacer(),
                Text(
                  _date(artifact.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(artifact.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 7),
            Text(artifact.summary, style: theme.textTheme.bodyMedium),
            if (artifact.cards.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppTheme.line,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${artifact.completedCards}/${artifact.cards.length}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 15),
            Row(
              children: <Widget>[
                ...artifact.tags
                    .take(3)
                    .map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Tag(label: tag),
                      ),
                    ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  final StudyConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: AppTheme.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(conversation.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text(
                    '${conversation.messages.where((message) => !message.isAction).length} mesaj · ${_date(conversation.updatedAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                    ),
                  ),
                  if (conversation.topic != null) ...<Widget>[
                    const SizedBox(height: 9),
                    Text(
                      conversation.topic!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Konuşmayı sil',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.muted,
              ),
            ),
            IconButton(
              tooltip: 'Konuşmayı aç',
              onPressed: onTap,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }
}

class _ConversationSwipeBackground extends StatelessWidget {
  const _ConversationSwipeBackground({required this.archived});

  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(
        archived ? Icons.unarchive_outlined : Icons.archive_outlined,
        color: AppTheme.primary,
      ),
    );
  }
}

class ConversationDetailScreen extends StatelessWidget {
  const ConversationDetailScreen({
    required this.conversationId,
    required this.studyStore,
    this.onResume,
    super.key,
  });

  final String conversationId;
  final FlashCardAiStore studyStore;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: studyStore,
      builder: (context, _) {
        final conversation = studyStore.conversationById(conversationId);
        if (conversation == null) {
          return const Scaffold(
            body: Center(child: Text('Konuşma bulunamadı.')),
          );
        }
        final linkedArtifacts = studyStore.artifacts
            .where(
              (artifact) =>
                  artifact.conversationId == conversation.id ||
                  conversation.artifactIds.contains(artifact.id),
            )
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Konuşma'),
            actions: <Widget>[
              IconButton(
                tooltip: conversation.isArchived ? 'Arşivden çıkar' : 'Arşivle',
                onPressed: () => studyStore.setConversationArchived(
                  conversation.id,
                  !conversation.isArchived,
                ),
                icon: Icon(
                  conversation.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
              ),
              if (onResume != null)
                IconButton(
                  tooltip: 'Studio’da devam et',
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              IconButton(
                tooltip: 'Konuşmayı sil',
                onPressed: () async {
                  final shouldDelete = await _showDeleteConversationDialog(
                    context,
                    conversation.title,
                  );
                  if (!context.mounted || shouldDelete != true) return;
                  studyStore.deleteConversation(conversation.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: <Widget>[
              _ConversationInfo(
                conversation: conversation,
                artifactCount: linkedArtifacts.length,
                onResume: onResume,
              ),
              if (linkedArtifacts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'BAĞLI İÇERİKLER',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 9),
                ...linkedArtifacts.map(
                  (artifact) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LinkedArtifactTile(
                      artifact: artifact,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ArtifactDetailScreen(
                            artifact: artifact,
                            studyStore: studyStore,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ...conversation.messages
                  .where((message) => !message.isAction)
                  .map((message) => _ConversationMessage(message: message)),
            ],
          ),
        );
      },
    );
  }
}

class _ConversationInfo extends StatelessWidget {
  const _ConversationInfo({
    required this.conversation,
    required this.artifactCount,
    this.onResume,
  });

  final StudyConversation conversation;
  final int artifactCount;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            conversation.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            conversation.topic ?? 'Konu belirtilmedi',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '${conversation.messages.where((message) => !message.isAction).length} mesaj · $artifactCount bağlı içerik · ${conversation.isArchived ? 'Arşivde' : 'Aktif'}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
          ),
          if (onResume != null) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Studio’da devam et'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkedArtifactTile extends StatelessWidget {
  const _LinkedArtifactTile({required this.artifact, required this.onTap});

  final StudyArtifact artifact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.line),
      ),
      leading: const Icon(Icons.auto_awesome_outlined, color: AppTheme.primary),
      title: Text(artifact.title),
      subtitle: Text(
        artifact.revisionNumber > 1
            ? 'Revizyon ${artifact.revisionNumber}'
            : artifact.type,
      ),
      trailing: const Icon(Icons.arrow_forward_rounded),
      onTap: onTap,
    );
  }
}

class _ConversationMessage extends StatelessWidget {
  const _ConversationMessage({required this.message});

  final StudyMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = !message.isAssistant;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primary.withValues(alpha: 0.13)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isUser ? AppTheme.primary : AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              isUser ? 'SEN' : 'FLASHCARD AI',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isUser ? AppTheme.secondary : AppTheme.primary,
              ),
            ),
            const SizedBox(height: 7),
            Text(message.text),
            if (message.actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '${message.actions.length} seçenek sunuldu',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ArtifactDetailScreen extends StatelessWidget {
  const ArtifactDetailScreen({
    required this.artifact,
    required this.studyStore,
    super.key,
  });

  final StudyArtifact artifact;
  final FlashCardAiStore studyStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(artifact.type == 'quiz' ? 'Test' : 'Study set'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Revizyon iste',
            onPressed: () => _requestRevision(context, artifact, studyStore),
            icon: const Icon(Icons.edit_note_outlined),
          ),
          IconButton(
            tooltip: 'Export',
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('PDF export sırada.'))),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: studyStore,
        builder: (context, _) {
          final current = studyStore.artifacts.firstWhere(
            (item) => item.id == artifact.id,
            orElse: () => artifact,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: <Widget>[
              _DetailIntro(artifact: current),
              const SizedBox(height: 18),
              ...current.cards.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StudyCardTile(
                    index: entry.key + 1,
                    card: entry.value,
                    onMastered: (value) =>
                        studyStore.markCard(current.id, entry.value.id, value),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestRevision(
    BuildContext context,
    StudyArtifact artifact,
    FlashCardAiStore studyStore,
  ) async {
    final instruction = await showDialog<String>(
      context: context,
      builder: (_) => const _RevisionDialog(),
    );
    if (!context.mounted || instruction == null || instruction.trim().isEmpty) {
      return;
    }
    await studyStore.reviseArtifact(artifact.id, instruction);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Revizyon oluşturuldu.')));
  }
}

Future<bool?> _showDeleteConversationDialog(
  BuildContext context,
  String title,
) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Konuşma silinsin mi?'),
      content: Text(
        '“$title” ve bu konuşmaya bağlı içerikler kalıcı olarak silinecek.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
}

class _RevisionDialog extends StatefulWidget {
  const _RevisionDialog();

  @override
  State<_RevisionDialog> createState() => _RevisionDialogState();
}

class _RevisionDialogState extends State<_RevisionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İçeriği revize et'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Örn. Daha kısa, daha zor ve örnekli yap…',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Revize et'),
        ),
      ],
    );
  }
}

class _DetailIntro extends StatelessWidget {
  const _DetailIntro({required this.artifact});

  final StudyArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = artifact.cards.isEmpty
        ? 0.0
        : artifact.completedCards / artifact.cards.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Badge(type: artifact.type),
          const SizedBox(height: 16),
          Text(artifact.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(artifact.summary, style: theme.textTheme.bodyMedium),
          if (artifact.cards.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppTheme.line,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${artifact.completedCards}/${artifact.cards.length} mastered',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudyCardTile extends StatefulWidget {
  const _StudyCardTile({
    required this.index,
    required this.card,
    required this.onMastered,
  });

  final int index;
  final StudyCard card;
  final ValueChanged<bool> onMastered;

  @override
  State<_StudyCardTile> createState() => _StudyCardTileState();
}

class _StudyCardTileState extends State<_StudyCardTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: widget.card.mastered
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.card.mastered ? AppTheme.primary : AppTheme.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '#${widget.index.toString().padLeft(2, '0')}',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(width: 8),
              _Tag(label: widget.card.type.replaceAll('_', ' ')),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => widget.onMastered(!widget.card.mastered),
                icon: Icon(
                  widget.card.mastered
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: widget.card.mastered
                      ? AppTheme.primary
                      : AppTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(widget.card.prompt, style: theme.textTheme.titleMedium),
          if (widget.card.options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 13),
            ...widget.card.options.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${String.fromCharCode(65 + entry.key)}  ${entry.value}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          const SizedBox(height: 13),
          OutlinedButton.icon(
            onPressed: () => setState(() => _revealed = !_revealed),
            icon: Icon(
              _revealed
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            label: Text(_revealed ? 'Cevabı gizle' : 'Cevabı göster'),
          ),
          if (_revealed) ...<Widget>[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('ANSWER', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Text(
                    widget.card.answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (widget.card.explanation != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      widget.card.explanation!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'quiz' => 'QUIZ',
      'topic_map' => 'MAP',
      'study_plan' => 'PLAN',
      _ => 'CARDS',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 8),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.line.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppTheme.muted, fontSize: 8),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.grid_view_rounded,
            size: 42,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Henüz içerik yok.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Studio’ya bir konu yaz ve ilk çalışma paketini oluştur.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations({required this.archived});

  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.forum_outlined, size: 42, color: AppTheme.primary),
          const SizedBox(height: 18),
          Text(
            archived
                ? 'Henüz arşivlenmiş konuşma yok.'
                : 'Henüz aktif konuşma yok.',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            archived
                ? 'Bir konuşmayı kaydırarak veya detayından arşivleyebilirsin.'
                : 'Studio’da bir mesaj gönderdiğinde konuşma burada görünür.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
