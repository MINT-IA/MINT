import 'package:flutter/material.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/confidence/confidence_dashboard_screen.dart';
import 'package:mint_mobile/screens/fiscal_comparator_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';

// ────────────────────────────────────────────────────────────
//  CHAT DRAWER HOST — CHAT-02 (Phase 3)
//
//  Shows any screen widget as a modal bottom sheet (drawer) over
//  the chat. The drawer takes ~90% of screen height, has a drag
//  handle, and dismisses back to the conversation.
//
//  Usage:
//    showChatDrawer(context: context, child: SomeScreen());
//
//  Route resolution:
//    ChatDrawerHost.resolveDrawerWidget('/pilier-3a') → widget or null
// ────────────────────────────────────────────────────────────

/// Shows a screen widget as a modal bottom sheet (drawer) over the chat.
///
/// The drawer takes ~90% of screen height, has a drag handle, and dismisses
/// back to the conversation. Standard Material bottom sheet animation.
Future<void> showChatDrawer({
  required BuildContext context,
  required Widget child,
  String? title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MintColors.craie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChatDrawerHost(title: title, child: child),
  );
}

/// Wrapper that provides drag handle + optional title + content.
class ChatDrawerHost extends StatelessWidget {
  final String? title;
  final Widget child;

  const ChatDrawerHost({
    super.key,
    this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Optional title
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Text(
                  title!,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            // Content
            Expanded(child: child),
          ],
        );
      },
    );
  }

  /// Resolves a route string to the corresponding screen widget.
  ///
  /// Returns null for unknown/unsupported routes so callers can use
  /// standard navigation.
  /// T-03-01: validates against known routes only — no arbitrary widget creation.
  ///
  static Widget? resolveDrawerWidget(String route) {
    // Strip query params for matching
    final basePath = route.split('?').first;

    // Known summonable routes → widget constructors.
    // Phase 5 can expand this map. Phase 3 covers the most common tool-call targets.
    final resolvers = <String, Widget Function()>{
      '/pilier-3a': () => const Simulator3aScreen(),
      '/rachat-lpp': () => const RachatEchelonneScreen(),
      '/retraite': () => const RetirementDashboardScreen(),
      '/retraite/rente-vs-capital': () => const RenteVsCapitalScreen(),
      '/fiscal': () => const FiscalComparatorScreen(),
      '/hypotheque': () => const AffordabilityScreen(),
      '/confidence': () => const ConfidenceDashboardDrawer(),
    };

    final resolver = resolvers[basePath];
    if (resolver == null) return null;

    return resolver();
  }
}

class ConfidenceDashboardDrawer extends StatelessWidget {
  const ConfidenceDashboardDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CoachProfileProvider?>()?.profile;
    return ConfidenceDashboardScreen(
      result: confidenceResultForCoachProfile(profile),
    );
  }
}

