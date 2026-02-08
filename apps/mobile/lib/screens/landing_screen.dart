import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/mint_ui_kit.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'dart:ui' as ui; // For BackdropFilter blur
import 'package:flutter/services.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Background Aurora Mesh (iOS 26 Style)
          Positioned(
            top: -100,
            left: -50,
            child: _buildBlurBlob(const Color(0xFFE5E5E7), 300), // Neutral Light Gray
          ),
          Positioned(
            top: 200,
            right: -100,
            child: _buildBlurBlob(const Color(0xFF4F46E5), 350), // Deep Indigo
          ),
          Positioned(
            bottom: -100,
            left: 50,
            child: _buildBlurBlob(const Color(0xFF0EA5E9), 300), // Sky Blue
          ),

          // 2. Content with Glassmorphism
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Logo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLogoPill(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white),
                                ),
                                child: const Text(
                                  "Bêta Privée",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: MintColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 48),

                          // Hero Text
                          Text(
                            "Le premier",
                            style: GoogleFonts.outfit(
                              fontSize: 56,
                              fontWeight: FontWeight.w400,
                              color: MintColors.textPrimary,
                              height: 0.9,
                              letterSpacing: -2.5,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [MintColors.primary, Color(0xFF6E6E73)],
                            ).createShader(bounds),
                            child: Text(
                              S.of(context)?.landingHero ?? "Financial OS.",
                              style: GoogleFonts.outfit(
                                fontSize: 62,
                                fontWeight: FontWeight.w800,
                                color: Colors.white, // Masked
                                height: 0.95,
                                letterSpacing: -2.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            "L'intelligence d'un CFO, dans ta poche.\nZéro bullshit. Pur conseil.",
                            style: GoogleFonts.inter(
                              fontSize: 19,
                              color: MintColors.textSecondary,
                              height: 1.6,
                              letterSpacing: -0.2,
                            ),
                          ),

                          const SizedBox(height: 56),

                          // Glass Card Features
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(
                                  color: MintColors.lightBorder.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildFeatureRow(
                                  Icons.bolt_rounded,
                                  "Diagnostic Instantané",
                                  "Analyse 360° en 5 min chrono.",
                                  MintColors.primary,
                                ),
                                const SizedBox(height: 32),
                                _buildFeatureRow(
                                  Icons.shield_rounded,
                                  "100% Privé & Local",
                                  "Tes données restent sur ton device.",
                                  MintColors.primary,
                                ),
                                const SizedBox(height: 32),
                                _buildFeatureRow(
                                  Icons.auto_graph_rounded,
                                  "Stratégie Neutre",
                                  "Zéro commission. Zéro conflit.",
                                  MintColors.primary,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 64),

                          // Floating Action Button
                          _buildPremiumButton(context),

                          const SizedBox(height: 24),

                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/home'), // Fixed: Route /login was failing
                              style: TextButton.styleFrom(
                                foregroundColor: MintColors.textMuted,
                              ),
                              child: const Text(
                                "Reprendre mon diagnostic",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.35),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildLogoPill() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.token_rounded, color: MintColors.primary, size: 28),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumButton(BuildContext context) {
    return MintPremiumButton(
      title: S.of(context)?.startDiagnostic ?? "Démarrer mon diagnostic",
      subtitle: "Bilan 360° • 5 minutes",
      onTap: () async {
        final isCompleted = await ReportPersistenceService.isCompleted();
        if (context.mounted) {
          if (isCompleted) {
            context.go('/report');
          } else {
            context.push('/home');
          }
        }
      },
    );
  }
}
