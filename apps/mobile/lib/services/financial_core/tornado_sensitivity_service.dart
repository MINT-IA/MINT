/// Tornado / sensitivity analysis — pure static service.
///
/// For each key input variable, computes two scenarios (pessimistic/optimistic),
/// calls the full retirement projection for each, and measures the impact on
/// the hero metric (revenuMensuelAt65). Returns a sorted list ready for display
/// in a Tornado chart.
///
/// Ref: educational tool, not financial advice (LSFin).
///
/// Sources:
///   - LPP art. 14 (taux de conversion minimum)
///   - LAVS art. 21-29 (rente AVS)
///   - OPP3 art. 7 (plafond 3a)
///   - LIFD art. 38 (imposition prestations en capital)
library;

import 'dart:math' show min, max;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

// ════════════════════════════════════════════════════════════════
//  DATA MODEL
// ════════════════════════════════════════════════════════════════

/// One variable in the Tornado chart.
class TornadoVariable {
  /// Label affiche en francais.
  final String label;

  /// Categorie : 'strategy', 'lpp', 'avs', '3a', 'libre', 'depenses'.
  final String category;

  /// Revenu mensuel a 65 ans avec les hypotheses de base.
  final double baseValue;

  /// Revenu mensuel a 65 ans avec l'hypothese pessimiste.
  final double lowValue;

  /// Revenu mensuel a 65 ans avec l'hypothese optimiste.
  final double highValue;

  /// Ecart absolu = highValue - lowValue.
  final double swing;

  /// Label lisible de l'hypothese basse (ex: "-20%", "63 ans").
  final String lowLabel;

  /// Label lisible de l'hypothese haute (ex: "+20%", "67 ans").
  final String highLabel;

  const TornadoVariable({
    required this.label,
    required this.category,
    required this.baseValue,
    required this.lowValue,
    required this.highValue,
    required this.swing,
    required this.lowLabel,
    required this.highLabel,
  });
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

class TornadoSensitivityService {
  TornadoSensitivityService._();

  /// Compute tornado sensitivity for all key variables.
  /// Returns list sorted by swing (descending = most impactful first).
  static List<TornadoVariable> compute({
    required CoachProfile profile,
    required int retirementAgeUser,
    int? retirementAgeConjoint,
    double? depensesMensuelles,
    double lppCapitalPct = 0.0,
  }) {
    // ── Base projection ──────────────────────────────────
    final baseResult = _project(
      profile: profile,
      retirementAgeUser: retirementAgeUser,
      retirementAgeConjoint: retirementAgeConjoint,
      depensesMensuelles: depensesMensuelles,
      lppCapitalPct: lppCapitalPct,
    );
    final base = baseResult;

    final variables = <TornadoVariable>[];

    // ── 1. Age de depart (strategy) ──────────────────────
    {
      final lowAge = max(58, retirementAgeUser - 2);
      final highAge = min(70, retirementAgeUser + 2);
      // Skip if collapsed range (user already at boundary).
      if (lowAge < highAge) {
        final low = _project(
          profile: profile,
          retirementAgeUser: lowAge,
          retirementAgeConjoint: retirementAgeConjoint,
          depensesMensuelles: depensesMensuelles,
          lppCapitalPct: lppCapitalPct,
        );
        final high = _project(
          profile: profile,
          retirementAgeUser: highAge,
          retirementAgeConjoint: retirementAgeConjoint,
          depensesMensuelles: depensesMensuelles,
          lppCapitalPct: lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Age de depart',
          category: 'strategy',
          base: base,
          low: low,
          high: high,
          lowLabel: '$lowAge ans',
          highLabel: '$highAge ans',
        ));
      }
    }

    // ── 2. Strategie LPP rente vs capital (strategy) ─────
    {
      final low = _project(
        profile: profile,
        retirementAgeUser: retirementAgeUser,
        retirementAgeConjoint: retirementAgeConjoint,
        depensesMensuelles: depensesMensuelles,
        lppCapitalPct: 0.0,
      );
      final high = _project(
        profile: profile,
        retirementAgeUser: retirementAgeUser,
        retirementAgeConjoint: retirementAgeConjoint,
        depensesMensuelles: depensesMensuelles,
        lppCapitalPct: 1.0,
      );
      variables.add(_buildVariable(
        label: 'Strategie LPP (rente vs capital)',
        category: 'strategy',
        base: base,
        low: low,
        high: high,
        lowLabel: '100% rente',
        highLabel: '100% capital',
      ));
    }

