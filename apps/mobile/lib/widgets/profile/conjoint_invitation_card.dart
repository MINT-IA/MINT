import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
  }) : assert(
         invitationLevel == 'declared' ||
             invitationLevel == 'invited' ||
             invitationLevel == 'linked',
         'invitationLevel must be one of: declared, invited, linked',
       );

  Map<String, String> _regimeLabels(S l) => {
    'participation_acquets': l.conjointRegimeParticipation,
    'separation': l.conjointRegimeSeparation,
    'communaute': l.conjointRegimeCommunaute,
  };

  bool get _isLinked => invitationLevel == 'linked';
  bool get _isInvited => invitationLevel == 'invited';

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isLinked ? MintColors.lightBorder : Colors.transparent,
        ),
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
            _buildHeader(l),
            const SizedBox(height: 12),

            // Status message
            _buildStatusMessage(l),
            const SizedBox(height: 12),

            // CTAs
            _buildActions(l),

            // Régime matrimonial footer
            const Divider(height: 24),
            _buildRegimeFooter(l),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S l) {
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
                ? l.conjointProfilsLies
                : l.conjointProfilConjoint,
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

  Widget _buildStatusMessage(S l) {
    final String message;
    final Color bgColor;

    switch (invitationLevel) {
      case 'declared':
        message = l.conjointDeclaredStatus(conjointFirstName);
        bgColor = MintColors.warning.withAlpha(15);
      case 'invited':
        message = l.conjointInvitedStatus(conjointFirstName);
        bgColor = MintColors.info.withAlpha(15);
      case 'linked':
        message = l.conjointLinkedStatus(conjointFirstName);
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

  Widget _buildActions(S l) {
    switch (invitationLevel) {
      case 'declared':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _actionButton(
              label: l.conjointInviteLabel(conjointFirstName),
              onTap: onInvite,
              isPrimary: true,
            ),
            const SizedBox(height: 8),
            _actionButton(
              label: l.conjointLierProfils,
              onTap: onLink,
              isPrimary: false,
            ),
          ],
        );
      case 'invited':
        return _actionButton(
          label: l.conjointRenvoyerInvitation,
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

  Widget _buildRegimeFooter(S l) {
    final regimeLabel =
        _regimeLabels(l)[regimeMatrimonial] ?? regimeMatrimonial;

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
                  text: l.conjointRegimeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textMuted,
                  ),
                ),
                TextSpan(text: '$regimeLabel ${l.conjointRegimeDefault}'),
              ],
            ),
          ),
        ),
        if (onChangeRegime != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChangeRegime,
            child: Text(
              l.conjointModifier,
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

  /// Valid invitation levels.
  static const validLevels = {'declared', 'invited', 'linked'};
}
