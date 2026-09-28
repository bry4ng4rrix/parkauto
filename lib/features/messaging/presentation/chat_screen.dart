import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_colors.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/tone.dart';
import '../../../core/lifecycle/app_lifecycle.dart';
import '../../../core/utils/app_date_time.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/websocket/realtime_service.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../application/own_message.dart';
import '../application/read_service.dart';
import '../application/realtime.dart';
import '../data/conversations_provider.dart';
import '../domain/messaging_models.dart';
import 'chat_composer.dart';
import 'chat_controller.dart';
import 'message_bubble.dart';

/// Conversation : fil, pagination vers le haut, envoi, temps réel.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.idConversation});

  final int idConversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with RouteAware {
  final _scroll = ScrollController();
  late final ActiveConversation _active;
  late final ConversationReadService _reads;
  ModalRoute<void>? _route;
  bool _visible = false;

  int get _id => widget.idConversation;

  @override
  void initState() {
    super.initState();
    // Lus ici : `ref` n'est plus utilisable dans dispose().
    _active = ref.read(activeConversationProvider.notifier);
    _reads = ref.read(conversationReadServiceProvider);
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  // La conversation est « active » quand son écran est au premier plan.
  @override
  void didPush() => _enter();

  @override
  void didPopNext() => _enter();

  @override
  void didPushNext() => _leave();

  @override
  void didPop() => _leave();

  // Les callbacks RouteAware peuvent survenir pendant un build
  // (`subscribe` appelle `didPush`) : l'état partagé est mis à jour juste
  // après.
  void _enter() {
    _visible = true;
    scheduleMicrotask(() {
      if (!mounted || !_visible) return;
      _active.enter(_id);
      _reads.markRead(_id);
    });
  }

  void _leave() {
    _visible = false;
    scheduleMicrotask(() => _active.leave(_id));
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _leave();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Liste inversée : l'extrémité « max » correspond aux plus anciens.
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(ref.read(chatControllerProvider(_id).notifier).loadOlder());
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider(_id));
    final conversation = ref.watch(
      conversationsProvider.select(
        (value) => value.value?.value
            .where((c) => c.idConversation == _id)
            .firstOrNull,
      ),
    );
    ref.listen(appLifecycleProvider, (previous, next) {
      if (next.isForeground && _visible) _reads.markRead(_id);
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _ChatTitle(conversation: conversation),
      ),
      body: Column(
        children: [
          Expanded(
            child: switch (chat) {
              AsyncValue(value: final state?) => _Thread(
                state: state,
                conversation: conversation,
                controller: _scroll,
                onRetryOlder: () => unawaited(
                  ref.read(chatControllerProvider(_id).notifier).loadOlder(),
                ),
                onRetry: (localId) => unawaited(
                  ref.read(chatControllerProvider(_id).notifier).retry(localId),
                ),
                onDiscard: (localId) => ref
                    .read(chatControllerProvider(_id).notifier)
                    .discard(localId),
              ),
              AsyncValue(error: final error?) => ErrorState(
                error: error,
                onRetry: () => ref.invalidate(chatControllerProvider(_id)),
              ),
              _ => const _ThreadSkeleton(),
            },
          ),
          ChatComposer(
            idConversation: _id,
            onSend: (text, files) {
              unawaited(
                ref
                    .read(chatControllerProvider(_id).notifier)
                    .send(text, files),
              );
              if (_scroll.hasClients) {
                _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ChatTitle extends ConsumerWidget {
  const _ChatTitle({required this.conversation});

  final Conversation? conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final status =
        ref.watch(realtimeStatusProvider).value ?? RealtimeStatus.disconnected;
    final (tone, label) = switch (status) {
      RealtimeStatus.connected => (Tone.success, 'En direct'),
      RealtimeStatus.connecting => (Tone.warning, 'Connexion…'),
      RealtimeStatus.disconnected => (Tone.neutral, 'Hors ligne'),
    };
    final c = conversation;
    final subtitle = switch (c) {
      Conversation(interlocuteur: final person?) => person.roleLabel,
      Conversation(:final type) => type.label,
      null => null,
    };
    return Row(
      children: [
        InitialsOrIcon(conversation: c, size: 36),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c?.titre ?? 'Conversation',
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Semantics(
                label: 'Connexion temps réel : $label',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.foreground(tone),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        [?subtitle, label].join(' · '),
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Avatar d'une conversation : initiales (privée) ou icône (canal, fil).
class InitialsOrIcon extends StatelessWidget {
  const InitialsOrIcon({super.key, required this.conversation, this.size = 44});

  final Conversation? conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (c?.type) {
      TypeConversation.canal => Icons.campaign_rounded,
      TypeConversation.fil => Icons.forum_rounded,
      _ => null,
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: icon != null
            ? Icon(icon, color: scheme.primary, size: size * 0.5)
            : Text(
                _initials(c?.interlocuteur?.nomComplet ?? c?.titre ?? '?'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontSize: size * 0.34,
                ),
              ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

sealed class _ThreadItem {
  const _ThreadItem();
}

final class _DayItem extends _ThreadItem {
  const _DayItem(this.day);

  final DateTime day;
}

final class _MessageItem extends _ThreadItem {
  const _MessageItem(this.message, {required this.showAuthor});

  final Message message;
  final bool showAuthor;
}

final class _PendingItem extends _ThreadItem {
  const _PendingItem(this.pending);

  final PendingMessage pending;
}

class _Thread extends ConsumerWidget {
  const _Thread({
    required this.state,
    required this.conversation,
    required this.controller,
    required this.onRetryOlder,
    required this.onRetry,
    required this.onDiscard,
  });

  final ChatState state;
  final Conversation? conversation;
  final ScrollController controller;
  final VoidCallback onRetryOlder;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onDiscard;

  List<_ThreadItem> _items(bool Function(Message) isMine) {
    final group = conversation?.type.isGroup ?? false;
    final items = <_ThreadItem>[];
    Message? previous;
    for (final message in state.messages) {
      final newDay =
          previous == null ||
          !AppDateTime.isSameDay(previous.dateEnvoi, message.dateEnvoi);
      if (newDay) items.add(_DayItem(message.dateEnvoi));
      final sameAuthor =
          !newDay &&
          previous.auteur.idUtilisateur == message.auteur.idUtilisateur;
      items.add(
        _MessageItem(
          message,
          showAuthor: group && !sameAuthor && !isMine(message),
        ),
      );
      previous = message;
    }
    for (final pending in state.pending) {
      items.add(_PendingItem(pending));
    }
    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMine = ref.watch(ownMessageMatcherProvider);
    if (state.messages.isEmpty && state.pending.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Aucun message',
        message: 'Écrivez le premier message de cette conversation.',
      );
    }
    final items = _items(isMine).reversed.toList();
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _OlderIndicator(state: state, onRetry: onRetryOlder);
        }
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: switch (item) {
            _DayItem(:final day) => _DaySeparator(day: day),
            _MessageItem(:final message, :final showAuthor) => MessageBubble(
              key: ValueKey(message.idMessage),
              message: message,
              mine: isMine(message),
              showAuthor: showAuthor,
            ),
            _PendingItem(:final pending) => PendingBubble(
              key: ValueKey(pending.localId),
              pending: pending,
              onRetry: () => onRetry(pending.localId),
              onDiscard: () => onDiscard(pending.localId),
            ),
          },
        );
      },
    );
  }
}

class _OlderIndicator extends StatelessWidget {
  const _OlderIndicator({required this.state, required this.onRetry});

  final ChatState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;
    if (state.loadingOlder) {
      child = const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    } else if (state.olderError != null) {
      child = TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Charger les messages précédents'),
      );
    } else if (!state.hasMore) {
      child = Text(
        'Début de la conversation',
        style: theme.textTheme.bodySmall,
      );
    } else {
      child = const SizedBox(height: 22);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(child: child),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(AppFormat.day(day), style: theme.textTheme.labelSmall),
        ),
      ),
    );
  }
}

class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView(
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (var i = 0; i < 8; i++)
          Align(
            alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SkeletonBox(
                width: 140.0 + (i % 3) * 50,
                height: 38,
                radius: 18,
              ),
            ),
          ),
      ],
    ),
  );
}
