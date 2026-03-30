import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/open_banking_service.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
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
                      S.of(context)!.consentActiveSection, Icons.privacy_tip_outlined),
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
      ))),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
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
        S.of(context)!.openBankingConsents,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ── FINMA Gate Banner ──────────────────────────────────────

  Widget _buildFinmaGateBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.disclaimerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.amberWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: MintColors.amberDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.consentFinmaTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.amberDark).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.consentFinmaDesc,
                  style: MintTextStyles.bodySmall(color: MintColors.amberDark),
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
          color: MintColors.neutralBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MintColors.neutralBg),
        ),
        child: Text(
          S.of(context)!.consentModeDemo,
          style: MintTextStyles.labelSmall(color: MintColors.blueDark).copyWith(
            fontWeight: FontWeight.w700,
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
          style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ── Consent Card ───────────────────────────────────────────

  Widget _buildConsentCard(int index, BankingConsent consent) {
    final statusConfig = _getStatusConfig(consent.statusKey);

    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 16,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: bank name + status
          Row(
            children: [
              Expanded(
                child: Text(
                  consent.bankName,
                  style: MintTextStyles.titleMedium(),
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
                      style: MintTextStyles.labelSmall(color: statusConfig.color).copyWith(
                        fontWeight: FontWeight.w600,
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
            S.of(context)!.consentAutorisations,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
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
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Dates
          Row(
            children: [
              Text(
                S.of(context)!.consentGrantedAtLabel(_formatDate(consent.grantedAt)),
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
              const SizedBox(width: MintSpacing.md),
              Text(
                S.of(context)!.consentExpiresAtLabel(_formatDate(consent.expiresAt)),
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
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
                label: Text(S.of(context)!.openBankingConsentRevoke),
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
                    S.of(context)!.consentRevokedLabel,
                    style: MintTextStyles.bodySmall(color: MintColors.error),
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
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.accentPastel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: MintColors.tealLight, size: 20),
              const SizedBox(width: 10),
              Text(
                S.of(context)!.consentNlpdTitle,
                style: MintTextStyles.labelLarge(color: MintColors.tealDark).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            S.of(context)!.consentNlpdSubtitle,
            style: MintTextStyles.bodySmall(color: MintColors.tealLight),
          ),
          const SizedBox(height: 10),
          _buildNlpdPoint(S.of(context)!.consentNlpdPoint1),
          _buildNlpdPoint(S.of(context)!.consentNlpdPoint2),
          _buildNlpdPoint(S.of(context)!.consentNlpdPoint3),
          _buildNlpdPoint(S.of(context)!.consentNlpdPoint4),
        ],
      ),
    );
  }

  Widget _buildNlpdPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: MintTextStyles.bodySmall(color: MintColors.tealDark),
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
        label: Text(S.of(context)!.openBankingAddConsent),
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
              color: MintColors.neutralBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MintColors.neutralBg),
            ),
            child: Text(
              S.of(context)!.consentModeDemo,
              style: MintTextStyles.labelSmall(color: MintColors.blueDark).copyWith(
                fontWeight: FontWeight.w700,
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
              S.of(context)!.consentAnnuler,
              style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final steps = [S.of(context)!.consentStepBanque, S.of(context)!.consentStepAutorisations, S.of(context)!.consentStepConfirmation];
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
                          ? const Icon(Icons.check, color: MintColors.white, size: 14)
                          : Text(
                              '${i + 1}',
                              style: MintTextStyles.bodySmall(
                                color: isActive ? MintColors.white : MintColors.textMuted,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  if (i < steps.length - 1) Expanded(child: Container(height: 2, color: isDone ? MintColors.success : MintColors.border)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps[i],
                style: MintTextStyles.micro(
                  color: isActive ? MintColors.textPrimary : MintColors.textMuted,
                ).copyWith(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.consentSelectBankTitle,
            style: MintTextStyles.titleMedium(),
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
    return Semantics(
      label: S.of(context)!.consentSelectedBankLabel(bank['name'] ?? ''),
      button: true,
      child: InkWell(
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
            color: isSelected ? MintColors.primary : MintColors.transparent,
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
                  style: MintTextStyles.bodySmall(
                    color: isSelected ? MintColors.primary : MintColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w700),
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
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'SWIFT: ${bank['swift']}',
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted),
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
    ),
    );
  }

  // ── Step 2: Select Scopes ──────────────────────────────────

  Widget _buildStepSelectScopes() {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintEntrance(child: Text(
            S.of(context)!.consentSelectScopesTitle,
            style: MintTextStyles.titleMedium(),
          )),
          const SizedBox(height: MintSpacing.xs),
          MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
            S.of(context)!.consentSelectedBankLabel(_selectedBankName ?? ''),
            style: MintTextStyles.bodySmall(),
          )),
          const SizedBox(height: 16),

          // Checkboxes — NOT pre-checked (nLPD compliance)
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildScopeCheckbox(
            value: _scopeAccounts,
            label: S.of(context)!.consentScopeAccountsDesc,
            onChanged: (v) => setState(() => _scopeAccounts = v ?? false),
          )),
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildScopeCheckbox(
            value: _scopeBalances,
            label: S.of(context)!.consentScopeBalancesDesc,
            onChanged: (v) => setState(() => _scopeBalances = v ?? false),
          )),
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildScopeCheckbox(
            value: _scopeTransactions,
            label: S.of(context)!.consentScopeTransactionsDesc,
            onChanged: (v) => setState(() => _scopeTransactions = v ?? false),
          )),

          const SizedBox(height: 16),

          // Info
          MintSurface(
            tone: MintSurfaceTone.porcelaine,
            padding: const EdgeInsets.all(12),
            radius: 10,
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: MintColors.textMuted.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of(context)!.consentReadOnlyInfo,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted),
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
                  child: Text(S.of(context)!.openBankingBack),
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
                  child: Text(S.of(context)!.openBankingNext),
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
            activeColor: MintColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Confirm ────────────────────────────────────────

  Widget _buildStepConfirm() {
    final scopes = <String>[];
    if (_scopeAccounts) scopes.add(S.of(context)!.consentScopeComptes);
    if (_scopeBalances) scopes.add(S.of(context)!.consentScopeSoldes);
    if (_scopeTransactions) scopes.add(S.of(context)!.consentScopeTransactions);

    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.consentStepConfirmation,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: 16),

          // Summary
          _buildConfirmRow(S.of(context)!.consentConfirmBanque, _selectedBankName ?? '-'),
          const SizedBox(height: 8),
          _buildConfirmRow(S.of(context)!.consentConfirmAutorisations, scopes.join(', ')),
          const SizedBox(height: 8),
          _buildConfirmRow(S.of(context)!.consentConfirmDuree, S.of(context)!.consentConfirmDureeValue),
          const SizedBox(height: 8),
          _buildConfirmRow(S.of(context)!.consentConfirmAcces, S.of(context)!.consentConfirmAccesValue),

          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.warningBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MintColors.orangeRetroWarm),
            ),
            child: Text(
              S.of(context)!.consentConfirmDisclaimer,
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
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
                  child: Text(S.of(context)!.openBankingBack),
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
                  child: Text(S.of(context)!.openBankingConfirm),
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
          style: MintTextStyles.bodySmall(),
        ),
        Flexible(
          child: Text(
            value,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(
              fontWeight: FontWeight.w600,
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
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.consentDisclaimer,
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  _StatusConfig _getStatusConfig(String statusKey) {
    final l = S.of(context)!;
    switch (statusKey) {
      case 'active':
        return _StatusConfig(label: l.consentStatusActif, color: MintColors.success);
      case 'expiring_soon':
        return _StatusConfig(label: l.consentStatusExpirantBientot, color: MintColors.warning);
      case 'expired':
        return _StatusConfig(label: l.consentStatusExpire, color: MintColors.error);
      case 'revoked':
        return _StatusConfig(label: l.consentStatusRevoque, color: MintColors.error);
      default:
        return _StatusConfig(label: l.consentStatusInconnu, color: MintColors.textMuted);
    }
  }

  String _scopeLabel(String scope) {
    final l = S.of(context)!;
    switch (scope) {
      case 'accounts':
        return l.consentScopeComptes;
      case 'balances':
        return l.consentScopeSoldes;
      case 'transactions':
        return l.consentScopeTransactions;
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
