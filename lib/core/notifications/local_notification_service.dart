import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import 'notification_payload.dart';

/// Notifications système locales (messages reçus en arrière-plan).
abstract interface class LocalNotificationService {
  Future<void> initialize();

  /// Demande l'autorisation (Android 13+, iOS). Renvoie `true` si accordée.
  Future<bool> requestPermission();

  Future<void> showMessage({
    required int id,
    required String title,
    required String body,
    required NotificationPayload payload,
  });

  /// Touchers sur une notification pendant que l'app tourne.
  Stream<NotificationPayload> get taps;

  /// Notification ayant lancé l'app (démarrage à froid), consommée une fois.
  NotificationPayload? takeLaunchPayload();

  Future<void> cancelAll();
}

class PluginLocalNotificationService implements LocalNotificationService {
  PluginLocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'Nouveaux messages des responsables',
    importance: Importance.high,
  );

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
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchPayload = NotificationPayload.tryDecode(
          launch?.notificationResponse?.payload,
        );
      }
      _ready = true;
    } on Object catch (e) {
      // Plateforme non prise en charge (ex. Windows) : notifications désactivées.
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
  Future<void> showMessage({
    required int id,
    required String title,
    required String body,
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
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
          linux: const LinuxNotificationDetails(),
        ),
      );
      AppLogger.debug('Notifications', 'Notification affichée ($id)');
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

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => PluginLocalNotificationService(),
);
