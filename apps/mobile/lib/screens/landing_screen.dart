import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
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
            child: _buildBlurBlob(const Color(0xFF6BFA9F), 300), // Mint Green
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
                              fontSize: 52,
                              fontWeight: FontWeight.w300,
                              color: MintColors.textPrimary,
                              height: 0.9,
                              letterSpacing: -2,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [MintColors.primary, Color(0xFF4F46E5)],
                            ).createShader(bounds),
                            child: Text(
                              "Financial OS.",
                              style: GoogleFonts.outfit(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: Colors.white, // Masked
                                height: 0.95,
                                letterSpacing: -2,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            "L'intelligence d'un CFO, dans ta poche.\nDédié aux 22-35 ans ambitieux.",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: MintColors.textSecondary.withOpacity(0.8),
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Glass Card Features
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.6)),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF4F46E5).withOpacity(0.05),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildFeatureRow(
                                  Icons.bolt_rounded,
                                  "Diagnostic Instantané",
                                  "Analyse 360° en 5 min chrono.",
                                  Colors.amber,
                                ),
                                const SizedBox(height: 24),
                                _buildFeatureRow(
                                  Icons.shield_rounded,
                                  "100% Privé & Local",
                                  "Tes données restent sur ton device.",
                                  Colors.green,
                                ),
                                const SizedBox(height: 24),
                                _buildFeatureRow(
                                  Icons.auto_graph_rounded,
                                  "Stratégie Neutre",
                                  "0 conflit d'intérêt. Pur conseil.",
                                  Colors.blue,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                              height:
                                  48), // Spacer causes crash in SingleChildScrollView
                          const SizedBox(height: 40),

                          // Floating Action Button
                          _buildPremiumButton(context),

                          const SizedBox(height: 20),

                          Center(
                            child: TextButton(
                              onPressed: () => context.push('/login'),
                              style: TextButton.styleFrom(
                                foregroundColor: MintColors.textMuted,
                              ),
                              child: const Text("J'ai déjà un compte"),
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
        color: color.withOpacity(0.4),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildLogoPill() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Icon(Icons.token, color: MintColors.primary),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [MintColors.primary, Color(0xFF059669)],
        ),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            final isCompleted = await ReportPersistenceService.isCompleted();
            if (context.mounted) {
              if (isCompleted) {
                context.go('/report'); // Go to report if wizard completed
              } else {
                context.push('/home'); // Go to wizard if not completed
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Démarrer mon diagnostic",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "C'est parti !",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
