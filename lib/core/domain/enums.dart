import 'api_enum.dart';
import 'tone.dart';

// Énumérations du contrat (`conventions.enumerations`).

enum CategorieEngin with ApiEnum {
  vehiculeRoutier('VEHICULE_ROUTIER', 'Véhicule routier'),
  enginChantier('ENGIN_CHANTIER', 'Engin de chantier'),
  inconnu('', 'Catégorie inconnue');

  const CategorieEngin(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;
}

enum StatutConducteur with ApiEnum {
  enService('EN_SERVICE', 'En service', Tone.success),
  suspendu('SUSPENDU', 'Suspendu', Tone.danger),
  conge('CONGE', 'En congé', Tone.warning),
  inactif('INACTIF', 'Inactif', Tone.neutral),
  inconnu('', 'Statut inconnu', Tone.neutral);

  const StatutConducteur(this.apiValue, this.label, this.tone);

  @override
  final String apiValue;
  @override
  final String label;
  final Tone tone;
}

enum NiveauEcheance with ApiEnum {
  ok('OK', 'À jour', Tone.success),
  bientot('BIENTOT', 'Expire bientôt', Tone.warning),
  expire('EXPIRE', 'Expiré', Tone.danger),
  sansDate('SANS_DATE', 'Sans date', Tone.neutral),
  inconnu('', 'Inconnu', Tone.neutral);

  const NiveauEcheance(this.apiValue, this.label, this.tone);

  @override
  final String apiValue;
  @override
  final String label;
  final Tone tone;

  bool get needsAttention => this == bientot || this == expire;
}

enum TypeQualification with ApiEnum {
  permis('PERMIS', 'Permis de conduire'),
  caces('CACES', 'CACES'),
  inconnu('', 'Qualification');

  const TypeQualification(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;
}

enum StatutEngin with ApiEnum {
  disponible('DISPONIBLE', 'Disponible', Tone.success),
  affecte('AFFECTE', 'Affecté', Tone.info),
  enMission('EN_MISSION', 'En mission', Tone.info),
  enPanne('EN_PANNE', 'En panne', Tone.danger),
  enMaintenance('EN_MAINTENANCE', 'En maintenance', Tone.warning),
  reforme('REFORME', 'Réformé', Tone.neutral),
  vendu('VENDU', 'Vendu', Tone.neutral),
  inconnu('', 'Statut inconnu', Tone.neutral);

  const StatutEngin(this.apiValue, this.label, this.tone);

  @override
  final String apiValue;
  @override
  final String label;
  final Tone tone;
}

enum SourceVehicule with ApiEnum {
  mission('MISSION', 'Via la mission en cours'),
  affectation('AFFECTATION', 'Affectation'),
  inconnu('', 'Source inconnue');

  const SourceVehicule(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;
}

enum Energie with ApiEnum {
  gasoil('GASOIL', 'Gasoil'),
  essence('ESSENCE', 'Essence'),
  electrique('ELECTRIQUE', 'Électrique'),
  hybride('HYBRIDE', 'Hybride'),
  autre('AUTRE', 'Autre'),
  inconnu('', 'Inconnue');

  const Energie(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;
}

enum TypeDocument with ApiEnum {
  carteGrise('CARTE_GRISE', 'Carte grise'),
  assurance('ASSURANCE', 'Assurance'),
  visiteTechnique('VISITE_TECHNIQUE', 'Visite technique'),
  permisConduire('PERMIS_CONDUIRE', 'Permis de conduire'),
  autre('AUTRE', 'Autre document'),
  conformiteFiscale('CONFORMITE_FISCALE', 'Conformité fiscale'),
  licenceTransport('LICENCE_TRANSPORT', 'Licence de transport'),
  carteCarburant('CARTE_CARBURANT', 'Carte carburant'),
  inconnu('', 'Document');

  const TypeDocument(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;
}

enum StatutMission with ApiEnum {
  planifiee('PLANIFIEE', 'Planifiée', Tone.info),
  enCours('EN_COURS', 'En cours', Tone.success),
  terminee('TERMINEE', 'Terminée', Tone.neutral),
  annulee('ANNULEE', 'Annulée', Tone.danger),
  inconnu('', 'Statut inconnu', Tone.neutral);

  const StatutMission(this.apiValue, this.label, this.tone);

  @override
  final String apiValue;
  @override
  final String label;
  final Tone tone;
}

enum TypeApprovisionnement with ApiEnum {
  pleinComplet('PLEIN_COMPLET', 'Plein complet'),
  appoint('APPOINT', 'Appoint'),
  bidon('BIDON', 'Bidon'),
  inconnu('', 'Approvisionnement');

