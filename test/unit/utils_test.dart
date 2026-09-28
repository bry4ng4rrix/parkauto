import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/app/config/app_config.dart';
import 'package:parkauto/core/logging/redaction.dart';
import 'package:parkauto/core/utils/decimal_input.dart';
import 'package:parkauto/core/utils/formatters.dart';
import 'package:parkauto/core/utils/validators.dart';

void main() {
  group('Saisie décimale', () {
    test('virgule, point et espaces acceptés', () {
      expect(DecimalInput.parse('52,5'), 52.5);
      expect(DecimalInput.parse('84 230'), 84230);
      expect(DecimalInput.parse('5200.75'), 5200.75);
      expect(DecimalInput.parse(''), isNull);
      expect(DecimalInput.parse('12,3,4'), isNull);
      expect(DecimalInput.format(84230), '84230');
      expect(DecimalInput.format(52.5), '52,5');
    });
  });

  group('Validations', () {
    test('kilométrage : obligatoire, positif, minimum', () {
      expect(Validators.kilometrage(''), 'Le kilométrage est obligatoire');
      expect(
        Validators.kilometrage('0'),
        'Le kilométrage doit être supérieur à 0',
      );
      expect(Validators.kilometrage('84 360'), isNull);
      expect(
        Validators.kilometrage(
          '84100',
          minimum: 84150,
          minimumLabel: 'au kilométrage de départ',
        ),
        'Ne peut pas être inférieur au kilométrage de départ (84 150 km)',
      );
    });

    test('email et valeurs positives', () {
      expect(Validators.email('tiana@parcauto.local'), isNull);
      expect(Validators.email('tiana'), 'Adresse email invalide');
      expect(
        Validators.positive('-1', label: 'La quantité'),
        'Nombre invalide',
      );
      expect(
        Validators.positive('0', label: 'La quantité'),
        'La quantité doit être supérieur à 0',
      );
    });
  });

  group('Logs : secrets masqués', () {
    test('clés sensibles et JWT', () {
      final redacted = Redactor.redact({
        'email': 'tiana@parcauto.local',
        'motDePasse': 'secret',
        'jetonAcces': 'eyJ.a.b',
        'nested': {'jetonRafraichissement': 'r', 'ticket': 't'},
      });
      expect(redacted, {
        'email': 'tiana@parcauto.local',
        'motDePasse': '***',
        'jetonAcces': '***',
        'nested': {'jetonRafraichissement': '***', 'ticket': '***'},
      });
      expect(
        Redactor.redactUrl('ws://h/ws/messagerie?ticket=abc'),
        'ws://h/ws/messagerie?ticket=***',
      );
      expect(
        Redactor.redactText('Bearer eyJhbGciOi.eyJzdWIi.sig et {"ticket":"x"}'),
        'Bearer *** et {"ticket":"***"}',
      );
    });
  });

  group('Formats', () {
    test('nombres et échéances en français', () {
      expect(AppFormat.km(84230), '84 230 km');
      expect(AppFormat.litres(52.5), '52,5 L');
      expect(AppFormat.remainingDays(3), 'Expire dans 3 jours');
      expect(AppFormat.remainingDays(-28), 'Expiré depuis 28 jours');
      expect(AppFormat.fileSize(412880), '403 Ko');
    });
  });

  test('URL WebSocket dérivée de l’URL de l’API', () {
    expect(
      AppConfig.deriveWsBaseUrl('http://192.168.88.20:8080'),
      'ws://192.168.88.20:8080',
    );
    expect(
      AppConfig.deriveWsBaseUrl('https://api.parkauto.mg'),
      'wss://api.parkauto.mg',
    );
    const config = AppConfig(
      environment: AppEnvironment.dev,
      apiBaseUrl: 'http://h:8080',
      wsBaseUrl: 'ws://h:8080',
    );
    expect(
      config.realtimeUri('a+b/c').toString(),
      'ws://h:8080/ws/messagerie?ticket=a%2Bb%2Fc',
    );
  });
}
