// Phase 52.1 PR 2 — Behavior test for the chat API persistence_consent
// flag derived from the cloud-sync toggle.
//
// The chat send method (CoachChatApiService.chat) reads the prefs
// key `auth_local_mode` and passes the inverse as `persistence_consent`
// in the request body. Backend uses this flag to gate every WRITE-tier
// tool (save_fact, save_insight, save_pre_mortem, save_provenance,
// save_earmark, save_partner_estimate, record_check_in, n5 marks).
//
// We test the helper `readPersistenceConsent` (visibleForTesting)
// directly, since the full chat() flow requires secure-storage mocking
// for the auth check (separate concern, separate refactor).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 52.1 PR 2 — chat persistence_consent flag', () {
    test('sync OFF (auth_local_mode=true) → persistence_consent = false',
        () async {
      SharedPreferences.setMockInitialValues({'auth_local_mode': true});
      final consent = await CoachChatApiService.readPersistenceConsent();
      expect(
        consent,
        false,
        reason: 'auth_local_mode=true means sync OFF; backend writes refused',
      );
    });

    test('sync ON (auth_local_mode=false) → persistence_consent = true',
        () async {
      SharedPreferences.setMockInitialValues({'auth_local_mode': false});
      final consent = await CoachChatApiService.readPersistenceConsent();
      expect(
        consent,
        true,
        reason: 'auth_local_mode=false means sync ON; backend writes allowed',
      );
    });

    test('default (no key) → persistence_consent = false (safest)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final consent = await CoachChatApiService.readPersistenceConsent();
      expect(
        consent,
        false,
        reason:
            'Missing auth_local_mode key defaults to true (sync OFF) — '
            'safest stance for new installs before user touches Settings',
      );
    });
  });
}
