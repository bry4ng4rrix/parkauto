import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/api_enum.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/tone.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/decimal_input.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/submit_button.dart';
import '../../home/data/moi_repository.dart';
import '../../vehicle/data/vehicle_repository.dart';
import '../../vehicle/domain/vehicule.dart';
import '../data/fuel_repository.dart';
import '../domain/fuel_entry.dart';
import 'fuel_draft.dart';
import 'fuel_list_screen.dart';

/// `POST /api/moi/pleins`.
class FuelCreateScreen extends ConsumerStatefulWidget {
  const FuelCreateScreen({super.key});

  @override
  ConsumerState<FuelCreateScreen> createState() => _FuelCreateScreenState();
}

class _FuelCreateScreenState extends ConsumerState<FuelCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _km;
  late final TextEditingController _litres;
  late final TextEditingController _prix;
  late final TextEditingController _station;
  bool _submitting = false;
  AppException? _error;

  FuelDraft get _draft => ref.read(fuelDraftProvider);

  VehiculeSummary? get _vehicle =>
      switch (ref.read(vehicleProvider).value?.value) {
        VehicleAssigned(:final details) => details.vehicule,
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    final draft = _draft;
    final lastPrice = ref
        .read(fuelEntriesProvider)
        .value
        ?.value
        .firstOrNull
        ?.prixUnitaire;
    final vehicleKm = _vehicle?.kilometrage;
    _km = TextEditingController(
      text: draft.kilometrage.isNotEmpty || vehicleKm == null
          ? draft.kilometrage
          : DecimalInput.format(vehicleKm),
    );
    _litres = TextEditingController(text: draft.litres);
    _prix = TextEditingController(
      text: draft.prix.isNotEmpty || lastPrice == null
          ? draft.prix
          : DecimalInput.format(lastPrice),
    );
    _station = TextEditingController(text: draft.station);
    for (final c in [_km, _litres, _prix, _station]) {
      c.addListener(_saveDraft);
    }
  }

  @override
  void dispose() {
    _km.dispose();
    _litres.dispose();
    _prix.dispose();
    _station.dispose();
    super.dispose();
  }

  void _saveDraft() {
    ref
        .read(fuelDraftProvider.notifier)
        .update(
          _draft.copyWith(
            kilometrage: _km.text,
            litres: _litres.text,
            prix: _prix.text,
            station: _station.text,
          ),
        );
    setState(() {}); // Aperçu du montant.
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _draft.dateHeure ?? now;
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
    ref
        .read(fuelDraftProvider.notifier)
        .setDate(picked.isAfter(now) ? now : picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final km = DecimalInput.parse(_km.text);
    final litres = DecimalInput.parse(_litres.text);
    final prix = DecimalInput.parse(_prix.text);
    if (km == null || litres == null || prix == null) return;

    final draft = _draft;
    final request = CreateFuelRequest(
      typeApprovisionnement: draft.type,
      kilometrageAuPlein: km,
      quantiteLitres: litres,
      prixUnitaire: prix,
      station: _station.text,
      dateHeure: draft.dateHeure,
    );
    final knownIds = {
      for (final e
          in ref.read(fuelEntriesProvider).value?.value ?? <FuelEntry>[])
        e.idCarburant,
    };

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final entry = await ref.read(fuelRepositoryProvider).declarer(request);
      ref.read(fuelEntriesProvider.notifier).prepend(entry);
      _onSuccess();
    } on NetworkException catch (e) {
      // Envoi incertain : jamais de nouvel essai automatique, on vérifie.
      await ref.read(fuelEntriesProvider.notifier).refresh();
      final recorded = (ref.read(fuelEntriesProvider).value?.value ?? []).any(
        (f) =>
            !knownIds.contains(f.idCarburant) &&
            f.kilometrageAuPlein == km &&
            f.quantiteLitres == litres,
      );
      recorded ? _onSuccess() : _fail(e);
    } on AppException catch (e) {
      _fail(e);
    }
  }

  void _onSuccess() {
    ref.read(fuelDraftProvider.notifier).clear();
    unawaited(ref.read(vehicleProvider.notifier).refresh());
    unawaited(ref.read(moiProvider.notifier).refresh());
    if (!mounted) return;
    showSuccessMessage(context, 'Réapprovisionnement enregistré');
    Navigator.of(context).pop();
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
    final draft = ref.watch(fuelDraftProvider);
    final currency = ref.watch(appConfigProvider).currencyLabel;
    final noVehicle = ref.watch(vehicleProvider).value?.value is NoVehicle;
    final vehicleKm = _vehicle?.kilometrage;
    final fieldErrors = switch (_error) {
      ApiException(:final fieldErrors) => fieldErrors,
      _ => const <String, String>{},
    };
    final litres = DecimalInput.parse(_litres.text);
    final prix = DecimalInput.parse(_prix.text);

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Réapprovisionnement de carburant')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (noVehicle) ...[
                      const InlineMessage(
                        message:
                            '${NoVehicle.message} : la déclaration risque '
                            "d'être refusée.",
                        tone: Tone.warning,
                      ),
                      AppSpacing.gapLg,
                    ],
                    if (_error case final error?) ...[
                      InlineMessage.error(error),
                      AppSpacing.gapLg,
                    ],
                    Text(
                      "Type d'approvisionnement",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    AppSpacing.gapSm,
                    SegmentedButton<TypeApprovisionnement>(
                      segments: [
                        for (final type in ApiEnum.selectable(
                          TypeApprovisionnement.values,
                        ))
                          ButtonSegment(
                            value: type,
                            label: Text(type.label),
                            icon: Icon(fuelTypeIcon(type)),
                          ),
                      ],
                      selected: {draft.type},
                      showSelectedIcon: false,
                      onSelectionChanged: _submitting
                          ? null
                          : (s) => ref
                                .read(fuelDraftProvider.notifier)
                                .setType(s.first),
                    ),
                    AppSpacing.gapXl,
                    TextFormField(
                      controller: _km,
                      enabled: !_submitting,
                      keyboardType: DecimalInput.keyboardType,
                      inputFormatters: DecimalInput.formatters,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Kilométrage au compteur',
                        suffixText: 'km',
                        prefixIcon: const Icon(Icons.speed_rounded),
                        helperText: vehicleKm == null
                            ? null
                            : 'Compteur actuel : ${AppFormat.km(vehicleKm)}',
                        errorText: fieldErrors['kilometrageAuPlein'],
                      ),
                      validator: (v) =>
                          Validators.kilometrage(v, minimum: vehicleKm),
                    ),
                    AppSpacing.gapLg,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _litres,
                            enabled: !_submitting,
                            keyboardType: DecimalInput.keyboardType,
                            inputFormatters: DecimalInput.formatters,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Quantité',
                              suffixText: 'L',
                              errorText: fieldErrors['quantiteLitres'],
                            ),
                            validator: (v) =>
                                Validators.positive(v, label: 'La quantité'),
                          ),
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: TextFormField(
                            controller: _prix,
                            enabled: !_submitting,
                            keyboardType: DecimalInput.keyboardType,
                            inputFormatters: DecimalInput.formatters,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Prix unitaire',
                              suffixText: '$currency/L',
                              errorText: fieldErrors['prixUnitaire'],
                            ),
                            validator: (v) =>
                                Validators.positive(v, label: 'Le prix'),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapLg,
                    TextFormField(
                      controller: _station,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Station (facultatif)',
                        prefixIcon: const Icon(Icons.place_outlined),
                        errorText: fieldErrors['station'],
                      ),
                    ),
                    AppSpacing.gapLg,
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text('Date et heure'),
                        subtitle: Text(switch (draft.dateHeure) {
                          null => 'Maintenant',
                          final date => AppFormat.dateTime(date),
                        }),
                        trailing: draft.dateHeure == null
                            ? const Icon(Icons.edit_calendar_rounded)
                            : IconButton(
                                tooltip: 'Revenir à maintenant',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => ref
                                    .read(fuelDraftProvider.notifier)
                                    .setDate(null),
                              ),
                        onTap: _submitting ? null : _pickDate,
                      ),
                    ),
                    AppSpacing.gapXl,
                    _TotalPreview(
                      litres: litres,
                      prix: prix,
                      currency: currency,
                    ),
                    AppSpacing.gapXxl,
                    SubmitButton(
                      label: 'Enregistrer',
                      icon: Icons.check_rounded,
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

/// Aperçu `quantité × prix unitaire = montant total` avant validation.
class _TotalPreview extends StatelessWidget {
  const _TotalPreview({
    required this.litres,
    required this.prix,
    required this.currency,
  });

  final double? litres;
  final double? prix;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (l, p) = (litres, prix);
    final ready = l != null && p != null && l > 0 && p > 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.lgAll,
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Montant total', style: theme.textTheme.bodySmall),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      ready ? AppFormat.money(l * p, currency) : '—',
                      key: ValueKey(ready ? l * p : -1),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
            ),
            if (ready)
              Text(
                '${AppFormat.litres(l)} × ${AppFormat.money(p, currency)}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
