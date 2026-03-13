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
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';

class OptimisationDecaissementScreen extends StatelessWidget {
  const OptimisationDecaissementScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                'Ordre de retrait 3a',
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
                  chiffre: '+CHF 3\'500',
                  explication:
                      'C\'est l\'impôt supplémentaire payé quand on retire 2 comptes 3a la même année plutôt que de les étaler sur 2 ans fiscales différentes — selon LIFD art. 38.',
                ),
                const SizedBox(height: 24),

                // ── Principe ─────────────────────────────────
                EduSectionTitle(text: 'Le principe de l\'échelonnement'),
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.calendar_today_outlined,
                  title: '1 compte 3a par année fiscale',
                  body:
                      'Le retrait du 3a est imposé séparément du revenu ordinaire (LIFD art. 38), mais le taux augmente avec le montant retiré. En fractionnant sur plusieurs années, chaque retrait reste dans une tranche basse.',
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.account_tree_outlined,
                  title: 'Jusqu\'à 10 comptes 3a simultanés',
                  body:
                      'Depuis 2026, tu peux détenir plusieurs comptes 3a simultanément (révision OPP3 2026). En les ouvrant progressivement, tu peux échelonner les retraits sur 3 à 10 ans selon ton plan.',
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.map_outlined,
                  title: 'La fiscalité varie par canton',
                  body:
                      'Plusieurs cantons offrent des abattements supplémentaires. Le choix du canton de résidence au moment du retrait influence directement l\'imposition.',
                ),
                const SizedBox(height: 24),

                // ── Tableau illustratif ───────────────────────
                EduSectionTitle(text: 'Illustration : CHF 150\'000 en 3a'),
                const SizedBox(height: 12),
                _WithdrawalTable(),
                const SizedBox(height: 8),
                Text(
                  '* Estimations indicatives basées sur un taux cantonal moyen (ZH). Varie selon le canton et la situation fiscale individuelle.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Plan d'action ────────────────────────────
                EduSectionTitle(text: 'Comment planifier ton décaissement'),
                const SizedBox(height: 12),
                _StepCard(
                  number: '1',
                  title: 'Inventaire de tes comptes 3a',
                  body:
                      'Liste chaque compte 3a avec son solde et son établissement. Note les années prévues de retraite pour chaque retrait.',
                ),
                const SizedBox(height: 10),
                _StepCard(
                  number: '2',
                  title: 'Simule l\'impact fiscal par scénario',
                  body:
                      'Compare : tout retirer en 1 an vs. étaler sur 3, 5 ou 7 ans. L\'écart peut représenter plusieurs milliers de francs.',
                ),
                const SizedBox(height: 10),
                _StepCard(
                  number: '3',
                  title: 'Coordinate avec ta retraite LPP',
                  body:
                      'Attendre 1 à 2 ans après le retrait du capital LPP pour le premier 3a réduit la charge fiscale totale sur l\'année de départ.',
                ),
                const SizedBox(height: 24),

                // ── CTA spécialiste ───────────────────────────
                EduSpecialistCta(
                  icon: Icons.person_outline,
                  color: MintColors.withdrawalOptim,
                  title: 'Consulter un·e spécialiste',
                  body: 'Un·e spécialiste en prévoyance peut modéliser ton plan de décaissement précis selon ta situation.',
                ),
                const SizedBox(height: 24),

                // ── Sources légales ───────────────────────────
                EduLegalSources(
                  sources: '• LIFD art. 38 — Imposition séparée des prestations en capital\n'
                      '• OPP3 art. 3 — Conditions de retrait anticipé du pilier 3a\n'
                      '• OPP3 art. 7 — Plafonds de déduction\n'
                      '• OPP3 (révision 2026) — Possibilité de détenir plusieurs comptes 3a',
                ),
                const SizedBox(height: 16),

                // ── Disclaimer LSFin ──────────────────────────
                EduDisclaimer(
                  text:
                      'Information à caractère éducatif, ne constitue pas un conseil fiscal au sens de la LSFin. Les montants illustrés sont indicatifs. L\'impact exact dépend de ton canton de résidence, de tes autres revenus et de ta situation fiscale individuelle. Consulte un·e spécialiste avant toute décision de retrait.',
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
  const _WithdrawalTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('1 an', 'CHF 150\'000', '~CHF 12\'500'),
      ('3 ans', 'CHF 50\'000/an', '~CHF 3\'200/an'),
      ('5 ans', 'CHF 30\'000/an', '~CHF 1\'700/an'),
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
                    'Étalement',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Montant/retrait',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Impôt est.*',
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
