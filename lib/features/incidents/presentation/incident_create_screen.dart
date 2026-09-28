import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_colors.dart';
import '../../../core/domain/api_enum.dart';
import '../../../core/domain/enums.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/submit_button.dart';
import '../data/incidents_repository.dart';
import '../domain/incident.dart';
import 'incident_draft.dart';
import 'incident_widgets.dart';
import 'photo_selection.dart';
import 'photo_upload_controller.dart';

/// `POST /api/moi/incidents`, puis envoi des photos choisies.
class IncidentCreateScreen extends ConsumerStatefulWidget {
  const IncidentCreateScreen({super.key});

  @override
  ConsumerState<IncidentCreateScreen> createState() =>
      _IncidentCreateScreenState();
}

class _IncidentCreateScreenState extends ConsumerState<IncidentCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  bool _submitting = false;
  AppException? _error;

  IncidentDraftNotifier get _draftNotifier =>
      ref.read(incidentDraftProvider.notifier);

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(
      text: ref.read(incidentDraftProvider).description,
    )..addListener(() => _draftNotifier.setDescription(_description.text));
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final draft = ref.read(incidentDraftProvider);
    final now = DateTime.now();
    final current = draft.dateSurvenue ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    _draftNotifier.setDate(picked.isAfter(now) ? now : picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final draft = ref.read(incidentDraftProvider);
    final request = CreateIncidentRequest(
      type: draft.type,
      gravite: draft.gravite,
      description: draft.description,
      dateSurvenue: draft.dateSurvenue,
    );
    final knownIds = {
      for (final i in ref.read(incidentsProvider).value?.value ?? <Incident>[])
        i.idIncident,
    };

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final incident = await ref
          .read(incidentsRepositoryProvider)
          .declarer(request);
      ref.read(incidentsProvider.notifier).prepend(incident);
      _onCreated(incident, draft.photos);
    } on NetworkException catch (e) {
      // Envoi incertain : on vérifie avant de proposer un nouvel essai.
      await ref.read(incidentsProvider.notifier).refresh();
      final created = (ref.read(incidentsProvider).value?.value ?? <Incident>[])
          .where(
            (i) =>
                !knownIds.contains(i.idIncident) &&
                i.description.trim() == request.description.trim(),
          )
          .firstOrNull;
      created != null ? _onCreated(created, draft.photos) : _fail(e);
    } on AppException catch (e) {
      _fail(e);
    }
  }

  void _onCreated(Incident incident, List<LocalPhoto> photos) {
    ref.read(photoUploadProvider(incident.idIncident).notifier).enqueue([
      for (final p in photos) (path: p.path, legende: p.legende),
    ]);
    _draftNotifier.clear();
    if (!mounted) return;
    showSuccessMessage(
      context,
      photos.isEmpty
          ? 'Incident déclaré'
          : 'Incident déclaré · envoi des photos en cours',
    );
    context.pushReplacement(AppRoutes.incident(incident.idIncident));
  }

  void _fail(AppException error) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(incidentDraftProvider);
    final theme = Theme.of(context);
    final fieldErrors = switch (_error) {
      ApiException(:final fieldErrors) => fieldErrors,
      _ => const <String, String>{},
    };

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Déclarer un incident')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error case final error?) ...[
                      InlineMessage.error(error),
                      AppSpacing.gapLg,
                    ],
                    Text('Type', style: theme.textTheme.titleSmall),
                    AppSpacing.gapSm,
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final type in ApiEnum.selectable(
                          TypeIncident.values,
                        ))
                          ChoiceChip(
                            avatar: Icon(incidentTypeIcon(type), size: 18),
                            label: Text(type.label),
                            selected: draft.type == type,
                            showCheckmark: false,
                            onSelected: _submitting
                                ? null
                                : (_) => _draftNotifier.setType(type),
                          ),
                      ],
                    ),
                    AppSpacing.gapXl,
                    Text('Gravité', style: theme.textTheme.titleSmall),
                    AppSpacing.gapSm,
                    _GravitePicker(
                      value: draft.gravite,
                      onChanged: _submitting ? null : _draftNotifier.setGravite,
                    ),
                    AppSpacing.gapXl,
                    TextFormField(
                      controller: _description,
                      enabled: !_submitting,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText:
                            'Ex. Voyant moteur allumé, perte de puissance',
                        alignLabelWithHint: true,
                        errorText: fieldErrors['description'],
                      ),
                      validator: (v) => Validators.required(
                        v,
                        message: "Décrivez ce qui s'est passé",
                      ),
                    ),
                    AppSpacing.gapMd,
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text("Date et heure de l'incident"),
                        subtitle: Text(switch (draft.dateSurvenue) {
                          null => 'Maintenant',
                          final date => AppFormat.dateTime(date),
                        }),
                        trailing: draft.dateSurvenue == null
                            ? const Icon(Icons.edit_calendar_rounded)
                            : IconButton(
                                tooltip: 'Revenir à maintenant',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => _draftNotifier.setDate(null),
                              ),
                        onTap: _submitting ? null : _pickDate,
                      ),
                    ),
                    AppSpacing.gapXl,
                    Text(
                      'Photos (facultatif)',
                      style: theme.textTheme.titleSmall,
                    ),
                    AppSpacing.gapSm,
                    PhotoSelection(
                      photos: draft.photos,
                      enabled: !_submitting,
                      remaining: remainingPhotoSlots(
                        alreadyUploaded: 0,
                        pending: draft.photos.length,
                      ),
                      onChanged: (photos) => _draftNotifier.setPhotos(photos),
                    ),
                    AppSpacing.gapXxl,
                    SubmitButton(
                      label: "Déclarer l'incident",
                      icon: Icons.send_rounded,
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                    AppSpacing.gapXxl,
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

class _GravitePicker extends StatelessWidget {
  const _GravitePicker({required this.value, required this.onChanged});

  final Gravite value;
  final ValueChanged<Gravite>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final g in ApiEnum.selectable(Gravite.values))
          ChoiceChip(
            label: Text(g.label),
            selected: value == g,
            showCheckmark: value == g,
            checkmarkColor: colors.foreground(g.tone),
            selectedColor: colors.background(g.tone),
            onSelected: onChanged == null ? null : (_) => onChanged?.call(g),
          ),
      ],
    );
  }
}
