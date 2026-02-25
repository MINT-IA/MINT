import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MintColors.primary,
                      MintColors.primary.withAlpha(220),
                    ],
                  ),
                ),
              ),
              title: Text(
                'AIDE EN CAS DE DETTE',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Intro
                _buildIntroCard(),
                const SizedBox(height: 24),

                // Dettes Conseils Suisse
                _buildNationalResourceCard(
                  nom: 'Dettes Conseils Suisse',
                  description:
                      'Federation faitiere des services de conseil en dettes '
                      'en Suisse. Conseil gratuit, confidentiel et professionnel. '
                      'Plus de 30 services membres dans toute la Suisse.',
                  url: 'https://www.dettes.ch',
                  telephone: '0800 40 40 40',
                  icon: Icons.phone_in_talk,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),

                // Caritas
                _buildNationalResourceCard(
                  nom: 'Caritas — Conseil en dettes',
                  description:
                      'Service d\'aide de Caritas Suisse pour les personnes '
                      'en situation d\'endettement. Aide au desendettement, '
                      'negociation avec les creanciers, accompagnement '
                      'budgetaire personnalise.',
                  url: 'https://www.caritas.ch/dettes',
                  telephone: '0800 708 708',
                  icon: Icons.favorite_outline,
                  color: Colors.red,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent,
                  color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Vous n\'etes pas seul',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'En Suisse, de nombreux services professionnels offrent un '
            'accompagnement gratuit et confidentiel pour les personnes '
            'confrontees a des difficultes financieres. Demander de l\'aide '
            'est un acte de courage, pas un signe de faiblesse.',
            style: TextStyle(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tous les liens ci-dessous menent vers des sites externes. '
            'MINT ne transmet aucune donnee a ces services.',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const Borderconst Radius.circular(16),
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
                  borderRadius: const Borderconst Radius.circular(12),
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
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: const Borderconst Radius.circular(4),
                      ),
                      child: const Text(
                        'GRATUIT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
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
                  label: const Text('Site web'),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SERVICE CANTONAL',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
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
                  borderRadius: const Borderconst Radius.circular(8),
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
            InkWell(
              onTap: () => _launchUrl(cantonalResource.url),
              borderRadius: const Borderconst Radius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: const Borderconst Radius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MintColors.primary.withValues(alpha: 0.1),
                        borderRadius: const Borderconst Radius.circular(8),
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
          ] else
            const Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aucun service cantonal reference pour ce canton. '
                'Contactez Dettes Conseils Suisse pour etre oriente.',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const Borderconst Radius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protection des donnees (nLPD)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MINT ne transmet aucune donnee personnelle aux services '
                  'references ci-dessus. Les liens externes ouvrent votre '
                  'navigateur. Votre utilisation de cet ecran reste strictement '
                  'confidentielle et n\'est ni enregistree ni partagee.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const Borderconst Radius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'MINT fournit ces liens a titre informatif et pedagogique. '
              'Ces services sont independants de MINT. MINT ne fournit '
              'pas de conseil juridique ou financier. En cas de difficulte '
              'financiere, contactez directement les services specialises.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
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
