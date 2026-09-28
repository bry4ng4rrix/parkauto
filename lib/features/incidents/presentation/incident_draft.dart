import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/domain/enums.dart';
import 'photo_selection.dart';

/// Déclaration en cours, conservée en mémoire.
@immutable
class IncidentDraft {
  const IncidentDraft({
    this.type = TypeIncident.panne,
    this.gravite = Gravite.moyenne,
    this.description = '',
    this.dateSurvenue,
    this.photos = const [],
  });

  final TypeIncident type;
  final Gravite gravite;
  final String description;

  /// `null` : maintenant (le serveur horodate).
  final DateTime? dateSurvenue;
  final List<LocalPhoto> photos;

  IncidentDraft copyWith({
    TypeIncident? type,
    Gravite? gravite,
    String? description,
    List<LocalPhoto>? photos,
  }) => IncidentDraft(
    type: type ?? this.type,
    gravite: gravite ?? this.gravite,
    description: description ?? this.description,
    dateSurvenue: dateSurvenue,
    photos: photos ?? this.photos,
  );

  IncidentDraft withDate(DateTime? value) => IncidentDraft(
    type: type,
    gravite: gravite,
    description: description,
    dateSurvenue: value,
    photos: photos,
  );
}

final incidentDraftProvider =
    NotifierProvider<IncidentDraftNotifier, IncidentDraft>(
      IncidentDraftNotifier.new,
    );

class IncidentDraftNotifier extends Notifier<IncidentDraft> {
  @override
  IncidentDraft build() {
    ref.watch(currentDriverIdProvider);
    return const IncidentDraft();
  }

  void update(IncidentDraft draft) => state = draft;

  void clear() => state = const IncidentDraft();
}
