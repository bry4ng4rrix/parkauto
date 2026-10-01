import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import 'notification_payload.dart';

/// Canaux Android : l'utilisateur peut régler chacun dans les paramètres du
/// téléphone.
enum NotificationChannel {
  messages('messages', 'Messages', 'Nouveaux messages des responsables'),
  missions('missions', 'Missions', 'Nouvelles missions et changements'),
  alertes(
    'alertes',
    'Alertes et échéances',
    'Incidents, alertes véhicule, documents et permis',
  );

  const NotificationChannel(this.id, this.nom, this.description);

  final String id;
  final String nom;
  final String description;
}

/// Notifications système Android (barre de notifications).
abstract interface class LocalNotificationService {
  Future<void> initialize();

  /// Demande l'autorisation (Android 13+, iOS). Renvoie `true` si accordée.
  Future<bool> requestPermission();

  /// Publie une notification. Republier le même [id] la met à jour sans
  /// nouvelle sonnerie.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationChannel channel,
    required NotificationPayload payload,
  });

  /// Retire une notification de la barre.
  Future<void> cancel(int id);

  /// Touchers sur une notification pendant que l'app tourne.
  Stream<NotificationPayload> get taps;

  /// Notification ayant lancé l'app (démarrage à froid), consommée une fois.
  NotificationPayload? takeLaunchPayload();

  Future<void> cancelAll();
}

class PluginLocalNotificationService implements LocalNotificationService {
  PluginLocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<NotificationPayload>.broadcast();
  NotificationPayload? _launchPayload;
  bool _ready = false;

  @override
  Stream<NotificationPayload> get taps => _taps.stream;

  @override
  Future<void> initialize() async {
    if (kIsWeb || _ready) return;
    try {
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
          linux: LinuxInitializationSettings(defaultActionName: 'Ouvrir'),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final channel in NotificationChannel.values) {
        await android?.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            channel.nom,
            description: channel.description,
            importance: Importance.high,
          ),
        );
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchPayload = NotificationPayload.tryDecode(
          launch?.notificationResponse?.payload,
        );
      }
      _ready = true;
    } on Object catch (e) {
      // Plateforme non prise en charge : notifications désactivées.
      AppLogger.warning('Notifications', 'Initialisation impossible', e);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } on Object catch (e) {
      AppLogger.warning('Notifications', 'Permission non obtenue', e);
      return false;
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationChannel channel,
    required NotificationPayload payload,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload.encode(),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.nom,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            onlyAlertOnce: true,
            category: channel == NotificationChannel.messages
                ? AndroidNotificationCategory.message
                : AndroidNotificationCategory.event,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
          linux: const LinuxNotificationDetails(),
        ),
      );
      AppLogger.debug('Notifications', 'Notification système publiée ($id)');
    } on Object catch (e) {
      AppLogger.warning('Notifications', 'Affichage impossible', e);
    }
  }

  @override
  NotificationPayload? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  @override
  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } on Object catch (e) {
      AppLogger.warning('Notifications', 'Retrait impossible', e);
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } on Object catch (e) {
      AppLogger.warning('Notifications', 'Effacement impossible', e);
    }
  }

  void _onResponse(NotificationResponse response) {
    final payload = NotificationPayload.tryDecode(response.payload);
    AppLogger.debug('Notifications', 'Notification touchée');
    if (payload != null && !_taps.isClosed) _taps.add(payload);
  }
}

/// Identifiant Android stable (FNV-1a 31 bits) dérivé d'un identifiant texte :
/// la même notification garde le même numéro d'un processus à l'autre.
int stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => PluginLocalNotificationService(),
);
