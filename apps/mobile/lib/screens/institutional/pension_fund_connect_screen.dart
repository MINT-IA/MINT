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

  Future<void> _connect(PensionFund fund) async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      await InstitutionalApiService.connect(fund: fund, authToken: "mock_token");
      HapticFeedback.mediumImpact();
      await _loadConnections();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion impossible pour le moment')), // TODO: i18n
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
        title: Text('Déconnecter la caisse\u00a0?', // TODO: i18n
            style: MintTextStyles.headlineMedium()),
        content: Text(
          'Tes projections reviendront en mode "estimé" au lieu de "certifié".',
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ), // TODO: i18n
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: MintTextStyles.bodyMedium()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter'),
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
                    title: Text('Données certifiées', // TODO: i18n
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
                              'Données certifiées', // TODO: i18n
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
                          headline: 'Import automatique',
                          body: 'Connecte ta caisse de pension pour remplacer '
                              'les estimations par tes données réelles. '
                              'Lecture seule — MINT ne modifie rien.',
                          tone: MintSurfaceTone.porcelaine,
                        ), // TODO: i18n
                      ),
                      const SizedBox(height: MintSpacing.xl),

                      // Section title
                      MintEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: Text('Caisses disponibles', // TODO: i18n
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

    return Semantics(
      label: '${fund.name}, ${isConnected ? "connecté" : "non connecté"}',
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
                        ? 'Synchro ${_formatDate(conn!.lastSync)}'
                        : isError
                            ? 'Reconnexion nécessaire'
                            : 'Disponible',
                    style: MintTextStyles.micro(
                      color: isError
                          ? MintColors.error
                          : MintColors.textMuted,
                    ),
                  ), // TODO: i18n
                ],
              ),
            ),

            // Action
            if (isConnected)
              IconButton(
                icon: const Icon(Icons.link_off_rounded, size: 20),
                color: MintColors.textMuted,
                onPressed: () => _disconnect(fund.id),
                tooltip: 'Déconnecter', // TODO: i18n
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
                child: Text('Connecter', // TODO: i18n
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
              'MINT est un outil éducatif en lecture seule (LSFin art.\u00a03). '
              'Aucune transaction n\u2019est effectuée sur tes comptes. '
              'Tu peux te déconnecter à tout moment.',
              style: MintTextStyles.micro(color: MintColors.textMuted)
                  .copyWith(height: 1.5),
            ), // TODO: i18n
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
