import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/arbitrage_summary_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  ARBITRAGE BILAN SCREEN — S45 Phase 1
// ────────────────────────────────────────────────────────────
//
//  Single scrollable screen showing all arbitrages computed
//  on the user's real data. Each card links to the full
//  arbitrage simulator.
//
//  Aucun terme banni. Ton educatif, tutoiement.
//  Compliance: conditionnel partout, pas de ranking.
// ────────────────────────────────────────────────────────────

class ArbitrageBilanScreen extends StatelessWidget {
  const ArbitrageBilanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile =
        context.watch<CoachProfileProvider>().profile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(S.of(context)!.arbitrageBilanTitle)),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.balance_outlined,
                    size: 48, color: MintColors.textMuted),
                const SizedBox(height: 16),
                MintEntrance(child: Text(
                  S.of(context)!.arbitrageBilanEmptyProfile,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.bodyLarge(),
                )),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 100), child: FilledButton(
                  onPressed: () => context.push('/onboarding/quick'),
                  child: Text(S.of(context)!.reportCommencer),
                )),
              ],
            ),
          ),
        ))),
      );
    }

    final summary = ArbitrageSummaryService.compute(profile);

    return Scaffold(
      backgroundColor: MintColors.white,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          // ── AppBar ──
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MintColors.primary,
                      MintColors.primary.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          S.of(context)!.arbitrageBilanLeviers,
                          style: MintTextStyles.headlineMedium(color: MintColors.white),
                        ),
                        const SizedBox(height: MintSpacing.xs),
                        if (summary.items.isNotEmpty)
                          Text(
                            S.of(context)!.arbitrageBilanPotentiel(formatChfWithPrefix(summary.aggregateMonthlyImpact)),
                            style: MintTextStyles.bodyMedium(color: MintColors.white.withValues(alpha: 0.85)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(
                S.of(context)!.arbitrageBilanTitle,
                style: MintTextStyles.titleMedium(),
              ),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Caveat
                if (summary.items.length > 1)
                  _buildCaveat(context),

                // Computed items
                ...summary.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ArbitrageItemCard(item: item),
                    )),

                // Locked items
                if (summary.lockedItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    S.of(context)!.arbitrageBilanDebloquer,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ...summary.lockedItems.map((locked) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LockedItemCard(locked: locked),
                      )),
                ],

                // Cross-dependencies
                if (summary.items.length >= 2)
                  _buildCrossDependencies(context, summary),

                // Disclaimer
                const SizedBox(height: 16),
                Text(
                  S.of(context)!.arbitrageBilanDisclaimer,
                  style: MintTextStyles.micro(),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  Widget _buildCaveat(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MintColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 16, color: MintColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                S.of(context)!.arbitrageBilanCaveat,
                style: MintTextStyles.bodySmall(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossDependencies(BuildContext context, ArbitrageSummary summary) {
    final hasRenteVsCapital =
        summary.items.any((i) => i.id == 'rente_vs_capital');
    final hasCalendrier =
        summary.items.any((i) => i.id == 'calendrier_retraits');
    final hasRachat = summary.items.any((i) => i.id == 'rachat_vs_marche');

    final notes = <String>[];
    if (hasRenteVsCapital && hasCalendrier) {
      notes.add(S.of(context)!.arbitrageBilanCrossDep1);
    }
    if (hasRachat && hasRenteVsCapital) {
      notes.add(S.of(context)!.arbitrageBilanCrossDep2);
    }

    if (notes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(16),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, size: 16, color: MintColors.info),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.arbitrageBilanLiens,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...notes.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: MintTextStyles.bodySmall()),
                      Expanded(
                        child: Text(
                          note,
                          style: MintTextStyles.bodySmall(),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  ARBITRAGE ITEM CARD — computed result
// ════════════════════════════════════════════════════════════

class _ArbitrageItemCard extends StatelessWidget {
  final ArbitrageSummaryItem item;

  const _ArbitrageItemCard({required this.item});

  static const _iconMap = <String, IconData>{
    'rente_vs_capital': Icons.compare_arrows_rounded,
    'calendrier_retraits': Icons.calendar_month_outlined,
    'rachat_vs_marche': Icons.add_chart_rounded,
    'allocation_annuelle': Icons.pie_chart_outline_rounded,
    'location_vs_propriete': Icons.home_outlined,
  };

  static const _colorMap = <String, Color>{
    'rente_vs_capital': MintColors.purple,
    'calendrier_retraits': MintColors.info,
    'rachat_vs_marche': MintColors.success,
    'allocation_annuelle': MintColors.warning,
    'location_vs_propriete': MintColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[item.id] ?? Icons.balance;
    final color = _colorMap[item.id] ?? MintColors.primary;

    return Semantics(
      label: 'Arbitrage : ${item.title}',
      button: true,
      child: InkWell(
      onTap: () => context.push(item.route),
      borderRadius: BorderRadius.circular(16),
      child: MintSurface(
        padding: const EdgeInsets.all(16),
        radius: 16,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // Confidence
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _confidenceColor(item.confidenceScore)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.confidenceScore.round()}%',
                    style: MintTextStyles.micro(color: _confidenceColor(item.confidenceScore)).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: color.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 12),

            // Verdict
            Text(
              item.verdict,
              style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: MintSpacing.sm),

            // Key insight
            Text(
              item.keyInsight,
              style: MintTextStyles.bodySmall(),
            ),
            const SizedBox(height: MintSpacing.xs),

            // Disclaimer line
            Text(
              S.of(context)!.arbitrageBilanScenario,
              style: MintTextStyles.micro(),
            ),
          ],
        ),
      ),
    ),
    );
  }

  static Color _confidenceColor(double score) {
    if (score >= 70) return MintColors.success;
    if (score >= 40) return MintColors.warning;
    return MintColors.scoreAttention;
  }
}

// ════════════════════════════════════════════════════════════
//  LOCKED ITEM CARD — missing data
// ════════════════════════════════════════════════════════════

class _LockedItemCard extends StatelessWidget {
  final ArbitrageLocked locked;

  const _LockedItemCard({required this.locked});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Débloquer : ${locked.title}',
      button: true,
      child: InkWell(
      onTap: () => context.push(locked.enrichmentRoute),
      borderRadius: BorderRadius.circular(14),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(14),
        radius: 14,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MintColors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline,
                  size: 18, color: MintColors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locked.title,
                    style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    locked.missingDataPrompt,
                    style: MintTextStyles.bodySmall(color: MintColors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline,
                size: 20, color: MintColors.primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    ),
    );
  }
}
