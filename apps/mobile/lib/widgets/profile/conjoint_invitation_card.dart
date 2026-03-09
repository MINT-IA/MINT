import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  CONJOINT INVITATION CARD — Couple linking & invitation CTA
// ────────────────────────────────────────────────────────────
//
// Displayed when the conjoint hasn't joined MINT or when
// profiles are pending / linked. Encourages data sharing
// for more accurate couple projections.
//
// Régimes matrimoniaux : CC art. 196 (participation aux acquêts),
// CC art. 247 (séparation de biens), CC art. 221 (communauté de biens).
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class ConjointInvitationCard extends StatelessWidget {
  final String conjointFirstName;
  final String invitationLevel; // 'declared' | 'invited' | 'linked'
  final VoidCallback? onInvite;
  final VoidCallback? onLink;
  final VoidCallback? onChangeRegime;
  final String regimeMatrimonial;

  const ConjointInvitationCard({
    super.key,
    required this.conjointFirstName,
    required this.invitationLevel,
    this.onInvite,
    this.onLink,
    this.onChangeRegime,
    this.regimeMatrimonial = 'participation_acquets',
  });

  static const _regimeLabels = {
    'participation_acquets': 'Participation aux acquêts',
    'separation': 'Séparation de biens',
    'communaute': 'Communauté de biens',
  };

  bool get _isLinked => invitationLevel == 'linked';
  bool get _isInvited => invitationLevel == 'invited';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: _isLinked
            ? Border.all(color: MintColors.lightBorder)
            : _dashedBorder(),
      ),
      // For dashed border we use foregroundDecoration
      foregroundDecoration: _isLinked
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isInvited
                    ? MintColors.warning.withAlpha(100)
                    : MintColors.info.withAlpha(100),
                style: BorderStyle.solid,
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            _buildHeader(),
            const SizedBox(height: 12),

            // Status message
            _buildStatusMessage(),
            const SizedBox(height: 12),

            // CTAs
            _buildActions(),

            // Régime matrimonial footer
            const Divider(height: 24),
            _buildRegimeFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isLinked
                ? MintColors.success.withAlpha(20)
                : MintColors.info.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.people_outline,
            size: 20,
            color: _isLinked ? MintColors.success : MintColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _isLinked
                ? 'Profils liés'
                : 'Profil conjoint·e',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage() {
    final String message;
    final Color bgColor;

    switch (invitationLevel) {
      case 'declared':
        message =
            '$conjointFirstName n\'a pas de compte MINT. '
            'Ses données sont estimées (\u{1F7E1}).';
        bgColor = MintColors.warning.withAlpha(15);
      case 'invited':
        message =
            'Invitation envoyée à $conjointFirstName. '
            'En attente de réponse.';
        bgColor = MintColors.info.withAlpha(15);
      case 'linked':
        message =
            '\u2705 Profils liés ! Les données de $conjointFirstName '
            'sont synchronisées.';
        bgColor = MintColors.success.withAlpha(15);
      default:
        message = '';
        bgColor = Colors.transparent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 12,
          height: 1.4,
          color: MintColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildActions() {
    switch (invitationLevel) {
      case 'declared':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _actionButton(
              label: 'Inviter $conjointFirstName (5 questions, sans compte)',
              onTap: onInvite,
              isPrimary: true,
            ),
            const SizedBox(height: 8),
            _actionButton(
              label: 'Lier nos profils',
              onTap: onLink,
              isPrimary: false,
            ),
          ],
        );
      case 'invited':
        return _actionButton(
          label: 'Renvoyer l\'invitation',
          onTap: onInvite,
          isPrimary: true,
        );
      case 'linked':
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _actionButton({
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: MintColors.info,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.info,
          side: const BorderSide(color: MintColors.info),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildRegimeFooter() {
    final regimeLabel =
        _regimeLabels[regimeMatrimonial] ?? regimeMatrimonial;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: 'Régime matrimonial : ',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textMuted,
                  ),
                ),
                TextSpan(text: '$regimeLabel (défaut CC art. 196)'),
              ],
            ),
          ),
        ),
        if (onChangeRegime != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChangeRegime,
            child: Text(
              'modifier',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MintColors.info,
                decoration: TextDecoration.underline,
                decorationColor: MintColors.info,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Creates a border decoration.
  /// Note: Flutter does not natively support dashed borders without
  /// CustomPainter. We use a dotted-style solid border with reduced
  /// opacity to suggest an incomplete/pending state.
  Border _dashedBorder() {
    return Border.all(color: Colors.transparent);
  }
}
