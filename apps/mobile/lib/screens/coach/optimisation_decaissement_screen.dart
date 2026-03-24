/// Optimisation Décaissement — Sprint S44 (Phase 2 — AgeBand 65+).
///
/// Écran éducatif sur l'échelonnement des retraits du pilier 3a.
/// Cible : profils AgeBand.retirement (65+).
///
/// Sources légales : LIFD art. 38, OPP3 art. 3.
/// Disclaimer LSFin obligatoire (outil éducatif, pas un conseil fiscal).
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

class OptimisationDecaissementScreen extends StatelessWidget {
  const OptimisationDecaissementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.white,
      body: CustomScrollView(
        slivers: [
          // ── AppBar white standard ──────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            title: Text(
              l.optimDecaissementTitle,
              style: MintTextStyles.headlineMedium(),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.lg,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Chiffre choc ─────────────────────────────
                _ChiffreChocCard(
                  chiffre: l.optimDecaissementChiffre,
                  explication: l.optimDecaissementChiffreExplication,
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── Principe ─────────────────────────────────
                MintEntrance(child: EduSectionTitle(text: l.optimDecaissementPrincipe)),
                const SizedBox(height: MintSpacing.sm + 4),
                _InfoCard(
                  icon: Icons.calendar_today_outlined,
                  title: l.optimDecaissementInfo1Title,
                  body: l.optimDecaissementInfo1Body,
                ),
                const SizedBox(height: MintSpacing.sm + 2),
                _InfoCard(
                  icon: Icons.account_tree_outlined,
                  title: l.optimDecaissementInfo2Title,
                  body: l.optimDecaissementInfo2Body,
                ),
                const SizedBox(height: MintSpacing.sm + 2),
                _InfoCard(
                  icon: Icons.map_outlined,
                  title: l.optimDecaissementInfo3Title,
                  body: l.optimDecaissementInfo3Body,
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── Tableau illustratif ───────────────────────
                MintEntrance(delay: Duration(milliseconds: 100), child: EduSectionTitle(text: l.optimDecaissementIllustration)),
                const SizedBox(height: MintSpacing.sm + 4),
                _WithdrawalTable(l: l),
                const SizedBox(height: MintSpacing.sm),
                MintEntrance(delay: Duration(milliseconds: 200), child: Text(
                  l.optimDecaissementTableFootnote,
                  style: MintTextStyles.micro(),
                )),
                const SizedBox(height: MintSpacing.lg),

                // ── Plan d'action ────────────────────────────
                MintEntrance(delay: Duration(milliseconds: 300), child: EduSectionTitle(text: l.optimDecaissementPlanTitle)),
                const SizedBox(height: MintSpacing.sm + 4),
                _StepCard(
                  number: '1',
                  title: l.optimDecaissementStep1Title,
                  body: l.optimDecaissementStep1Body,
                ),
                const SizedBox(height: MintSpacing.sm + 2),
                _StepCard(
                  number: '2',
                  title: l.optimDecaissementStep2Title,
                  body: l.optimDecaissementStep2Body,
                ),
                const SizedBox(height: MintSpacing.sm + 2),
                _StepCard(
                  number: '3',
                  title: l.optimDecaissementStep3Title,
                  body: l.optimDecaissementStep3Body,
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── CTA spécialiste ───────────────────────────
                MintEntrance(delay: Duration(milliseconds: 400), child: EduSpecialistCta(
                  icon: Icons.person_outline,
                  color: MintColors.withdrawalOptim,
                  title: l.optimDecaissementSpecialisteTitle,
                  body: l.optimDecaissementSpecialisteBody,
                )),
                const SizedBox(height: MintSpacing.lg),

                // ── Sources légales ───────────────────────────
                EduLegalSources(sources: l.optimDecaissementSources),
                const SizedBox(height: MintSpacing.md),

                // ── Disclaimer LSFin ──────────────────────────
                EduDisclaimer(text: l.optimDecaissementDisclaimer),
                const SizedBox(height: MintSpacing.xl),
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
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(MintSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chiffre,
            style: MintTextStyles.displayMedium(color: MintColors.white).copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            explication,
            style: MintTextStyles.bodySmall(color: MintColors.white.withAlpha(220)).copyWith(height: 1.5),
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
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: MintColors.primary, size: 22),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: MintSpacing.xs),
                  Text(body, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalTable extends StatelessWidget {
  final S l;
  const _WithdrawalTable({required this.l});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (l.optimDecaissementTableRow1Spread, l.optimDecaissementTableRow1Amount, l.optimDecaissementTableRow1Tax),
      (l.optimDecaissementTableRow2Spread, l.optimDecaissementTableRow2Amount, l.optimDecaissementTableRow2Tax),
      (l.optimDecaissementTableRow3Spread, l.optimDecaissementTableRow3Amount, l.optimDecaissementTableRow3Tax),
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
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.primary.withAlpha(15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(l.optimDecaissementTableSpread, style: MintTextStyles.labelSmall())),
                Expanded(child: Text(l.optimDecaissementTableAmount, style: MintTextStyles.labelSmall())),
                Expanded(child: Text(l.optimDecaissementTableTax, style: MintTextStyles.labelSmall(), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Rows
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            final (etalement, montant, impot) = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: MintColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(etalement, style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600))),
                  Expanded(child: Text(montant, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12))),
                  Expanded(
                    child: Text(
                      impot,
                      style: MintTextStyles.bodyMedium().copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: entry.key == 0 ? MintColors.error : MintColors.primary,
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

  const _StepCard({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
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
                  style: MintTextStyles.bodySmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: MintSpacing.xs),
                  Text(body, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