    // ── 3. Salaire brut (±20%) ───────────────────────────
    {
      final baseSalary = profile.salaireBrutMensuel;
      if (baseSalary > 0) {
        final lowSalary = baseSalary * 0.80;
        final highSalary = baseSalary * 1.20;
        final low = _projectWithProfile(
          profile.copyWith(salaireBrutMensuel: lowSalary),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        final high = _projectWithProfile(
          profile.copyWith(salaireBrutMensuel: highSalary),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Salaire brut',
          category: 'lpp',
          base: base,
          low: low,
          high: high,
          lowLabel: '-20%',
          highLabel: '+20%',
        ));
      }
    }

    // ── 4. Avoir LPP actuel (±30%) ──────────────────────
    {
      final baseAvoir = profile.prevoyance.avoirLppTotal ?? 0;
      if (baseAvoir > 0) {
        final low = _projectWithPrevoyance(
          profile,
          _clonePrevoyanceWith(profile.prevoyance,
            avoirLppTotal: baseAvoir * 0.70,
          ),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        final high = _projectWithPrevoyance(
          profile,
          _clonePrevoyanceWith(profile.prevoyance,
            avoirLppTotal: baseAvoir * 1.30,
          ),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Avoir LPP actuel',
          category: 'lpp',
          base: base,
          low: low,
          high: high,
          lowLabel: '-30%',
          highLabel: '+30%',
        ));
      }
    }

    // ── 5. Taux de conversion LPP ───────────────────────
    {
      final baseTaux = profile.prevoyance.tauxConversion;
      const lowTaux = 0.050;
      final highTaux = baseTaux >= 0.068 ? 0.072 : 0.068;
      final low = _projectWithPrevoyance(
        profile,
        _clonePrevoyanceWith(profile.prevoyance, tauxConversion: lowTaux),
        retirementAgeUser, retirementAgeConjoint,
        depensesMensuelles, lppCapitalPct,
      );
      final high = _projectWithPrevoyance(
        profile,
        _clonePrevoyanceWith(profile.prevoyance, tauxConversion: highTaux),
        retirementAgeUser, retirementAgeConjoint,
        depensesMensuelles, lppCapitalPct,
      );
      variables.add(_buildVariable(
        label: 'Taux de conversion LPP',
        category: 'lpp',
        base: base,
        low: low,
        high: high,
        lowLabel: '${(lowTaux * 100).toStringAsFixed(1)}%',
        highLabel: '${(highTaux * 100).toStringAsFixed(1)}%',
      ));
    }

    // ── 6. Rendement caisse LPP ─────────────────────────
    {
      final low = _projectWithPrevoyance(
        profile,
        _clonePrevoyanceWith(profile.prevoyance, rendementCaisse: 0.01),
        retirementAgeUser, retirementAgeConjoint,
        depensesMensuelles, lppCapitalPct,
      );
      final high = _projectWithPrevoyance(
        profile,
        _clonePrevoyanceWith(profile.prevoyance, rendementCaisse: 0.03),
        retirementAgeUser, retirementAgeConjoint,
        depensesMensuelles, lppCapitalPct,
      );
      variables.add(_buildVariable(
        label: 'Rendement caisse LPP',
        category: 'lpp',
        base: base,
        low: low,
        high: high,
        lowLabel: '1.0%',
        highLabel: '3.0%',
      ));
    }

    // ── 7. Capital 3e pilier (±50%) ─────────────────────
    {
      final base3a = profile.prevoyance.totalEpargne3a;
      if (base3a > 0) {
        final low = _projectWithPrevoyance(
          profile,
          _clonePrevoyanceWith(profile.prevoyance,
              totalEpargne3a: base3a * 0.50),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        final high = _projectWithPrevoyance(
          profile,
          _clonePrevoyanceWith(profile.prevoyance,
              totalEpargne3a: base3a * 1.50),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Capital 3e pilier',
          category: '3a',
          base: base,
          low: low,
          high: high,
          lowLabel: '-50%',
          highLabel: '+50%',
        ));
      }
    }

