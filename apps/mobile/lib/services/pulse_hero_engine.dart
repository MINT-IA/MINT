import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Result of PulseHeroEngine — drives the adaptive hero card on Pulse.
class PulseHero {
  final String title;
  final String subtitle;
  final String? detail;
  final String ctaLabel;
  final String ctaRoute;
  final IconData icon;
  final Color color;

  const PulseHero({
    required this.title,
    required this.subtitle,
    this.detail,
    required this.ctaLabel,
    required this.ctaRoute,
    required this.icon,
    required this.color,
  });
}

/// Adaptive hero engine for the Pulse screen.
///
/// Priority:
/// 0. No focus → null (show FocusSelector)
/// 1. Critical alert → override hero
/// 2. primaryFocus → mapped hero
/// 3. Fallback by age
///
/// Pure function — no side effects. All computation from profile data.
class PulseHeroEngine {
  PulseHeroEngine._();

  /// Returns null if no focus is set (should show FocusSelector instead).
  static PulseHero? compute(CoachProfile profile) {
    // PRIORITY 1: Critical alerts override everything
    final critical = _checkCriticalAlerts(profile);
    if (critical != null) return critical;

    // PRIORITY 0/2: Use primaryFocus if set
    final focus = profile.primaryFocus;
    if (focus == null || focus.isEmpty) return null; // Show FocusSelector

    return _fromFocus(focus, profile);
  }

  // ── PRIORITY 1: Critical alerts ─────────────────────────

  static PulseHero? _checkCriticalAlerts(CoachProfile profile) {
    // Independent with zero LPP
    if (profile.employmentStatus == 'independant' &&
        (profile.prevoyance.avoirLppTotal == null ||
            profile.prevoyance.avoirLppTotal == 0)) {
      return const PulseHero(
        title: 'CHF 0',
        subtitle: "C'est ton 2e pilier aujourd'hui.",
        detail: 'Sans LPP, ta retraite = AVS seule : ~CHF 1\'934/mois.',
        ctaLabel: 'Construire mon filet',
        ctaRoute: '/independants/lpp-volontaire',
        icon: Icons.warning_amber_rounded,
        color: MintColors.error,
      );
    }

    // Active debt
    if (profile.dettes.hasDette && profile.dettes.totalDettes > 10000) {
      final total = profile.dettes.totalDettes;
      return PulseHero(
        title: formatChfWithPrefix(total),
        subtitle: 'de dettes à rembourser.',
        detail: null,
        ctaLabel: 'Voir mon plan',
        ctaRoute: '/debt/repayment',
        icon: Icons.warning_amber_rounded,
        color: MintColors.error,
      );
    }

    return null;
  }

  // ── PRIORITY 2: Focus-based hero ────────────────────────

  /// Maps legacy onboarding stress IDs to new focus keys.
  /// Allows smooth transition: existing users with `stress_retraite` get
  /// the same hero as users who pick `proteger_retraite` via FocusSelector.
  static const _legacyStressMap = {
    'stress_retraite': 'proteger_retraite',
    'stress_impots': 'optimiser_fiscal',
    'stress_budget': 'comprendre_salaire',
    'stress_patrimoine': 'optimiser_patrimoine',
    'stress_couple': 'proteger_famille',
    // 'stress_general' → not mapped, falls through to age-based fallback
  };

  static PulseHero _fromFocus(String focus, CoachProfile profile) {
    final resolved = _legacyStressMap[focus] ?? focus;
    switch (resolved) {
      case 'comprendre_salaire':
        return _heroComprSalaire(profile);
      case 'comprendre_systeme':
        return _heroComprSysteme(profile);
      case 'comprendre_situation':
        return _heroComprSituation(profile);
      case 'proteger_retraite':
        return _heroProtRetraite(profile);
      case 'proteger_famille':
        return _heroProtFamille(profile);
      case 'proteger_urgence':
        return _heroProtUrgence(profile);
      case 'optimiser_fiscal':
        return _heroOptFiscal(profile);
      case 'optimiser_patrimoine':
        return _heroOptPatrimoine(profile);
      case 'optimiser_capital_rente':
        return _heroOptCapitalRente(profile);
      case 'naviguer_expat':
        return _heroNavExpat(profile);
      case 'naviguer_achat':
        return _heroNavAchat(profile);
      case 'naviguer_independant':
        return _heroNavIndependant(profile);
      case 'naviguer_evenement':
        return _heroNavEvenement(profile);
      default:
        return _fallbackByAge(profile);
    }
  }

  // ── Comprendre ──────────────────────────────────────────

