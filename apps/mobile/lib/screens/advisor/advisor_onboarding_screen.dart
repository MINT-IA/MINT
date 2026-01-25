import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:go_router/go_router.dart';

/// Écran d'onboarding expliquant le parcours MINT selon la théorie des cercles
class AdvisorOnboardingScreen extends StatelessWidget {
  const AdvisorOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec logo et titre
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MintColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue sur MINT',
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: MintColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Ton coach financier suisse',
                          style: TextStyle(
                            fontSize: 14,
                            color: MintColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Durée et bénéfices
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '10-15 minutes pour ton diagnostic complet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBenefit('Score de santé financière personnalisé'),
                    _buildBenefit('Recommandations concrètes et actionnables'),
                    _buildBenefit('Économies fiscales potentielles calculées'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Les 3 cercles
              Text(
                'Ton parcours en 3 cercles',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  children: [
                    _buildCircleCard(
                      number: 1,
                      title: 'Protection & Sécurité',
                      emoji: '🛡️',
                      description: 'Construis ta base solide',
                      items: [
                        'Budget : revenus et charges',
                        'Fonds d\'urgence',
                        'Gestion des dettes',
                      ],
                      duration: '3 min',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildCircleCard(
                      number: 2,
                      title: 'Prévoyance Fiscale',
                      emoji: '💰',
                      description: 'Optimise tes impôts et ta retraite',
                      items: [
                        '3a : stratégie multi-comptes',
                        'Rachat LPP échelonné',
                        'Lacunes AVS',
                      ],
                      duration: '4 min',
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildCircleCard(
                      number: 3,
                      title: 'Croissance & Patrimoine',
                      emoji: '📈',
                      description: 'Développe ton patrimoine',
                      items: [
                        'Immobilier',
                        'Investissements hors-pilier',
                        'Objectifs long terme',
                      ],
                      duration: '3 min',
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // CTA Principal
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Navigation vers le wizard
                    context.push('/advisor/wizard');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text(
                    'Commencer mon diagnostic',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Lien secondaire
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Reprendre diagnostic sauvegardé
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Fonctionnalité à venir : reprendre où tu t\'es arrêté')),
                    );
                  },
                  child: const Text('J\'ai déjà commencé mon diagnostic'),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleCard({
    required int number,
    required String title,
    required String emoji,
    required String description,
    required List<String> items,
    required String duration,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
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
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  duration,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
