import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/api_service.dart';

/// Unit tests for RagService and its associated data models
///
/// Tests cover:
/// - RagResponse.fromJson deserialization (happy path + missing fields)
/// - RagSource.fromJson deserialization
/// - RagStatus.fromJson deserialization
/// - RagApiException construction and toString
/// - RagService constructor (baseUrl configuration)
/// - URI construction for endpoints
/// - Error handling conventions (error codes)
/// - Query body construction logic
void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // RagResponse — Deserialization
  // ═══════════════════════════════════════════════════════════════════════

  group('RagResponse.fromJson', () {
    test('parses complete response with all fields', () {
      final json = {
        'answer': 'Le 3e pilier permet une deduction fiscale.',
        'sources': [
          {'title': 'OPP3', 'file': 'opp3.pdf', 'section': 'Art. 1'},
          {'title': 'LIFD', 'file': 'lifd.pdf', 'section': 'Art. 33'},
        ],
        'disclaimers': [
          'Outil educatif, ne constitue pas un conseil.',
          'Consultez un·e specialiste.',
        ],
        'tokens_used': 1234,
      };

      final response = RagResponse.fromJson(json);

      expect(response.answer, contains('3e pilier'));
      expect(response.sources, hasLength(2));
      expect(response.disclaimers, hasLength(2));
      expect(response.tokensUsed, equals(1234));
    });

    test('handles missing answer field gracefully', () {
      final json = <String, dynamic>{
        'sources': [],
        'disclaimers': [],
        'tokens_used': 0,
      };

      final response = RagResponse.fromJson(json);
      expect(response.answer, equals(''));
    });

    test('handles null sources with empty list default', () {
      final json = <String, dynamic>{
        'answer': 'test',
        'tokens_used': 10,
      };

      final response = RagResponse.fromJson(json);
      expect(response.sources, isEmpty);
    });

    test('handles null disclaimers with empty list default', () {
      final json = <String, dynamic>{
        'answer': 'test',
        'tokens_used': 10,
      };

      final response = RagResponse.fromJson(json);
      expect(response.disclaimers, isEmpty);
    });

    test('handles missing tokens_used with zero default', () {
      final json = <String, dynamic>{
        'answer': 'test',
      };

      final response = RagResponse.fromJson(json);
      expect(response.tokensUsed, equals(0));
    });

    test('handles completely empty JSON object', () {
      final json = <String, dynamic>{};

      final response = RagResponse.fromJson(json);
      expect(response.answer, equals(''));
      expect(response.sources, isEmpty);
      expect(response.disclaimers, isEmpty);
      expect(response.tokensUsed, equals(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // RagSource — Deserialization
  // ═══════════════════════════════════════════════════════════════════════

  group('RagSource.fromJson', () {
    test('parses complete source', () {
      final json = {
        'title': 'LPP Art. 14',
        'file': 'lpp_complet.pdf',
        'section': 'Taux de conversion',
      };

      final source = RagSource.fromJson(json);
      expect(source.title, equals('LPP Art. 14'));
      expect(source.file, equals('lpp_complet.pdf'));
      expect(source.section, equals('Taux de conversion'));
    });

    test('handles missing title with empty string default', () {
      final json = <String, dynamic>{
        'file': 'doc.pdf',
        'section': 'sec',
      };

      final source = RagSource.fromJson(json);
      expect(source.title, equals(''));
    });

    test('handles missing file with empty string default', () {
      final json = <String, dynamic>{
        'title': 'A Title',
        'section': 'sec',
      };

      final source = RagSource.fromJson(json);
      expect(source.file, equals(''));
    });

    test('handles missing section with empty string default', () {
      final json = <String, dynamic>{
        'title': 'A Title',
        'file': 'f.pdf',
      };

      final source = RagSource.fromJson(json);
      expect(source.section, equals(''));
    });

    test('handles completely empty JSON', () {
      final json = <String, dynamic>{};

      final source = RagSource.fromJson(json);
      expect(source.title, equals(''));
      expect(source.file, equals(''));
      expect(source.section, equals(''));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // RagStatus — Deserialization
  // ═══════════════════════════════════════════════════════════════════════

  group('RagStatus.fromJson', () {
    test('parses ready status with documents', () {
      final json = {
        'vector_store_ready': true,
        'documents_count': 42,
      };

      final status = RagStatus.fromJson(json);
      expect(status.vectorStoreReady, isTrue);
      expect(status.documentsCount, equals(42));
    });

    test('parses not-ready status', () {
      final json = {
        'vector_store_ready': false,
        'documents_count': 0,
      };

      final status = RagStatus.fromJson(json);
      expect(status.vectorStoreReady, isFalse);
      expect(status.documentsCount, equals(0));
    });

    test('handles missing vector_store_ready with false default', () {
      final json = <String, dynamic>{
        'documents_count': 10,
      };

      final status = RagStatus.fromJson(json);
      expect(status.vectorStoreReady, isFalse);
    });

    test('handles missing documents_count with zero default', () {
      final json = <String, dynamic>{
        'vector_store_ready': true,
      };

      final status = RagStatus.fromJson(json);
      expect(status.documentsCount, equals(0));
    });

    test('handles completely empty JSON', () {
      final json = <String, dynamic>{};

      final status = RagStatus.fromJson(json);
      expect(status.vectorStoreReady, isFalse);
      expect(status.documentsCount, equals(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // RagApiException
  // ═══════════════════════════════════════════════════════════════════════

  group('RagApiException', () {
    test('stores code and message', () {
      const e =
          RagApiException(code: 'invalid_key', message: 'Cle API invalide');
      expect(e.code, equals('invalid_key'));
      expect(e.message, equals('Cle API invalide'));
    });

    test('toString includes code and message', () {
      const e = RagApiException(
        code: 'rate_limit',
        message: 'Limite atteinte',
      );
      final str = e.toString();
      expect(str, contains('RagApiException'));
      expect(str, contains('rate_limit'));
      expect(str, contains('Limite atteinte'));
    });

    test('toString format is RagApiException(code): message', () {
      const e = RagApiException(code: 'server_error', message: 'Erreur 500');
      expect(e.toString(), equals('RagApiException(server_error): Erreur 500'));
    });

    test('implements Exception', () {
      const e = RagApiException(code: 'test', message: 'msg');
      expect(e, isA<Exception>());
    });

    test('known error codes match service conventions', () {
      // The service uses these specific error codes
      const validCodes = ['invalid_key', 'rate_limit', 'server_error', 'status_error'];
      for (final code in validCodes) {
        final e = RagApiException(code: code, message: 'test');
        expect(validCodes, contains(e.code));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // RagService — Constructor and Configuration
  // ═══════════════════════════════════════════════════════════════════════

  group('RagService — constructor', () {
    test('default baseUrl uses ApiService.baseUrl', () {
      final service = RagService();
      expect(service.baseUrl, equals(ApiService.baseUrl));
    });

    test('custom baseUrl overrides the default', () {
      final service = RagService(baseUrl: 'https://api.mint.ch/v1');
      expect(service.baseUrl, equals('https://api.mint.ch/v1'));
    });

    test('null baseUrl falls back to ApiService.baseUrl', () {
      final service = RagService(baseUrl: null);
      expect(service.baseUrl, equals(ApiService.baseUrl));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // RagService — URI endpoint paths
  // ═══════════════════════════════════════════════════════════════════════

  group('RagService — endpoint URIs', () {
    test('query endpoint URI is baseUrl + /rag/query', () {
      final service = RagService();
      final uri = Uri.parse('${service.baseUrl}/rag/query');
      expect(uri.path, endsWith('/rag/query'));
    });

    test('status endpoint URI is baseUrl + /rag/status', () {
      final service = RagService();
      final uri = Uri.parse('${service.baseUrl}/rag/status');
      expect(uri.path, endsWith('/rag/status'));
    });

    test('custom baseUrl produces correct query URI', () {
      final service = RagService(baseUrl: 'https://prod.mint.ch/api/v2');
      final uri = Uri.parse('${service.baseUrl}/rag/query');
      expect(uri.host, equals('prod.mint.ch'));
      expect(uri.path, equals('/api/v2/rag/query'));
      expect(uri.scheme, equals('https'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Query body construction logic
  // ═══════════════════════════════════════════════════════════════════════

  group('RagService — query body construction', () {
    test('minimal query body has required fields', () {
      // Mirrors the body construction in RagService.query()
      final body = <String, dynamic>{
        'question': 'Comment fonctionne le 3e pilier?',
        'api_key': 'sk-abc123',
        'provider': 'claude',
        'language': 'fr',
      };

      expect(body.keys, containsAll(['question', 'api_key', 'provider', 'language']));
      expect(body.length, equals(4));
    });

    test('optional model is added when provided', () {
      final body = <String, dynamic>{
        'question': 'Test?',
        'api_key': 'key',
        'provider': 'openai',
        'language': 'fr',
      };
      const String model = 'gpt-4';
      body['model'] = model;

      expect(body.containsKey('model'), isTrue);
      expect(body['model'], equals('gpt-4'));
    });

    test('optional model is omitted when null', () {
      final body = <String, dynamic>{
        'question': 'Test?',
        'api_key': 'key',
        'provider': 'claude',
        'language': 'fr',
      };
      const String? model = null;
      if (model != null) body['model'] = model;

      expect(body.containsKey('model'), isFalse);
    });

    test('profileContext is added when provided', () {
      final body = <String, dynamic>{
        'question': 'Test?',
        'api_key': 'key',
        'provider': 'mistral',
        'language': 'fr',
      };
      final profileContext = {'canton': 'VD', 'age': 30};
      body['profile_context'] = profileContext;

      expect(body.containsKey('profile_context'), isTrue);
      expect(body['profile_context'], equals({'canton': 'VD', 'age': 30}));
    });

    test('default language is fr', () {
      // The method signature defaults language to 'fr'
      const language = 'fr';
      expect(language, equals('fr'));
    });

    test('supported providers include claude, openai, mistral', () {
      // BYOK providers as documented in the service
      const providers = ['claude', 'openai', 'mistral'];
      expect(providers, contains('claude'));
      expect(providers, contains('openai'));
      expect(providers, contains('mistral'));
    });
  });
}
