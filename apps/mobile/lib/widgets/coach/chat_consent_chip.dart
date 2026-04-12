import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/consent_manager.dart';

// ────────────────────────────────────────────────────────────
//  CHAT CONSENT CHIP — CHAT-03 (Phase 3)
//
//  Inline consent request shown as a coach message with
//  accept/decline chips. One human sentence per consent —
//  no nLPD article numbers, no conservation durations.
//
//  T-03-05: Each consent sentence is human-readable, specific
//  about what is shared. Accept/decline chips are equally
//  prominent (no dark pattern). Decline is respected immediately.
// ────────────────────────────────────────────────────────────

/// Inline consent request widget with accept/decline chips.
///
/// Renders a human sentence explaining the consent, followed by
/// two equally-prominent suggestion-chip-style buttons.
class ChatConsentChip extends StatelessWidget {
  final ConsentType consentType;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const ChatConsentChip({
    super.key,
    required this.consentType,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Human sentence
          Text(
            _consentSentence(consentType),
            style: MintTextStyles.bodyMedium(
              color: MintColors.textPrimary,
            ).copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          // Accept / Decline chips — equally prominent
          Row(
            children: [
              _buildChip(
                label: 'Oui, c\u2019est bon',
                onTap: onAccept,
                isPrimary: false, // No dark pattern — both equal
              ),
              const SizedBox(width: 8),
              _buildChip(
                label: 'Non merci',
                onTap: onDecline,
                isPrimary: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: MintColors.porcelaine,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MintColors.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: MintTextStyles.bodySmall(
            color: MintColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w500, height: 1.3),
        ),
      ),
    );
  }

  /// Maps each ConsentType to a human sentence.
  ///
  /// French with proper diacritics. No nLPD references.
  /// No conservation durations. Just human language.
  static String _consentSentence(ConsentType type) {
    switch (type) {
      case ConsentType.byokDataSharing:
        return 'Pour personnaliser mes r\u00e9ponses, j\u2019ai besoin '
            'd\u2019envoyer tes donn\u00e9es financi\u00e8res agr\u00e9g\u00e9es '
            '\u00e0 mon fournisseur IA. \u00c7a te va\u00a0?';
      case ConsentType.ragQueries:
        return 'Pour mieux r\u00e9pondre \u00e0 tes questions, j\u2019aimerais '
            'chercher dans ma base de connaissances. D\u2019accord\u00a0?';
      case ConsentType.documentUpload:
        return 'Pour analyser ton document, j\u2019ai besoin de scanner '
            'son contenu. Tu es OK\u00a0?';
      case ConsentType.snapshotStorage:
        return 'Pour suivre l\u2019\u00e9volution de ta situation, j\u2019aimerais '
            'garder un historique de tes projections. \u00c7a te convient\u00a0?';
      case ConsentType.notifications:
        return 'Je pourrais t\u2019envoyer des rappels personnalis\u00e9s '
            'avec tes chiffres. Tu veux\u00a0?';
      case ConsentType.analytics:
        return 'Pour am\u00e9liorer l\u2019exp\u00e9rience, j\u2019aimerais '
            'collecter des statistiques anonymis\u00e9es. D\u2019accord\u00a0?';
      case ConsentType.openBanking:
        return 'Pour importer tes transactions automatiquement, j\u2019ai besoin '
            'd\u2019une connexion lecture seule \u00e0 tes comptes. On y va\u00a0?';
    }
  }

  /// Returns the consent sentence for a given type (for testing).
  static String sentenceFor(ConsentType type) => _consentSentence(type);
}
