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
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/coach/testament_invisible_widget.dart';
import 'package:mint_mobile/widgets/coach/avancement_hoirie_widget.dart';
import 'package:mint_mobile/widgets/coach/death_urgency_guide_widget.dart';

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
              icon: const Icon(Icons.arrow_back, color: MintColors.white),
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
                  title: 'Sans testament, ton concubin·e hérite de RIEN',
                  body:
                      'Le droit successoral suisse (CC art. 457 ss) protège d\'abord les descendants, puis les parents et le conjoint·e légal·e. Sans lien légal et sans testament, un·e concubin·e est exclu·e de la succession — quelle que soit la durée de la vie commune.',
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
                EduSectionTitle(text: 'Les notions clés'),
                const SizedBox(height: 12),

                _ConceptCard(
                  icon: Icons.shield_outlined,
                  title: 'Réserves héréditaires',
                  subtitle: 'CC art. 470–471',
                  body:
                      'Une part de ta succession est réservée par la loi à tes descendants (1/2 de leur part légale) et à ton conjoint·e (1/2 de sa part légale). Cette part ne peut pas être écartée par testament, sauf révocation pour cause ingratitude.',
                  color: MintColors.blueDark,
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.pie_chart_outline,
                  title: 'Quotité disponible',
                  subtitle: 'CC art. 470 al. 2',
                  body:
                      'Ce qui reste après les réserves héréditaires est ta "quotité disponible" — la part que tu peux léguer librement à qui tu veux : conjoint·e non marié·e, amis, associations. Si tu as des enfants, ta quotité disponible est 1/2 de ta succession.',
                  color: MintColors.purpleDark,
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.description_outlined,
                  title: 'Testament',
                  subtitle: 'CC art. 498–504',
                  body:
                      'Deux formes valides :\n• Olographe : entièrement manuscrit, daté et signé — pas de témoin requis.\n• Notarié : devant notaire avec 2 témoins — recommandé pour les situations complexes.\nPas de testament = succession légale par défaut.',
                  color: MintColors.withdrawalOptim,
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.card_giftcard_outlined,
                  title: 'Donation du vivant',
                  subtitle: 'CO art. 239 ss',
                  body:
                      'Transmettre de ton vivant permet d\'anticiper la succession et de réduire potentiellement l\'impôt successoral (variable par canton). Attention : les donations sont rapportables à la succession si tu as des héritiers réservataires. Les 5 années précédant le décès sont particulièrement scrutées.',
                  color: MintColors.successionDark,
                ),
                const SizedBox(height: 10),

                _ConceptCard(
                  icon: Icons.how_to_reg_outlined,
                  title: 'Bénéficiaires LPP et 3a',
                  subtitle: 'LPP art. 20 · OPP3 art. 2',
                  body:
                      'Le capital LPP non converti en rente et le solde 3a ne font PAS partie de ta succession ordinaire — ils sont versés aux bénéficiaires désignés. Si tu ne désignes personne, l\'ordre légal s\'applique : conjoint·e marié·e ou partenaire enregistré·e, puis descendants, puis parents. Un·e concubin·e doit être explicitement désigné·e.',
                  color: MintColors.urgentOrange,
                ),
                const SizedBox(height: 24),

                // ── P14-A : Guide de première urgence ────────────
                EduSectionTitle(text: 'En cas de décès d\'un proche'),
                const SizedBox(height: 12),
                DeathUrgencyGuideWidget(
                  phases: [
                    UrgencyPhase(
                      timeframe: 'J+1 à J+7',
                      emoji: '🆘',
                      title: 'Urgence immédiate',
                      color: MintColors.urgentOrange,
                      actions: [
                        'Déclarer le décès à l\'état civil dans les 2 jours',
                        'Informer l\'employeur et les assurances (LAMal, LPP)',
                        'Bloquer les comptes bancaires conjoints si nécessaire',
                        'Contacter le notaire si la personne avait un testament',
                      ],
                    ),
                    UrgencyPhase(
                      timeframe: 'J+8 à J+30',
                      emoji: '📋',
                      title: 'Démarches administratives',
                      color: MintColors.orangeDarkDeep,
                      actions: [
                        'Demander les rentes de survivants AVS (LAVS art. 23)',
                        'Contacter la caisse LPP pour le capital décès',
                        'Résilier les abonnements et contrats au nom du défunt',
                        'Faire l\'inventaire des avoirs et dettes',
                        'Demander les certificats d\'héritiers au notaire',
                      ],
                    ),
                    UrgencyPhase(
                      timeframe: 'J+31 à J+365',
                      emoji: '⚖️',
                      title: 'Succession légale',
                      color: MintColors.successDeep,
                      actions: [
                        'Ouvrir la procédure de succession avec le notaire',
                        'Partager les biens selon le testament ou la loi (CC art. 537)',
                        'Déposer la déclaration fiscale pour l\'année du décès',
                        'Mettre à jour les bénéficiaires de vos propres contrats',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Checklist pratique ────────────────────────
                EduSectionTitle(text: 'Checklist protection patrimoine'),
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
                EduSpecialistCta(
                  icon: Icons.gavel_outlined,
                  color: MintColors.successionDark,
                  title: 'Consulter un·e notaire ou spécialiste',
                  body: 'Un·e notaire ou spécialiste en droit successoral peut rédiger ou réviser ton testament et t\'orienter sur l\'organisation successorale adaptée à ta situation.',
                ),
                const SizedBox(height: 24),

                // ── Sources légales ───────────────────────────
                EduLegalSources(
                  sources: '• CC art. 457–640 — Droit des successions\n'
                      '• CC art. 470–471 — Réserves héréditaires\n'
                      '• CC art. 498–504 — Formes du testament\n'
                      '• LPP art. 20 — Bénéficiaires du capital LPP\n'
                      '• OPP3 art. 2 — Bénéficiaires du pilier 3a',
                ),
                const SizedBox(height: 16),

                // ── Disclaimer LSFin ──────────────────────────
                EduDisclaimer(
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
