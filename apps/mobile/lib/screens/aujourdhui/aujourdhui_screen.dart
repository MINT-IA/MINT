/// AujourdhuiScreen — living timeline home for authenticated users.
///
/// Phase 18: Full Living Timeline. CustomScrollView with:
/// - MINT wordmark (pinned)
/// - 3 tension cards from Phase 17 (sticky summary)
/// - Cleo loop indicator
/// - Month-grouped timeline nodes (SliverList.builder for lazy loading)
/// - Collapsible month headers (current month expanded, past collapsed)
/// - "Charger plus" pagination when 50+ nodes exist
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
// Wave B-minimal B1 (2026-04-18): Cap du jour banner pulls the
// highest-priority CapDecision from MintStateProvider and surfaces it
// above the TensionCards. The provider is kept fresh by the
// ChangeNotifierProxyProvider wired in `app.dart`.
import 'package:mint_mobile/widgets/aujourdhui/cap_du_jour_banner.dart';
import 'package:mint_mobile/widgets/tension/cleo_loop_indicator.dart';
import 'package:mint_mobile/widgets/tension/tension_card_widget.dart';
import 'package:mint_mobile/widgets/timeline/month_header_widget.dart';
import 'package:mint_mobile/widgets/timeline/timeline_node_widget.dart';

class AujourdhuiScreen extends StatefulWidget {
  const AujourdhuiScreen({super.key});

  @override
  State<AujourdhuiScreen> createState() => _AujourdhuiScreenState();
}

class _AujourdhuiScreenState extends State<AujourdhuiScreen> {
  final Set<String> _collapsedMonths = {};
  bool _initialCollapseSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimelineProvider>().refresh();
    });
  }

  /// Set initial collapse state: current month expanded, past collapsed.
  void _ensureInitialCollapse(TimelineProvider provider) {
    if (_initialCollapseSet || provider.months.isEmpty) return;
    _initialCollapseSet = true;
    for (final month in provider.months) {
      if (!month.isCurrentMonth) {
        _collapsedMonths.add('${month.year}-${month.month}');
      }
    }
  }

  bool _isCollapsed(int year, int month) {
    return _collapsedMonths.contains('$year-$month');
  }

  void _toggleMonth(int year, int month) {
    setState(() {
      final key = '$year-$month';
      if (_collapsedMonths.contains(key)) {
        _collapsedMonths.remove(key);
      } else {
        _collapsedMonths.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimelineProvider>();
    final l10n = S.of(context)!;

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: MintColors.warmWhite,
        body: Center(
          child: CircularProgressIndicator(
            color: MintColors.success,
          ),
        ),
      );
    }

    if (provider.isEmpty) {
      return Scaffold(
        backgroundColor: MintColors.warmWhite,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GestureDetector(
                onTap: () => context.go('/coach/chat'),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MintColors.craie,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.tensionEmptyWelcome,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.tensionEmptySubtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: MintColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Set initial collapse state once provider has data.
    _ensureInitialCollapse(provider);

    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── MINT wordmark ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 32),
                child: Center(
                  child: Text(
                    'MINT',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),

            // ── Cap du jour (B1, above tension cards) ──────────
            // Wave B-minimal B1: the single highest-priority CapDecision
            // from MintStateProvider. Watches the proxy provider so the
            // banner refreshes automatically whenever CoachProfile
            // changes (save_fact, scan enrichment, wizard load).
            const SliverToBoxAdapter(
              child: CapDuJourBanner(),
            ),

            // ── Tension cards (Phase 17 header) ────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    TensionCardWidget(card: provider.cards[0]),
                    const SizedBox(height: 12),
                    TensionCardWidget(card: provider.cards[1]),
                    const SizedBox(height: 12),
                    TensionCardWidget(card: provider.cards[2]),
                  ],
                ),
              ),
            ),

            // ── Cleo loop indicator ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: CleoLoopIndicator(position: provider.loopPosition),
                ),
              ),
            ),

            // ── Divider: "Ton histoire" ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: MintColors.textMutedAaa.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n.timelineSectionTitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: MintColors.textMutedAaa,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: MintColors.textMutedAaa.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),

            // ── Timeline months + nodes ────────────────────────
            ...provider.months.expand((month) => [
                  SliverToBoxAdapter(
                    child: MonthHeaderWidget(
                      month: month,
                      isCollapsed: _isCollapsed(month.year, month.month),
                      onToggle: () => _toggleMonth(month.year, month.month),
                    ),
                  ),
                  if (!_isCollapsed(month.year, month.month))
                    SliverList.builder(
                      itemCount: month.nodes.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: TimelineNodeWidget(node: month.nodes[i]),
                      ),
                    ),
                ]),

            // ── "Charger plus" button ──────────────────────────
            if (provider.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: TextButton(
                      onPressed: provider.loadMore,
                      child: Text(
                        l10n.timelineLoadMore,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Empty timeline state ───────────────────────────
            if (!provider.hasNodes)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: MintColors.craie,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.timelineEmpty,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: MintColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

            // ── Bottom padding ─────────────────────────────────
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }
}