ConfidenceResult confidenceResultForCoachProfile(CoachProfile? profile) {
  if (profile == null) {
    return EnhancedConfidenceService.computeConfidence(
      const <String, dynamic>{},
      const <FieldSource>[],
    );
  }

  final values = <String, dynamic>{};
  final sources = <FieldSource>[];

  void add(
    String fieldName,
    Object? value,
    List<String> sourcePaths, {
    ProfileDataSource fallbackSource = ProfileDataSource.estimated,
    bool allowZero = false,
  }) {
    if (!_hasConfidenceValue(value, allowZero: allowZero)) return;

    values[fieldName] = value;
    final sourcePath = _bestSourcePath(profile, sourcePaths);
    final profileSource = profile.dataSources[sourcePath] ?? fallbackSource;
    sources.add(
      FieldSource(
        fieldName: fieldName,
        source: _toConfidenceDataSource(profileSource),
        updatedAt: profile.dataTimestamps[sourcePath] ?? profile.updatedAt,
        value: value,
      ),
    );
  }

  void addComposite(
    String fieldName,
    Object? value,
    Map<String, Object?> contributors,
  ) {
    if (!_hasConfidenceValue(value)) return;

    final activePaths = contributors.entries
        .where((entry) => _hasConfidenceValue(entry.value))
        .map((entry) => entry.key)
        .toList();
    if (activePaths.isEmpty) return;

    values[fieldName] = value;
    final profileSource = _weakestProfileDataSource(profile, activePaths);
    sources.add(
      FieldSource(
        fieldName: fieldName,
        source: _toConfidenceDataSource(profileSource),
        updatedAt: _oldestTimestamp(profile, activePaths),
        value: value,
      ),
    );
  }

  add(
    'age',
    profile.ageOrNull,
    const ['age', 'dateOfBirth', 'birthYear'],
    fallbackSource: _userProvidedFallback(profile, 'age'),
  );
  add(
    'canton',
    profile.canton.trim(),
    const ['canton'],
    fallbackSource: _userProvidedFallback(profile, 'canton'),
  );
  add(
    'salaire_brut',
    profile.revenuBrutAnnuel,
    const ['salaireBrutMensuel', 'revenuBrutAnnuel'],
    fallbackSource: _userProvidedFallback(profile, 'salary'),
  );
  add(
    'salaire_net',
    profile.explicitMonthlyNetIncome,
    const ['explicitMonthlyNetIncome'],
  );
  add(
    'lpp_total',
    profile.prevoyance.avoirLppTotal,
    const ['prevoyance.avoirLppTotal'],
    fallbackSource: _userProvidedFallback(profile, 'pensionFund'),
  );
  add(
    'lpp_obligatoire',
    profile.prevoyance.avoirLppObligatoire,
    const ['prevoyance.avoirLppObligatoire'],
  );
  add(
    'lpp_surobligatoire',
    profile.prevoyance.avoirLppSurobligatoire,
    const ['prevoyance.avoirLppSurobligatoire'],
  );
  add(
    'lpp_insured_salary',
    profile.prevoyance.salaireAssure,
    const ['prevoyance.salaireAssure'],
  );
  if (_hasProfileDataSource(profile, const ['prevoyance.tauxConversion'])) {
    add(
      'conversion_rate_oblig',
      profile.prevoyance.tauxConversion,
      const ['prevoyance.tauxConversion'],
    );
  }
  if (_hasProfileDataSource(
    profile,
    const ['prevoyance.tauxConversionSuroblig'],
  )) {
    add(
      'conversion_rate_suroblig',
      profile.prevoyance.tauxConversionSuroblig,
      const ['prevoyance.tauxConversionSuroblig'],
    );
  }
  add(
    'buyback_potential',
    profile.prevoyance.rachatMaximum,
    const ['prevoyance.rachatMaximum'],
  );
  add(
    'avs_contribution_years',
    profile.prevoyance.anneesContribuees,
    const ['prevoyance.anneesContribuees'],
    allowZero: _hasKnownProfileField(
      profile,
      const ['prevoyance.anneesContribuees'],
    ),
  );
  add(
    'avs_ramd',
    profile.prevoyance.ramd,
    const ['prevoyance.ramd'],
  );
  add(
    'pillar_3a_balance',
    profile.prevoyance.totalEpargne3a,
    const ['prevoyance.totalEpargne3a'],
  );
  addComposite(
    'patrimoine_total',
    profile.patrimoine.totalPatrimoine,
    {
      'patrimoine.epargneLiquide': profile.patrimoine.epargneLiquide,
      'patrimoine.investissements': profile.patrimoine.investissements,
      'patrimoine.propertyMarketValue': profile.patrimoine.propertyMarketValue,
      'patrimoine.immobilier': profile.patrimoine.immobilier,
    },
  );
  final mortgageRemaining =
      profile.patrimoine.mortgageBalance ?? profile.dettes.hypotheque;
  final mortgageRemainingPath = profile.patrimoine.mortgageBalance != null
      ? 'patrimoine.mortgageBalance'
      : 'dettes.hypotheque';
  add(
    'mortgage_remaining',
    mortgageRemaining,
    [mortgageRemainingPath],
    allowZero: _hasKnownProfileField(profile, [mortgageRemainingPath]),
  );
  final mortgageRate =
      profile.patrimoine.mortgageRate ?? profile.dettes.tauxHypotheque;
  final mortgageRatePath = profile.patrimoine.mortgageRate != null
      ? 'patrimoine.mortgageRate'
      : 'dettes.tauxHypotheque';
  add(
    'mortgage_rate',
    mortgageRate,
    [mortgageRatePath],
  );
  final propertyValue =
      profile.patrimoine.propertyMarketValue ?? profile.patrimoine.immobilier;
  final propertyValuePath = profile.patrimoine.propertyMarketValue != null
      ? 'patrimoine.propertyMarketValue'
      : 'patrimoine.immobilier';
  add(
    'property_value',
    propertyValue,
    [propertyValuePath],
  );
  if (profile.etatCivil != CoachCivilStatus.celibataire ||
      profile.userProvidedFields.contains('civilStatus')) {
    add('is_married', profile.etatCivil == CoachCivilStatus.marie,
        const ['etatCivil']);
  }
  add(
    'nb_children',
    profile.nombreEnfants,
    const ['nombreEnfants'],
    allowZero: _hasKnownProfileField(profile, const ['nombreEnfants']),
  );
  addComposite(
    'monthly_expenses',
    profile.depenses.totalMensuel,
    {
      'depenses.loyer': profile.depenses.loyer,
      'depenses.assuranceMaladie': profile.depenses.assuranceMaladie,
      'depenses.electricite': profile.depenses.electricite,
      'depenses.transport': profile.depenses.transport,
      'depenses.telecom': profile.depenses.telecom,
      'depenses.fraisMedicaux': profile.depenses.fraisMedicaux,
      'depenses.autresDepensesFixes': profile.depenses.autresDepensesFixes,
    },
  );
  if (profile.employmentStatus == 'independant' ||
      profile.userProvidedFields.contains('employmentStatus')) {
    add(
      'is_independant',
      profile.employmentStatus == 'independant',
      const ['employmentStatus'],
    );
  }
  if (profile.prevoyance.avoirLppTotal != null ||
      profile.userProvidedFields.contains('pensionFund')) {
    add(
      'has_lpp',
      profile.prevoyance.avoirLppTotal != null &&
          profile.prevoyance.avoirLppTotal! > 0,
      const ['prevoyance.avoirLppTotal'],
    );
  }

  return EnhancedConfidenceService.computeConfidence(
    values,
    sources,
    literacyLevel: profile.financialLiteracyLevel.name,
    checkInCount: profile.checkIns.length,
  );
}