  static PulseHero _heroComprSalaire(CoachProfile p) {
    final brut = p.salaireBrutMensuel;
    final charges = (brut * 0.13).round();
    return PulseHero(
      title: 'CHF $charges/mois',
      subtitle: 'disparaissent de ton salaire avant même d\'arriver.',
      detail: 'AVS, LPP, AC, impôts — découvre où va chaque franc.',
      ctaLabel: 'Comprendre ma fiche',
      ctaRoute: '/profile/bilan',
      icon: Icons.receipt_long_outlined,
      color: MintColors.info,
    );
  }

  static PulseHero _heroComprSysteme(CoachProfile p) {
    return const PulseHero(
      title: '3 piliers',
      subtitle: 'Le système suisse en 1 minute.',
      detail: 'AVS (État) + LPP (employeur) + 3a (toi) = ta retraite.',
      ctaLabel: 'Découvrir',
      ctaRoute: '/education/hub',
      icon: Icons.account_balance_outlined,
      color: MintColors.info,
    );
  }

  static PulseHero _heroComprSituation(CoachProfile p) {
    return const PulseHero(
      title: 'Ta visibilité financière',
      subtitle: 'Que sais-tu vraiment de ta situation ?',
      detail: 'Complète ton profil pour affiner ton score.',
      ctaLabel: 'Voir mon score',
      ctaRoute: '/confidence',
      icon: Icons.pie_chart_outline,
      color: MintColors.info,
    );
  }

  // ── Protéger ────────────────────────────────────────────

  static PulseHero _heroProtRetraite(CoachProfile p) {
    if (p.age > 55) {
      // Capital vs Rente for pre-retirees
      return const PulseHero(
        title: 'Capital ou Rente ?',
        subtitle: 'Le choix qui change tout.',
        detail: 'Compare les deux options avec tes chiffres réels.',
        ctaLabel: 'Comparer',
        ctaRoute: '/rente-vs-capital',
        icon: Icons.compare_arrows_outlined,
        color: MintColors.success,
      );
    }
    // Standard retirement hook
    final replacement = p.salaireBrutMensuel > 0
        ? '~${(65 + (p.age > 45 ? 10 : 0))}%'
        : '?%';
    return PulseHero(
      title: '$replacement de ton revenu',
      subtitle: 'conservé à la retraite.',
      detail: 'Médiane suisse : 60%. Où te situes-tu ?',
      ctaLabel: 'Voir ma projection',
      ctaRoute: '/retraite',
      icon: Icons.beach_access_outlined,
      color: MintColors.success,
    );
  }

  static PulseHero _heroProtFamille(CoachProfile p) {
    final conjName = p.conjoint?.firstName ?? 'ton conjoint';
    return PulseHero(
      title: '${p.firstName ?? "Toi"} + $conjName',
      subtitle: 'Votre retraite à deux.',
      detail: 'Anticipe le creux quand un seul est retraité.',
      ctaLabel: 'Voir la timeline',
      ctaRoute: '/profile/bilan',
      icon: Icons.people_outline,
      color: MintColors.success,
    );
  }

  static PulseHero _heroProtUrgence(CoachProfile p) {
    if (p.dettes.hasDette) {
      return PulseHero(
        title: formatChfWithPrefix(p.dettes.totalDettes),
        subtitle: 'à rembourser.',
        detail: 'Commence par le taux le plus élevé.',
        ctaLabel: 'Mon plan de remboursement',
        ctaRoute: '/debt/repayment',
        icon: Icons.warning_amber_outlined,
        color: MintColors.warning,
      );
    }
    return const PulseHero(
      title: 'Ton filet de sécurité',
      subtitle: 'Que se passe-t-il si tu ne peux plus travailler ?',
      detail: 'IJM, AI, LPP invalidité — vérifie ta couverture.',
      ctaLabel: 'Vérifier',
      ctaRoute: '/invalidite',
      icon: Icons.shield_outlined,
      color: MintColors.warning,
    );
  }

  // ── Optimiser ───────────────────────────────────────────

  static PulseHero _heroOptFiscal(CoachProfile p) {
    final saving3a = (pilier3aPlafondAvecLpp * 0.25).round(); // ~25% marginal rate estimate
    return PulseHero(
      title: 'CHF ~${saving3a + 1500}/an',
      subtitle: 'laissés au fisc chaque année.',
      detail: '3a + rachat LPP = tes leviers les plus puissants.',
      ctaLabel: 'Récupérer',
      ctaRoute: '/tools',
      icon: Icons.savings_outlined,
      color: MintColors.warning,
    );
  }

