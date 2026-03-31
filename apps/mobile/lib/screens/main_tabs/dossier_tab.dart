import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/models/coaching_preference.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// SharedPreferences key for the last time the user visited the Dossier tab.
const _kLastDossierVisit = 'dossier_last_visit_ts';

/// SharedPreferences key for the snapshot of financial values at last visit.
const _kDossierSnapshot = 'dossier_values_snapshot';

/// Tab 3 — Dossier
///
/// "Mes données, mes documents, mes réglages."
/// Mirror unifié de l'état utilisateur via [MintUserState].
/// Six sections : Identité, Données, Documents, Couple, Plan, Préférences.
///
/// Design: fond porcelaine, sections MintSurface(blanc), espacement xl.
/// Espace personnel calme — pas de couleurs vives, icônes textSecondary.
class DossierTab extends StatefulWidget {
  const DossierTab({super.key});

  @override
  State<DossierTab> createState() => _DossierTabState();
}

class _DossierTabState extends State<DossierTab> {
  /// Previous financial values snapshot for delta computation.
  Map<String, double> _previousValues = {};

  bool _snapshotLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _saveSnapshot();
    super.dispose();
  }

  /// Load previous snapshot + last visit timestamp from SharedPreferences.
  Future<void> _loadSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load previous values snapshot.
      final snapshotJson = prefs.getString(_kDossierSnapshot);
      if (snapshotJson != null) {
        final decoded = json.decode(snapshotJson) as Map<String, dynamic>;
        _previousValues = decoded.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
      }

      if (mounted) setState(() => _snapshotLoaded = true);
    } catch (_) {
      if (mounted) setState(() => _snapshotLoaded = true);
    }
  }

  /// Save current financial values + timestamp on dispose.
  Future<void> _saveSnapshot() async {
    // Capture values synchronously before any await — context may be
    // invalid after await when called from dispose().
    final currentValues = _buildCurrentValues();
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save current timestamp.
      await prefs.setInt(
        _kLastDossierVisit,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (currentValues.isNotEmpty) {
        await prefs.setString(_kDossierSnapshot, json.encode(currentValues));
      }
    } catch (_) {
      // Silent — non-critical.
    }
  }

  /// Build a map of current financial values for snapshot comparison.
  Map<String, double> _buildCurrentValues() {
    MintUserState? mintState;
    try {
      mintState = context.read<MintStateProvider>().state;
    } catch (_) {
      mintState = null;
    }
    CoachProfileProvider? provider;
    try {
      provider = context.read<CoachProfileProvider>();
    } catch (_) {
      provider = null;
    }
    final profile = mintState?.profile ?? provider?.profile;
    final prev = profile?.prevoyance;

    final values = <String, double>{};
    final lpp = prev?.avoirLppTotal;
    if (lpp != null && lpp > 0) values['lpp'] = lpp;
    final total3a = prev?.totalEpargne3a ?? 0.0;
    if (total3a > 0) values['3a'] = total3a;
    final patrimoine = profile?.patrimoine.totalPatrimoine;
    if (patrimoine != null && patrimoine > 0) values['patrimoine'] = patrimoine;
    final monthlyFree = mintState?.monthlyFree;
    if (monthlyFree != null) values['marge'] = monthlyFree;
    return values;
  }

  void _showSettingsSheet(BuildContext context, S l) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MintColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
              Text(
                l.dossierSettingsTitle,
                style: MintTextStyles.headlineMedium(),
              ),
              const SizedBox(height: MintSpacing.lg),
              MintSurface(
                tone: MintSurfaceTone.blanc,
                padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
                child: Column(
                  children: [
                    _DossierRow(
                      icon: Icons.smart_toy_outlined,
                      title: l.dossierSlmTitle,
                      subtitle: l.dossierSlmSubtitle,
                      onTap: () {
                        Navigator.of(context).pop();
                        this.context.push('/profile/slm');
                      },
                    ),
                    _DossierRow(
                      icon: Icons.vpn_key_outlined,
                      title: l.dossierByokTitle,
                      subtitle: l.dossierByokSubtitle,
                      onTap: () {
                        Navigator.of(context).pop();
                        this.context.push('/profile/byok');
                      },
                    ),
                    _DossierRow(
                      icon: Icons.verified_user_outlined,
                      title: l.dossierConsentsTitle,
                      subtitle: l.dossierConsentsSubtitle,
                      onTap: () {
                        Navigator.of(context).pop();
                        this.context.push('/profile/consent');
                      },
                    ),
                    _DossierRow(
                      icon: Icons.tune_outlined,
                      title: l.dossierCoachingTitle,
                      subtitle: l.dossierCoachingSubtitle,
                      onTap: () {
                        Navigator.of(context).pop();
                        _showCoachingPreferenceSheet(this.context, l);
                      },
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  void _showCoachingPreferenceSheet(BuildContext context, S l) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CoachingPreferenceSheet(l: l),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    // Graceful: tests without MintStateProvider in tree won't crash.
    MintUserState? mintState;
    try {
      mintState = context.watch<MintStateProvider>().state;
    } catch (_) {
      mintState = null;
    }
    final provider = context.watch<CoachProfileProvider>();

    // Derived from MintUserState when available; fall back to CoachProfileProvider.
    final firstName = mintState?.profile.firstName
        ?? (provider.hasProfile ? (provider.profile!.firstName ?? '') : '');
    final profile = mintState?.profile ?? provider.profile;

    // Confidence score: prefer pre-computed from MintUserState, fall back to
    // real EnhancedConfidence (4-axis) when MintUserState not available.
    EnhancedConfidence? enhancedConf;
    double rawConfidence = mintState?.confidenceScore ?? 0.0;
    if (profile != null) {
      try {
        enhancedConf = ConfidenceScorer.scoreEnhanced(profile);
        // Use real combined score if MintUserState didn't pre-compute one.
        if (mintState?.confidenceScore == null || mintState!.confidenceScore == 0.0) {
          rawConfidence = enhancedConf.combined / 100.0;
        }
      } catch (_) {
        enhancedConf = null;
      }
    }
    final confidencePct = (rawConfidence * 100).round().clamp(0, 100);
    final enrichmentPrompts = enhancedConf?.axisPrompts ?? const [];

    final isCouple = profile?.isCouple ?? false;
    // Determine if enough data exists for expert section.
    final hasEnoughDataForExpert = confidencePct >= 40;

    // Timestamps for section freshness display.
    final timestamps = profile?.dataTimestamps ?? const {};

    return ColoredBox(
      color: MintColors.porcelaine,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.porcelaine,
            surfaceTintColor: MintColors.porcelaine,
            elevation: 0,
            title: Semantics(
              header: true,
              child: Text(
                l.tabDossier,
                style: MintTextStyles.headlineMedium(
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: MintColors.textSecondary,
                  size: 22,
                ),
                onPressed: () => _showSettingsSheet(context, l),
                tooltip: l.dossierSettingsTitle,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ═══════════════════════════════════════
                //  Section 1 — Identité
                // ═══════════════════════════════════════
                MintEntrance(child: _SectionLabel(
                  l.dossierIdentiteSection,
                  timestamp: _mostRecentTimestamp(timestamps, [
                    'firstName', 'birthYear', 'canton', 'nationality',
                    'etatCivil',
                  ]),
                  l: l,
                )),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _ProfileSection(
                  mintState: mintState,
                  provider: provider,
                  enrichmentPrompts: enrichmentPrompts,
                  firstName: firstName,
                  confidencePct: confidencePct,
                  l: l,
                )),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Section 2 — Données
                // ═══════════════════════════════════════
                MintEntrance(delay: const Duration(milliseconds: 200), child: _SectionLabel(
                  l.dossierDataSection,
                  timestamp: _mostRecentTimestamp(timestamps, [
                    'salaireBrutMensuel', 'prevoyance.avoirLppTotal',
                    'prevoyance.totalEpargne3a', 'depenses.budget',
                  ]),
                  l: l,
                )),
                MintEntrance(delay: const Duration(milliseconds: 300), child: _DataSection(
                  mintState: mintState,
                  provider: provider,
                  l: l,
                  previousValues: _snapshotLoaded ? _previousValues : const {},
                )),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Section 3 — Documents
                // ═══════════════════════════════════════
                MintEntrance(delay: const Duration(milliseconds: 400), child: _SectionLabel(l.dossierDocumentsSection, l: l)),
                MintEntrance(delay: const Duration(milliseconds: 500), child: _DocumentsSection(l: l)),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Section 4 — Couple (only if isCouple)
                // ═══════════════════════════════════════
                if (isCouple) ...[
                  _SectionLabel(
                    l.dossierCoupleSection,
                    timestamp: _mostRecentTimestamp(timestamps, [
                      'conjoint.firstName', 'conjoint.birthYear',
                      'conjoint.salaireBrutMensuel',
                    ]),
                    l: l,
                  ),
                  _CoupleSection(
                    profile: profile,
                    l: l,
                  ),
                  const SizedBox(height: MintSpacing.xl),
                ],

                // ═══════════════════════════════════════
                //  Section 5 — Plan (CapSequence)
                // ═══════════════════════════════════════
                _SectionLabel(l.dossierPlanSection, l: l),
                _PlanSection(mintState: mintState, l: l),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Section 6 — Expert (only if enough data)
                // ═══════════════════════════════════════
                if (hasEnoughDataForExpert) ...[
                  if (FeatureFlags.enableExpertTier) ...[
                    _SectionLabel(l.dossierExpertSectionTitle, l: l),
                    MintSurface(
                      tone: MintSurfaceTone.blanc,
                      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
                      child: _DossierRow(
                        icon: Icons.person_search_outlined,
                        title: l.dossierExpertSectionTitle,
                        subtitle: l.expertSubtitle,
                        onTap: () => context.push('/expert-tier'),
                        showDivider: false,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Find the most recent timestamp among a set of field paths.
  /// Returns null if none of the fields have timestamps.
  static DateTime? _mostRecentTimestamp(
    Map<String, DateTime> timestamps,
    List<String> fieldPaths,
  ) {
    DateTime? latest;
    for (final path in fieldPaths) {
      final ts = timestamps[path];
      if (ts != null && (latest == null || ts.isAfter(latest))) {
        latest = ts;
      }
    }
    return latest;
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

/// Thin label above each dossier section (e.g. "Identité", "Données").
/// Optionally shows a freshness timestamp below the label.
class _SectionLabel extends StatelessWidget {
  final String text;
  final DateTime? timestamp;
  final S l;

  const _SectionLabel(this.text, {this.timestamp, required this.l});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: MintSpacing.xs,
        bottom: MintSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              text,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
          ),
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatTimestamp(timestamp!, l),
                style: MintTextStyles.labelSmall(
                  color: MintColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Format a timestamp as a relative or absolute date string.
  /// - Today: "Mis à jour aujourd'hui"
  /// - Yesterday: "Mis à jour hier"
  /// - 2–30 days: "Mis à jour il y a X jours"
  /// - > 30 days: "Mis à jour le 14 mars"
  static String _formatTimestamp(DateTime ts, S l) {
    final now = DateTime.now();
    final diff = now.difference(ts);

    if (diff.inDays == 0 && now.day == ts.day) {
      return l.dossierUpdatedToday;
    }
    if (diff.inDays == 1 ||
        (diff.inDays == 0 && now.day != ts.day)) {
      return l.dossierUpdatedYesterday;
    }
    if (diff.inDays <= 30) {
      return l.dossierUpdatedAgo(diff.inDays);
    }
    // > 30 days — show absolute date.
    final formatted = DateFormat('d MMMM', 'fr_CH').format(ts);
    return l.dossierUpdatedOn(formatted);
  }
}

// ── Section 1 — Identité ─────────────────────────────────────────────────────

/// Identity card + confidence score with progress bar.
/// Shows "Compléter mon profil" CTA when confidence < 60.
class _ProfileSection extends StatelessWidget {
  final MintUserState? mintState;
  final CoachProfileProvider provider;
  final String firstName;
  final int confidencePct;
  final S l;
  final List<EnrichmentPrompt> enrichmentPrompts;

  const _ProfileSection({
    required this.mintState,
    required this.provider,
    required this.firstName,
    required this.confidencePct,
    required this.l,
    this.enrichmentPrompts = const [],
  });

  /// Derive archetype display label from [FinancialArchetype].
  String _archetypeLabel(FinancialArchetype archetype, S l) {
    return switch (archetype) {
      FinancialArchetype.swissNative => l.archetypeSwissNative,
      FinancialArchetype.expatEu => l.archetypeExpatEu,
      FinancialArchetype.expatNonEu => l.archetypeExpatNonEu,
      FinancialArchetype.expatUs => l.archetypeExpatUs,
      FinancialArchetype.independentWithLpp => l.archetypeIndependentWithLpp,
      FinancialArchetype.independentNoLpp => l.archetypeIndependentNoLpp,
      FinancialArchetype.crossBorder => l.archetypeCrossBorder,
      FinancialArchetype.returningSwiss => l.archetypeReturningSwiss,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = provider.hasProfile || mintState != null;
    final profile = mintState?.profile ?? provider.profile;
    final age = profile?.age;
    final canton = profile?.canton ?? '';
    final archetype = mintState?.archetype ?? profile?.archetype;
    final confidenceLow = confidencePct < 60;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + meta ──
          InkWell(
            onTap: () => context.push('/profile'),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MintColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      firstName.isNotEmpty
                          ? firstName[0].toUpperCase()
                          : '?',
                      style: MintTextStyles.titleMedium(
                        color: MintColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: MintSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName.isNotEmpty ? firstName : l.tabMoi,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (age != null || canton.isNotEmpty)
                        Text(
                          [
                            if (age != null) '$age ans',
                            if (canton.isNotEmpty) canton,
                          ].join(' · '),
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textMuted,
                          ),
                        ),
                      if (archetype != null)
                        Text(
                          _archetypeLabel(archetype, l),
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MintColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),

          const SizedBox(height: MintSpacing.md),
          Divider(height: 1, color: MintColors.textPrimary.withValues(alpha: 0.06)),
          const SizedBox(height: MintSpacing.md),

          // ── Confidence score ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.dossierConfidenceLabel,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
              Text(
                l.dossierConfidencePct(confidencePct),
                style: MintTextStyles.bodyMedium(
                  color: confidencePct >= 60
                      ? MintColors.success
                      : MintColors.warning,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidencePct / 100,
              backgroundColor: MintColors.textPrimary.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                confidencePct >= 60 ? MintColors.success : MintColors.warning,
              ),
              minHeight: 4,
            ),
          ),

          // ── Enrichment prompts (top actions to improve score) ──
          if (enrichmentPrompts.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              l.dossierEnrichmentHint,
              style: MintTextStyles.labelSmall(
                color: MintColors.textMuted,
              ),
            ),
            const SizedBox(height: MintSpacing.xs),
            // Show top 2 enrichment prompts max.
            for (int i = 0; i < enrichmentPrompts.length && i < 2; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: MintColors.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: MintSpacing.xs),
                    Expanded(
                      child: Text(
                        enrichmentPrompts[i].action,
                        style: MintTextStyles.labelSmall(
                          color: MintColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '+${enrichmentPrompts[i].impact}\u00a0%',
                      style: MintTextStyles.labelSmall(
                        color: MintColors.success,
                      ).copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // ── CTA when confidence is low ──
          if (hasProfile && confidenceLow) ...[
            const SizedBox(height: MintSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(l.dossierCompleteCta),
                style: TextButton.styleFrom(
                  foregroundColor: MintColors.primary,
                  textStyle: MintTextStyles.labelSmall(
                    color: MintColors.primary,
                  ).copyWith(fontWeight: FontWeight.w500),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section 2 — Données ──────────────────────────────────────────────────────

/// Shows what MINT knows: revenue, LPP, 3a, monthly margin.
/// Data sourced from [MintUserState] / [CoachProfile] — no service calls.
class _DataSection extends StatelessWidget {
  final MintUserState? mintState;
  final CoachProfileProvider provider;
  final S l;
  final Map<String, double> previousValues;

  const _DataSection({
    required this.mintState,
    required this.provider,
    required this.l,
    required this.previousValues,
  });

  /// Navigate to [route] then trigger a full state recompute on return.
  Future<void> _pushAndRecompute(BuildContext context, String route,
      {Object? extra}) async {
    await context.push(route, extra: extra);
    if (!context.mounted) return;
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile != null) {
      context.read<MintStateProvider>().forceRecompute(profile);
    }
  }

  /// Compute the delta between a current value and its previous snapshot.
  /// Returns null if no previous value exists or if there is no change.
  double? _delta(String key, double? current) {
    if (current == null || current <= 0) return null;
    final prev = previousValues[key];
    if (prev == null) return null;
    final diff = current - prev;
    if (diff.abs() < 1) return null; // ignore sub-CHF changes
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final profile = mintState?.profile ?? provider.profile;
    final prev = profile?.prevoyance;

    // Revenue: formatted range or exact.
    final revenuBrut = profile?.revenuBrutAnnuel;
    final revenuStr = revenuBrut != null && revenuBrut > 0
        ? formatChfWithPrefix(revenuBrut)
        : l.dossierDataUnknown;

    // LPP avoir.
    final lppAvoir = prev?.avoirLppTotal;
    final lppStr = lppAvoir != null && lppAvoir > 0
        ? formatChfWithPrefix(lppAvoir)
        : null;

    // 3a total.
    final total3a = prev?.totalEpargne3a ?? 0.0;
    final str3a = total3a > 0
        ? formatChfWithPrefix(total3a)
        : l.dossierDataUnknown;

    // Monthly free margin from BudgetSnapshot.
    final monthlyFree = mintState?.monthlyFree;
    final budgetStr = monthlyFree != null
        ? formatChfMonthly(monthlyFree)
        : l.dossierDataUnknown;

    // Data source provenance map for badge display.
    final ds = profile?.dataSources ?? const {};

    // Deltas.
    final lppDelta = _delta('lpp', lppAvoir);
    final delta3a = _delta('3a', total3a > 0 ? total3a : null);
    final margeDelta = _delta('marge', monthlyFree);

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Column(
        children: [
          // ── Revenu ──
          _DataRow(
            icon: Icons.work_outline,
            label: l.dossierDataRevenu,
            value: revenuStr,
            source: revenuBrut != null && revenuBrut > 0
                ? ds['salaireBrutMensuel'] ?? ProfileDataSource.estimated
                : null,
            onTap: () => _pushAndRecompute(context, '/data-block/revenu'),
          ),

          // ── LPP ──
          lppStr != null
              ? _DataRow(
                  icon: Icons.account_balance_outlined,
                  label: l.dossierDataLpp,
                  value: lppStr,
                  delta: lppDelta,
                  source: ds['prevoyance.avoirLppTotal'],
                  // Show scan CTA when LPP is known but from estimation (not certificate)
                  cta: (profile?.prevoyance.isLppEstimated ?? false)
                      ? l.dossierScanLppPrecision
                      : null,
                  onTap: () => (profile?.prevoyance.isLppEstimated ?? false)
                      ? _pushAndRecompute(
                          context, '/scan',
                          extra: DocumentType.lppCertificate,
                        )
                      : _pushAndRecompute(context, '/data-block/lpp'),
                )
              : _DataRow(
                  icon: Icons.account_balance_outlined,
                  label: l.dossierDataLpp,
                  value: l.dossierDataUnknown,
                  cta: l.dossierScanLppCta,
                  onTap: () => _pushAndRecompute(
                    context,
                    '/scan',
                    extra: DocumentType.lppCertificate,
                  ),
                ),

          // ── 3a ──
          _DataRow(
            icon: Icons.savings_outlined,
            label: l.dossierData3a,
            value: str3a,
            delta: delta3a,
            source: total3a > 0
                ? ds['prevoyance.totalEpargne3a'] ??
                    ProfileDataSource.estimated
                : null,
            onTap: () => _pushAndRecompute(context, '/data-block/3a'),
          ),

          // ── Budget mensuel ──
          _DataRow(
            icon: Icons.bar_chart_outlined,
            label: l.dossierDataBudget,
            value: budgetStr,
            delta: margeDelta,
            source: monthlyFree != null
                ? ds['depenses.budget'] ?? ProfileDataSource.estimated
                : null,
            onTap: () => _pushAndRecompute(context, '/budget'),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

// ── Section 3 — Documents ────────────────────────────────────────────────────

/// Documents section: scanned certificates, agent-prepared docs.
class _DocumentsSection extends StatelessWidget {
  final S l;

  const _DocumentsSection({required this.l});

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Column(
        children: [
          _DossierRow(
            icon: Icons.folder_outlined,
            title: l.dossierDocumentsTitle,
            subtitle: l.dossierDocumentsSubtitle,
            onTap: () => context.push('/documents'),
          ),
          _DossierRow(
            icon: Icons.receipt_long_outlined,
            title: l.agentFormsTaxCta,
            subtitle: l.agentFormsTaxSubtitle,
            onTap: () =>
                context.push('/coach/chat?prompt=tax_declaration'),
          ),
          _DossierRow(
            icon: Icons.assignment_ind_outlined,
            title: l.agentFormsAvsCta,
            subtitle: l.agentFormsAvsSubtitle,
            onTap: () => context.push('/coach/chat?prompt=avs_extract'),
          ),
          _DossierRow(
            icon: Icons.send_outlined,
            title: l.agentFormsLppCta,
            subtitle: l.agentFormsLppSubtitle,
            onTap: () => context.push('/coach/chat?prompt=lpp_transfer'),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

// ── Section 4 — Couple ───────────────────────────────────────────────────────

/// Couple section: shows conjoint data or CTA to add.
class _CoupleSection extends StatelessWidget {
  final CoachProfile? profile;
  final S l;

  const _CoupleSection({required this.profile, required this.l});

  @override
  Widget build(BuildContext context) {
    final hasConjoint = profile?.conjoint != null;
    final conjoint = profile?.conjoint;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Column(
        children: [
          _DossierRow(
            icon: hasConjoint ? Icons.people_outlined : Icons.person_add_outlined,
            title: hasConjoint
                ? (conjoint?.firstName ?? l.dossierCoupleTitle)
                : l.dossierAddConjointCta,
            subtitle: hasConjoint
                ? l.dossierCoupleSubtitle
                : l.dossierDataUnknown,
            onTap: () => context.push(
              hasConjoint ? '/couple' : '/data-block/compositionMenage',
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

// ── Section 5 — Mon plan ──────────────────────────────────────────────────────

/// CapSequence progress: X/Y étapes, current step, next step, change goal chip.
/// Falls back to "Choisir un objectif" CTA when no goal is selected.
class _PlanSection extends StatelessWidget {
  final MintUserState? mintState;
  final S l;

  const _PlanSection({required this.mintState, required this.l});

  @override
  Widget build(BuildContext context) {
    final plan = mintState?.capSequencePlan;
    final hasGoal = plan != null && plan.hasSteps;

    if (!hasGoal) {
      return MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined,
                size: 20, color: MintColors.textSecondary),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Text(
                l.dossierChooseGoalCta,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/home'),
              style: TextButton.styleFrom(
                foregroundColor: MintColors.primary,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.dossierChooseGoalCta,
                style: MintTextStyles.labelSmall(
                  color: MintColors.primary,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    final currentStep = plan.currentStep;
    final nextStep = plan.nextStep;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Progress header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.dossierPlanProgress(plan.completedCount, plan.totalCount),
                style: MintTextStyles.titleMedium(
                  color: MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              ActionChip(
                label: Text(
                  l.dossierPlanChangeGoal,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondary,
                  ),
                ),
                onPressed: () => context.go('/home'),
                backgroundColor:
                    MintColors.textPrimary.withValues(alpha: 0.05),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.xs,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: plan.progressPercent,
              backgroundColor: MintColors.textPrimary.withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MintColors.primary),
              minHeight: 4,
            ),
          ),

          // ── Current step ──
          if (currentStep != null) ...[
            const SizedBox(height: MintSpacing.md),
            Divider(
                height: 1,
                color: MintColors.textPrimary.withValues(alpha: 0.06)),
            const SizedBox(height: MintSpacing.md),
            _PlanStepRow(
              label: l.dossierPlanCurrentStep,
              stepTitleKey: currentStep.titleKey,
              isActive: true,
              onTap: currentStep.intentTag != null
                  ? () => context.push(currentStep.intentTag!)
                  : null,
            ),
          ],

          // ── Next step ──
          if (nextStep != null) ...[
            const SizedBox(height: MintSpacing.sm),
            _PlanStepRow(
              label: l.dossierPlanNextStep,
              stepTitleKey: nextStep.titleKey,
              isActive: false,
              onTap: null,
            ),
          ],
        ],
      ),
    );
  }
}

/// A single plan step row inside [_PlanSection].
class _PlanStepRow extends StatelessWidget {
  final String label;
  final String stepTitleKey;
  final bool isActive;
  final VoidCallback? onTap;

  const _PlanStepRow({
    required this.label,
    required this.stepTitleKey,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    // Resolve step title from ARB key. The key is stored in the CapStep model.
    // We use a dynamic lookup via the generated AppLocalizations.
    final title = _resolveStepTitle(stepTitleKey, l);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: isActive ? MintColors.primary : MintColors.textMuted,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
                Text(
                  title,
                  style: MintTextStyles.bodySmall(
                    color: isActive
                        ? MintColors.textPrimary
                        : MintColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: MintColors.textMuted,
              size: 16,
            ),
        ],
      ),
    );
  }

  /// Resolve an ARB key stored in a [CapStep.titleKey] to a display string.
  ///
  /// Falls back to the raw key when no match is found (should never happen
  /// in production if ARB files are kept in sync with CapSequenceEngine).
  static String _resolveStepTitle(String key, S l) {
    return switch (key) {
      'capStepRetirement01Title' => l.capStepRetirement01Title,
      'capStepRetirement02Title' => l.capStepRetirement02Title,
      'capStepRetirement03Title' => l.capStepRetirement03Title,
      'capStepRetirement04Title' => l.capStepRetirement04Title,
      'capStepRetirement05Title' => l.capStepRetirement05Title,
      _ => key,
    };
  }
}

// ── Shared widgets ───────────────────────────────────────────────────────────

/// Compact read-only data row for Section 2 — Données.
class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Optional CTA label shown in accent colour instead of [value].
  final String? cta;

  /// Data provenance — drives the source badge (Estimé/Déclaré/Certifié).
  final ProfileDataSource? source;

  /// Delta since last Dossier visit. Positive = gain, negative = loss.
  final double? delta;

  final VoidCallback onTap;
  final bool showDivider;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.cta,
    this.source,
    this.delta,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: MintSpacing.sm,
              horizontal: MintSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: MintColors.textSecondary, size: 18),
                const SizedBox(width: MintSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                cta != null
                    ? Flexible(
                        child: Text(
                          cta!,
                          style: MintTextStyles.labelSmall(
                            color: MintColors.primary,
                          ).copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value,
                            style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary,
                            ).copyWith(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (delta != null) ...[
                            const SizedBox(width: MintSpacing.xs),
                            _DeltaBadge(delta: delta!),
                          ],
                        ],
                      ),
                if (source != null && cta == null) ...[
                  const SizedBox(width: MintSpacing.xs),
                  _SourceBadge(source: source!),
                ],
                const SizedBox(width: MintSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MintColors.textMuted,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
            child: Divider(
              height: 1,
              color: MintColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
      ],
    );
  }
}

/// Delta indicator badge: "+5'377" in green or "-1'200" in red.
class _DeltaBadge extends StatelessWidget {
  final double delta;

  const _DeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isPositive = delta > 0;
    final color = isPositive ? MintColors.success : MintColors.error;
    final prefix = isPositive ? '+' : '';
    final formatted = '$prefix${formatChf(delta)}';

    return Text(
      formatted,
      style: MintTextStyles.labelSmall(color: color),
    );
  }
}

/// Compact provenance badge — shows data source quality at a glance.
///
/// - [estimated] → "Estimé" (warning amber)
/// - [userInput] → "Déclaré" (info blue)
/// - [crossValidated]/[certificate]/[openBanking] → "Certifié" (success green)
class _SourceBadge extends StatelessWidget {
  final ProfileDataSource source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    final String label;
    final Color textColor;
    final Color bgColor;

    switch (source) {
      case ProfileDataSource.estimated:
        label = l.sourceBadgeEstimated;
        textColor = MintColors.warning;
        bgColor = MintColors.warning.withValues(alpha: 0.15);
      case ProfileDataSource.userInput:
        label = l.sourceBadgeDeclared;
        textColor = MintColors.info;
        bgColor = MintColors.info.withValues(alpha: 0.10);
      case ProfileDataSource.crossValidated:
      case ProfileDataSource.certificate:
      case ProfileDataSource.openBanking:
        label = l.sourceBadgeCertified;
        textColor = MintColors.success;
        bgColor = MintColors.success.withValues(alpha: 0.15);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: MintTextStyles.labelSmall(color: textColor),
      ),
    );
  }
}

/// Single row inside a dossier section surface.
/// Uses spacing instead of borders between items.
class _DossierRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _DossierRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MintSpacing.md,
                horizontal: MintSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(icon, color: MintColors.textSecondary, size: 20),
                  const SizedBox(width: MintSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MintTextStyles.labelLarge(
                            color: MintColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MintColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: Divider(
                height: 1,
                color: MintColors.textPrimary.withValues(alpha: 0.05),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
//  Coaching Preference Bottom Sheet — P3.5
// ════════════════════════════════════════════════════════════════════════════════

class _CoachingPreferenceSheet extends StatefulWidget {
  final S l;
  const _CoachingPreferenceSheet({required this.l});

  @override
  State<_CoachingPreferenceSheet> createState() =>
      _CoachingPreferenceSheetState();
}

class _CoachingPreferenceSheetState extends State<_CoachingPreferenceSheet> {
  CoachingPreference _pref = CoachingPreference.balanced;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pref = CoachingPreference.load(prefs);
      _loaded = true;
    });
  }

  Future<void> _save(int newIntensity) async {
    final updated = _pref.withIntensity(newIntensity);
    setState(() => _pref = updated);
    final prefs = await SharedPreferences.getInstance();
    await updated.save(prefs);
  }

  String _intensityLabel(int intensity) {
    switch (intensity) {
      case 1:
        return widget.l.coachingIntensityDiscret;
      case 2:
        return widget.l.coachingIntensityCalme;
      case 3:
        return widget.l.coachingIntensityEquilibre;
      case 4:
        return widget.l.coachingIntensityAttentif;
      case 5:
        return widget.l.coachingIntensityProactif;
      default:
        return widget.l.coachingIntensityEquilibre;
    }
  }

  String _intensityDescription(int intensity) {
    switch (intensity) {
      case 1:
        return widget.l.coachingDescDiscret;
      case 2:
        return widget.l.coachingDescCalme;
      case 3:
        return widget.l.coachingDescEquilibre;
      case 4:
        return widget.l.coachingDescAttentif;
      case 5:
        return widget.l.coachingDescProactif;
      default:
        return widget.l.coachingDescEquilibre;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
        height: 200,
        child: MintLoadingSkeleton(),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.md, MintSpacing.lg, MintSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),

            // Title
            Text(
              widget.l.dossierCoachingTitle,
              style: MintTextStyles.headlineMedium(),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              widget.l.coachingSheetSubtitle,
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.lg),

            // Intensity slider
            MintPremiumSlider(
              label: _intensityLabel(_pref.intensity),
              value: _pref.intensity.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              formatValue: (v) => '${v.round()}/5',
              onChanged: (v) => _save(v.round()),
            ),

            // Labels under slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.l.coachingIntensityDiscret,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondary,
                  ),
                ),
                Text(
                  widget.l.coachingIntensityProactif,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.md),

            // Description
            MintSurface(
              tone: MintSurfaceTone.porcelaine,
              padding: const EdgeInsets.all(MintSpacing.sm + 4),
              radius: 8,
              child: Text(
                _intensityDescription(_pref.intensity),
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textSecondary,
                ),
              ),
            ),

            // Engagement stats (subtle)
            if (_pref.totalGreetingsShown > 0) ...[
              const SizedBox(height: MintSpacing.md),
              Text(
                widget.l.coachingEngagementStats(
                  _pref.totalGreetingsEngaged.toString(),
                  _pref.totalGreetingsShown.toString(),
                ),
                style: MintTextStyles.labelSmall(
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
