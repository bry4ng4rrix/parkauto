import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/domain/enums.dart';

/// Saisie en cours, conservée en mémoire (navigation, erreur réseau).
@immutable
class FuelDraft {
  const FuelDraft({
    this.type = TypeApprovisionnement.pleinComplet,
    this.kilometrage = '',
    this.litres = '',
    this.prix = '',
    this.station = '',
    this.dateHeure,
  });

  final TypeApprovisionnement type;
  final String kilometrage;
  final String litres;
  final String prix;
  final String station;

  /// `null` : maintenant (le serveur horodate).
  final DateTime? dateHeure;

  FuelDraft copyWith({
    TypeApprovisionnement? type,
    String? kilometrage,
    String? litres,
    String? prix,
    String? station,
  }) => FuelDraft(
    type: type ?? this.type,
    kilometrage: kilometrage ?? this.kilometrage,
    litres: litres ?? this.litres,
    prix: prix ?? this.prix,
    station: station ?? this.station,
    dateHeure: dateHeure,
  );

  FuelDraft withDate(DateTime? value) => FuelDraft(
    type: type,
    kilometrage: kilometrage,
    litres: litres,
    prix: prix,
    station: station,
    dateHeure: value,
  );
}

final fuelDraftProvider = NotifierProvider<FuelDraftNotifier, FuelDraft>(
  FuelDraftNotifier.new,
);

class FuelDraftNotifier extends Notifier<FuelDraft> {
  @override
  FuelDraft build() {
    ref.watch(currentDriverIdProvider);
    return const FuelDraft();
  }

  void update(FuelDraft draft) => state = draft;

  void clear() => state = const FuelDraft();
}
