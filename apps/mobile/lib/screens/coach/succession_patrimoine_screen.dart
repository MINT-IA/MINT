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
import 'package:mint_mobile/theme/colors.dart';

class SuccessionPatrimoineScreen extends StatelessWidget {
  const SuccessionPatrimoineScreen({super.key});

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
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 16, right: 24),
              title: Text(
                'Succession & transmission',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.25,
                ),
                maxLines: 2,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF37474F), Color(0xFF263238)],
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
                  title: 'Sans testament, ton concubin·e hérite de RIEN',
                  body:
                      'Le droit successoral suisse (CC art. 457 ss) protège d\'abord les descendants, puis les parents et le conjoint·e légal·e. Sans lien légal et sans testament, un·e concubin·e est exclu·e de la succession — quelle que soit la durée de la vie commune.',
                  color: const Color(0xFFE65100),
                ),
                const SizedBox(height: 24),

                // ── Concepts clés ────────────────────────────
                _SectionTitle(text: 'Les notions clés'),
                const SizedBox(height: 12),

                _ConceptCard(
                  icon: Icons.shield_outlined,
                  title: 'Réserves héréditaires',
                  subtitle: 'CC art. 470–471',
                  body:
                      'Une part de ta succession est réservée par la loi à tes descendants (1/2 de leur part légale) et à ton conjoint·e (1/2 de sa part légale). Cette part ne peut pas être écartée par testament, sauf révocation pour cause ingratitude.',
                  color: const Color(0xFF1565C0),
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.pie_chart_outline,
                  title: 'Quotité disponible',
                  subtitle: 'CC art. 470 al. 2',
                  body:
                      'Ce qui reste après les réserves héréditaires est ta "quotité disponible" — la part que tu peux léguer librement à qui tu veux : conjoint·e non marié·e, amis, associations. Si tu as des enfants, ta quotité disponible est 1/2 de ta succession.',
                  color: const Color(0xFF6A1B9A),
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.description_outlined,
                  title: 'Testament',
                  subtitle: 'CC art. 498–504',
                  body:
                      'Deux formes valides :\n• Olographe : entièrement manuscrit, daté et signé — pas de témoin requis.\n• Notarié : devant notaire avec 2 témoins — conseillé pour les situations complexes.\nPas de testament = succession légale par défaut.',
                  color: const Color(0xFF00695C),
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.card_giftcard_outlined,
                  title: 'Donation du vivant',
                  subtitle: 'CC art. 239 ss',
                  body:
                      'Transmettre de ton vivant permet d\'anticiper la succession et de réduire potentiellement l\'impôt successoral (variable par canton). Attention : les donations sont rapportables à la succession si tu as des héritiers réservataires. Les 5 années précédant le décès sont particulièrement scrutées.',
                  color: const Color(0xFF37474F),
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.how_to_reg_outlined,
                  title: 'Bénéficiaires LPP et 3a',
                  subtitle: 'LPP art. 20 · OPP3 art. 2',
                  body:
                      'Le capital LPP non converti en rente et le solde 3a ne font PAS partie de ta succession ordinaire — ils sont versés aux bénéficiaires désignés. Si tu ne désignes personne, l\'ordre légal s\'applique : conjoint·e marié·e ou partenaire enregistré·e, puis descendants, puis parents. Un·e concubin·e doit être explicitement désigné·e.',
                  color: const Color(0xFFE65100),
                ),
                const SizedBox(height: 24),

                // ── Checklist pratique ────────────────────────
                _SectionTitle(text: 'Checklist protection patrimoine'),
                const SizedBox(height: 12),
                _ChecklistCard(
                  items: [
                    'Vérifier la désignation des bénéficiaires sur chaque compte 3a',
                    'Vérifier la désignation de bénéficiaire LPP auprès de ta caisse',
                    'Rédiger ou mettre à jour ton testament',
                    'Vérifier ton régime matrimonial si marié·e (CC art. 181 ss)',
                    'Informer tes proches de l\'emplacement de ton testament',
                  ],
                ),
                const SizedBox(height: 24),

                // ── CTA spécialiste ───────────────────────────
                _SpecialistCta(),
                const SizedBox(height: 24),

                // ── Sources légales ───────────────────────────
                _LegalSources(),
                const SizedBox(height: 16),

                // ── Disclaimer LSFin ──────────────────────────
                _Disclaimer(
                  text:
                      'Information à caractère éducatif, ne constitue pas un conseil juridique ou patrimonial au sens de la LSFin ou du CC. Les règles successorales varient selon la situation familiale, le régime matrimonial et le canton. Consulte un·e notaire ou un·e spécialiste en droit successoral pour ta situation personnelle.',
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: MintColors.textPrimary,
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

class _SpecialistCta extends StatelessWidget {
  const _SpecialistCta();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF37474F).withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF37474F).withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel_outlined,
              color: Color(0xFF37474F), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consulter un·e notaire ou spécialiste',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Un·e notaire peut rédiger ou réviser ton testament et te conseiller sur l\'organisation successorale adaptée à ta situation.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
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

class _LegalSources extends StatelessWidget {
  const _LegalSources();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources légales',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• CC art. 457–640 — Droit des successions\n'
            '• CC art. 470–471 — Réserves héréditaires\n'
            '• CC art. 498–504 — Formes du testament\n'
            '• LPP art. 20 — Bénéficiaires du capital LPP\n'
            '• OPP3 art. 2 — Bénéficiaires du pilier 3a',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final String text;
  const _Disclaimer({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: Color(0xFFF57F17)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF5D4037),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
