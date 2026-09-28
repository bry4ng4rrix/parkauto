import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/enums.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/decimal_input.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/submit_button.dart';
import '../../home/data/moi_repository.dart';
import '../../vehicle/data/vehicle_repository.dart';
import '../../vehicle/domain/vehicule.dart';
import '../data/missions_repository.dart';
import '../domain/mission.dart';

enum MissionAction {
  start('Démarrer la mission', 'Démarrer', StatutMission.enCours),
  finish('Terminer la mission', 'Terminer', StatutMission.terminee);

  const MissionAction(this.title, this.verb, this.expectedStatus);

  final String title;
  final String verb;
  final StatutMission expectedStatus;
}

/// Démarre ou termine [mission] après saisie du kilométrage et
/// confirmation. Met à jour missions, accueil et véhicule.
Future<void> showMissionActionSheet(
  BuildContext context,
  Mission mission,
  MissionAction action,
) async {
  final updated = await showModalBottomSheet<Mission>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MissionActionSheet(mission: mission, action: action),
  );
  if (updated != null && context.mounted) {
    showSuccessMessage(
      context,
      action == MissionAction.start ? 'Mission démarrée' : 'Mission terminée',
    );
  }
}

class _MissionActionSheet extends ConsumerStatefulWidget {
  const _MissionActionSheet({required this.mission, required this.action});

  final Mission mission;
  final MissionAction action;

  @override
  ConsumerState<_MissionActionSheet> createState() =>
      _MissionActionSheetState();
}

class _MissionActionSheetState extends ConsumerState<_MissionActionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _km = TextEditingController();
  bool _submitting = false;
  AppException? _error;

  Mission get _mission => widget.mission;

  /// Compteur du véhicule de la mission (le contrôle n'a de sens que pour
  /// ce véhicule).
  double? _vehicleKm(VehicleState? state) => switch (state) {
    VehicleAssigned(:final details)
        when details.vehicule.idEngin == _mission.idEngin =>
      details.vehicule.kilometrage,
    _ => null,
  };

  /// Minimum accepté : compteur du véhicule au démarrage, kilométrage de
  /// départ à la fin.
  ({double value, String helper, String label})? _minimum(double? vehicleKm) {
    final depart = _mission.kilometrageDepart;
    return switch (widget.action) {
      MissionAction.start when vehicleKm != null => (
        value: vehicleKm,
        helper: 'Compteur actuel : ${AppFormat.km(vehicleKm)}',
        label: 'au kilométrage actuel du véhicule',
      ),
      MissionAction.finish when depart != null => (
        value: depart,
        helper: 'Kilométrage de départ : ${AppFormat.km(depart)}',
        label: 'au kilométrage de départ',
      ),
      _ => null,
    };
  }

  /// Pré-remplissage avec la meilleure valeur connue.
  void _prefill(double? vehicleKm) {
    if (_km.text.isNotEmpty) return;
    final candidates = [
      vehicleKm,
      _mission.kilometrageDepart,
    ].whereType<double>();
    if (candidates.isEmpty) return;
    _km.text = DecimalInput.format(candidates.reduce((a, b) => a > b ? a : b));
  }

  @override
  void initState() {
    super.initState();
    _prefill(_vehicleKm(ref.read(vehicleProvider).value?.value));
  }

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final km = DecimalInput.parse(_km.text);
    if (km == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: widget.action.title,
      message:
          '${widget.action.verb} « ${_mission.motif} » avec un kilométrage de '
          '${AppFormat.km(km)} ?',
      confirmLabel: widget.action.verb,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await _perform(km);
      ref.read(missionsProvider.notifier).replace(updated);
      unawaited(ref.read(moiProvider.notifier).refresh());
      unawaited(ref.read(vehicleProvider.notifier).refresh());
      if (mounted) Navigator.of(context).pop(updated);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e;
        });
      }
    }
  }

  /// POST non idempotent : après un échec incertain (réseau, 409), on
  /// relit les missions pour constater l'état réel avant d'afficher
  /// une erreur.
  Future<Mission> _perform(double km) async {
    final repository = ref.read(missionsRepositoryProvider);
    try {
      return widget.action == MissionAction.start
          ? await repository.demarrer(_mission.idMission, km)
          : await repository.terminer(_mission.idMission, km);
    } on AppException catch (e) {
      final uncertain =
          e is NetworkException || (e is ApiException && e.isConflict);
      if (!uncertain) rethrow;
      final missions = ref.read(missionsProvider.notifier);
      await missions.refresh();
      for (final m in ref.read(missionsProvider).value?.value ?? <Mission>[]) {
        if (m.idMission == _mission.idMission &&
            m.statut == widget.action.expectedStatus) {
          return m;
        }
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Le véhicule peut arriver après l'ouverture de la feuille.
    final vehicleKm = _vehicleKm(ref.watch(vehicleProvider).value?.value);
    ref.listen(
      vehicleProvider,
      (_, next) => _prefill(_vehicleKm(next.value?.value)),
    );
    final minimum = _minimum(vehicleKm);
    final fieldError = switch (_error) {
      ApiException(:final fieldErrors) => fieldErrors['kilometrage'],
      _ => null,
    };
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.action.title, style: theme.textTheme.titleLarge),
              AppSpacing.gapXs,
              Text(
                '${_mission.motif}\n${_mission.vehicule}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.gapXl,
              if (_error case final error?) ...[
                InlineMessage.error(error),
                AppSpacing.gapLg,
              ],
              TextFormField(
                controller: _km,
                autofocus: true,
                enabled: !_submitting,
                keyboardType: DecimalInput.keyboardType,
                inputFormatters: DecimalInput.formatters,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Kilométrage actuel',
                  suffixText: 'km',
                  prefixIcon: const Icon(Icons.speed_rounded),
                  helperText: minimum?.helper,
                  errorText: fieldError,
                ),
                validator: (value) => Validators.kilometrage(
                  value,
                  minimum: minimum?.value,
                  minimumLabel: minimum?.label ?? '',
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              AppSpacing.gapXxl,
              SubmitButton(
                label: widget.action.title,
                icon: widget.action == MissionAction.start
                    ? Icons.play_arrow_rounded
                    : Icons.flag_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
