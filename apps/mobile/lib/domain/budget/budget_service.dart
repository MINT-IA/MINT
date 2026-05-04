import 'dart:math';
import 'budget_inputs.dart';
import 'budget_plan.dart';

class BudgetService {
  static const String disclaimer =
      'Outil éducatif — ne constitue pas un conseil financier '
      'personnalisé au sens de la LSFin. Les montants sont des '
      'estimations basées sur les données déclarées.';

  static const List<String> sources = [
    'LP art. 93 (minimum vital / calcul du budget)',
    'Directives CSIAS (Conférence suisse des institutions d\'action sociale)',
    'LAMal art. 61 (primes d\'assurance-maladie obligatoire)',
    'LIFD art. 33 (déductions fiscales fédérales)',
    'CC art. 163 (contribution d\'entretien / charges du ménage)',
  ];

  /// Premier éclairage : pourcentage des charges fixes par rapport au revenu net.
  ///
  /// Wave 7 fiscal audit P0-B1 (2026-04-18) — la version précédente
  /// retournait « 0 % de ton revenu part en charges fixes » quand
  /// `netIncome <= 0` (masque un profil incomplet) et acceptait sans
  /// broncher des pct > 100 % (situation dette-crise sans aucun signal
  /// d'escalade). Cette version escalade aux seuils 70 % / 100 % pour
  /// que l'UI (et le coach, via `BudgetPlan.distress`) puisse router
  /// vers le Safe Mode protection-désendettement (CLAUDE.md §7).
  /// Sources : LP art. 93 (minimum vital), normes CSIAS 2025.
  static String premierEclairage(BudgetInputs inputs) {
    if (inputs.netIncome <= 0 || !inputs.netIncome.isFinite) {
      return 'Déclare ton revenu net pour voir la part de tes charges fixes';
    }
    final totalCharges = _totalFixedCharges(inputs);
    if (!totalCharges.isFinite) {
      return 'Complète tes charges fixes pour voir ton éclairage';
    }
    final ratio = totalCharges / inputs.netIncome;
    final pct = (ratio * 100).round();
    if (ratio >= BudgetPlan.criticalThreshold) {
      return '$pct % — tes charges fixes dépassent ton revenu. '
          'Safe Mode recommandé (LP art. 93).';
    }
    if (ratio >= BudgetPlan.fragileThreshold) {
      return '$pct % de ton revenu part en charges fixes. '
          'Situation fragile — priorité désendettement (LP art. 93).';
    }
    return '$pct % de ton revenu part en charges fixes';
  }

  static double _totalFixedCharges(BudgetInputs inputs) =>
      inputs.housingCost +
      inputs.debtPayments +
      inputs.taxProvision +
      inputs.healthInsurance +
      inputs.otherFixedCosts;

  /// Classe le niveau de détresse budgétaire — alimente `BudgetPlan.distress`.
  static BudgetDistressLevel _distressOf(BudgetInputs inputs) {
    if (inputs.netIncome <= 0 || !inputs.netIncome.isFinite) {
      return BudgetDistressLevel.unknown;
    }
    final charges = _totalFixedCharges(inputs);
    if (!charges.isFinite) return BudgetDistressLevel.unknown;
    final ratio = charges / inputs.netIncome;
    if (ratio >= BudgetPlan.criticalThreshold) return BudgetDistressLevel.critical;
    if (ratio >= BudgetPlan.fragileThreshold) return BudgetDistressLevel.fragile;
    return BudgetDistressLevel.none;
  }

  static double? _chargesRatioOf(BudgetInputs inputs) {
    if (inputs.netIncome <= 0 || !inputs.netIncome.isFinite) return null;
    final charges = _totalFixedCharges(inputs);
    if (!charges.isFinite) return null;
    return charges / inputs.netIncome;
  }

  /// Calcule le plan budgétaire en fonction des inputs et des overrides optionnels (sliders).
  /// [overrides] contient les valeurs forcées par l'utilisateur pour 'variables' ou 'future'.
  BudgetPlan computePlan(BudgetInputs inputs,
      {Map<String, double>? overrides}) {
    // 1. Calcul du Available de base
    // available = income - charges fixes (logement + dettes + impots + sante + autres)
    // On s'assure de ne pas descendre sous 0 logiquement pour le "disponible à répartir"
    // (même si techniquement un déficit est possible, ici on parle de l'allocation).
    final rawAvailable = inputs.netIncome -
        inputs.housingCost -
        inputs.debtPayments -
        inputs.taxProvision -
        inputs.healthInsurance -
        inputs.otherFixedCosts;
    final available = max(0.0, rawAvailable);

    final distress = _distressOf(inputs);
    final chargesRatio = _chargesRatioOf(inputs);

    if (inputs.style == BudgetStyle.justAvailable) {
      return BudgetPlan(
        available: available,
        variables:
            available, // Tout est considéré comme disponible/variable par défaut
        future: 0,
        stopRuleTriggered: false,
        emergencyFundMonths: inputs.emergencyFundMonths,
        distress: distress,
        chargesRatio: chargesRatio,
      );
    }

    // Cas Envelopes 3
    // Par défaut, sans overrides, tout va dans variables, future=0 (comportement safe par défaut)
    // Ou alors on pourrait faire 50/30/20 mais la consigne dit "pas de ratios universels".
    // Donc: default variables = available.

    double variables = available;
    double future = 0;

    if (overrides != null) {
      // Si on a des overrides, on essaie de les respecter tout en gardant la somme = available.
      // Priorité à l'input utilisateur.
      // Si l'user définit 'future', variables = available - future.
      // Si l'user définit 'variables', future = available - variables.

      if (overrides.containsKey('future')) {
        future = overrides['future']!;
        // Clamp pour rester cohérent
        future = max(0.0, min(available, future));
        variables = available - future;
      } else if (overrides.containsKey('variables')) {
        variables = overrides['variables']!;
        variables = max(0.0, min(available, variables));
        future = available - variables;
      }
    }

    // Stop Rule: Si Envelopes mode et variables == 0 => Stop dépot
    // (Consigne: stopRuleTriggered = (style=envelopes_3 && variables == 0))
    // Note: variables peut être 0 si available est 0, ou si l'user a tout mis dans future (peu probable mais possible).
    // La consigne semble impliquer une alerte si on n'a plus rien pour vivre.
    final _ = (inputs.style == BudgetStyle.envelopes3 &&
        variables <= 0.01 &&
        available > 0);
    // J'ajoute available > 0 pour ne pas trigger le stop rule si on n'a juste pas de revenus (cas edge).
    // Quoique, si available=0, variables=0, le stop rule est pertinent aussi.
    // Respectons la spec stricte: "stopRuleTriggered = (style=envelopes_3 && variables == 0)"
    // J'utilise un epsilon pour les doubles.

    return BudgetPlan(
      available: available,
      variables: variables,
      future: future,
      stopRuleTriggered: variables <= 0.01,
      /* quasi 0 */
      emergencyFundMonths: inputs.emergencyFundMonths,
      distress: distress,
      chargesRatio: chargesRatio,
    );
  }
}
