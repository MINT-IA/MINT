import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/rag_error_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rateLimitCopy = <String, String>{
    'fr': 'Limite d’utilisation atteinte. Réessaie plus tard.',
    'en': 'Usage limit reached. Try again later.',
    'de': 'Nutzungslimit erreicht. Versuche es später erneut.',
    'es': 'Límite de uso alcanzado. Inténtalo de nuevo más tarde.',
    'it': 'Limite di utilizzo raggiunto. Riprova più tardi.',
    'pt': 'Limite de utilização atingido. Tenta novamente mais tarde.',
  };
  const unavailableCopy = <String, String>{
    'fr': 'Le service n’est pas disponible pour le moment. Réessaie plus tard.',
    'en': 'The service is not available at the moment. Try again later.',
    'de': 'Der Dienst ist momentan nicht verfügbar. Versuche es später erneut.',
    'es':
        'El servicio no está disponible en este momento. Inténtalo de nuevo más tarde.',
    'it': 'Il servizio non è disponibile al momento. Riprova più tardi.',
    'pt':
        'O serviço não está disponível de momento. Tenta novamente mais tarde.',
  };

  test('429 and 503 keep machine identity outside presentation copy', () {
    final rateLimit = RagApiException.machine(RagErrorCode.rateLimit);
    final unavailable =
        RagApiException.machine(RagErrorCode.serviceUnavailable);

    expect(rateLimit.code, 'rate_limit');
    expect(rateLimit.message, isEmpty);
    expect(rateLimit.toString(), 'RagApiException(rate_limit)');
    expect(unavailable.code, 'service_unavailable');
    expect(unavailable.message, isEmpty);
    expect(unavailable.code, isNot(rateLimit.code));
  });

  for (final locale in rateLimitCopy.keys) {
    test('RAG and Coach resolve 429/503 copy in $locale', () async {
      final l10n = await S.delegate.load(Locale(locale));

      expect(
        RagErrorCode.rateLimit.localizedRagMessage(
          l10n,
          fallback: l10n.docScanGenericError,
        ),
        rateLimitCopy[locale],
      );
      expect(
        RagErrorCode.rateLimit.localizedCoachMessage(l10n),
        rateLimitCopy[locale],
      );
      expect(
        RagErrorCode.serviceUnavailable.localizedRagMessage(
          l10n,
          fallback: l10n.docScanGenericError,
        ),
        unavailableCopy[locale],
      );
      expect(
        RagErrorCode.serviceUnavailable.localizedCoachMessage(l10n),
        unavailableCopy[locale],
      );
    });
  }

  test('presentation resolvers never render arbitrary backend detail',
      () async {
    final l10n = await S.delegate.load(const Locale('en'));
    const backendDetail = '<script>provider detail</script>';
    const error = RagApiException(
      code: 'rate_limit',
      message: backendDetail,
    );

    expect(
      error.errorCode.localizedRagMessage(
        l10n,
        fallback: l10n.docScanGenericError,
      ),
      rateLimitCopy['en'],
    );
    expect(
      error.errorCode.localizedCoachMessage(l10n),
      rateLimitCopy['en'],
    );
    expect(
      error.errorCode.localizedRagMessage(
        l10n,
        fallback: l10n.docScanGenericError,
      ),
      isNot(contains(backendDetail)),
    );
  });

  test('all live UI consumers resolve the machine code at their boundary', () {
    final byok =
        File('lib/screens/byok_settings_screen.dart').readAsStringSync();
    final coach =
        File('lib/screens/coach/coach_chat_screen.dart').readAsStringSync();
    final scan = File('lib/screens/document_scan/document_scan_screen.dart')
        .readAsStringSync();
    final service = File('lib/services/rag_service.dart').readAsStringSync();

    expect(byok, contains('localizedRagMessage'));
    expect(coach, contains('localizedCoachMessage'));
    expect(scan, contains('localizedRagMessage'));
    expect(service, isNot(contains('Limite de requ')));
    expect(service, isNot(contains('Service temporairement')));
  });
}