  static PulseHero _heroOptPatrimoine(CoachProfile p) {
    final total = p.patrimoine.totalPatrimoine +
        (p.prevoyance.avoirLppTotal ?? 0) +
        p.prevoyance.totalEpargne3a;
    final display = total >= 1000000
        ? 'CHF ${(total / 1000000).toStringAsFixed(1)}M'
        : total >= 1000
            ? 'CHF ${(total / 1000).round()}k'
            : 'CHF ${total.round()}';
    return PulseHero(
      title: display,
      subtitle: 'Ton patrimoine total.',
      detail: 'Épargne + LPP + 3a + investissements.',
      ctaLabel: 'Détail',
      ctaRoute: '/profile/bilan',
      icon: Icons.account_balance_wallet_outlined,
      color: MintColors.primary,
    );
  }

  static PulseHero _heroOptCapitalRente(CoachProfile p) {
    return const PulseHero(
      title: 'Capital ou Rente ?',
      subtitle: 'La différence peut dépasser CHF 200\'000.',
      detail: 'Taxé une fois (capital) vs chaque année (rente).',
      ctaLabel: 'Comparer',
      ctaRoute: '/rente-vs-capital',
      icon: Icons.compare_arrows_outlined,
      color: MintColors.primary,
    );
  }

  // ── Naviguer ────────────────────────────────────────────

  static PulseHero _heroNavExpat(CoachProfile p) {
    final arrivalAge = p.arrivalAge;
    final gaps = arrivalAge != null ? (arrivalAge - 20).clamp(0, 44) : null;
    if (gaps != null && gaps > 0) {
      return PulseHero(
        title: '$gaps années',
        subtitle: 'de cotisations manquent dans ton AVS.',
        detail: 'Chaque année manquante = -2.3% de rente à vie.',
        ctaLabel: 'Analyser mes lacunes',
        ctaRoute: '/tools',
        icon: Icons.flight_land_outlined,
        color: MintColors.primary,
      );
    }
    return const PulseHero(
      title: 'Nouveau en Suisse ?',
      subtitle: 'Tes droits, tes lacunes, tes pièges à éviter.',
      detail: 'AVS, LPP, 3a — tout ce qui compte dès ton arrivée.',
      ctaLabel: 'Découvrir',
      ctaRoute: '/education/hub',
      icon: Icons.flight_land_outlined,
      color: MintColors.primary,
    );
  }

  static PulseHero _heroNavAchat(CoachProfile p) {
    if (p.salaireBrutMensuel <= 0) {
      return const PulseHero(
        title: 'Acheter un bien',
        subtitle: 'Calcule ta capacité d\'achat.',
        detail: 'Ton 3a et ton LPP = ta principale mise de fonds.',
        ctaLabel: 'Simuler',
        ctaRoute: '/hypotheque',
        icon: Icons.home_outlined,
        color: MintColors.primary,
      );
    }
    // Rough capacity: annual income / theoretical rate 5% = max mortgage, *0.8
    final capacity = (p.revenuBrutAnnuel / 0.05 * 0.80 / 1000).round();
    return PulseHero(
      title: 'CHF ~${capacity}k',
      subtitle: 'Le bien que tu pourrais viser.',
      detail: 'Ton 3a et ton LPP = ta principale mise de fonds.',
      ctaLabel: 'Simuler mon achat',
      ctaRoute: '/hypotheque',
      icon: Icons.home_outlined,
      color: MintColors.primary,
    );
  }

  static PulseHero _heroNavIndependant(CoachProfile p) {
    return const PulseHero(
      title: 'Indépendant·e ?',
      subtitle: 'Sans employeur, ton filet = toi.',
      detail: 'LPP volontaire, 3a max 36\'288/an, IJM obligatoire.',
      ctaLabel: 'Vérifier ma couverture',
      ctaRoute: '/independants/lpp-volontaire',
      icon: Icons.business_center_outlined,
      color: MintColors.primary,
    );
  }

  static PulseHero _heroNavEvenement(CoachProfile p) {
    return const PulseHero(
      title: 'Un changement de vie ?',
      subtitle: 'Chaque événement a un impact financier.',
      detail: 'Mariage, naissance, divorce, héritage, déménagement...',
      ctaLabel: 'Explorer',
      ctaRoute: '/tools',
      icon: Icons.family_restroom_outlined,
      color: MintColors.primary,
    );
  }

  // ── PRIORITY 3: Fallback by age ─────────────────────────

  static PulseHero _fallbackByAge(CoachProfile p) {
    if (p.age < 28) return _heroComprSalaire(p);
    if (p.age < 35) return _heroNavAchat(p);
    if (p.age < 45) return _heroOptFiscal(p);
    if (p.age < 55) return _heroProtRetraite(p);
    return _heroOptCapitalRente(p);
  }
}
