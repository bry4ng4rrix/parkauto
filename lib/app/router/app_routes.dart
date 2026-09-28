/// Chemins de navigation (uniquement des chemins : pas d'`extra`, ce qui
/// permet d'ouvrir un écran depuis une notification).
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';

  // Onglets
  static const home = '/home';
  static const missions = '/missions';
  static const messages = '/messages';
  static const profile = '/profile';

  // Écrans plein écran
  static String mission(int idMission) => '/mission/$idMission';
  static String chat(int idConversation) => '/chat/$idConversation';
  static const contacts = '/contacts';
  static const notifications = '/notifications';
  static const vehicle = '/vehicle';
  static const fuel = '/fuel';
  static const fuelNew = '/fuel/new';
  static const incidents = '/incidents';
  static const incidentNew = '/incidents/new';
  static String incident(int idIncident) => '/incidents/$idIncident';
  static String incidentPhotos(int idIncident) =>
      '/incidents/$idIncident/photos';
  static const settings = '/settings';
}
