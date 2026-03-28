import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
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
  static PulseHero? compute(CoachProfile profile, {S? l}) {
    // PRIORITY 1: Critical alerts override everything
    final critical = _checkCriticalAlerts(profile, l);
    if (critical != null) return critical;

    // PRIORITY 0/2: Use primaryFocus if set
    final focus = profile.primaryFocus;
    if (focus == null || focus.isEmpty) return null; // Show FocusSelector

    return _fromFocus(focus, profile, l);
  }

  // ── PRIORITY 1: Critical alerts ─────────────────────────

  static PulseHero? _checkCriticalAlerts(CoachProfile profile, S? l) {
    // Independent with zero LPP
    if (profile.employmentStatus == 'independant' &&
        (profile.prevoyance.avoirLppTotal == null ||
            profile.prevoyance.avoirLppTotal == 0)) {
      return PulseHero(
        title: l?.pulseIndepLppTitle ?? 'CHF 0',
        subtitle: l?.pulseIndepLppSubtitle ?? "C'est ton 2e pilier aujourd'hui.",
        detail: l?.pulseIndepLppDetail ?? 'Sans LPP, ta retraite = AVS seule : ~CHF 1\'934/mois.',
        ctaLabel: l?.pulseIndepLppCta ?? 'Construire mon filet',
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
        subtitle: l?.pulseDebtSubtitle ?? 'de dettes à rembourser.',
        detail: null,
        ctaLabel: l?.pulseDebtCta ?? 'Voir mon plan',
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

  static PulseHero _fromFocus(String focus, CoachProfile profile, S? l) {
    final resolved = _legacyStressMap[focus] ?? focus;
    switch (resolved) {
      case 'comprendre_salaire':
        return _heroComprSalaire(profile, l);
      case 'comprendre_systeme':
        return _heroComprSysteme(l);
      case 'comprendre_situation':
        return _heroComprSituation(l);
      case 'proteger_retraite':
        return _heroProtRetraite(profile, l);
      case 'proteger_famille':
        return _heroProtFamille(profile, l);
      case 'proteger_urgence':
        return _heroProtUrgence(profile, l);
      case 'optimiser_fiscal':
        return _heroOptFiscal(profile, l);
      case 'optimiser_patrimoine':
        return _heroOptPatrimoine(profile, l);
      case 'optimiser_capital_rente':
        return _heroOptCapitalRente(l);
      case 'naviguer_expat':
        return _heroNavExpat(profile, l);
      case 'naviguer_achat':
        return _heroNavAchat(profile, l);
      case 'naviguer_independant':
        return _heroNavIndependant(l);
      case 'naviguer_evenement':
        return _heroNavEvenement(l);
      default:
        return _fallbackByAge(profile, l);
    }
  }

  // ── Comprendre ──────────────────────────────────────────

  static PulseHero _heroComprSalaire(CoachProfile p, S? l) {
    final brut = p.salaireBrutMensuel;
    final charges = (brut * 0.13).round();
    return PulseHero(
      title: 'CHF $charges/mois',
      subtitle: l?.pulseComprSalaireSubtitle ?? 'disparaissent de ton salaire avant même d\'arriver.',
      detail: l?.pulseComprSalaireDetail ?? 'AVS, LPP, AC, impôts — découvre où va chaque franc.',
      ctaLabel: l?.pulseComprSalaireCta ?? 'Comprendre ma fiche',
      ctaRoute: '/profile/bilan',
      icon: Icons.receipt_long_outlined,
      color: MintColors.info,
    );
  }

  static PulseHero _heroComprSysteme(S? l) {
    return PulseHero(
      title: l?.pulseComprSystemeTitle ?? '3 piliers',
      subtitle: l?.pulseComprSystemeSubtitle ?? 'Le système suisse en 1 minute.',
      detail: l?.pulseComprSystemeDetail ?? 'AVS (État) + LPP (employeur) + 3a (toi) = ta retraite.',
      ctaLabel: l?.pulseComprSystemeCta ?? 'Découvrir',
      ctaRoute: '/education/hub',
      icon: Icons.account_balance_outlined,
      color: MintColors.info,
    );
  }

  static PulseHero _heroComprSituation(S? l) {
    return PulseHero(
      title: l?.pulseComprSituationTitle ?? 'Ta visibilité financière',
      subtitle: l?.pulseComprSituationSubtitle ?? 'Que sais-tu vraiment de ta situation ?',
      detail: l?.pulseComprSituationDetail ?? 'Complète ton profil pour affiner ton score.',
      ctaLabel: l?.pulseComprSituationCta ?? 'Voir mon score',
      ctaRoute: '/confidence',
      icon: Icons.pie_chart_outline,
      color: MintColors.info,
    );
  }

  // ── Protéger ────────────────────────────────────────────

  static PulseHero _heroProtRetraite(CoachProfile p, S? l) {
    if (p.age > 55) {
      // Capital vs Rente for pre-retirees
      return PulseHero(
        title: l?.pulseProtRetraiteCapRenteTitle ?? 'Capital ou Rente ?',
        subtitle: l?.pulseProtRetraiteCapRenteSubtitle ?? 'Le choix qui change tout.',
        detail: l?.pulseProtRetraiteCapRenteDetail ?? 'Compare les deux options avec tes chiffres réels.',
        ctaLabel: l?.pulseProtRetraiteCapRenteCta ?? 'Comparer',
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
      subtitle: l?.pulseProtRetraiteSubtitle ?? 'conservé à la retraite.',
      detail: l?.pulseProtRetraiteDetail ?? 'Médiane suisse : 60%. Où te situes-tu ?',
      ctaLabel: l?.pulseProtRetraiteCta ?? 'Voir ma projection',
      ctaRoute: '/retraite',
      icon: Icons.beach_access_outlined,
      color: MintColors.success,
    );
  }

  static PulseHero _heroProtFamille(CoachProfile p, S? l) {
    final conjName = p.conjoint?.firstName ?? 'ton conjoint';
    return PulseHero(
      title: '${p.firstName ?? "Toi"} + $conjName',
      subtitle: l?.pulseProtFamilleSubtitle ?? 'Votre retraite à deux.',
      detail: l?.pulseProtFamilleDetail ?? 'Anticipe le creux quand un seul est retraité.',
      ctaLabel: l?.pulseProtFamilleCta ?? 'Voir la timeline',
      ctaRoute: '/profile/bilan',
      icon: Icons.people_outline,
      color: MintColors.success,
    );
  }

  static PulseHero _heroProtUrgence(CoachProfile p, S? l) {
    if (p.dettes.hasDette) {
      return PulseHero(
        title: formatChfWithPrefix(p.dettes.totalDettes),
        subtitle: l?.pulseProtUrgenceDebtSubtitle ?? 'à rembourser.',
        detail: l?.pulseProtUrgenceDebtDetail ?? 'Commence par le taux le plus élevé.',
        ctaLabel: l?.pulseProtUrgenceDebtCta ?? 'Mon plan de remboursement',
        ctaRoute: '/debt/repayment',
        icon: Icons.warning_amber_outlined,
        color: MintColors.warning,
      );
    }
    return PulseHero(
      title: l?.pulseProtUrgenceTitle ?? 'Ton filet de sécurité',
      subtitle: l?.pulseProtUrgenceSubtitle ?? 'Que se passe-t-il si tu ne peux plus travailler ?',
      detail: l?.pulseProtUrgenceDetail ?? 'IJM, AI, LPP invalidité — vérifie ta couverture.',
      ctaLabel: l?.pulseProtUrgenceCta ?? 'Vérifier',
      ctaRoute: '/invalidite',
      icon: Icons.shield_outlined,
      color: MintColors.warning,
    );
  }

  // ── Optimiser ───────────────────────────────────────────

  static PulseHero _heroOptFiscal(CoachProfile p, S? l) {
    final saving3a = (reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) * 0.25).round(); // ~25% marginal rate estimate
    return PulseHero(
      title: 'CHF ~${saving3a + 1500}/an',
      subtitle: l?.pulseOptFiscalSubtitle ?? 'laissés au fisc chaque année.',
      detail: l?.pulseOptFiscalDetail ?? '3a + rachat LPP = tes leviers les plus puissants.',
      ctaLabel: l?.pulseOptFiscalCta ?? 'Récupérer',
      ctaRoute: '/tools',
      icon: Icons.savings_outlined,
      color: MintColors.warning,
    );
  }

  static PulseHero _heroOptPatrimoine(CoachProfile p, S? l) {
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
      subtitle: l?.pulseOptPatrimoineSubtitle ?? 'Ton patrimoine total.',
      detail: l?.pulseOptPatrimoineDetail ?? 'Épargne + LPP + 3a + investissements.',
      ctaLabel: l?.pulseOptPatrimoineCtaLabel ?? 'Détail',
      ctaRoute: '/profile/bilan',
      icon: Icons.account_balance_wallet_outlined,
      color: MintColors.primary,
    );
  }

  static PulseHero _heroOptCapitalRente(S? l) {
    return PulseHero(
      title: l?.pulseOptCapRenteTitle ?? 'Capital ou Rente ?',
      subtitle: l?.pulseOptCapRenteSubtitle ?? 'La différence peut dépasser CHF 200\'000.',
      detail: l?.pulseOptCapRenteDetail ?? 'Taxé une fois (capital) vs chaque année (rente).',
      ctaLabel: l?.pulseOptCapRenteCta ?? 'Comparer',
      ctaRoute: '/rente-vs-capital',
      icon: Icons.compare_arrows_outlined,
      color: MintColors.primary,
    );
  }

  // ── Naviguer ────────────────────────────────────────────

  static PulseHero _heroNavExpat(CoachProfile p, S? l) {
    final arrivalAge = p.arrivalAge;
    final gaps = arrivalAge != null ? (arrivalAge - 20).clamp(0, 44) : null;
    if (gaps != null && gaps > 0) {
      return PulseHero(
        title: '$gaps années',
        subtitle: l?.pulseNavExpatGapsSubtitle ?? 'de cotisations manquent dans ton AVS.',
        detail: l?.pulseNavExpatGapsDetail ?? 'Chaque année manquante = -2.3% de rente à vie.',
        ctaLabel: l?.pulseNavExpatGapsCta ?? 'Analyser mes lacunes',
        ctaRoute: '/tools',
        icon: Icons.flight_land_outlined,
        color: MintColors.primary,
      );
    }
    return PulseHero(
      title: l?.pulseNavExpatTitle ?? 'Nouveau en Suisse ?',
      subtitle: l?.pulseNavExpatSubtitle ?? 'Tes droits, tes lacunes, tes pièges à éviter.',
      detail: l?.pulseNavExpatDetail ?? 'AVS, LPP, 3a — tout ce qui compte dès ton arrivée.',
      ctaLabel: l?.pulseNavExpatCta ?? 'Découvrir',
      ctaRoute: '/education/hub',
      icon: Icons.flight_land_outlined,
      color: MintColors.primary,
    );
  }

  static PulseHero _heroNavAchat(CoachProfile p, S? l) {
    if (p.salaireBrutMensuel <= 0) {
      return PulseHero(
        title: l?.pulseNavAchatTitle ?? 'Acheter un bien',
        subtitle: l?.pulseNavAchatSubtitle ?? 'Calcule ta capacité d\'achat.',
        detail: l?.pulseNavAchatDetail ?? 'Ton 3a et ton LPP = ta principale mise de fonds.',
        ctaLabel: l?.pulseNavAchatCta ?? 'Simuler',
        ctaRoute: '/hypotheque',
        icon: Icons.home_outlined,
        color: MintColors.primary,
      );
    }
    // Rough capacity: annual income / theoretical rate 5% = max mortgage, *0.8
    final capacity = (p.revenuBrutAnnuel / 0.05 * 0.80 / 1000).round();
    return PulseHero(
      title: 'CHF ~${capacity}k',
      subtitle: l?.pulseNavAchatCapSubtitle ?? 'Le bien que tu pourrais viser.',
      detail: l?.pulseNavAchatDetail ?? 'Ton 3a et ton LPP = ta principale mise de fonds.',
      ctaLabel: l?.pulseNavAchatCapCta ?? 'Simuler mon achat',
      ctaRoute: '/hypotheque',
      icon: Icons.home_outlined,
      color: MintColors.primary,
    );
  }

  static PulseHero _heroNavIndependant(S? l) {
    return PulseHero(
      title: l?.pulseNavIndependantTitle ?? 'Indépendant·e ?',
      subtitle: l?.pulseNavIndependantSubtitle ?? 'Sans employeur, ton filet = toi.',
      detail: l?.pulseNavIndependantDetail ?? 'LPP volontaire, 3a max 36\'288/an, IJM obligatoire.',
      ctaLabel: l?.pulseNavIndependantCta ?? 'Vérifier ma couverture',
      ctaRoute: '/independants/lpp-volontaire',
      icon: Icons.business_center_outlined,
      color: MintColors.primary,
    );
  }

  static PulseHero _heroNavEvenement(S? l) {
    return PulseHero(
      title: l?.pulseNavEvenementTitle ?? 'Un changement de vie ?',
      subtitle: l?.pulseNavEvenementSubtitle ?? 'Chaque événement a un impact financier.',
      detail: l?.pulseNavEvenementDetail ?? 'Mariage, naissance, divorce, héritage, déménagement...',
      ctaLabel: l?.pulseNavEvenementCta ?? 'Explorer',
      ctaRoute: '/tools',
      icon: Icons.family_restroom_outlined,
      color: MintColors.primary,
    );
  }

  // ── PRIORITY 3: Fallback by age ─────────────────────────

  static PulseHero _fallbackByAge(CoachProfile p, S? l) {
    if (p.age < 28) return _heroComprSalaire(p, l);
    if (p.age < 35) return _heroNavAchat(p, l);
    if (p.age < 45) return _heroOptFiscal(p, l);
    if (p.age < 55) return _heroProtRetraite(p, l);
    return _heroOptCapitalRente(l);
  }
}
