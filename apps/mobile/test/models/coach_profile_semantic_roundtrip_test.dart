import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('legacy household and employment aliases serialize canonically', () {
    final profile = CoachProfile.fromWizardAnswers({
      'q_birth_year': 1985,
      'q_civil_status': 'married',
      'q_employment_status': 'self_employed',
      'q_self_employed_income': 90000,
    });

    expect(profile.etatCivil, CoachCivilStatus.marie);
    expect(profile.employmentStatus, 'independant');

    final json = profile.toJson();
    expect(json['etatCivil'], 'marie');
    expect(json['employmentStatus'], 'self_employed');

    final restored = CoachProfile.fromJson(json);
    expect(restored.etatCivil, CoachCivilStatus.marie);
    expect(restored.employmentStatus, 'independant');
  });

  test('explicit unemployed never falls back to employee', () {
    for (final alias in ['unemployed', 'chomage', 'chômage']) {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_employment_status': alias,
      });
      expect(profile.employmentStatus, 'chomage', reason: alias);
      expect(profile.toJson()['employmentStatus'], 'unemployed');
    }
  });

  test(
      'registered_partner stays registered partnership through wizard -> model -> json -> model',
      () {
    final profile = CoachProfile.fromWizardAnswers({
      'q_birth_year': 1985,
      'q_civil_status': 'registered_partner',
    });

    expect(profile.etatCivil, CoachCivilStatus.registeredPartnership);
    expect(profile.civilStatusNeedsConfirmation, isFalse);

    final json = profile.toJson();
    expect(json['etatCivil'], 'registeredPartnership');

    final restored = CoachProfile.fromJson(json);
    expect(restored.etatCivil, CoachCivilStatus.registeredPartnership);
    expect(restored.civilStatusNeedsConfirmation, isFalse);
  });

  test('explicit registered partnership aliases converge', () {
    for (final alias in [
      'registered_partner',
      'registered_partnership',
      'partenariat_enregistre',
    ]) {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_civil_status': alias,
      });
      expect(
        profile.etatCivil,
        CoachCivilStatus.registeredPartnership,
        reason: alias,
      );
      expect(profile.civilStatusNeedsConfirmation, isFalse, reason: alias);
    }

    for (final alias in ['cohabiting', 'concubinage']) {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_civil_status': alias,
      });
      expect(profile.etatCivil, CoachCivilStatus.concubinage, reason: alias);
    }
  });

  test('registered partner update does not clear spouse answers', () async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1985,
      'q_civil_status': 'married',
      'q_partner_birth_year': 1965,
      'q_spouse_avs_contribution_years': 38,
    });
    final provider = CoachProfileProvider();

    await provider.mergeAnswers({
      'q_civil_status': 'registered_partner',
    });

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_partner_birth_year', 1965));
    expect(answers, containsPair('q_spouse_avs_contribution_years', 38));
    expect(
      provider.profile?.etatCivil,
      CoachCivilStatus.registeredPartnership,
    );
    expect(provider.profile?.conjoint?.birthYear, 1965);
    expect(provider.profile?.conjoint?.prevoyance?.anneesContribuees, 38);
  });

  test('AVS legal predicates are distinct', () {
    CoachProfile profile(String civilStatus) => CoachProfile.fromWizardAnswers({
          'q_birth_year': 1985,
          'q_civil_status': civilStatus,
        });

    for (final status in ['married', 'registered_partner']) {
      expect(profile(status).hasPartnerContext, isTrue, reason: status);
      expect(profile(status).isAvsMarriageEquivalent, isTrue, reason: status);
    }
    for (final status in ['cohabiting', 'concubinage']) {
      expect(profile(status).hasPartnerContext, isTrue, reason: status);
      expect(profile(status).isAvsMarriageEquivalent, isFalse, reason: status);
    }
    for (final status in ['single', 'divorced', 'widowed']) {
      expect(profile(status).hasPartnerContext, isFalse, reason: status);
      expect(profile(status).isAvsMarriageEquivalent, isFalse, reason: status);
    }
  });

  test('bare partenariat is quarantined for reconfirmation', () {
    final profile = CoachProfile.fromWizardAnswers({
      'q_birth_year': 1985,
      'q_civil_status': 'partenariat',
      'q_partner_birth_year': 1965,
      'q_spouse_avs_contribution_years': 38,
    });

    expect(profile.civilStatusNeedsConfirmation, isTrue);
    expect(profile.civilStatusRawValue, 'partenariat');
    expect(profile.etatCivil, isNot(CoachCivilStatus.marie));
    expect(profile.etatCivil, isNot(CoachCivilStatus.concubinage));
    expect(profile.hasPartnerContext, isFalse);
    expect(profile.isAvsMarriageEquivalent, isFalse);
    expect(profile.conjoint?.birthYear, 1965);
    expect(profile.conjoint?.prevoyance?.anneesContribuees, 38);

    final restored = CoachProfile.fromJson(profile.toJson());
    expect(restored.civilStatusNeedsConfirmation, isTrue);
    expect(restored.civilStatusRawValue, 'partenariat');
    expect(restored.hasPartnerContext, isFalse);
    expect(restored.isAvsMarriageEquivalent, isFalse);
    expect(restored.conjoint?.birthYear, 1965);

    final legacyJson = CoachProfile.defaults().toJson()
      ..['etatCivil'] = 'partenariat'
      ..remove('civilStatusNeedsConfirmation')
      ..remove('civilStatusRawValue');
    final migratedLegacy = CoachProfile.fromJson(legacyJson);
    expect(migratedLegacy.civilStatusNeedsConfirmation, isTrue);
    expect(migratedLegacy.civilStatusRawValue, 'partenariat');
    expect(migratedLegacy.hasPartnerContext, isFalse);

    final confirmed = profile.copyWith(
      etatCivil: CoachCivilStatus.registeredPartnership,
    );
    expect(confirmed.civilStatusNeedsConfirmation, isFalse);
    expect(confirmed.civilStatusRawValue, isNull);
    expect(confirmed.conjoint?.birthYear, 1965);
    expect(confirmed, isNot(profile));

    final confirmedSingle = profile.copyWith(
      etatCivil: CoachCivilStatus.celibataire,
    );
    expect(confirmedSingle.civilStatusNeedsConfirmation, isFalse);
    expect(confirmedSingle.civilStatusRawValue, isNull);
    expect(confirmedSingle.conjoint, isNull);
  });

  test('foreign union tokens require recognition confirmation', () {
    for (final rawStatus in [
      'pacs',
      ' PACS ',
      'civil_union',
      'foreign_registered_partnership',
    ]) {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_civil_status': rawStatus,
        'q_partner_birth_year': 1965,
        'q_spouse_avs_contribution_years': 38,
      });

      expect(profile.civilStatusNeedsConfirmation, isTrue, reason: rawStatus);
      expect(profile.civilStatusRawValue, rawStatus, reason: rawStatus);
      expect(profile.hasPartnerContext, isFalse, reason: rawStatus);
      expect(profile.isAvsMarriageEquivalent, isFalse, reason: rawStatus);
      expect(profile.conjoint?.birthYear, 1965, reason: rawStatus);
      expect(
        profile.conjoint?.prevoyance?.anneesContribuees,
        38,
        reason: rawStatus,
      );

      final restored = CoachProfile.fromJson(profile.toJson());
      expect(
        restored.civilStatusNeedsConfirmation,
        isTrue,
        reason: rawStatus,
      );
      expect(restored.civilStatusRawValue, rawStatus, reason: rawStatus);
      expect(restored.isAvsMarriageEquivalent, isFalse, reason: rawStatus);
      expect(restored.conjoint?.birthYear, 1965, reason: rawStatus);

      final legacyJson = CoachProfile.defaults().toJson()
        ..['etatCivil'] = rawStatus
        ..remove('civilStatusNeedsConfirmation')
        ..remove('civilStatusRawValue');
      final migratedLegacy = CoachProfile.fromJson(legacyJson);
      expect(
        migratedLegacy.civilStatusNeedsConfirmation,
        isTrue,
        reason: rawStatus,
      );
      expect(
        migratedLegacy.civilStatusRawValue,
        rawStatus,
        reason: rawStatus,
      );
      expect(
        migratedLegacy.isAvsMarriageEquivalent,
        isFalse,
        reason: rawStatus,
      );

      final inconsistentJson = CoachProfile.defaults().toJson()
        ..['etatCivil'] = rawStatus
        ..['civilStatusNeedsConfirmation'] = false
        ..['civilStatusRawValue'] = rawStatus;
      final failClosed = CoachProfile.fromJson(inconsistentJson);
      expect(
        failClosed.civilStatusNeedsConfirmation,
        isTrue,
        reason: rawStatus,
      );
      expect(failClosed.civilStatusRawValue, rawStatus, reason: rawStatus);
      expect(
        failClosed.isAvsMarriageEquivalent,
        isFalse,
        reason: rawStatus,
      );
    }
  });

  for (final rawStatus in [
    'pacs',
    ' PACS ',
    'civil_union',
    'foreign_registered_partnership',
  ]) {
    test('$rawStatus merge and restart preserve partner facts', () async {
      await ReportPersistenceService.saveAnswers({
        'q_birth_year': 1985,
        'q_civil_status': 'married',
        'q_partner_birth_year': 1965,
        'q_spouse_avs_contribution_years': 38,
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      final provider = CoachProfileProvider();

      await provider.mergeAnswers({'q_civil_status': rawStatus});

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers, containsPair('q_civil_status', rawStatus));
      expect(answers, containsPair('q_partner_birth_year', 1965));
      expect(answers, containsPair('q_spouse_avs_contribution_years', 38));
      expect(provider.profile?.civilStatusNeedsConfirmation, isTrue);
      expect(provider.profile?.civilStatusRawValue, rawStatus);
      expect(provider.profile?.isAvsMarriageEquivalent, isFalse);
      expect(provider.profile?.conjoint?.birthYear, 1965);

      final restarted = CoachProfileProvider();
      await restarted.loadFromWizard();

      expect(restarted.profile?.civilStatusNeedsConfirmation, isTrue);
      expect(restarted.profile?.civilStatusRawValue, rawStatus);
      expect(restarted.profile?.hasPartnerContext, isFalse);
      expect(restarted.profile?.isAvsMarriageEquivalent, isFalse);
      expect(restarted.profile?.conjoint?.birthYear, 1965);
      expect(
        restarted.profile?.conjoint?.prevoyance?.anneesContribuees,
        38,
      );
    });
  }
}
