import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/b2b/white_label_config.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WhiteLabelConfig', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default config has MINT branding', () {
      const config = WhiteLabelConfig.defaultConfig;
      expect(config.organizationName, 'MINT');
      expect(config.primaryColor, MintColors.primary);
      expect(config.accentColor, MintColors.accent);
      expect(config.supportEmail, 'support@mint-app.ch');
      expect(config.hiddenFeatures, isEmpty);
    });

    test('custom config applies org colors', () {
      const config = WhiteLabelConfig(
        organizationName: 'Banque Cantonale',
        primaryColor: Color(0xFF003366),
        accentColor: Color(0xFF0066CC),
        welcomeMessage: 'Bienvenue chez BC\u00a0!',
        supportEmail: 'rh@bc.ch',
      );
      expect(config.primaryColor, const Color(0xFF003366));
      expect(config.accentColor, const Color(0xFF0066CC));
      expect(config.organizationName, 'Banque Cantonale');
    });

    test('hidden features respected', () {
      const config = WhiteLabelConfig(
        organizationName: 'Corp',
        primaryColor: MintColors.primary,
        accentColor: MintColors.accent,
        welcomeMessage: 'Bienvenue',
        hiddenFeatures: ['mortgage_simulator', 'debt_analysis'],
        supportEmail: 'hr@corp.ch',
      );
      expect(config.isFeatureVisible('mortgage_simulator'), isFalse);
      expect(config.isFeatureVisible('debt_analysis'), isFalse);
      expect(config.isFeatureVisible('avs_calculator'), isTrue);
    });

    test('config persistence via SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      const config = WhiteLabelConfig(
        organizationName: 'Persisted Corp',
        primaryColor: Color(0xFF112233),
        accentColor: Color(0xFF445566),
        welcomeMessage: 'Sauvegardé\u00a0!',
        supportEmail: 'save@test.ch',
      );
      await config.save(prefs: prefs);

      final loaded = await WhiteLabelConfig.load(prefs: prefs);
      expect(loaded.organizationName, 'Persisted Corp');
      expect(loaded.primaryColor, const Color(0xFF112233));
      expect(loaded.supportEmail, 'save@test.ch');

      // Clear and verify default returns.
      await WhiteLabelConfig.clear(prefs: prefs);
      final cleared = await WhiteLabelConfig.load(prefs: prefs);
      expect(cleared.organizationName, 'MINT');
    });

    test('welcome message French with accents', () {
      const config = WhiteLabelConfig.defaultConfig;
      // Non-breaking space before em-dash is present.
      expect(config.welcomeMessage, contains('\u00a0'));
      // The word 'Bienvenue' is present.
      expect(config.welcomeMessage, contains('Bienvenue'));
    });

    // ═══════════════════════════════════════════════════════════════
    //  ADVERSARIAL TESTS — Compliance Hardener + Test Generation
    // ═══════════════════════════════════════════════════════════════

    group('Protected features — compliance guard', () {
      test('disclaimer cannot be hidden via hiddenFeatures', () {
        const config = WhiteLabelConfig(
          organizationName: 'Evil Corp',
          primaryColor: MintColors.primary,
          accentColor: MintColors.accent,
          welcomeMessage: 'Welcome',
          hiddenFeatures: ['disclaimer'],
          supportEmail: 'evil@corp.ch',
        );
        // Disclaimer is protected — must always be visible.
        expect(config.isFeatureVisible('disclaimer'), isTrue,
            reason: 'Compliance: disclaimer can NEVER be hidden');
      });

      test('privacy_notice cannot be hidden via hiddenFeatures', () {
        const config = WhiteLabelConfig(
          organizationName: 'Evil Corp',
          primaryColor: MintColors.primary,
          accentColor: MintColors.accent,
          welcomeMessage: 'Welcome',
          hiddenFeatures: ['privacy_notice'],
          supportEmail: 'evil@corp.ch',
        );
        expect(config.isFeatureVisible('privacy_notice'), isTrue,
            reason: 'Compliance: privacy_notice can NEVER be hidden');
      });

      test('compliance_banner cannot be hidden', () {
        const config = WhiteLabelConfig(
          organizationName: 'Corp',
          primaryColor: MintColors.primary,
          accentColor: MintColors.accent,
          welcomeMessage: 'Welcome',
          hiddenFeatures: ['compliance_banner'],
          supportEmail: 'x@y.ch',
        );
        expect(config.isFeatureVisible('compliance_banner'), isTrue);
      });

      test('lsfin_notice cannot be hidden', () {
        const config = WhiteLabelConfig(
          organizationName: 'Corp',
          primaryColor: MintColors.primary,
          accentColor: MintColors.accent,
          welcomeMessage: 'Welcome',
          hiddenFeatures: ['lsfin_notice'],
          supportEmail: 'x@y.ch',
        );
        expect(config.isFeatureVisible('lsfin_notice'), isTrue);
      });

      test('data_sources cannot be hidden', () {
        const config = WhiteLabelConfig(
          organizationName: 'Corp',
          primaryColor: MintColors.primary,
          accentColor: MintColors.accent,
          welcomeMessage: 'Welcome',
          hiddenFeatures: ['data_sources'],
          supportEmail: 'x@y.ch',
        );
        expect(config.isFeatureVisible('data_sources'), isTrue);
      });

      test('confidence_score cannot be hidden', () {
        const config = WhiteLabelConfig(
          organizationName: 'Corp',
          primaryColor: MintColors.primary,
          accentColor: MintColors.accent,
          welcomeMessage: 'Welcome',
          hiddenFeatures: ['confidence_score'],
          supportEmail: 'x@y.ch',
        );
        expect(config.isFeatureVisible('confidence_score'), isTrue);
      });

      test('ALL protected features remain visible even when all listed', () {
        const config = WhiteLabelConfig(
          organizationName: 'Max Evil Corp',
          primaryColor: MintColors.primary,
          accentColor: MintColors.accent,
          welcomeMessage: 'Welcome',
          hiddenFeatures: [
            'disclaimer',
            'privacy_notice',
            'compliance_banner',
            'lsfin_notice',
            'data_sources',
            'confidence_score',
            'mortgage_simulator', // this one CAN be hidden
          ],
          supportEmail: 'x@y.ch',
        );

        for (final pf in WhiteLabelConfig.kProtectedFeatures) {
          expect(config.isFeatureVisible(pf), isTrue,
              reason: '$pf is protected and must not be hideable');
        }
        // Non-protected feature IS hidden.
        expect(config.isFeatureVisible('mortgage_simulator'), isFalse);
      });

      test('kProtectedFeatures contains at least disclaimer and lsfin', () {
        expect(
          WhiteLabelConfig.kProtectedFeatures,
          containsAll(['disclaimer', 'lsfin_notice', 'privacy_notice']),
        );
      });
    });

    group('Banned terms — adversarial', () {
      test('default welcome message has no banned terms', () {
        const config = WhiteLabelConfig.defaultConfig;
        final text = config.welcomeMessage.toLowerCase();
        expect(text.contains('garanti'), isFalse);
        expect(text.contains('certain'), isFalse);
        expect(text.contains('sans risque'), isFalse);
        expect(text.contains('optimal'), isFalse);
        expect(text.contains('meilleur'), isFalse);
        expect(text.contains('parfait'), isFalse);
      });
    });

    group('Edge cases', () {
      test('fromJson with missing fields uses safe defaults', () {
        final config = WhiteLabelConfig.fromJson(<String, dynamic>{});
        expect(config.organizationName, 'MINT');
        expect(config.supportEmail, 'support@mint-app.ch');
        expect(config.hiddenFeatures, isEmpty);
      });

      test('corrupted prefs returns default config', () async {
        SharedPreferences.setMockInitialValues({
          '_white_label_config': 'not-json{{{',
        });
        final prefs = await SharedPreferences.getInstance();
        final config = await WhiteLabelConfig.load(prefs: prefs);
        expect(config.organizationName, 'MINT');
      });

      test('round-trip JSON preserves all fields', () {
        const original = WhiteLabelConfig(
          organizationName: 'Test AG',
          logoAssetPath: 'assets/logo.png',
          primaryColor: Color(0xFF112233),
          accentColor: Color(0xFF445566),
          welcomeMessage: 'Bienvenue\u00a0!',
          hiddenFeatures: ['some_feature'],
          supportEmail: 'test@test.ch',
        );
        final json = original.toJson();
        final restored = WhiteLabelConfig.fromJson(json);
        expect(restored.organizationName, original.organizationName);
        expect(restored.logoAssetPath, original.logoAssetPath);
        expect(restored.welcomeMessage, original.welcomeMessage);
        expect(restored.hiddenFeatures, original.hiddenFeatures);
        expect(restored.supportEmail, original.supportEmail);
      });
    });
  });
}
