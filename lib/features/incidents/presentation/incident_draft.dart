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

  // Chaque modification part de l'état courant (jamais d'une copie
  // capturée lors d'un build précédent).
  void setType(TypeIncident type) => state = state.copyWith(type: type);

  void setGravite(Gravite gravite) => state = state.copyWith(gravite: gravite);

  void setDescription(String text) => state = state.copyWith(description: text);

  void setDate(DateTime? date) => state = state.withDate(date);

  void setPhotos(List<LocalPhoto> photos) =>
      state = state.copyWith(photos: photos);

  void clear() => state = const IncidentDraft();
}
