import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../application/unread_counter.dart';
import '../data/conversations_provider.dart';
import '../domain/messaging_models.dart';
import 'chat_screen.dart';

/// `GET /api/messagerie/conversations`.
class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    Future<void> refresh() async {
      final results = await Future.wait([
        ref.read(conversationsProvider.notifier).refresh(),
        ref.read(unreadCountProvider.notifier).reconcile().then((_) => null),
      ]);
      final error = results.first;
      if (error != null && context.mounted) showErrorMessage(context, error);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie'),
        actions: [
          IconButton(
            tooltip: 'Nouveau message',
            onPressed: () => context.push(AppRoutes.contacts),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouveau message',
        onPressed: () => context.push(AppRoutes.contacts),
        child: const Icon(Icons.add_comment_rounded),
      ),
      body: ResourceView(
        value: conversations,
        loading: const SkeletonConversations(),
        onRetry: () => ref.invalidate(conversationsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: RefreshableFill(
          onRefresh: refresh,
          child: EmptyState(
            icon: Icons.forum_outlined,
            title: 'Aucune conversation',
            message: 'Écrivez à un responsable du parc ou de la maintenance.',
            action: FilledButton.icon(
              onPressed: () => context.push(AppRoutes.contacts),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Nouveau message'),
            ),
          ),
        ),
        builder: (context, data) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: data.value.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    0,
                  ),
                  child: StaleNote(data: data),
                );
              }
              return ResponsiveCenter(
                child: ConversationTile(conversation: data.value[index - 1]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ConversationTile extends ConsumerWidget {
  const ConversationTile({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preview = ref.watch(
      conversationPreviewsProvider.select(
        (p) => p[conversation.idConversation],
      ),
    );
    final unread = conversation.nonLus;
    final date = conversation.dateDernierMessage;
    final subtitle = switch (preview) {
      final Message message when message.preview.isNotEmpty =>
        conversation.type.isGroup
            ? '${message.auteur.nomComplet.split(' ').first} : ${message.preview}'
            : message.preview,
      _ => conversation.interlocuteur?.roleLabel ?? conversation.type.label,
    };
    return Semantics(
      button: true,
      label:
          '${conversation.titre}. $subtitle'
          '${unread > 0 ? '. ${AppFormat.plural(unread, 'message non lu', 'messages non lus')}' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(AppRoutes.chat(conversation.idConversation)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              InitialsOrIcon(conversation: conversation),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (date != null)
                          Text(
                            AppFormat.compact(date),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: unread > 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: unread > 0
                                  ? theme.colorScheme.onSurface
                                  : null,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          AppSpacing.gapSm,
                          Badge(
                            label: Text(unread > 99 ? '99+' : '$unread'),
                            backgroundColor: theme.colorScheme.primary,
                            textColor: theme.colorScheme.onPrimary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonConversations extends StatelessWidget {
  const SkeletonConversations({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SkeletonBox(width: 44, height: 44, radius: 22),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 220, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
