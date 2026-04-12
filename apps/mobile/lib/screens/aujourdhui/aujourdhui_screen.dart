/// AujourdhuiScreen — living tension-based home for authenticated users.
///
/// Phase 17: Living Timeline. Replaces LandingScreen on Tab 0 for
/// authenticated users. Shows 3 tension cards (earned/pulsing/ghosted)
/// reflecting the user's actual financial state, plus a Cleo loop indicator.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/tension_card_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/tension/cleo_loop_indicator.dart';
import 'package:mint_mobile/widgets/tension/tension_card_widget.dart';

class AujourdhuiScreen extends StatefulWidget {
  const AujourdhuiScreen({super.key});

  @override
  State<AujourdhuiScreen> createState() => _AujourdhuiScreenState();
}

class _AujourdhuiScreenState extends State<AujourdhuiScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TensionCardProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TensionCardProvider>();
    final l10n = S.of(context)!;

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: MintColors.warmWhite,
        body: Center(
          child: CircularProgressIndicator(
            color: MintColors.success,
          ),
        ),
      );
    }

    if (provider.isEmpty) {
      return Scaffold(
        backgroundColor: MintColors.warmWhite,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GestureDetector(
                onTap: () => context.go('/coach/chat'),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MintColors.craie,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.tensionEmptyWelcome,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.tensionEmptySubtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: MintColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // MINT wordmark
            Text(
              'MINT',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            // Three tension cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TensionCardWidget(card: provider.cards[0]),
                  const SizedBox(height: 12),
                  TensionCardWidget(card: provider.cards[1]),
                  const SizedBox(height: 12),
                  TensionCardWidget(card: provider.cards[2]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Cleo loop indicator
            CleoLoopIndicator(position: provider.loopPosition),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