String _bestSourcePath(CoachProfile profile, List<String> sourcePaths) {
  for (final path in sourcePaths) {
    if (profile.dataSources.containsKey(path) ||
        profile.dataTimestamps.containsKey(path)) {
      return path;
    }
  }
  return sourcePaths.first;
}

bool _hasKnownProfileField(CoachProfile profile, List<String> sourcePaths) {
  for (final path in sourcePaths) {
    if (profile.dataSources.containsKey(path) ||
        profile.dataTimestamps.containsKey(path)) {
      return true;
    }
  }
  return false;
}

bool _hasProfileDataSource(CoachProfile profile, List<String> sourcePaths) {
  for (final path in sourcePaths) {
    if (profile.dataSources.containsKey(path)) return true;
  }
  return false;
}

ProfileDataSource _weakestProfileDataSource(
  CoachProfile profile,
  List<String> sourcePaths,
) {
  var weakest = ProfileDataSource.openBanking;
  for (final path in sourcePaths) {
    final source = profile.dataSources[path] ?? ProfileDataSource.estimated;
    if (_profileSourceWeight(source) < _profileSourceWeight(weakest)) {
      weakest = source;
    }
  }
  return weakest;
}

DateTime _oldestTimestamp(CoachProfile profile, List<String> sourcePaths) {
  var oldest = profile.updatedAt;
  for (final path in sourcePaths) {
    final timestamp = profile.dataTimestamps[path] ?? profile.updatedAt;
    if (timestamp.isBefore(oldest)) oldest = timestamp;
  }
  return oldest;
}

double _profileSourceWeight(ProfileDataSource source) {
  return switch (source) {
    ProfileDataSource.estimated => 0.25,
    ProfileDataSource.userInput => 0.50,
    ProfileDataSource.crossValidated => 0.70,
    ProfileDataSource.certificate => 0.95,
    ProfileDataSource.openBanking => 1.00,
  };
}

ProfileDataSource _userProvidedFallback(CoachProfile profile, String field) {
  if (profile.userProvidedFields.contains(field)) {
    return ProfileDataSource.userInput;
  }
  return ProfileDataSource.estimated;
}

bool _hasConfidenceValue(Object? value, {bool allowZero = false}) {
  if (value == null) return false;
  if (value is num) return value.isFinite && (value > 0 || allowZero);
  if (value is String) return value.isNotEmpty;
  return true;
}

DataSource _toConfidenceDataSource(ProfileDataSource source) {
  return switch (source) {
    ProfileDataSource.estimated => DataSource.systemEstimate,
    ProfileDataSource.userInput => DataSource.userEntry,
    ProfileDataSource.crossValidated => DataSource.userEntryCrossValidated,
    ProfileDataSource.certificate => DataSource.documentScanVerified,
    ProfileDataSource.openBanking => DataSource.openBanking,
  };
}
