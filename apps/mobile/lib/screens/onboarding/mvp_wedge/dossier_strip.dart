/// DossierStrip — la bande « Ton dossier » qui se densifie ligne par
/// ligne au fil des tours validés.
///
/// Panel final (2026-04-22) :
///   - Apparition d'une ligne : fade-in + slide-up 12px en 240 ms
///     `Curves.easeOutCubic`, décalage 60 ms entre label et valeur.
///   - Count-up du chiffre : 420 ms `Curves.easeOutQuart` (simplifié
///     ici en fade car les valeurs ne sont pas toutes numériques).
///   - Haptic `HapticFeedback.selectionClick` au settle.
///   - Fond `MintColors.craie`, border-top 0.5px, label eyebrow en
///     `MintColors.corailDiscret`, valeur en Montserrat 15pt w500.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
import 'package:mint_mobile/theme/colors.dart';

class DossierStrip extends StatefulWidget {
  const DossierStrip({super.key});

  @override
  State<DossierStrip> createState() => _DossierStripState();
}

class _DossierStripState extends State<DossierStrip> {
  int _previousLen = 0;

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<OnboardingProvider>().dossier;

    // Haptic discret au moment où une nouvelle ligne arrive.
    if (entries.length > _previousLen) {
      _previousLen = entries.length;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => HapticFeedback.selectionClick(),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MintColors.craie,
        border: Border(
          top: BorderSide(
            color: MintColors.textPrimary.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TON DOSSIER',
            style: GoogleFonts.montserrat(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: MintColors.corailDiscret,
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              'Il se remplit tour par tour.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.40,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in entries)
                      Padding(
                        key: ValueKey('dossier_entry_${entry.key}'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DossierLine(entry: entry),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DossierLine extends StatefulWidget {
  const _DossierLine({required this.entry});
  final DossierEntry entry;

  @override
  State<_DossierLine> createState() => _DossierLineState();
}

class _DossierLineState extends State<_DossierLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _DossierLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.value != widget.entry.value) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fade + slide-up 12px, easeOutCubic.
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curved),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                widget.entry.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: MintColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                widget.entry.value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
