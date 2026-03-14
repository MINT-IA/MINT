/// Optimisation Décaissement — Sprint S44 (Phase 2 — AgeBand 65+).
///
/// Écran éducatif sur l'échelonnement des retraits du pilier 3a.
/// Cible : profils AgeBand.retirement (65+).
///
/// Sources légales : LIFD art. 38, OPP3 art. 3.
/// Disclaimer LSFin obligatoire (outil éducatif, pas un conseil fiscal).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';

class OptimisationDecaissementScreen extends StatelessWidget {
  const OptimisationDecaissementScreen({super.key});

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
                s.optimDecaissementTitle,
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
                    colors: [MintColors.primary, MintColors.accent],
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
                _ChiffreChocCard(
                  chiffre: s.optimDecaissementChiffreChoc,
                  explication: s.optimDecaissementChiffreChocExplication,
                ),
                const SizedBox(height: 24),

                // ── Principe ─────────────────────────────────
                EduSectionTitle(text: s.optimDecaissementPrincipeTitle),
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.calendar_today_outlined,
                  title: s.optimDecaissementInfo1Title,
                  body: s.optimDecaissementInfo1Body,
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.account_tree_outlined,
                  title: s.optimDecaissementInfo2Title,
                  body: s.optimDecaissementInfo2Body,
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.map_outlined,
                  title: s.optimDecaissementInfo3Title,
                  body: s.optimDecaissementInfo3Body,
                ),
                const SizedBox(height: 24),

                // ── Tableau illustratif ───────────────────────
                EduSectionTitle(text: s.optimDecaissementTableTitle),
                const SizedBox(height: 12),
                _WithdrawalTable(s: s),
                const SizedBox(height: 8),
                Text(
                  s.optimDecaissementTableFootnote,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Plan d'action ────────────────────────────
                EduSectionTitle(text: s.optimDecaissementPlanTitle),
                const SizedBox(height: 12),
                _StepCard(
                  number: '1',
                  title: s.optimDecaissementStep1Title,
                  body: s.optimDecaissementStep1Body,
                ),
                const SizedBox(height: 10),
                _StepCard(
                  number: '2',
                  title: s.optimDecaissementStep2Title,
                  body: s.optimDecaissementStep2Body,
                ),
                const SizedBox(height: 10),
                _StepCard(
                  number: '3',
                  title: s.optimDecaissementStep3Title,
                  body: s.optimDecaissementStep3Body,
                ),
                const SizedBox(height: 24),

                // ── CTA spécialiste ───────────────────────────
                EduSpecialistCta(
                  icon: Icons.person_outline,
                  color: MintColors.withdrawalOptim,
                  title: s.optimDecaissementCtaTitle,
                  body: s.optimDecaissementCtaBody,
                ),
                const SizedBox(height: 24),

                // ── Sources légales ───────────────────────────
                EduLegalSources(
                  sources: s.optimDecaissementSources,
                ),
                const SizedBox(height: 16),

                // ── Disclaimer LSFin ──────────────────────────
                EduDisclaimer(
                  text: s.optimDecaissementDisclaimer,
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

class _ChiffreChocCard extends StatelessWidget {
  final String chiffre;
  final String explication;

  const _ChiffreChocCard({required this.chiffre, required this.explication});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MintColors.withdrawalOptim, MintColors.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chiffre,
            style: GoogleFonts.montserrat(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            explication,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.white.withAlpha(220),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MintColors.primary, size: 22),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
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
          ),
        ],
      ),
    );
  }
}

class _WithdrawalTable extends StatelessWidget {
  final S s;
  const _WithdrawalTable({required this.s});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (s.optimDecaissementRow1Period, s.optimDecaissementRow1Amount, s.optimDecaissementRow1Tax),
      (s.optimDecaissementRow2Period, s.optimDecaissementRow2Amount, s.optimDecaissementRow2Tax),
      (s.optimDecaissementRow3Period, s.optimDecaissementRow3Amount, s.optimDecaissementRow3Tax),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.primary.withAlpha(15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.optimDecaissementHeaderSpread,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.optimDecaissementHeaderAmount,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.optimDecaissementHeaderTax,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            final (etalement, montant, impot) = entry.value;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: MintColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      etalement,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      montant,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      impot,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: entry.key == 0
                            ? MintColors.redMedium
                            : MintColors.primary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _StepCard(
      {required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: MintColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: MintColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
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
          ),
        ],
      ),
    );
  }
}
