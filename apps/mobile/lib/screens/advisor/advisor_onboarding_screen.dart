import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:go_router/go_router.dart';

/// Ecran d'onboarding expliquant le parcours MINT selon la theorie des cercles
class AdvisorOnboardingScreen extends StatefulWidget {
  const AdvisorOnboardingScreen({super.key});

  @override
  State<AdvisorOnboardingScreen> createState() =>
      _AdvisorOnboardingScreenState();
}

class _AdvisorOnboardingScreenState extends State<AdvisorOnboardingScreen> {
  bool _hasSavedProgress = false;
  int _savedProgress = 0;

  @override
  void initState() {
    super.initState();
    _checkSavedProgress();
  }

  Future<void> _checkSavedProgress() async {
    final savedAnswers = await ReportPersistenceService.loadAnswers();
    if (savedAnswers.isNotEmpty && mounted) {
      setState(() {
        _hasSavedProgress = true;
        // Rough progress estimate based on answer count
        _savedProgress = ((savedAnswers.length / 24) * 100).round().clamp(0, 99);
      });
    }
  }

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
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: MintColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
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
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: MintColors.textPrimary,
                            letterSpacing: -0.5,
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
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: MintColors.info, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '10-15 minutes pour ton diagnostic',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: MintColors.textPrimary,
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
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
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
                      color: MintColors.primary,
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
                      color: MintColors.primary,
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
                      color: MintColors.primary,
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
                    backgroundColor: MintColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Commencer mon diagnostic',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Resume saved progress
              if (_hasSavedProgress) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/advisor/wizard');
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(
                      'Reprendre mon diagnostic ($_savedProgress%)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MintColors.primary,
                      side: const BorderSide(color: MintColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],

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
          const Icon(Icons.check_circle, color: MintColors.primary, size: 16),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.outfit(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MintColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  duration,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
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
