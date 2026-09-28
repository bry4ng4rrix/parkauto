import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';
import 'session.dart';

/// Persistance de la session. Les jetons ne quittent jamais le stockage
/// sécurisé (Keystore / Keychain).
abstract interface class SessionStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();

  /// Efface tout (le Keychain iOS survit à la désinstallation).
  Future<void> wipe();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _key = 'parkauto.session';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final session = Session.fromStorage(jsonDecode(raw));
      if (session == null) await clear();
      return session;
    } on Exception catch (e) {
      AppLogger.warning('Session', 'Lecture de la session impossible', e);
      return null;
    }
  }

  @override
  Future<void> write(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toStorage()));

  @override
  Future<void> clear() => _storage.delete(key: _key);

  @override
  Future<void> wipe() => _storage.deleteAll();
}
