import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/widgets/common/debt_tools_nav.dart';

/// Ecran des ressources d'aide en cas de dette.
///
/// Liens vers Dettes Conseils Suisse, Caritas et services cantonaux.
/// Note privacy nLPD et disclaimer.
class HelpResourcesScreen extends StatefulWidget {
  const HelpResourcesScreen({super.key});

  @override
  State<HelpResourcesScreen> createState() => _HelpResourcesScreenState();
}

class _HelpResourcesScreenState extends State<HelpResourcesScreen> {
  String _canton = 'VD';

  @override
  Widget build(BuildContext context) {
    final cantonalResource = DebtHelpResources.getCantonalResource(_canton);

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'AIDE EN CAS DE DETTE',
              style: MintTextStyles.titleMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Intro
                _buildIntroCard(),
                const SizedBox(height: 24),

                // Dettes Conseils Suisse
                _buildNationalResourceCard(
                  nom: 'Dettes Conseils Suisse',
                  description:
                      'Fédération faîtière des services de conseil en dettes '
                      'en Suisse. Conseil gratuit, confidentiel et professionnel. '
                      'Plus de 30 services membres dans toute la Suisse.',
                  url: 'https://www.dettes.ch',
                  telephone: '0800 40 40 40',
                  icon: Icons.phone_in_talk,
                  color: MintColors.info,
                ),
                const SizedBox(height: 16),

                // Caritas
                _buildNationalResourceCard(
                  nom: 'Caritas — Conseil en dettes',
                  description:
                      'Service d\'aide de Caritas Suisse pour les personnes '
                      'en situation d\'endettement. Aide au désendettement, '
                      'négociation avec les créanciers, accompagnement '
                      'budgétaire personnalisé.',
                  url: 'https://www.caritas.ch/dettes',
                  telephone: '0800 708 708',
                  icon: Icons.favorite_outline,
                  color: MintColors.error,
                ),
                const SizedBox(height: 24),

                // Service cantonal
                _buildCantonalSection(cantonalResource),
                const SizedBox(height: 24),

                // Note privacy nLPD
                _buildPrivacyNote(),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 24),

                // Navigation croisée dette
                const DebtToolsNav(currentRoute: '/debt/help'),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent,
                  color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Vous n\'êtes pas seul',
                style: MintTextStyles.titleMedium(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'En Suisse, de nombreux services professionnels offrent un '
            'accompagnement gratuit et confidentiel pour les personnes '
            'confrontées à des difficultés financières. Demander de l\'aide '
            'est un acte de courage, pas un signe de faiblesse.',
            style: TextStyle(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tous les liens ci-dessous mènent vers des sites externes. '
            'MINT ne transmet aucune donnée à ces services.',
            style: TextStyle(
              fontSize: 12,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNationalResourceCard({
    required String nom,
    required String description,
    required String url,
    required String telephone,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: MintTextStyles.titleMedium(),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.successBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'GRATUIT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: MintColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchUrl(url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(S.of(context)!.helpResourceSiteWeb),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _launchUrl('tel:$telephone'),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text(telephone, style: const TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCantonalSection(HelpResource? cantonalResource) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SERVICE CANTONAL',
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: 16),

          // Dropdown canton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Votre canton',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: MintColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _canton,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                    items: DebtHelpResources.cantons
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _canton = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (cantonalResource != null) ...[
            Semantics(
              label: cantonalResource.nom,
              button: true,
              child: InkWell(
              onTap: () => _launchUrl(cantonalResource.url),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MintColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_city,
                          color: MintColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cantonalResource.nom,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cantonalResource.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MintColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new,
                        color: MintColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Aucun service cantonal référencé pour ce canton. '
                'Contactez Dettes Conseils Suisse pour être orienté.',
                style: TextStyle(
                  fontSize: 13,
                  color: MintColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.neutralBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.neutralBg),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: MintColors.blueDark, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protection des données (nLPD)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.blueMaterial900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'MINT ne transmet aucune donnée personnelle aux services '
                  'référencés ci-dessus. Les liens externes ouvrent votre '
                  'navigateur. Votre utilisation de cet écran reste strictement '
                  'confidentielle et n\'est ni enregistrée ni partagée.',
                  style: TextStyle(
                    fontSize: 12,
                    color: MintColors.blueDark,
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

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'MINT fournit ces liens à titre informatif et pédagogique. '
              'Ces services sont indépendants de MINT. MINT ne fournit '
              'pas de conseil juridique ou financier. En cas de difficulté '
              'financière, contactez directement les services spécialisés.',
              style: TextStyle(
                fontSize: 11,
                color: MintColors.deepOrange,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
