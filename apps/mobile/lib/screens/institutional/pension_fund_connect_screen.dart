/// Pension Fund Connect Screen — institutional API connection.
///
/// Design: Neo-sober, trust-building. The user is connecting their
/// most sensitive financial data — the tone must be reassuring,
/// the process transparent, and the read-only posture unmistakable.
///
/// Hero: warm gradient with shield icon → trust signal.
/// Cards: each fund with connection status, last sync, one-tap connect.
/// Footer: disclaimer (read-only, no money movement, disconnect anytime).
///
/// Sprint S69-S70 — Phase 4 "La Référence"
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/institutional/institutional_api_service.dart';
import 'package:mint_mobile/services/institutional/pension_fund_registry.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class PensionFundConnectScreen extends StatefulWidget {
  const PensionFundConnectScreen({super.key});

  @override
  State<PensionFundConnectScreen> createState() => _PensionFundConnectScreenState();
}

class _PensionFundConnectScreenState extends State<PensionFundConnectScreen> {
  
  List<PensionFundConnection> _connections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final connections = await InstitutionalApiService.listConnections();
    if (mounted) setState(() { _connections = connections; _loading = false; });
  }

  // FIX-128: Institutional API not yet live — show "coming soon" instead of
  // fake connection with mock_token. Will be wired when pilot agreements signed.
  static const _isApiLive = false;

  Future<void> _connect(PensionFund fund) async {
    if (!_isApiLive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bientôt disponible — en attente des accords pilotes')), // TODO: i18n
        );
      }
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      await InstitutionalApiService.connect(fund: fund, authToken: token);
      HapticFeedback.mediumImpact();
      await _loadConnections();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.pensionFundConnectionError)),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _disconnect(PensionFund fund) async {
    // FIX-123: Confirm before disconnecting — sensitive action.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.of(context)!.pensionFundDisconnectTitle,
            style: MintTextStyles.headlineMedium()),
        content: Text(
          S.of(context)!.pensionFundDisconnectBody,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context)!.commonCancel, style: MintTextStyles.bodyMedium()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context)!.pensionFundDisconnectButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await InstitutionalApiService.disconnect(fund: fund);
    await _loadConnections();
  }

  PensionFundConnection? _connectionFor(PensionFund fund) =>
      _connections.where((c) => c.fund == fund).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final activeFunds = PensionFundRegistry.getActive();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Hero: trust gradient ──────────────────────────
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(S.of(context)!.pensionFundTitle,
                        style: MintTextStyles.titleMedium(
                            color: MintColors.white)),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            MintColors.primary.withAlpha(230),
                            MintColors.primary,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 40),
                            Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                color: MintColors.white.withAlpha(26),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(Icons.verified_user_outlined,
                                  color: MintColors.white.withAlpha(138), size: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              S.of(context)!.pensionFundTitle,
                              style: MintTextStyles.bodySmall(
                                  color: MintColors.white.withAlpha(153)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Content ──────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.all(MintSpacing.xl),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Narrative intro
                      MintEntrance(
                        child: MintNarrativeCard(
                          headline: S.of(context)!.pensionFundNarrativeHeadline,
                          body: S.of(context)!.pensionFundNarrativeBody,
                          tone: MintSurfaceTone.porcelaine,
                        ),
                      ),
                      const SizedBox(height: MintSpacing.xl),

                      // Section title
                      MintEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: Text(S.of(context)!.pensionFundAvailableTitle,
                            style: MintTextStyles.headlineMedium()),
                      ),
                      const SizedBox(height: MintSpacing.md),

                      // Fund cards — staggered
                      ...activeFunds.asMap().entries.map((e) {
                        final delay = Duration(milliseconds: 200 + e.key * 150);
                        return MintEntrance(
                          delay: delay,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                bottom: MintSpacing.sm + 2),
                            child: _buildFundCard(
                              e.value,
                              _connectionFor(e.value.id),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: MintSpacing.xl * 2),

                      // Disclaimer
                      MintEntrance(
                        delay: Duration(
                            milliseconds: 200 + activeFunds.length * 150 + 100),
                        child: _buildDisclaimer(),
                      ),
                      const SizedBox(height: MintSpacing.xl),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFundCard(PensionFundInfo fund, PensionFundConnection? conn) {
    final isConnected = conn?.status == ConnectionStatus.connected;
    final isError = conn?.status == ConnectionStatus.error ||
        conn?.status == ConnectionStatus.expired;

    final l = S.of(context)!;
    return Semantics(
      label: isConnected
          ? l.pensionFundConnectedStatus(fund.name)
          : l.pensionFundDisconnectedStatus(fund.name),
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        radius: 16,
        elevated: isConnected,
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isConnected
                    ? MintColors.success.withAlpha(15)
                    : isError
                        ? MintColors.error.withAlpha(15)
                        : MintColors.surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isConnected
                    ? Icons.check_circle_outline
                    : isError
                        ? Icons.error_outline
                        : Icons.account_balance_outlined,
                color: isConnected
                    ? MintColors.success
                    : isError
                        ? MintColors.error
                        : MintColors.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(width: MintSpacing.md),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fund.name,
                      style: MintTextStyles.bodyMedium()
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    isConnected
                        ? l.pensionFundSyncDate(_formatDate(conn!.lastSync))
                        : isError
                            ? l.pensionFundReconnectionNeeded
                            : l.pensionFundAvailable,
                    style: MintTextStyles.micro(
                      color: isError
                          ? MintColors.error
                          : MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Action
            if (isConnected)
              IconButton(
                icon: const Icon(Icons.link_off_rounded, size: 20),
                color: MintColors.textMuted,
                onPressed: () => _disconnect(fund.id),
                tooltip: l.pensionFundDisconnectTooltip,
              )
            else
              FilledButton(
                onPressed: () => _connect(fund.id),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.md + 4, vertical: MintSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l.pensionFundConnectButton,
                    style: MintTextStyles.bodySmall(color: MintColors.white)
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 14,
      tone: MintSurfaceTone.porcelaine,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined,
              color: MintColors.textMuted, size: 18),
          const SizedBox(width: MintSpacing.sm + 2),
          Expanded(
            child: Text(
              S.of(context)!.pensionFundDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '\u2014';
    // FIX-125: Pad both day and month.
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
