/// Succession & Patrimoine — Sprint S44 (Phase 2 — AgeBand 65+).
///
/// Écran éducatif sur la succession et la transmission du patrimoine.
/// Cible : profils AgeBand.retirement (65+), particulièrement 70+.
///
/// Sources légales : CC art. 457-640, LPP art. 20, OPP3 art. 2.
/// Disclaimer LSFin obligatoire (outil éducatif, pas un conseil juridique).
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/coach/testament_invisible_widget.dart';
import 'package:mint_mobile/widgets/coach/avancement_hoirie_widget.dart';
import 'package:mint_mobile/widgets/coach/death_urgency_guide_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';

class SuccessionPatrimoineScreen extends StatelessWidget {
  const SuccessionPatrimoineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.white,
      // AX iOS 26.2 (ADR 2026-07-30, tranche AX 2 — patron #1127) : AppBar
      // classique fixe en `Scaffold.appBar` au lieu d'un SliverAppBar dans le
      // CustomScrollView. Le SliverAppBar ré-effondrait l'arbre AX des routes
      // poussées AU SCROLL (2ᵉ déclencheur ADR) → `succession-result`
      // inatteignable et `succession-back` (leading) non-ciblable par id. En
      // AppBar fixe : arbre stable au scroll, back ciblable par id. Ancres
      // C1 (succession-anchor) / C4 (succession-back) préservées.
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Ancre C4 « pas de cul-de-sac » : bouton retour identifié (safePop →
        // pop, sinon go('/home')) — non-poppable sur entrée deeplink. Smoke Tier B.
        leading: Semantics(
          identifier: 'succession-back',
          button: true,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => safePop(context),
          ),
        ),
        // Ancre régionale Tier B smoke (C1 « atteignable ») posée sur le titre
        // AppBar — motif profond, JAMAIS le wrapper racine (leçon ADR AX iOS 26.2).
        title: Semantics(
          identifier: 'succession-anchor',
          child: Text(
            l.successionTitle,
            style: MintTextStyles.headlineMedium(),
          ),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.lg,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Chiffre choc ─────────────────────────────
                _AlertCard(
                  icon: Icons.warning_amber_outlined,
                  title: l.successionAlertTitle,
                  body: l.successionAlertBody,
                  color: MintColors.urgentOrange,
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── P8-A : Testament invisible ───────────────
                // Ancre régionale Tier B smoke (C2 « chiffré ») : le widget rend
                // « Patrimoine : CHF 500'000 » + la répartition légale au repos
                // (écran éducatif, aucun gate) — motif profond, jamais le
                // wrapper racine.
                Semantics(
                  identifier: 'succession-result',
                  child: const TestamentInvisibleWidget(
                    patrimoine: 500000,
                    initialStatus: FamilyStatus.concubin,
                  ),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── P8-E : Avancement d'hoirie ────────────────
                const AvancementHoirieWidget(
                  totalPatrimoine: 500000,
                  donationAmount: 50000,
                  donationRecipientIndex: 0,
                  children: [
                    HoirieChild(name: 'Enfant 1', emoji: ''),
                    HoirieChild(name: 'Enfant 2', emoji: ''),
                  ],
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── Concepts clés ────────────────────────────
                MintEntrance(child: EduSectionTitle(text: l.successionNotionsCles)),
                const SizedBox(height: MintSpacing.sm + 4),

                _ConceptCard(
                  icon: Icons.shield_outlined,
                  title: l.successionReservesTitle,
                  subtitle: l.successionReservesSubtitle,
                  body: l.successionReservesBody,
                  color: MintColors.info,
                ),
                const SizedBox(height: MintSpacing.sm + 2),

                _ConceptCard(
                  icon: Icons.pie_chart_outline,
                  title: l.successionQuotiteTitle,
                  subtitle: l.successionQuotiteSubtitle,
                  body: l.successionQuotiteBody,
                  color: MintColors.purple,
                ),
                const SizedBox(height: MintSpacing.sm + 2),

                _ConceptCard(
                  icon: Icons.description_outlined,
                  title: l.successionTestamentTitle,
                  subtitle: l.successionTestamentSubtitle,
                  body: l.successionTestamentBody,
                  color: MintColors.withdrawalOptim,
                ),
                const SizedBox(height: MintSpacing.sm + 2),

                _ConceptCard(
                  icon: Icons.card_giftcard_outlined,
                  title: l.successionDonationTitle,
                  subtitle: l.successionDonationSubtitle,
                  body: l.successionDonationBody,
                  color: MintColors.successionDark,
                ),
                const SizedBox(height: MintSpacing.sm + 2),

                _ConceptCard(
                  icon: Icons.how_to_reg_outlined,
                  title: l.successionBeneficiairesTitle,
                  subtitle: l.successionBeneficiairesSubtitle,
                  body: l.successionBeneficiairesBody,
                  color: MintColors.urgentOrange,
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── P14-A : Guide de première urgence ────────────
                MintEntrance(delay: const Duration(milliseconds: 100), child: EduSectionTitle(text: l.successionDecesProche)),
                const SizedBox(height: MintSpacing.sm + 4),
                MintEntrance(delay: const Duration(milliseconds: 200), child: DeathUrgencyGuideWidget(
                  phases: [
                    UrgencyPhase(
                      timeframe: 'J+1 à J+7',
                      emoji: '',
                      title: S.of(context)!.successionUrgence,
                      color: MintColors.urgentOrange,
                      actions: [
                        S.of(context)!.successionUrgenceAction1,
                        S.of(context)!.successionUrgenceAction2,
                        S.of(context)!.successionUrgenceAction3,
                        S.of(context)!.successionUrgenceAction4,
                      ],
                    ),
                    UrgencyPhase(
                      timeframe: 'J+8 à J+30',
                      emoji: '',
                      title: S.of(context)!.successionDemarches,
                      color: MintColors.orangeDarkDeep,
                      actions: [
                        S.of(context)!.successionDemarchesAction1,
                        S.of(context)!.successionDemarchesAction2,
                        S.of(context)!.successionDemarchesAction3,
                        S.of(context)!.successionDemarchesAction4,
                        S.of(context)!.successionDemarchesAction5,
                      ],
                    ),
                    UrgencyPhase(
                      timeframe: 'J+31 à J+365',
                      emoji: '',
                      title: S.of(context)!.successionLegale,
                      color: MintColors.successDeep,
                      actions: [
                        S.of(context)!.successionLegaleAction1,
                        S.of(context)!.successionLegaleAction2,
                        S.of(context)!.successionLegaleAction3,
                        S.of(context)!.successionLegaleAction4,
                      ],
                    ),
                  ],
                )),
                const SizedBox(height: MintSpacing.lg),

                // ── Checklist pratique ────────────────────────
                MintEntrance(delay: const Duration(milliseconds: 300), child: EduSectionTitle(text: l.successionChecklistTitle)),
                const SizedBox(height: MintSpacing.sm + 4),
                _ChecklistCard(
                  items: [
                    l.successionCheck1,
                    l.successionCheck2,
                    l.successionCheck3,
                    l.successionCheck4,
                    l.successionCheck5,
                  ],
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── CTA spécialiste ───────────────────────────
                MintEntrance(delay: const Duration(milliseconds: 400), child: EduSpecialistCta(
                  icon: Icons.gavel_outlined,
                  color: MintColors.successionDark,
                  title: l.successionSpecialisteTitle,
                  body: l.successionSpecialisteBody,
                )),
                const SizedBox(height: MintSpacing.lg),

                // ── Sources légales ───────────────────────────
                EduLegalSources(sources: l.successionSources),
                const SizedBox(height: MintSpacing.md),

                // ── Disclaimer LSFin ──────────────────────────
                EduDisclaimer(text: l.successionDisclaimer),
                const SizedBox(height: MintSpacing.xl),
              ]),
            ),
          ),
        ],
      ))),
    );
  }
}

// ── Widgets internes ─────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Text(
                    title,
                    style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            Text(
              body,
              style: MintTextStyles.bodyMedium().copyWith(height: 1.5),
            ),
          ],
        ),
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
    return Semantics(
      container: true,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 14,
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
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: MintTextStyles.labelSmall(color: color).copyWith(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 2),
            Text(body, style: MintTextStyles.labelMedium().copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final List<String> items;
  const _ChecklistCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 14,
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
                    const SizedBox(width: MintSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        item,
                        style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
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
