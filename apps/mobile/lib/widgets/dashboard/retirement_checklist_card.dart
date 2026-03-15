import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT CHECKLIST CARD — Chantier 2 / Retirement Cockpit
// ────────────────────────────────────────────────────────────
//
//  Checklist personnalisee d'actions temporelles :
//    - Commander extrait AVS
//    - Verser 3a avant le 31 decembre
//    - Evaluer un rachat LPP
//    - Planifier rente vs capital (5 ans avant retraite)
//    - Coordonner les dates de retrait (couple)
//
//  Chaque action est conditionnelle au profil.
//  Tap → ecran pertinent.
//
//  Widget pur — aucune dependance Provider.
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class RetirementChecklistCard extends StatelessWidget {
  final CoachProfile profile;

  const RetirementChecklistCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final items = _buildChecklistItems(profile, s);
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MintColors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: MintColors.amber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.retirementChecklistTitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      s.retirementChecklistSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Checklist items
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return _buildChecklistTile(context, entry.value, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildChecklistTile(
    BuildContext context,
    _ChecklistItem item,
    bool isLast,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: InkWell(
        onTap: item.route != null ? () => context.push(item.route!) : null,
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
              // Priority indicator
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 14, color: item.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MintColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (item.timeline != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.timeline!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: item.color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.route != null)
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

  static List<_ChecklistItem> _buildChecklistItems(CoachProfile profile, S s) {
    final items = <_ChecklistItem>[];
    final yearsToRetirement = profile.anneesAvantRetraite;
    final retirementYear = profile.birthYear + 65;
    final now = DateTime.now();

    // 1. AVS extract
    final hasAvsData = profile.prevoyance.anneesContribuees != null;
    if (!hasAvsData) {
      items.add(_ChecklistItem(
        icon: Icons.description_outlined,
        color: MintColors.info,
        title: s.retirementChecklistAvsTitle,
        subtitle: s.retirementChecklistAvsSubtitle,
        timeline: s.retirementChecklistAvsTimeline,
        route: '/document-scan/avs-guide',
      ));
    }

    // 2. 3a not maxed
    final annualPlafond = profile.employmentStatus == 'independant' &&
            profile.revenuBrutAnnuel < lppSeuilEntree
        ? pilier3aPlafondSansLpp
        : pilier3aPlafondAvecLpp;
    final annual3a = profile.total3aMensuel * 12;
    final remaining3a = (annualPlafond - annual3a).clamp(0.0, annualPlafond);
    if (remaining3a > 100) {
      items.add(_ChecklistItem(
        icon: Icons.savings_outlined,
        color: MintColors.retirement3a,
        title: s.retirementChecklist3aTitle,
        subtitle: s.retirementChecklist3aSubtitle(_fmt(remaining3a), now.year.toString()),
        timeline: s.retirementChecklist3aTimeline(now.year.toString()),
        route: '/3a-deep/comparator',
      ));
    }

    // 3. Rachat LPP
    final lacune = profile.prevoyance.lacuneRachatRestante;
    if (lacune > 5000) {
      final revenuBrut = profile.revenuBrutAnnuel;
      final tauxMarginal = revenuBrut > 150000
          ? 0.35
          : revenuBrut > 100000
              ? 0.30
              : 0.25;
      final economie = lacune * tauxMarginal;
      items.add(_ChecklistItem(
        icon: Icons.add_chart_rounded,
        color: MintColors.success,
        title: s.retirementChecklistRachatTitle,
        subtitle: s.retirementChecklistRachatSubtitle(_fmt(economie), _fmt(lacune)),
        timeline: s.retirementChecklistRachatTimeline(retirementYear.toString()),
        route: '/lpp-deep/rachat',
      ));
    }

    // 4. Rente vs Capital decision (5 years before retirement)
    if (yearsToRetirement <= 5 && yearsToRetirement > 0 &&
        FeatureFlags.enableDecisionScaffold) {
      items.add(_ChecklistItem(
        icon: Icons.compare_arrows_rounded,
        color: MintColors.purple,
        title: s.retirementChecklistRenteVsCapitalTitle,
        subtitle: s.retirementChecklistRenteVsCapitalSubtitle,
        timeline: s.retirementChecklistRenteVsCapitalTimeline((retirementYear - 1).toString()),
        route: '/arbitrage/rente-vs-capital',
      ));
    }

    // 5. Couple coordination
    final hasConjoint =
        profile.isCouple && profile.conjoint?.birthYear != null;
    if (hasConjoint && yearsToRetirement <= 10 &&
        FeatureFlags.enableDecisionScaffold) {
      final conjName = profile.conjoint!.firstName ?? s.retirementChecklistPartnerDefault;
      items.add(_ChecklistItem(
        icon: Icons.people_outline_rounded,
        color: MintColors.indigo,
        title: s.retirementChecklistCoupleTitle,
        subtitle: s.retirementChecklistCoupleSubtitle(conjName),
        timeline: s.retirementChecklistCoupleTimeline,
        route: '/arbitrage/calendrier-retraits',
      ));
    }

    return items;
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

class _ChecklistItem {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? timeline;
  final String? route;

  const _ChecklistItem({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.timeline,
    this.route,
  });
}
