import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../data/conversations_provider.dart';
import '../data/messaging_repository.dart';
import '../domain/messaging_models.dart';

/// `GET /api/messagerie/contacts`.
final contactsProvider = FutureProvider.autoDispose<List<Contact>>(
  (ref) => ref.watch(messagingRepositoryProvider).contacts(),
);

/// Choix d'un destinataire, puis `POST /api/messagerie/conversations/privee`.
class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int? _opening;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => setState(() => _query = value.trim().toLowerCase()),
    );
  }

  Future<void> _open(Contact contact) async {
    if (_opening != null) return;
    setState(() => _opening = contact.idUtilisateur);
    try {
      final conversation = await ref
          .read(messagingRepositoryProvider)
          .ouvrirConversationPrivee(contact.idUtilisateur);
      ref.read(conversationsProvider.notifier).upsert(conversation);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.chat(conversation.idConversation));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _opening = null);
      showErrorMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Rechercher un contact',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: switch (contacts) {
              AsyncValue(value: final list?) => _ContactList(
                contacts: [
                  for (final c in list)
                    if (_query.isEmpty ||
                        c.nomComplet.toLowerCase().contains(_query) ||
                        c.roleLabel.toLowerCase().contains(_query))
                      c,
                ]..sort((a, b) => a.nomComplet.compareTo(b.nomComplet)),
                opening: _opening,
                onTap: _open,
              ),
              AsyncValue(error: final error?) => ErrorState(
                error: error,
                onRetry: () => ref.invalidate(contactsProvider),
              ),
              _ => const SkeletonList(count: 6, lines: 1),
            },
          ),
        ],
      ),
    );
  }
}

class _ContactList extends StatelessWidget {
  const _ContactList({
    required this.contacts,
    required this.opening,
    required this.onTap,
  });

  final List<Contact> contacts;
  final int? opening;
  final ValueChanged<Contact> onTap;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_rounded,
        title: 'Aucun contact trouvé',
      );
    }
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final busy = opening == contact.idUtilisateur;
        return ResponsiveCenter(
          child: ListTile(
            enabled: opening == null || busy,
            leading: InitialsAvatar(label: contact.nomComplet),
            title: Text(contact.nomComplet),
            subtitle: Text(contact.roleLabel),
            trailing: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: () => onTap(contact),
          ),
        );
      },
    );
  }
}
