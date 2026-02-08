import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/theme/colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final authProvider = context.watch<AuthProvider>();
    final double precision = profile?.factfindCompletionIndex ?? 0.3;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPrecisionCard(precision),
                  const SizedBox(height: 32),
                  const Text('Détails FactFind', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildFactFindSection(
                    title: 'Identité & Foyer',
                    status: 'Complet',
                    isComplete: true,
                    icon: Icons.person_outline,
                  ),
                  _buildFactFindSection(
                    title: 'Revenus & Épargne',
                    status: 'Partial (Net)',
                    isComplete: false,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _buildFactFindSection(
                    title: 'Prévoyance (LPP)',
                    status: 'Manquant',
                    isComplete: false,
                    icon: Icons.security_outlined,
                    reward: '+15% de précision',
                  ),
                  _buildFactFindSection(
                    title: 'Immobilier & Dettes',
                    status: 'Manquant',
                    isComplete: false,
                    icon: Icons.home_outlined,
                    reward: '+10% de précision',
                  ),
                  const SizedBox(height: 32),
                  const Text('Sécurité & Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildFactFindSection(
                    title: 'Contrôle des Partages',
                    status: 'Gérer mes accès bLink',
                    isComplete: true,
                    icon: Icons.lock_outline,
                    onTap: () => context.push('/profile/consent'),
                  ),
                  const SizedBox(height: 32),
                  // Auth section (if logged in)
                  if (authProvider.isLoggedIn) ...[
                    const Text('Compte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildAuthSection(context, authProvider),
                    const SizedBox(height: 32),
                  ],
                  _buildDangerZone(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: MintColors.background,
      title: Text('MON PROFIL MENTOR', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildPrecisionCard(double precision) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: MintColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Precision Index', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              Text('${(precision * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: precision,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 16),
          const Text(
            'Plus votre profil est complet, plus votre rapport "Statement of Advice" est puissant.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFactFindSection({
    required String title,
    required String status,
    required bool isComplete,
    required IconData icon,
    String? reward,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: isComplete ? MintColors.success : MintColors.textMuted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(status, style: TextStyle(fontSize: 12, color: isComplete ? MintColors.success : MintColors.textMuted)),
                  ],
                ),
              ),
              if (reward != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: MintColors.appleSurface, borderRadius: BorderRadius.circular(8)),
                  child: Text(reward, style: const TextStyle(color: MintColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              const Icon(Icons.chevron_right, size: 18, color: MintColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthSection(BuildContext context, AuthProvider authProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: MintColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.displayName ?? authProvider.email ?? 'Utilisateur',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (authProvider.displayName != null)
                      Text(
                        authProvider.email ?? '',
                        style: const TextStyle(fontSize: 12, color: MintColors.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                context.go('/');
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Se déconnecter'),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.error,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Supprimer mes données locales'),
        ),
      ],
    );
  }
}
