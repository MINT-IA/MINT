import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/providers/household_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';

/// Screen for accepting a household invitation code.
///
/// Provides a 6-character code input field. On success, navigates
/// back to the household screen showing the updated membership.
class AcceptInvitationScreen extends StatefulWidget {
  /// Optional pre-filled code (from deep link).
  final String? initialCode;

  const AcceptInvitationScreen({super.key, this.initialCode});

  @override
  State<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  final _codeController = TextEditingController();
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rejoindre un menage',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        backgroundColor: MintColors.primary,
        foregroundColor: MintColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _accepted
            ? _buildSuccess(context)
            : _buildForm(context, household),
      ),
    );
  }

  Widget _buildForm(BuildContext context, HouseholdProvider household) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Icon(Icons.people, size: 64, color: MintColors.primary),
        const SizedBox(height: 24),
        Text(
          'Entre le code recu de ton/ta partenaire',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Le code est valable 72 heures apres l\'envoi.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
          ),
          decoration: InputDecoration(
            hintText: 'CODE',
            hintStyle: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              letterSpacing: 6,
              color: MintColors.greyBorder,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
          ),
        ),
        if (household.error != null) ...[
          const SizedBox(height: 12),
          Text(
            household.error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.redDeep,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: household.isLoading
              ? null
              : () async {
                  final code = _codeController.text.trim();
                  if (code.isEmpty) return;
                  household.clearError();
                  final success = await household.acceptInvitation(code);
                  if (success && mounted) {
                    setState(() => _accepted = true);
                  }
                },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: household.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MintColors.white,
                  ),
                )
              : Text(
                  'Rejoindre le menage',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MintColors.successBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 72,
              color: MintColors.categoryGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bienvenue dans le menage !',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tu as rejoint le menage Couple+. Tes projections '
            'de retraite sont desormais liees.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/couple'),
            child: const Text('Voir mon menage'),
          ),
        ],
      ),
    );
  }
}
