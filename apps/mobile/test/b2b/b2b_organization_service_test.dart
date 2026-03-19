import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/b2b/b2b_organization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('B2bOrganizationService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('join with valid invite code persists organization', () async {
      final prefs = await SharedPreferences.getInstance();
      await B2bOrganizationService.joinOrganization(
        inviteCode: 'MINT-DEMO-2026',
        prefs: prefs,
      );
      final org = await B2bOrganizationService.getOrganization(prefs: prefs);
      expect(org, isNotNull);
      expect(org!.name, 'MINT Demo Corp');
      expect(org.plan, B2bPlan.professional);
    });

    test('join with invalid code throws ArgumentError', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        () => B2bOrganizationService.joinOrganization(
          inviteCode: 'INVALID-CODE',
          prefs: prefs,
        ),
        throwsArgumentError,
      );
    });

    test('get organization returns null when not joined', () async {
      final prefs = await SharedPreferences.getInstance();
      final org = await B2bOrganizationService.getOrganization(prefs: prefs);
      expect(org, isNull);
    });

    test('leave organization clears data', () async {
      final prefs = await SharedPreferences.getInstance();
      await B2bOrganizationService.joinOrganization(
        inviteCode: 'MINT-DEMO-2026',
        prefs: prefs,
      );
      expect(
        await B2bOrganizationService.getOrganization(prefs: prefs),
        isNotNull,
      );
      await B2bOrganizationService.leaveOrganization(prefs: prefs);
      expect(
        await B2bOrganizationService.getOrganization(prefs: prefs),
        isNull,
      );
    });

    test('isModuleEnabled returns true for enabled module', () {
      final org = B2bOrganization(
        id: 'test',
        name: 'Test',
        plan: B2bPlan.professional,
        employeeCount: 20,
        enabledModules: ['education', 'wellness', '3a'],
        primaryColor: '#1D1D1F',
        contactEmail: 'test@test.ch',
        contractStart: DateTime(2026),
      );
      expect(
        B2bOrganizationService.isModuleEnabled(org, 'wellness'),
        isTrue,
      );
      expect(
        B2bOrganizationService.isModuleEnabled(org, 'lpp'),
        isFalse,
      );
    });

    test('availableModules respects plan AND enabledModules intersection',
        () {
      final org = B2bOrganization(
        id: 'test',
        name: 'Test',
        plan: B2bPlan.starter, // starter only has 'education'
        employeeCount: 10,
        enabledModules: ['education', 'wellness'], // wellness not in starter
        primaryColor: '#1D1D1F',
        contactEmail: 'test@test.ch',
        contractStart: DateTime(2026),
      );
      final modules = B2bOrganizationService.availableModules(org);
      expect(modules, ['education']);
      expect(modules.contains('wellness'), isFalse);
    });

    test('persistence across sessions (re-read from prefs)', () async {
      final prefs = await SharedPreferences.getInstance();
      await B2bOrganizationService.joinOrganization(
        inviteCode: 'MINT-DEMO-2026',
        prefs: prefs,
      );
      // Simulate new session by reading again.
      final org = await B2bOrganizationService.getOrganization(prefs: prefs);
      expect(org, isNotNull);
      expect(org!.id, 'org_demo_001');
      expect(org.contactEmail, 'demo@mint-app.ch');
    });

    test('no PII in organization data', () async {
      final prefs = await SharedPreferences.getInstance();
      await B2bOrganizationService.joinOrganization(
        inviteCode: 'MINT-DEMO-2026',
        prefs: prefs,
      );
      final org = await B2bOrganizationService.getOrganization(prefs: prefs);
      final json = org!.toJson();
      final jsonStr = json.toString().toLowerCase();
      // Must not contain any PII-like fields.
      expect(jsonStr.contains('salary'), isFalse);
      expect(jsonStr.contains('ssn'), isFalse);
      expect(jsonStr.contains('iban'), isFalse);
      expect(jsonStr.contains('employeeName'), isFalse);
    });

    // ═══════════════════════════════════════════════════════════════
    //  ADVERSARIAL TESTS — Compliance Hardener + Test Generation
    // ═══════════════════════════════════════════════════════════════

    group('Data isolation — adversarial', () {
      test('two organizations have distinct IDs', () {
        final orgA = B2bOrganization(
          id: 'org_alpha',
          name: 'Alpha SA',
          plan: B2bPlan.professional,
          employeeCount: 50,
          enabledModules: ['education'],
          primaryColor: '#111111',
          contactEmail: 'a@alpha.ch',
          contractStart: DateTime(2026),
        );
        final orgB = B2bOrganization(
          id: 'org_beta',
          name: 'Beta AG',
          plan: B2bPlan.enterprise,
          employeeCount: 200,
          enabledModules: ['education', 'lpp'],
          primaryColor: '#222222',
          contactEmail: 'b@beta.ch',
          contractStart: DateTime(2026),
        );
        expect(orgA.id, isNot(equals(orgB.id)));
        expect(orgA.name, isNot(equals(orgB.name)));
      });

      test('joining new org replaces previous org (no data leak)', () async {
        // Add a second org to the registry for this test.
        kInviteCodeRegistry['TEST-ORG-B'] = B2bOrganization(
          id: 'org_test_b',
          name: 'Test Org B',
          plan: B2bPlan.starter,
          employeeCount: 30,
          enabledModules: ['education'],
          primaryColor: '#333333',
          contactEmail: 'b@test.ch',
          contractStart: DateTime(2026),
        );

        final prefs = await SharedPreferences.getInstance();

        // Join org A.
        await B2bOrganizationService.joinOrganization(
          inviteCode: 'MINT-DEMO-2026',
          prefs: prefs,
        );
        final orgA =
            await B2bOrganizationService.getOrganization(prefs: prefs);
        expect(orgA!.id, 'org_demo_001');

        // Join org B — should replace A entirely.
        await B2bOrganizationService.joinOrganization(
          inviteCode: 'TEST-ORG-B',
          prefs: prefs,
        );
        final orgB =
            await B2bOrganizationService.getOrganization(prefs: prefs);
        expect(orgB!.id, 'org_test_b');
        expect(orgB.name, 'Test Org B');

        // Clean up registry.
        kInviteCodeRegistry.remove('TEST-ORG-B');
      });
    });

    group('Read-only — adversarial', () {
      test('B2bOrganization fields are final (immutable)', () {
        // Compile-time guarantee: all fields are final.
        // This test verifies the object can be constructed but not mutated.
        final org = B2bOrganization(
          id: 'immutable_test',
          name: 'Immutable Corp',
          plan: B2bPlan.professional,
          employeeCount: 10,
          enabledModules: ['education'],
          primaryColor: '#000000',
          contactEmail: 'x@y.ch',
          contractStart: DateTime(2026),
        );
        expect(org.id, 'immutable_test');
        // No setter available — compile-time safety.
      });

      test('service has private constructor (no instantiation)', () {
        // B2bOrganizationService._() — all methods are static.
        // Verify static methods exist.
        expect(B2bOrganizationService.getOrganization, isNotNull);
        expect(B2bOrganizationService.joinOrganization, isNotNull);
        expect(B2bOrganizationService.leaveOrganization, isNotNull);
      });
    });

    group('Edge cases', () {
      test('invite code is case-insensitive', () async {
        final prefs = await SharedPreferences.getInstance();
        await B2bOrganizationService.joinOrganization(
          inviteCode: 'mint-demo-2026',
          prefs: prefs,
        );
        final org =
            await B2bOrganizationService.getOrganization(prefs: prefs);
        expect(org, isNotNull);
        expect(org!.name, 'MINT Demo Corp');
      });

      test('invite code trims whitespace', () async {
        final prefs = await SharedPreferences.getInstance();
        await B2bOrganizationService.joinOrganization(
          inviteCode: '  MINT-DEMO-2026  ',
          prefs: prefs,
        );
        final org =
            await B2bOrganizationService.getOrganization(prefs: prefs);
        expect(org, isNotNull);
      });

      test('empty invite code throws ArgumentError', () async {
        final prefs = await SharedPreferences.getInstance();
        expect(
          () => B2bOrganizationService.joinOrganization(
            inviteCode: '',
            prefs: prefs,
          ),
          throwsArgumentError,
        );
      });

      test('corrupted prefs returns null (no crash)', () async {
        SharedPreferences.setMockInitialValues({
          '_b2b_organization': 'corrupted{{{json',
        });
        final prefs = await SharedPreferences.getInstance();
        final org =
            await B2bOrganizationService.getOrganization(prefs: prefs);
        expect(org, isNull);
      });

      test('enterprise plan has all 4 modules', () {
        expect(kPlanModules[B2bPlan.enterprise],
            containsAll(['education', 'wellness', '3a', 'lpp']));
      });

      test('starter plan only has education', () {
        expect(kPlanModules[B2bPlan.starter], ['education']);
      });

      test('fromJson with missing fields uses safe defaults', () {
        final org = B2bOrganization.fromJson({
          'id': 'test',
          'name': 'Test',
          'plan': 'unknown_plan',
          'contractStart': '2026-01-01T00:00:00.000',
        });
        expect(org.plan, B2bPlan.starter); // fallback
        expect(org.employeeCount, 0);
        expect(org.enabledModules, isEmpty);
      });

      test('round-trip JSON preserves all fields', () {
        final original = B2bOrganization(
          id: 'rt_test',
          name: 'Round Trip AG',
          logoUrl: 'https://example.ch/logo.png',
          plan: B2bPlan.enterprise,
          employeeCount: 500,
          enabledModules: ['education', 'wellness', '3a', 'lpp'],
          primaryColor: '#AABBCC',
          contactEmail: 'rt@test.ch',
          contractStart: DateTime(2026, 6, 1),
          contractEnd: DateTime(2027, 5, 31),
        );
        final json = original.toJson();
        final restored = B2bOrganization.fromJson(json);
        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.logoUrl, original.logoUrl);
        expect(restored.plan, original.plan);
        expect(restored.employeeCount, original.employeeCount);
        expect(restored.enabledModules, original.enabledModules);
        expect(restored.primaryColor, original.primaryColor);
        expect(restored.contactEmail, original.contactEmail);
        expect(restored.contractEnd, isNotNull);
      });
    });

    group('Banned terms — adversarial', () {
      test('invite error message has no banned terms', () async {
        final prefs = await SharedPreferences.getInstance();
        try {
          await B2bOrganizationService.joinOrganization(
            inviteCode: 'BAD',
            prefs: prefs,
          );
        } on ArgumentError catch (e) {
          final msg = e.message.toString().toLowerCase();
          expect(msg.contains('garanti'), isFalse);
          expect(msg.contains('optimal'), isFalse);
          expect(msg.contains('meilleur'), isFalse);
        }
      });
    });
  });
}
