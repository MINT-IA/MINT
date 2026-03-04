import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  COUPLE ACTION PLAN — P5 / Couple Interactif
// ────────────────────────────────────────────────────────────
//
//  Actions taggées par personne + impact ménage.
//  Chaque action est contextualisée au couple
//  (échelonnement fiscal, coordination 3a, etc.).
//
//  Widget pur — aucune dépendance Provider.
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

/// Tag indicating which partner an action concerns.
enum ActionOwner { user, conjoint, household }

class CoupleActionPlan extends StatelessWidget {
  final CoachProfile profile;

  const CoupleActionPlan({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (!profile.isCouple || profile.conjoint == null || profile.conjoint?.birthYear == null) {
      return const SizedBox.shrink();
    }

    final actions = _buildCoupleActions(profile);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          ...actions.asMap().entries.map((entry) {
            final isLast = entry.key == actions.length - 1;
            return _buildActionTile(context, entry.value, isLast);
          }),
          const SizedBox(height: 8),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final conjName = profile.conjoint!.firstName ?? 'Conjoint\u00b7e';
    final userName = profile.firstName ?? 'Toi';
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: MintColors.indigo.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.handshake_outlined,
            color: MintColors.indigo,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan d\u2019action couple',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                '$userName & $conjName',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    _CoupleAction action,
    bool isLast,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: InkWell(
        onTap: action.route != null ? () => context.push(action.route!) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Owner tag
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: action.ownerColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, size: 14, color: action.ownerColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildOwnerChip(action),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            action.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MintColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (action.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MintColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (action.impactLabel != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MintColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          action.impactLabel!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: MintColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action.route != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MintColors.textMuted,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerChip(_CoupleAction action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: action.ownerColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        action.ownerLabel,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: action.ownerColor,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Actions \u00e9ducatives. Ne constituent pas un conseil financier (LSFin).',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  static List<_CoupleAction> _buildCoupleActions(CoachProfile profile) {
    final actions = <_CoupleAction>[];
    final conj = profile.conjoint!;
    final userName = profile.firstName ?? 'Toi';
    final conjName = conj.firstName ?? 'Conjoint\u00b7e';
    final now = DateTime.now();
    final userYearsToRetirement = profile.anneesAvantRetraite;
    final conjYearsToRetirement = conj.anneesAvantRetraite ?? 99;

    // ── 1. Staggered withdrawal coordination (household) ──
    final userRetYear = profile.birthYear + profile.effectiveRetirementAge;
    final conjRetYear = conj.birthYear! + conj.effectiveRetirementAge;
    if (userRetYear != conjRetYear && FeatureFlags.enableDecisionScaffold) {
      final firstRetires = userRetYear < conjRetYear ? userName : conjName;
      final gap = (userRetYear - conjRetYear).abs();
      actions.add(_CoupleAction(
        owner: ActionOwner.household,
        ownerLabel: 'M\u00c9NAGE',
        ownerColor: MintColors.primary,
        icon: Icons.calendar_month_outlined,
        title: '\u00c9chelonner les retraits sur $gap ans',
        subtitle:
            '$firstRetires prend sa retraite en premier. '
            '\u00c9chelonner 3a/LPP peut r\u00e9duire la charge fiscale.',
        impactLabel: 'Jusqu\u2019\u00e0 CHF\u00a015\u2019000\u201340\u2019000 d\u2019\u00e9conomie (estimation)',
        route: '/arbitrage/calendrier-retraits',
      ));
    }

    // ── 2. User 3a action ──
    {
      final hasUserLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;
      final plafond = profile.employmentStatus == 'independant' && !hasUserLpp
          ? pilier3aPlafondSansLpp
          : pilier3aPlafondAvecLpp;
      // Filter to user-only 3a: keep contributions that match user name
      // or use '_user' suffix, exclude those matching conjoint name.
      // Same name-matching convention as MonteCarloService (L298-310).
      // Naming convention: onboarding → '3a_user', golden → '3a_julien'.
      final conjNameLower = conj.firstName?.toLowerCase() ?? '';
      final userNameLower = (profile.firstName ?? '').toLowerCase();
      final user3aMensuel = profile.plannedContributions
          .where((c) {
            if (c.category != '3a') return false;
            final idLow = c.id.toLowerCase();
            final labelLow = c.label.toLowerCase();
            // Positive match: explicitly user-owned
            if (userNameLower.isNotEmpty &&
                (idLow.contains(userNameLower) ||
                    labelLow.contains(userNameLower))) {
              return true;
            }
            if (idLow.contains('_user')) return true;
            // Negative match: exclude conjoint-owned
            if (conjNameLower.isNotEmpty &&
                (idLow.contains(conjNameLower) ||
                    labelLow.contains(conjNameLower))) {
              return false;
            }
            // Ambiguous: no name match either way → include (conservative)
            return true;
          })
          .fold(0.0, (sum, c) => sum + c.amount);
      final annual3a = user3aMensuel * 12;
      final remaining = (plafond - annual3a).clamp(0.0, plafond);
      if (remaining > 100) {
        actions.add(_CoupleAction(
          owner: ActionOwner.user,
          ownerLabel: userName.toUpperCase(),
          ownerColor: MintColors.info,
          icon: Icons.savings_outlined,
          title: 'Verser 3a avant le 31.12',
          subtitle:
              'CHF\u00a0${_fmt(remaining)} restant avant le plafond ${now.year}.',
          impactLabel: null,
          route: '/3a-deep/comparator',
        ));
      }
    }

    // ── 3. Conjoint 3a action ──
    // Use prevoyance.canContribute3a (same source as ForecasterService,
    // RetirementProjectionService, MonteCarloService).
    final conjCanContribute3a =
        conj.prevoyance?.canContribute3a ?? true;
    if (conjCanContribute3a) {
      final conjHasLpp = (conj.prevoyance?.avoirLppTotal ?? 0) > 0;
      final conjPlafond = conj.employmentStatus == 'independant' && !conjHasLpp
          ? pilier3aPlafondSansLpp
          : pilier3aPlafondAvecLpp;
      actions.add(_CoupleAction(
        owner: ActionOwner.conjoint,
        ownerLabel: conjName.toUpperCase(),
        ownerColor: MintColors.purple,
        icon: Icons.savings_outlined,
        title: 'Verser 3a ($conjName)',
        subtitle:
            'Plafond annuel\u00a0: CHF\u00a0${_fmt(conjPlafond.toDouble())}.',
        impactLabel: null,
        route: '/3a-deep/comparator',
      ));
    } else {
      // FATCA — can't contribute 3a
      actions.add(_CoupleAction(
        owner: ActionOwner.conjoint,
        ownerLabel: conjName.toUpperCase(),
        ownerColor: MintColors.purple,
        icon: Icons.block_outlined,
        title: '3a non disponible ($conjName)',
        subtitle:
            'Les r\u00e9sidents fiscaux US (FATCA) ne peuvent '
            'g\u00e9n\u00e9ralement pas ouvrir un 3a en Suisse.',
        impactLabel: null,
        route: null,
      ));
    }

    // ── 4. Rente vs Capital couple coordination ──
    if ((userYearsToRetirement <= 7 || conjYearsToRetirement <= 7) &&
        FeatureFlags.enableDecisionScaffold) {
      actions.add(_CoupleAction(
        owner: ActionOwner.household,
        ownerLabel: 'M\u00c9NAGE',
        ownerColor: MintColors.primary,
        icon: Icons.compare_arrows_rounded,
        title: 'Rente vs capital : coordonner \u00e0 deux',
        subtitle:
            'La strat\u00e9gie mixte (rente oblig. + capital suroblig.) '
            'peut \u00eatre diff\u00e9rente pour chaque partenaire.',
        impactLabel: null,
        route: '/arbitrage/rente-vs-capital',
      ));
    }

    // ── 5. AVS couple cap awareness ──
    if (profile.etatCivil == CoachCivilStatus.marie) {
      actions.add(_CoupleAction(
        owner: ActionOwner.household,
        ownerLabel: 'M\u00c9NAGE',
        ownerColor: MintColors.primary,
        icon: Icons.info_outline,
        title: 'Plafonnement AVS couple (LAVS art.\u00a035)',
        subtitle:
            'Mari\u00e9\u00b7e\u00a0: la somme des rentes AVS est plafonn\u00e9e '
            '\u00e0 150\u00a0% de la rente maximale (CHF\u00a03\u2019780/mois).',
        impactLabel: null,
        route: '/document-scan/avs-guide',
      ));
    }

    return actions;
  }

  static String _fmt(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class _CoupleAction {
  final ActionOwner owner;
  final String ownerLabel;
  final Color ownerColor;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? impactLabel;
  final String? route;

  const _CoupleAction({
    required this.owner,
    required this.ownerLabel,
    required this.ownerColor,
    required this.icon,
    required this.title,
    this.subtitle,
    this.impactLabel,
    this.route,
  });
}
