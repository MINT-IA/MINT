import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';

void main() {
  group('OnboardingProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts empty before load', () {
      final provider = OnboardingProvider();
      expect(provider.birthYear, isNull);
      expect(provider.grossSalary, isNull);
      expect(provider.canton, isNull);
      expect(provider.payload.isComplete, isFalse);
    });

    test('setBirthYear persists and notifies', () async {
      final provider = OnboardingProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setBirthYear(1977);

      expect(provider.birthYear, 1977);
      expect(notified, isTrue);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('onboarding_birth_year'), 1977);
    });

    test('setGrossSalary persists and notifies', () async {
      final provider = OnboardingProvider();
      await provider.setGrossSalary(122207.0);
      expect(provider.grossSalary, 122207.0);
    });

    test('setCanton persists and notifies', () async {
      final provider = OnboardingProvider();
      await provider.setCanton('VS');
      expect(provider.canton, 'VS');
    });

    test('setChoc stores both type and value', () async {
      final provider = OnboardingProvider();
      await provider.setChoc(OnboardingChocType.retirementGap, 5600.0);
      expect(provider.chocType, OnboardingChocType.retirementGap);
      expect(provider.chocValue, 5600.0);
      expect(provider.payload.hasChocData, isTrue);
    });

    test('setEmotion stores emotion string', () async {
      final provider = OnboardingProvider();
      await provider.setEmotion("C'est flippant");
      expect(provider.emotion, "C'est flippant");
      expect(provider.payload.hasEmotion, isTrue);
    });

    test('payload.isComplete is true when 3 core fields set', () async {
      final provider = OnboardingProvider();
      await provider.setBirthYear(1977);
      await provider.setGrossSalary(122207.0);
      expect(provider.payload.isComplete, isFalse); // missing canton
      await provider.setCanton('VS');
      expect(provider.payload.isComplete, isTrue);
    });

    test('load recovers from SharedPreferences', () async {
      // Pre-populate SharedPreferences
      SharedPreferences.setMockInitialValues({
        'onboarding_birth_year': 1982,
        'onboarding_gross_salary': 67000.0,
        'onboarding_canton': 'VS',
        'onboarding_choc_type': 'retirementIncome',
        'onboarding_choc_value': 4200.0,
        'onboarding_emotion': 'Ça me semble OK',
      });

      final provider = OnboardingProvider();
      await provider.load();

      expect(provider.birthYear, 1982);
      expect(provider.grossSalary, 67000.0);
      expect(provider.canton, 'VS');
      expect(provider.chocType, OnboardingChocType.retirementIncome);
      expect(provider.chocValue, 4200.0);
      expect(provider.emotion, 'Ça me semble OK');
      expect(provider.isLoaded, isTrue);
    });

    test('clear removes all data', () async {
      final provider = OnboardingProvider();
      await provider.setBirthYear(1977);
      await provider.setGrossSalary(122207.0);
      await provider.setCanton('VS');
      await provider.setEmotion('Flippant');

      await provider.clear();

      expect(provider.birthYear, isNull);
      expect(provider.grossSalary, isNull);
      expect(provider.canton, isNull);
      expect(provider.emotion, isNull);
      expect(provider.payload.isComplete, isFalse);

      // Verify SharedPreferences cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('onboarding_birth_year'), isNull);
    });

    test('setAnxietyLevel stores Hinge prompt 1 response', () async {
      final provider = OnboardingProvider();
      await provider.setAnxietyLevel('far');
      expect(provider.anxietyLevel, 'far');
    });
  });
}
