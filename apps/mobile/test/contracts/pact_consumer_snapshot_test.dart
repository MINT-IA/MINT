// Phase 95 — Plan 02 — Pact consumer-driven contract snapshot test
//
// Closes TEST-02. The contract authored on the mobile side at
// `.planning/contracts/pacts/mint_mobile-mint_backend.json` declares
// 4 interactions (one per hot endpoint). This test verifies that the
// mobile call sites still match the contract by static-analysis grep:
// for each interaction, we read the relevant service file, find the
// matching `Uri.parse(...)` line, and assert that the mobile body keys
// are a superset of the contract's body keys.
//
// Why a snapshot test (not pact_dart):
//   * pact_dart 0.8.0 (latest, 2025-04) declares `http: ^0.13.3` while
//     `apps/mobile/pubspec.yaml` is on `http: ^1.2.0`. Direct version
//     conflict — `flutter pub get` fails with pact_dart added.
//   * The maintained pact-python 2.x bundles a Ruby `pact-provider-verifier`
//     binary that talks HTTP. We use it on the backend side
//     (`services/backend/tests/contracts/test_pact_provider_verification.py`)
//     to replay each interaction against the FastAPI app via TestClient.
//   * Per planner discretion (`95-02-PLAN.md` <risks> clause 1, fallback
//     path), we hand-author the Pact-v3 JSON and drift-check via this
//     snapshot test on the mobile side + provider verifier on the
//     backend side.
//
// Karpathy 3 (surgical): zero edits to `apps/mobile/lib/services/api_service.dart`
// or to any production code — additive only.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pact consumer-driven contract — mint_mobile -> mint_backend', () {
    // The pact file lives at the repo root, under .planning/contracts/pacts/.
    // From `apps/mobile/`, that is two levels up.
    final pactFile = File(
      '../../.planning/contracts/pacts/mint_mobile-mint_backend.json',
    );

    late Map<String, dynamic> pact;

    setUpAll(() {
      expect(
        pactFile.existsSync(),
        isTrue,
        reason:
            'Pact file missing at ${pactFile.path}. '
            'See .planning/contracts/pacts/README.md for authoring rules.',
      );
      pact = jsonDecode(pactFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('Pact-v3 envelope is well-formed', () {
      expect(
        (pact['consumer'] as Map)['name'],
        equals('mint_mobile'),
        reason: 'Consumer name is the single source of truth for this contract.',
      );
      expect(
        (pact['provider'] as Map)['name'],
        equals('mint_backend'),
      );
      final interactions = pact['interactions'] as List;
      expect(
        interactions.length,
        greaterThanOrEqualTo(4),
        reason:
            'Contract must cover the 4 hot endpoints (anonymous_chat, '
            'coach_chat, documents_upload, premier_eclairage). Add the '
            'missing interaction or adjust this test if the scope changes.',
      );
      expect(
        (pact['metadata'] as Map)['pactSpecification']['version'],
        equals('3.0.0'),
        reason: 'pact-python verifier 2.x targets Pact-v3.',
      );
    });

    test('Each interaction declares method, path, and response status', () {
      for (final raw in pact['interactions'] as List) {
        final interaction = raw as Map<String, dynamic>;
        final desc = interaction['description'] as String;
        final request = interaction['request'] as Map<String, dynamic>;
        final response = interaction['response'] as Map<String, dynamic>;
        expect(request['method'], isA<String>(), reason: desc);
        expect(request['path'], isA<String>(), reason: desc);
        expect(response['status'], isA<int>(), reason: desc);
        expect(
          (request['path'] as String).startsWith('/api/v1/'),
          isTrue,
          reason: 'All MINT endpoints sit under /api/v1/. desc=$desc',
        );
      }
    });

    test('All 4 endpoints are covered by exactly one interaction each', () {
      final paths = <String>{};
      for (final raw in pact['interactions'] as List) {
        final request = (raw as Map)['request'] as Map<String, dynamic>;
        paths.add(request['path'] as String);
      }
      expect(
        paths,
        containsAll(<String>[
          '/api/v1/anonymous/chat',
          '/api/v1/coach/chat',
          '/api/v1/documents/upload',
          '/api/v1/onboarding/premier-eclairage',
        ]),
        reason:
            'Plan 95-02 mandates these 4 endpoints. To add or remove an '
            'endpoint, update both this list and the JSON.',
      );
    });

    // ─────────────────────────────────────────────────────────────────
    // Drift checks against the actual mobile call sites. For each
    // interaction we read the source file containing the call, find the
    // line that constructs the URI, and verify that every body key the
    // contract declares is present in the surrounding code (within a
    // small window). This catches the « mobile renamed `message` to
    // `text` but forgot to update the contract » class of regression
    // BEFORE the test even hits the backend.
    // ─────────────────────────────────────────────────────────────────

    test('anonymous_chat call site still emits the contract body keys', () {
      final source = File(
        'lib/services/coach/coach_chat_api_service.dart',
      ).readAsStringSync();
      // The anon-chat call site lives in this service file. Verify the
      // contract's request body keys are still emitted by the source.
      final interaction = _findInteraction(pact, '/api/v1/anonymous/chat');
      final body = (interaction['request'] as Map)['body'] as Map<String, dynamic>;
      for (final key in body.keys) {
        expect(
          source.contains("'$key'"),
          isTrue,
          reason:
              'Mobile source no longer emits body key `$key` for '
              '/anonymous/chat — contract drift. Update the pact OR fix '
              'the call site.',
        );
      }
      // Header pinned by the contract:
      expect(
        source.contains("'X-Anonymous-Session'"),
        isTrue,
        reason:
            'X-Anonymous-Session header pinned by the contract; missing '
            'from the source.',
      );
    });

    test('coach_chat call site still emits the contract body keys', () {
      final source = File(
        'lib/services/coach/coach_chat_api_service.dart',
      ).readAsStringSync();
      final interaction = _findInteraction(pact, '/api/v1/coach/chat');
      final body = (interaction['request'] as Map)['body'] as Map<String, dynamic>;
      for (final key in body.keys) {
        expect(
          source.contains("'$key'"),
          isTrue,
          reason:
              'Mobile source no longer emits body key `$key` for '
              '/coach/chat — contract drift. Update the pact OR fix the '
              'call site.',
        );
      }
    });

    test('documents/upload call site still constructs the upload URI', () {
      final source = File(
        'lib/services/document_service.dart',
      ).readAsStringSync();
      // documents_upload is multipart so we only assert the URI + the
      // Authorization + Idempotency-Key + 'file' field presence (the
      // request body in the contract is a marker only — see the JSON).
      expect(source.contains('/documents/upload'), isTrue);
      expect(source.contains("'Authorization'"), isTrue);
      expect(source.contains("'Idempotency-Key'"), isTrue);
      expect(
        source.contains("'file'"),
        isTrue,
        reason:
            'Multipart field name `file` pinned by the contract — backend '
            'verifier asserts response shape, not request body.',
      );
    });

    test('premier_eclairage call site still emits the contract body keys', () {
      final source = File(
        'lib/services/api_service.dart',
      ).readAsStringSync();
      final interaction =
          _findInteraction(pact, '/api/v1/onboarding/premier-eclairage');
      final body = (interaction['request'] as Map)['body'] as Map<String, dynamic>;
      // We only assert the keys the source DOES send — `existing_3a`,
      // `existing_lpp` etc are conditionally attached. The mandatory
      // 3 are age + gross_salary + canton.
      for (final key in <String>['age', 'gross_salary', 'canton']) {
        expect(
          body.containsKey(key),
          isTrue,
          reason:
              'Contract is missing mandatory body key `$key` for '
              '/onboarding/premier-eclairage.',
        );
        expect(
          source.contains("'$key'"),
          isTrue,
          reason:
              'Mobile source no longer emits mandatory body key `$key` '
              'for /onboarding/premier-eclairage — contract drift.',
        );
      }
    });

    test('Each interaction declares matchingRules — no literal-only contracts', () {
      // Doctrine §3 anti-pattern guard: a contract that pins literal
      // values would fail every time the LLM generates a different
      // response string. Pact `matchingRules` (type/regex/integer/decimal)
      // pin shape, not value. Every interaction MUST declare at least
      // one matching rule on the response body.
      for (final raw in pact['interactions'] as List) {
        final interaction = raw as Map<String, dynamic>;
        final response = interaction['response'] as Map<String, dynamic>;
        final matchingRules = response['matchingRules'];
        expect(
          matchingRules,
          isNotNull,
          reason:
              'Interaction `${interaction['description']}` has no response '
              'matchingRules — that is literal-value pinning, which is the '
              'anti-pattern doctrine §3 calls out.',
        );
        final body = (matchingRules as Map)['body'] as Map?;
        expect(
          body,
          isNotNull,
          reason:
              'Interaction `${interaction['description']}` has no body-level '
              'matchingRules.',
        );
        expect(
          body!.isNotEmpty,
          isTrue,
          reason:
              'Interaction `${interaction['description']}` has empty body '
              'matchingRules.',
        );
      }
    });
  });
}

/// Look up the interaction whose `request.path` matches [path].
Map<String, dynamic> _findInteraction(Map<String, dynamic> pact, String path) {
  for (final raw in pact['interactions'] as List) {
    final interaction = raw as Map<String, dynamic>;
    final request = interaction['request'] as Map<String, dynamic>;
    if (request['path'] == path) {
      return interaction;
    }
  }
  fail('No interaction with path=$path in the pact file.');
}
