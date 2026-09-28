/// Toutes les routes du contrat, centralisées. Aucune autre route n'existe.
abstract final class ApiEndpoints {
  // 1. Session (sans Bearer)
  static const authPrefix = '/api/auth/mobile/';
  static const connexion = '/api/auth/mobile/connexion';
  static const rafraichir = '/api/auth/mobile/rafraichir';
  static const deconnexion = '/api/auth/mobile/deconnexion';

  // 2. Moi
  static const moi = '/api/moi';
  static const profil = '/api/moi/profil';
  static const vehicule = '/api/moi/vehicule';

  // 3. Missions
  static const missions = '/api/moi/missions';
  static String demarrerMission(int idMission) =>
      '/api/moi/missions/$idMission/demarrer';
  static String terminerMission(int idMission) =>
      '/api/moi/missions/$idMission/terminer';

  // 4. Carburant
  static const pleins = '/api/moi/pleins';

  // 5. Incidents
  static const incidents = '/api/moi/incidents';
  static String incidentPhotos(int idIncident) =>
      '/api/moi/incidents/$idIncident/photos';
  static String incidentPhotoFichier(int idPhoto) =>
      '/api/moi/incidents/photos/$idPhoto/fichier';

  // 6. Messagerie
  static const conversations = '/api/messagerie/conversations';
  static const nonLus = '/api/messagerie/non-lus';
  static const contacts = '/api/messagerie/contacts';
  static const conversationPrivee = '/api/messagerie/conversations/privee';
  static String messages(int idConversation) =>
      '/api/messagerie/conversations/$idConversation/messages';
  static String marquerLu(int idConversation) =>
      '/api/messagerie/conversations/$idConversation/lu';
  static String pieceJointe(int idPieceJointe) =>
      '/api/messagerie/pieces-jointes/$idPieceJointe';
  static const ticketTempsReel = '/api/messagerie/ticket-temps-reel';
}
