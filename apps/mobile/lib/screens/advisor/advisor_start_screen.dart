import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class AdvisorSessionStartScreen extends StatelessWidget {
  const AdvisorSessionStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MintColors.accentPastel,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.auto_awesome, color: MintColors.primary, size: 32),
              ),
              const SizedBox(height: 32),
              Text(
                'Votre Session\nConseiller',
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Je vais vous guider à travers un diagnostic rapide pour identifier vos leviers d\'optimisation en Suisse.',
                style: TextStyle(
                  fontSize: 17,
                  color: MintColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              _buildInfoRow(Icons.timer_outlined, 'Durée estimée : 5 minutes'),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.lock_outline, '100% Confidentiel. Aucun stockage sensible.'),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.read_more, 'Orientation uniquement, pas de conseil juridique.'),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/advisor/focus'),
                  child: const Text('Commencer le diagnostic'),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Éducation financière proactive',
                  style: TextStyle(fontSize: 12, color: MintColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MintColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: MintColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
