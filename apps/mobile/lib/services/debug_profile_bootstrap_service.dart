import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DebugProfileBootstrapMode {
  establish,
  updateIncome,
}

class DebugProfileBootstrapResult {
  final bool ok;
  final String slug;
  final DebugProfileBootstrapMode mode;
  final bool seedActive;
  final double? selfEmployedNetIncomeAnnual;
  final double? monthlyNetIncome;
  final double? annual3aContribution;
  final String storageMode;
  final String? error;

  const DebugProfileBootstrapResult({
    required this.ok,
    required this.slug,
    required this.mode,
    required this.seedActive,
    required this.storageMode,
    this.selfEmployedNetIncomeAnnual,
    this.monthlyNetIncome,
    this.annual3aContribution,
    this.error,
  });
}

class DebugProfileBootstrapService {
  DebugProfileBootstrapService._();

  static Future<DebugProfileBootstrapResult> persistFixture({
    required String slug,
    DebugProfileBootstrapMode mode = DebugProfileBootstrapMode.establish,
    double? selfEmployedNetIncomeAnnual,
    double? annual3aContribution,
  }) async {
    if (kReleaseMode) {
      return DebugProfileBootstrapResult(
        ok: false,
        slug: slug,
        mode: mode,
        seedActive: false,
        storageMode: 'unavailable',
        error: 'Debug profile bootstrap is unavailable in release builds.',
      );
    }

    final seed = CoachProfileSeeds.registry[slug];
    if (seed == null) {
      return DebugProfileBootstrapResult(
        ok: false,
        slug: slug,
        mode: mode,
        seedActive: CoachProfileSeeds.activeSeed != null,
        storageMode: 'unavailable',
        error: 'Unknown debug fixture: $slug',
      );
    }

    final answers = mode == DebugProfileBootstrapMode.updateIncome
        ? await ReportPersistenceService.loadAnswers()
        : Map<String, dynamic>.from(seed.toWizardAnswers());
    if (mode == DebugProfileBootstrapMode.updateIncome && answers.isEmpty) {
      return DebugProfileBootstrapResult(
        ok: false,
        slug: slug,
        mode: mode,
        seedActive: CoachProfileSeeds.activeSeed != null,
        storageMode: 'unavailable',
        error: 'Cannot update debug fixture before persisted answers exist.',
      );
    }

    final appliesIndependentNoLppPatch = selfEmployedNetIncomeAnnual != null ||
        seed.independentNetProfessionalIncomeAnnual != null ||
        answers.containsKey('q_self_employed_net_income_annual_chf');
    final annualIncome = appliesIndependentNoLppPatch
        ? selfEmployedNetIncomeAnnual ??
            _parseDouble(answers['q_self_employed_net_income_annual_chf']) ??
            seed.independentNetProfessionalIncomeAnnual
        : null;

    if (appliesIndependentNoLppPatch) {
      answers['q_employment_status'] = 'independant';
      answers['q_has_pension_fund'] = false;
      answers['q_pay_frequency'] = 'monthly';
      if (annualIncome != null) {
        answers['q_self_employed_net_income_annual_chf'] = annualIncome;
        answers['q_net_income_period_chf'] = annualIncome / 12;
      }
    }

    final annual3a = annual3aContribution ??
        _parseDouble(answers['q_3a_annual_contribution']) ??
        seed.annual3aContribution;
    if (annual3a != null &&
        (annual3aContribution != null || appliesIndependentNoLppPatch)) {
      answers['q_3a_annual_contribution'] = annual3a;
      answers['q_has_3a'] = annual3a > 0;
      if (appliesIndependentNoLppPatch) {
        answers['q_3a_accounts_count'] = annual3a > 0 ? 1 : 0;
      }
    }
    final monthlyNetIncome = _parseDouble(answers['q_net_income_period_chf']) ??
        (annualIncome == null ? null : annualIncome / 12);

    var storageMode = 'secureSeal';
    var sealed = await ReportPersistenceService.saveAnswers(answers);
    if (!sealed) {
      sealed = await _savePlainDebugFixtureForSimulator(answers);
      storageMode = sealed ? 'debugPlainFallback' : 'unavailable';
    }
    if (!sealed) {
      return DebugProfileBootstrapResult(
        ok: false,
        slug: slug,
        mode: mode,
        seedActive: CoachProfileSeeds.activeSeed != null,
        storageMode: storageMode,
        selfEmployedNetIncomeAnnual: annualIncome,
        monthlyNetIncome: monthlyNetIncome,
        annual3aContribution: annual3a,
        error: 'Profile fixture could not be sealed into secure storage.',
      );
    }

    await ReportPersistenceService.setCompleted(true);

    return DebugProfileBootstrapResult(
      ok: true,
      slug: slug,
      mode: mode,
      seedActive: CoachProfileSeeds.activeSeed != null,
      storageMode: storageMode,
      selfEmployedNetIncomeAnnual: annualIncome,
      monthlyNetIncome: monthlyNetIncome,
      annual3aContribution: annual3a,
    );
  }

  static Future<bool> _savePlainDebugFixtureForSimulator(
    Map<String, dynamic> answers,
  ) async {
    if (kReleaseMode) return false;
    // E2E-only fixture path: iOS simulators can reject keychain writes. This
    // keeps the non-seed restart proof possible without weakening production
    // SEC-10, because the route and this fallback are unreachable in release.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wizard_answers_v2', json.encode(answers));
    return true;
  }

  static double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
