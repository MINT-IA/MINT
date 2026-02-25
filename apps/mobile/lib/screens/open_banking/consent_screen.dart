import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/open_banking_service.dart';

// ────────────────────────────────────────────────────────────
//  CONSENT MANAGEMENT SCREEN — Sprint S14
// ────────────────────────────────────────────────────────────
//
// nLPD-compliant consent management for Open Banking.
// Shows active consents, revocation controls, and new
// consent flow with explicit opt-in checkboxes (never
// pre-checked). Behind FINMA gate.
//
// Compliance: FINMA gate banner, nLPD explicit opt-in,
// read-only, no banned terms, disclaimer.
// ────────────────────────────────────────────────────────────

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  late List<BankingConsent> _consents;
  bool _showNewConsentFlow = false;

  // New consent flow state
  int _newConsentStep = 0; // 0 = select bank, 1 = scopes, 2 = confirm
  String? _selectedBankId;
  String? _selectedBankName;
  bool _scopeAccounts = false; // NOT pre-checked (nLPD compliance)
  bool _scopeBalances = false;
  bool _scopeTransactions = false;

  @override
  void initState() {
    super.initState();
    _consents = OpenBankingService.getMockConsents();
  }

  void _revokeConsent(int index) {
    setState(() {
      _consents[index] = _consents[index].revoke();
    });
  }

  void _startNewConsentFlow() {
    setState(() {
      _showNewConsentFlow = true;
      _newConsentStep = 0;
      _selectedBankId = null;
      _selectedBankName = null;
      _scopeAccounts = false;
      _scopeBalances = false;
      _scopeTransactions = false;
    });
  }

  void _cancelNewConsentFlow() {
    setState(() {
      _showNewConsentFlow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildFinmaGateBanner(),
                const SizedBox(height: 12),
                _buildDemoModeBadge(),
                const SizedBox(height: 20),

                // Active consents
                if (!_showNewConsentFlow) ...[
                  _buildSectionTitle(
                      'CONSENTEMENTS ACTIFS', Icons.privacy_tip_outlined),
                  const SizedBox(height: 12),
                  ..._consents.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildConsentCard(entry.key, entry.value),
                      )),
                  const SizedBox(height: 20),

                  // nLPD info card
                  _buildNlpdInfoCard(),
                  const SizedBox(height: 20),

                  // Add consent button
                  _buildAddConsentButton(),
                ],

                // New consent flow
                if (_showNewConsentFlow) ...[
                  _buildNewConsentFlow(),
                ],

                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () {
          if (_showNewConsentFlow) {
            _cancelNewConsentFlow();
          } else {
            context.pop();
          }
        },
      ),
      title: Text(
        'CONSENTEMENTS',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── FINMA Gate Banner ──────────────────────────────────────

  Widget _buildFinmaGateBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.amber.shade800, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fonctionnalite en preparation',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consultation reglementaire FINMA en cours. '
                  'Les donnees affichees sont des exemples de demonstration.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.amber.shade800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Demo mode badge ──────────────────────────────────────

  Widget _buildDemoModeBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(
          'MODE DEMO',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MintColors.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ── Consent Card ───────────────────────────────────────────

  Widget _buildConsentCard(int index, BankingConsent consent) {
    final statusConfig = _getStatusConfig(consent.statusKey);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: bank name + status
          Row(
            children: [
              Expanded(
                child: Text(
                  consent.bankName,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusConfig.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusConfig.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusConfig.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusConfig.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scopes
          Text(
            'Autorisations',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: consent.scopes.map((scope) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _scopeLabel(scope),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Dates
          Row(
            children: [
              Text(
                'Accorde le ${_formatDate(consent.grantedAt)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Expire le ${_formatDate(consent.expiresAt)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Revoke button
          if (consent.isActive)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _revokeConsent(index),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Revoquer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MintColors.error,
                  side: BorderSide(color: MintColors.error.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          if (consent.isRevoked)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: MintColors.error.withValues(alpha: 0.7), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Consentement revoque',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── nLPD Info Card ─────────────────────────────────────────

  Widget _buildNlpdInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: Colors.teal.shade700, size: 20),
              const SizedBox(width: 10),
              Text(
                'Tes droits (nLPD)',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.teal.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tes droits selon la nLPD '
            '(Loi federale sur la protection des donnees) :',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.teal.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildNlpdPoint(
            '\u2022 Tu peux revoquer ton consentement a tout moment',
          ),
          _buildNlpdPoint(
            '\u2022 Tes donnees ne sont jamais partagees avec des tiers',
          ),
          _buildNlpdPoint(
            '\u2022 Acces en lecture seule \u2014 aucune operation financiere',
          ),
          _buildNlpdPoint(
            '\u2022 Duree maximale de consentement : 90 jours (renouvelable)',
          ),
        ],
      ),
    );
  }

  Widget _buildNlpdPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.teal.shade800,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Add Consent Button ─────────────────────────────────────

  Widget _buildAddConsentButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _startNewConsentFlow,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Ajouter un consentement'),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.textPrimary,
          side: const BorderSide(color: MintColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── New Consent Flow ───────────────────────────────────────

  Widget _buildNewConsentFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step indicator
        _buildStepIndicator(),
        const SizedBox(height: 20),

        // Demo badge
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              'MODE DEMO',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_newConsentStep == 0) _buildStepSelectBank(),
        if (_newConsentStep == 1) _buildStepSelectScopes(),
        if (_newConsentStep == 2) _buildStepConfirm(),

        const SizedBox(height: 16),

        // Cancel
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _cancelNewConsentFlow,
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(
                color: MintColors.textMuted,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Banque', 'Autorisations', 'Confirmation'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _newConsentStep;
        final isDone = i < _newConsentStep;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0) Expanded(child: Container(height: 2, color: isDone ? MintColors.success : MintColors.border)),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDone
                          ? MintColors.success
                          : isActive
                              ? MintColors.primary
                              : MintColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : Text(
                              '${i + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Colors.white
                                    : MintColors.textMuted,
                              ),
                            ),
                    ),
                  ),
                  if (i < steps.length - 1) Expanded(child: Container(height: 2, color: isDone ? MintColors.success : MintColors.border)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps[i],
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? MintColors.textPrimary
                      : MintColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Step 1: Select Bank ────────────────────────────────────

  Widget _buildStepSelectBank() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisir une banque',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...OpenBankingService.supportedBanks.map((bank) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildBankOption(bank),
              )),
        ],
      ),
    );
  }

  Widget _buildBankOption(Map<String, String> bank) {
    final isSelected = _selectedBankId == bank['id'];
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBankId = bank['id'];
          _selectedBankName = bank['name'];
          _newConsentStep = 1;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.05)
              : MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? MintColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Bank initials avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? MintColors.primary.withValues(alpha: 0.1)
                    : MintColors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  OpenBankingService.getBankInitials(bank['name']!),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? MintColors.primary
                        : MintColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank['name']!,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  Text(
                    'SWIFT: ${bank['swift']}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: MintColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Select Scopes ──────────────────────────────────

  Widget _buildStepSelectScopes() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisir les autorisations',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Banque selectionnee : $_selectedBankName',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Checkboxes — NOT pre-checked (nLPD compliance)
          _buildScopeCheckbox(
            value: _scopeAccounts,
            label: 'Comptes (liste de tes comptes)',
            onChanged: (v) => setState(() => _scopeAccounts = v ?? false),
          ),
          _buildScopeCheckbox(
            value: _scopeBalances,
            label: 'Soldes (solde actuel de tes comptes)',
            onChanged: (v) => setState(() => _scopeBalances = v ?? false),
          ),
          _buildScopeCheckbox(
            value: _scopeTransactions,
            label: 'Transactions (historique des mouvements)',
            onChanged: (v) => setState(() => _scopeTransactions = v ?? false),
          ),

          const SizedBox(height: 16),

          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: MintColors.textMuted.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Acces en lecture seule. Aucune operation '
                    'financiere ne peut etre effectuee.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Navigation
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _newConsentStep = 0),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Retour'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (_scopeAccounts ||
                          _scopeBalances ||
                          _scopeTransactions)
                      ? () => setState(() => _newConsentStep = 2)
                      : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Suivant'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeThumbColor: MintColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Confirm ────────────────────────────────────────

  Widget _buildStepConfirm() {
    final scopes = <String>[];
    if (_scopeAccounts) scopes.add('Comptes');
    if (_scopeBalances) scopes.add('Soldes');
    if (_scopeTransactions) scopes.add('Transactions');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirmation',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Summary
          _buildConfirmRow('Banque', _selectedBankName ?? '-'),
          const SizedBox(height: 8),
          _buildConfirmRow('Autorisations', scopes.join(', ')),
          const SizedBox(height: 8),
          _buildConfirmRow('Duree', '90 jours'),
          const SizedBox(height: 8),
          _buildConfirmRow('Acces', 'Lecture seule'),

          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              'En confirmant, tu autorises MINT a acceder aux '
              'donnees selectionnees en lecture seule pour une duree '
              'de 90 jours. Tu peux revoquer ce consentement '
              'a tout moment.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Navigation
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _newConsentStep = 1),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Retour'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    // Add mock consent and go back
                    final now = DateTime.now();
                    final selectedScopes = <String>[];
                    if (_scopeAccounts) selectedScopes.add('accounts');
                    if (_scopeBalances) selectedScopes.add('balances');
                    if (_scopeTransactions) {
                      selectedScopes.add('transactions');
                    }

                    setState(() {
                      _consents.add(BankingConsent(
                        consentId:
                            'consent_demo_${DateTime.now().millisecondsSinceEpoch}',
                        bankId: _selectedBankId!,
                        bankName: _selectedBankName!,
                        scopes: selectedScopes,
                        grantedAt: now,
                        expiresAt: now.add(const Duration(days: 90)),
                      ));
                      _showNewConsentFlow = false;
                    });
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Confirmer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cette fonctionnalite est en cours de developpement. '
              'Les donnees affichees sont des exemples. '
              'L\'activation du service Open Banking est soumise '
              'a une consultation reglementaire prealable.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  _StatusConfig _getStatusConfig(String statusKey) {
    switch (statusKey) {
      case 'active':
        return _StatusConfig(label: 'Actif', color: MintColors.success);
      case 'expiring_soon':
        return _StatusConfig(
            label: 'Expire bientot', color: MintColors.warning);
      case 'expired':
        return _StatusConfig(label: 'Expire', color: MintColors.error);
      case 'revoked':
        return _StatusConfig(label: 'Revoque', color: MintColors.error);
      default:
        return _StatusConfig(label: 'Inconnu', color: MintColors.textMuted);
    }
  }

  String _scopeLabel(String scope) {
    switch (scope) {
      case 'accounts':
        return 'Comptes';
      case 'balances':
        return 'Soldes';
      case 'transactions':
        return 'Transactions';
      default:
        return scope;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _StatusConfig {
  final String label;
  final Color color;

  const _StatusConfig({required this.label, required this.color});
}
