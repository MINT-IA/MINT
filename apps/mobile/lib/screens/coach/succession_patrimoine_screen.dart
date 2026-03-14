/// Succession & Patrimoine — Sprint S44 (Phase 2 — AgeBand 65+).
///
/// Écran éducatif sur la succession et la transmission du patrimoine.
/// Cible : profils AgeBand.retirement (65+), particulièrement 70+.
///
/// Sources légales : CC art. 457-640, LPP art. 20, OPP3 art. 2.
/// Disclaimer LSFin obligatoire (outil éducatif, pas un conseil juridique).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/coach/testament_invisible_widget.dart';
import 'package:mint_mobile/widgets/coach/avancement_hoirie_widget.dart';
import 'package:mint_mobile/widgets/coach/death_urgency_guide_widget.dart';

class SuccessionPatrimoineScreen extends StatelessWidget {
  const SuccessionPatrimoineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar gradient ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 16, right: 24),
              title: Text(
                s.successionPatrimoineTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: MintColors.white,
                  height: 1.25,
                ),
                maxLines: 2,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.successionDark, MintColors.slateDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Chiffre choc ─────────────────────────────
                _AlertCard(
                  icon: Icons.warning_amber_outlined,
                  title: s.successionPatrimoineAlertTitle,
                  body: s.successionPatrimoineAlertBody,
                  color: MintColors.urgentOrange,
                ),
                const SizedBox(height: 24),

                // ── P8-A : Testament invisible ───────────────
                TestamentInvisibleWidget(
                  patrimoine: 500000,
                  initialStatus: FamilyStatus.concubin,
                ),
                const SizedBox(height: 20),

                // ── P8-E : Avancement d'hoirie ────────────────
                AvancementHoirieWidget(
                  totalPatrimoine: 500000,
                  donationAmount: 50000,
                  donationRecipientIndex: 0,
                  children: const [
                    HoirieChild(name: 'Enfant 1', emoji: '👦'),
                    HoirieChild(name: 'Enfant 2', emoji: '👧'),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Concepts clés ────────────────────────────
                EduSectionTitle(text: s.successionPatrimoineNotionsCles),
                const SizedBox(height: 12),

                _ConceptCard(
                  icon: Icons.shield_outlined,
                  title: s.successionPatrimoineReservesTitle,
                  subtitle: s.successionPatrimoineReservesSubtitle,
                  body: s.successionPatrimoineReservesBody,
                  color: MintColors.blueDark,
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.pie_chart_outline,
                  title: s.successionPatrimoineQuotiteTitle,
                  subtitle: s.successionPatrimoineQuotiteSubtitle,
                  body: s.successionPatrimoineQuotiteBody,
                  color: MintColors.purpleDark,
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.description_outlined,
                  title: s.successionPatrimoineTestamentTitle,
                  subtitle: s.successionPatrimoineTestamentSubtitle,
                  body: s.successionPatrimoineTestamentBody,
                  color: MintColors.withdrawalOptim,
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.card_giftcard_outlined,
                  title: s.successionPatrimoineDonationTitle,
                  subtitle: s.successionPatrimoineDonationSubtitle,
                  body: s.successionPatrimoineDonationBody,
                  color: MintColors.successionDark,
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.how_to_reg_outlined,
                  title: s.successionPatrimoineBeneficiairesTitle,
                  subtitle: s.successionPatrimoineBeneficiairesSubtitle,
                  body: s.successionPatrimoineBeneficiairesBody,
                  color: MintColors.urgentOrange,
                ),
                const SizedBox(height: 24),

                // ── P14-A : Guide de première urgence ────────────
                EduSectionTitle(text: s.successionPatrimoineDecesProche),
                const SizedBox(height: 12),
                DeathUrgencyGuideWidget(
                  phases: [
                    UrgencyPhase(
                      timeframe: s.successionPatrimoinePhase1Timeframe,
                      emoji: '🆘',
                      title: s.successionPatrimoinePhase1Title,
                      color: MintColors.urgentOrange,
                      actions: [
                        s.successionPatrimoinePhase1Action1,
                        s.successionPatrimoinePhase1Action2,
                        s.successionPatrimoinePhase1Action3,
                        s.successionPatrimoinePhase1Action4,
                      ],
                    ),
                    UrgencyPhase(
                      timeframe: s.successionPatrimoinePhase2Timeframe,
                      emoji: '📋',
                      title: s.successionPatrimoinePhase2Title,
                      color: MintColors.orangeDarkDeep,
                      actions: [
                        s.successionPatrimoinePhase2Action1,
                        s.successionPatrimoinePhase2Action2,
                        s.successionPatrimoinePhase2Action3,
                        s.successionPatrimoinePhase2Action4,
                        s.successionPatrimoinePhase2Action5,
                      ],
                    ),
                    UrgencyPhase(
                      timeframe: s.successionPatrimoinePhase3Timeframe,
                      emoji: '⚖️',
                      title: s.successionPatrimoinePhase3Title,
                      color: MintColors.successDeep,
                      actions: [
                        s.successionPatrimoinePhase3Action1,
                        s.successionPatrimoinePhase3Action2,
                        s.successionPatrimoinePhase3Action3,
                        s.successionPatrimoinePhase3Action4,
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Checklist pratique ────────────────────────
                EduSectionTitle(text: s.successionPatrimoineChecklistTitle),
                const SizedBox(height: 12),
                _ChecklistCard(
                  items: [
                    s.successionPatrimoineChecklist1,
                    s.successionPatrimoineChecklist2,
                    s.successionPatrimoineChecklist3,
                    s.successionPatrimoineChecklist4,
                    s.successionPatrimoineChecklist5,
                  ],
                ),
                const SizedBox(height: 24),

                // ── CTA spécialiste ───────────────────────────
                EduSpecialistCta(
                  icon: Icons.gavel_outlined,
                  color: MintColors.successionDark,
                  title: s.successionPatrimoineCtaTitle,
                  body: s.successionPatrimoineCtaBody,
                ),
                const SizedBox(height: 24),

                // ── Sources légales ───────────────────────────
                EduLegalSources(
                  sources: s.successionPatrimoineLegalSources,
                ),
                const SizedBox(height: 16),

                // ── Disclaimer LSFin ──────────────────────────
                EduDisclaimer(
                  text: s.successionPatrimoineDisclaimer,
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets internes ─────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _AlertCard(
      {required this.icon,
      required this.title,
      required this.body,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final Color color;

  const _ConceptCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final List<String> items;
  const _ChecklistCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: MintColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