    // ── 8. Epargne 3a mensuelle (0 vs capped 2x) ────────
    {
      final base3aMensuel = profile.total3aMensuel;
      if (base3aMensuel > 0) {
        // Cap high scenario at OPP3 legal max (pilier3aPlafondAvecLpp).
        final plafond3aMensuel = pilier3aPlafondAvecLpp / 12;
        final cappedHigh = min(base3aMensuel * 2, plafond3aMensuel);

        // Skip if already at max (cappedHigh would equal base, zero swing).
        if (cappedHigh > base3aMensuel) {
          // Zero contributions
          final contribsNo3a = profile.plannedContributions
              .where((c) => c.category != '3a')
              .toList();
          // Scale each 3a contribution proportionally to reach cappedHigh.
          final scaleFactor = cappedHigh / base3aMensuel;
          final contribsCapped = profile.plannedContributions.map((c) {
            if (c.category == '3a') {
              return c.copyWith(amount: c.amount * scaleFactor);
            }
            return c;
          }).toList();

          final low = _projectWithProfile(
            profile.copyWith(plannedContributions: contribsNo3a),
            retirementAgeUser, retirementAgeConjoint,
            depensesMensuelles, lppCapitalPct,
          );
          final high = _projectWithProfile(
            profile.copyWith(plannedContributions: contribsCapped),
            retirementAgeUser, retirementAgeConjoint,
            depensesMensuelles, lppCapitalPct,
          );
          variables.add(_buildVariable(
            label: 'Epargne 3a mensuelle',
            category: '3a',
            base: base,
            low: low,
            high: high,
            lowLabel: 'CHF 0/mois',
            highLabel: 'CHF ${cappedHigh.round()}/mois',
          ));
        }
      }
    }

    // ── 9. Annees AVS cotisees (±5 ans) ─────────────────
    {
      final baseYears = profile.prevoyance.anneesContribuees;
      if (baseYears != null && baseYears > 0) {
        final lowYears = (baseYears - 5).clamp(0, avsDureeCotisationComplete);
        final highYears = (baseYears + 5).clamp(0, avsDureeCotisationComplete);
        final low = _projectWithPrevoyance(
          profile,
          _clonePrevoyanceWith(profile.prevoyance,
              anneesContribuees: lowYears),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        final high = _projectWithPrevoyance(
          profile,
          _clonePrevoyanceWith(profile.prevoyance,
              anneesContribuees: highYears),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Annees AVS cotisees',
          category: 'avs',
          base: base,
          low: low,
          high: high,
          lowLabel: '$lowYears ans',
          highLabel: '$highYears ans',
        ));
      }
    }

    // ── 10. Lacunes AVS (0 vs +3) ──────────────────────
    {
      final baseLacunes = profile.prevoyance.lacunesAVS ?? 0;
      final low = _projectWithPrevoyance(
        profile,
        _clonePrevoyanceWith(profile.prevoyance,
            lacunesAVS: baseLacunes + 3, forceLacunesAVS: true),
        retirementAgeUser, retirementAgeConjoint,
        depensesMensuelles, lppCapitalPct,
      );
      final high = _projectWithPrevoyance(
        profile,
        _clonePrevoyanceWith(profile.prevoyance,
            lacunesAVS: 0, forceLacunesAVS: true),
        retirementAgeUser, retirementAgeConjoint,
        depensesMensuelles, lppCapitalPct,
      );
      variables.add(_buildVariable(
        label: 'Lacunes AVS',
        category: 'avs',
        base: base,
        low: low,
        high: high,
        lowLabel: '${baseLacunes + 3} lacunes',
        highLabel: '0 lacune',
      ));
    }

    // ── 11. Investissements libres (±50%) ───────────────
    {
      final baseInvest = profile.patrimoine.investissements;
      if (baseInvest > 0) {
        final low = _projectWithPatrimoine(
          profile,
          PatrimoineProfile(
            epargneLiquide: profile.patrimoine.epargneLiquide,
            investissements: baseInvest * 0.50,
            immobilier: profile.patrimoine.immobilier,
            deviseInvestissements: profile.patrimoine.deviseInvestissements,
            plateformeInvestissement:
                profile.patrimoine.plateformeInvestissement,
          ),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        final high = _projectWithPatrimoine(
          profile,
          PatrimoineProfile(
            epargneLiquide: profile.patrimoine.epargneLiquide,
            investissements: baseInvest * 1.50,
            immobilier: profile.patrimoine.immobilier,
            deviseInvestissements: profile.patrimoine.deviseInvestissements,
            plateformeInvestissement:
                profile.patrimoine.plateformeInvestissement,
          ),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Investissements libres',
          category: 'libre',
          base: base,
          low: low,
          high: high,
          lowLabel: '-50%',
          highLabel: '+50%',
        ));
      }
    }

