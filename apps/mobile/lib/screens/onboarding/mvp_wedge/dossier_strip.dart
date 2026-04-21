/// DossierStrip — la bande « Ton dossier » qui se densifie ligne par ligne
/// à chaque pas validé. Visible dès écran 2, en bas de l'écran.
///
/// Contrat doctrinal : la valeur de MINT se montre en continu (dossier
/// vivant), pas dans un aha final. Chaque ligne apparaît avec une
/// animation subtile dès qu'elle entre dans le provider.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
import 'package:mint_mobile/theme/colors.dart';

class DossierStrip extends StatelessWidget {
  const DossierStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<OnboardingProvider>().dossier;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MintColors.craie,
        border: Border(
          top: BorderSide(
            color: MintColors.textPrimary.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ton dossier',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              'Il va se remplir ligne par ligne.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in entries)
                  Padding(
                    key: ValueKey('dossier_entry_${entry.key}'),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: _DossierLine(entry: entry),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DossierLine extends StatelessWidget {
  const _DossierLine({required this.entry});
  final DossierEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            entry.label,
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
            entry.value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