  const TypeApprovisionnement(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;
}

enum TypeIncident with ApiEnum {
  accident('ACCIDENT', 'Accident'),
  panne('PANNE', 'Panne'),
  vol('VOL', 'Vol'),
  autre('AUTRE', 'Autre'),
  inconnu('', 'Incident');

  const TypeIncident(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;
}

/// Gravité d'un incident et priorité d'une alerte.
enum Gravite with ApiEnum {
  faible('FAIBLE', 'Faible', Tone.info),
  moyenne('MOYENNE', 'Moyenne', Tone.warning),
  elevee('ELEVEE', 'Élevée', Tone.danger),
  critique('CRITIQUE', 'Critique', Tone.danger),
  inconnu('', 'Inconnue', Tone.neutral);

  const Gravite(this.apiValue, this.label, this.tone);

  @override
  final String apiValue;
  @override
  final String label;
  final Tone tone;
}

enum StatutIncident with ApiEnum {
  declare('DECLARE', 'Déclaré', Tone.warning),
  enTraitement('EN_TRAITEMENT', 'En traitement', Tone.info),
  cloture('CLOTURE', 'Clôturé', Tone.success),
  inconnu('', 'Statut inconnu', Tone.neutral);

  const StatutIncident(this.apiValue, this.label, this.tone);

  @override
  final String apiValue;
  @override
  final String label;
  final Tone tone;
}

enum TypeAlerte with ApiEnum {
  survitesse('SURVITESSE', 'Survitesse'),
  deplacementAnormal('DEPLACEMENT_ANORMAL', 'Déplacement anormal'),
  arretProlonge('ARRET_PROLONGE', 'Arrêt prolongé'),
  entreeZoneInterdite('ENTREE_ZONE_INTERDITE', 'Entrée en zone interdite'),
  sortieZoneAutorisee('SORTIE_ZONE_AUTORISEE', 'Sortie de zone autorisée'),
  perteConnexionGps('PERTE_CONNEXION_GPS', 'Perte du signal GPS'),
  gpsDesactivePendantMission(
    'GPS_DESACTIVE_PENDANT_MISSION',
    'GPS désactivé pendant la mission',
  ),
  stockPieceBas('STOCK_PIECE_BAS', 'Stock de pièces bas'),
  maintenanceAPrevoir('MAINTENANCE_A_PREVOIR', 'Maintenance à prévoir'),
  consommationAnormale('CONSOMMATION_ANORMALE', 'Consommation anormale'),
  baisseCarburantSuspecte(
    'BAISSE_CARBURANT_SUSPECTE',
    'Baisse de carburant suspecte',
  ),
  documentExpire('DOCUMENT_EXPIRE', 'Document expiré'),
  documentAExpirer('DOCUMENT_A_EXPIRER', 'Document bientôt expiré'),
  incidentCritique('INCIDENT_CRITIQUE', 'Incident critique'),
  inconnu('', 'Alerte');

  const TypeAlerte(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;
}

enum TypeConversation with ApiEnum {
  privee('PRIVEE', 'Conversation privée'),
  canal('CANAL', 'Canal'),
  fil('FIL', 'Fil de discussion'),
  inconnu('', 'Conversation');

  const TypeConversation(this.apiValue, this.label);

  @override
  final String apiValue;
  @override
  final String label;

  /// Plusieurs participants : le nom de l'auteur est affiché sur chaque bulle.
  bool get isGroup => this == canal || this == fil;
}

/// Rôles des utilisateurs (`role`). Le contrat n'énumère que `CONDUCTEUR` ;
/// les contacts ont d'autres rôles, donc le champ reste un texte.
abstract final class UserRoles {
  static const conducteur = 'CONDUCTEUR';

  static const _labels = {
    'CONDUCTEUR': 'Conducteur',
    'RESPONSABLE_PARC': 'Responsable du parc',
    'CHEF_MAINTENANCE': 'Chef maintenance',
    'ADMINISTRATEUR': 'Administrateur',
    'COMPTABLE': 'Comptable',
    'DG': 'Direction générale',
  };

  static String label(String role) {
    final known = _labels[role];
    if (known != null) return known;
    final words = role.toLowerCase().split('_').where((w) => w.isNotEmpty);
    final text = words.join(' ');
    return text.isEmpty ? role : '${text[0].toUpperCase()}${text.substring(1)}';
  }
}