    // ── 12. Epargne liquide (±50%) ──────────────────────
    {
      final baseEpargne = profile.patrimoine.epargneLiquide;
      if (baseEpargne > 0) {
        final low = _projectWithPatrimoine(
          profile,
          PatrimoineProfile(
            epargneLiquide: baseEpargne * 0.50,
            investissements: profile.patrimoine.investissements,
            immobilier: profile.patrimoine.immobilier,
            deviseInvestissements: profile.patrimoine.deviseInvestissements,
            plateformeInvestissement:
                profile.patrimoine.plateformeInvestissement,
          ),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        final high = _projectWithPatrimoine(
          profile,
          PatrimoineProfile(
            epargneLiquide: baseEpargne * 1.50,
            investissements: profile.patrimoine.investissements,
            immobilier: profile.patrimoine.immobilier,
            deviseInvestissements: profile.patrimoine.deviseInvestissements,
            plateformeInvestissement:
                profile.patrimoine.plateformeInvestissement,
          ),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Epargne liquide',
          category: 'libre',
          base: base,
          low: low,
          high: high,
          lowLabel: '-50%',
          highLabel: '+50%',
        ));
      }
    }

    // ── 13. Epargne libre mensuelle (±50%) ──────────────
    {
      final baseLibreMensuel = profile.totalEpargneLibreMensuel;
      if (baseLibreMensuel > 0) {
        final contribsLow = profile.plannedContributions.map((c) {
          if (c.category == 'epargne_libre' || c.category == 'investissement') {
            return c.copyWith(amount: c.amount * 0.50);
          }
          return c;
        }).toList();
        final contribsHigh = profile.plannedContributions.map((c) {
          if (c.category == 'epargne_libre' || c.category == 'investissement') {
            return c.copyWith(amount: c.amount * 1.50);
          }
          return c;
        }).toList();

        final low = _projectWithProfile(
          profile.copyWith(plannedContributions: contribsLow),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        final high = _projectWithProfile(
          profile.copyWith(plannedContributions: contribsHigh),
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Epargne libre mensuelle',
          category: 'libre',
          base: base,
          low: low,
          high: high,
          lowLabel: '-50%',
          highLabel: '+50%',
        ));
      }
    }

