import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';
import 'session.dart';

/// Persistance de la session. Les jetons ne quittent jamais le stockage
/// sécurisé (Keystore Android, Keychain, libsecret sous Linux).
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

  /// Repli si le stockage sécurisé est indisponible (ex. Linux sans
  /// trousseau) : la session reste en mémoire, jamais écrite en clair.
  Session? _memory;

  @override
  Future<Session?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return _memory;
      final session = Session.fromStorage(jsonDecode(raw));
      if (session == null) await clear();
      return session;
    } on Exception catch (e) {
      AppLogger.warning('Session', 'Stockage sécurisé illisible', e);
      return _memory;
    }
  }

  @override
  Future<void> write(Session session) async {
    _memory = session;
    try {
      await _storage.write(key: _key, value: jsonEncode(session.toStorage()));
    } on Exception catch (e) {
      AppLogger.warning(
        'Session',
        'Stockage sécurisé indisponible : session conservée en mémoire',
        e,
      );
    }
  }

  @override
  Future<void> clear() async {
    _memory = null;
    try {
      await _storage.delete(key: _key);
    } on Exception catch (e) {
      AppLogger.warning('Session', 'Effacement de la session impossible', e);
    }
  }

  @override
  Future<void> wipe() async {
    _memory = null;
    try {
      await _storage.deleteAll();
    } on Exception catch (e) {
      AppLogger.warning('Session', 'Effacement du stockage impossible', e);
    }
  }
}