    // ── 14. Salaire conjoint·e (±20%) — couples only ────
    if (profile.isCouple && profile.conjoint != null) {
      final conjSalaire = profile.conjoint!.salaireBrutMensuel;
      if (conjSalaire != null && conjSalaire > 0) {
        final lowConj = profile.copyWith(
          conjoint: profile.conjoint!.copyWith(
            salaireBrutMensuel: conjSalaire * 0.80,
          ),
        );
        final highConj = profile.copyWith(
          conjoint: profile.conjoint!.copyWith(
            salaireBrutMensuel: conjSalaire * 1.20,
          ),
        );
        final low = _projectWithProfile(
          lowConj,
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        final high = _projectWithProfile(
          highConj,
          retirementAgeUser, retirementAgeConjoint,
          depensesMensuelles, lppCapitalPct,
        );
        variables.add(_buildVariable(
          label: 'Salaire conjoint\u00B7e',
          category: 'lpp',
          base: base,
          low: low,
          high: high,
          lowLabel: '-20%',
          highLabel: '+20%',
        ));
      }
    }

    // ── Sort by swing descending ─────────────────────────
    variables.sort((a, b) => b.swing.compareTo(a.swing));

    return variables;
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS — projection wrappers
  // ════════════════════════════════════════════════════════════════

  /// Run projection and return revenuMensuelAt65.
  /// Returns 0.0 on failure to prevent one bad scenario from crashing the
  /// entire tornado computation.
  static double _project({
    required CoachProfile profile,
    required int retirementAgeUser,
    int? retirementAgeConjoint,
    double? depensesMensuelles,
    double lppCapitalPct = 0.0,
  }) {
    try {
      final result = RetirementProjectionService.project(
        profile: profile,
        retirementAgeUser: retirementAgeUser,
        retirementAgeConjoint: retirementAgeConjoint,
        depensesMensuelles: depensesMensuelles,
        lppCapitalPct: lppCapitalPct,
      );
      return result.revenuMensuelAt65;
    } catch (_) {
      return 0.0;
    }
  }

  /// Shorthand: project with a modified profile.
  static double _projectWithProfile(
    CoachProfile modifiedProfile,
    int retirementAgeUser,
    int? retirementAgeConjoint,
    double? depensesMensuelles,
    double lppCapitalPct,
  ) {
    return _project(
      profile: modifiedProfile,
      retirementAgeUser: retirementAgeUser,
      retirementAgeConjoint: retirementAgeConjoint,
      depensesMensuelles: depensesMensuelles,
      lppCapitalPct: lppCapitalPct,
    );
  }

  /// Project with a modified PrevoyanceProfile.
  static double _projectWithPrevoyance(
    CoachProfile profile,
    PrevoyanceProfile newPrevoyance,
    int retirementAgeUser,
    int? retirementAgeConjoint,
    double? depensesMensuelles,
    double lppCapitalPct,
  ) {
    return _projectWithProfile(
      profile.copyWith(prevoyance: newPrevoyance),
      retirementAgeUser, retirementAgeConjoint,
      depensesMensuelles, lppCapitalPct,
    );
  }

  /// Project with a modified PatrimoineProfile.
  static double _projectWithPatrimoine(
    CoachProfile profile,
    PatrimoineProfile newPatrimoine,
    int retirementAgeUser,
    int? retirementAgeConjoint,
    double? depensesMensuelles,
    double lppCapitalPct,
  ) {
    return _projectWithProfile(
      profile.copyWith(patrimoine: newPatrimoine),
      retirementAgeUser, retirementAgeConjoint,
      depensesMensuelles, lppCapitalPct,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS — prevoyance cloning
  // ════════════════════════════════════════════════════════════════

  /// Clone PrevoyanceProfile with overridden fields.
  /// [forceLacunesAVS]: if true, use the provided lacunesAVS even if null/0.
  static PrevoyanceProfile _clonePrevoyanceWith(
    PrevoyanceProfile original, {
    double? avoirLppTotal,
    double? tauxConversion,
    double? rendementCaisse,
    double? totalEpargne3a,
    int? anneesContribuees,
    int? lacunesAVS,
    bool forceLacunesAVS = false,
  }) {
    return PrevoyanceProfile(
      anneesContribuees: anneesContribuees ?? original.anneesContribuees,
      lacunesAVS: forceLacunesAVS
          ? lacunesAVS
          : (lacunesAVS ?? original.lacunesAVS),
      renteAVSEstimeeMensuelle: original.renteAVSEstimeeMensuelle,
      nomCaisse: original.nomCaisse,
      avoirLppTotal: avoirLppTotal ?? original.avoirLppTotal,
      avoirLppObligatoire: original.avoirLppObligatoire,
      avoirLppSurobligatoire: original.avoirLppSurobligatoire,
      rachatMaximum: original.rachatMaximum,
      rachatEffectue: original.rachatEffectue,
      tauxConversion: tauxConversion ?? original.tauxConversion,
      tauxConversionSuroblig: original.tauxConversionSuroblig,
      rendementCaisse: rendementCaisse ?? original.rendementCaisse,
      salaireAssure: original.salaireAssure,
      ramd: original.ramd,
      nombre3a: original.nombre3a,
      totalEpargne3a: totalEpargne3a ?? original.totalEpargne3a,
      comptes3a: original.comptes3a,
      canContribute3a: original.canContribute3a,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS — build variable
  // ════════════════════════════════════════════════════════════════

  static TornadoVariable _buildVariable({
    required String label,
    required String category,
    required double base,
    required double low,
    required double high,
    required String lowLabel,
    required String highLabel,
  }) {
    return TornadoVariable(
      label: label,
      category: category,
      baseValue: base,
      lowValue: low,
      highValue: high,
      swing: (high - low).abs(),
      lowLabel: lowLabel,
      highLabel: highLabel,
    );
  }
}
