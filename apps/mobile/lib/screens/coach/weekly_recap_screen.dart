import 'package:flutter/material.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/recap/ai_recap_narrator.dart';
import 'package:mint_mobile/services/recap/recap_formatter.dart';
import 'package:mint_mobile/services/recap/weekly_recap_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// ────────────────────────────────────────────────────────────
//  WEEKLY RECAP SCREEN — Sprint S59
// ────────────────────────────────────────────────────────────
//
//  Displays the user's weekly financial recap:
//  budget snapshot, completed actions, confidence progress,
//  highlights, and next-week focus.
//
//  Data source: WeeklyRecapService.generate() → RecapFormatter.format().
//  All strings via AppLocalizations (S).
//
//  No hardcoded colors — MintColors only.
//  No GoogleFonts direct — MintTextStyles only.
//  No Navigator.push — GoRouter only.
//
//  Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  WeeklyRecap? _recap;
  String? _aiNarrative;
  bool _loading = true;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    _loadRecap();
  }

  Future<void> _loadRecap() async {
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorKey = 'recapEmpty';
        });
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // Mark recap as seen so the Monday proactive trigger doesn't re-fire.
      await ProactiveTriggerService.markRecapSeen(prefs);
      final recap = await WeeklyRecapService.generate(
        profile: profile,
        prefs: prefs,
      );
      if (mounted) {
        setState(() {
          _recap = recap;
          _loading = false;
        });
        // Generate AI narrative in background (non-blocking)
        _generateAiNarrative(recap, profile);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorKey = 'recapEmpty';
        });
      }
    }
  }

  Future<void> _generateAiNarrative(WeeklyRecap recap, CoachProfile profile) async {
    try {
      final byok = context.read<ByokProvider>();
      if (!byok.isConfigured || byok.apiKey == null || byok.provider == null) {
        // No LLM configured — use template fallback in narrator
        final narrative = AiRecapNarrator.templateFallback(recap, profile);
        if (mounted && narrative.isNotEmpty) {
          setState(() => _aiNarrative = narrative);
        }
        return;
      }
      final providerEnum = switch (byok.provider!.toLowerCase()) {
        'anthropic' || 'claude' => LlmProvider.anthropic,
        'mistral' => LlmProvider.mistral,
        _ => LlmProvider.openai,
      };
      final config = LlmConfig(
        apiKey: byok.apiKey!,
        provider: providerEnum,
      );
      final narrative = await AiRecapNarrator.narrate(
        recap: recap,
        profile: profile,
        config: config,
      );
      if (mounted && narrative.isNotEmpty) {
        setState(() => _aiNarrative = narrative);
      }
    } catch (_) {
      // AI narrative is optional — template sections always shown
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: MintColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          l.recapTitle,
          style: MintTextStyles.headlineMedium(),
        ),
        centerTitle: false,
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: _loading
          ? const MintLoadingSkeleton()
          : _errorKey != null
              ? _buildEmpty(l)
              : _buildContent(l))),
    );
  }

  // ── Empty / error state ─────────────────────────────────

  Widget _buildEmpty(S l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: MintColors.textMuted,
            ),
            const SizedBox(height: MintSpacing.md),
            MintEntrance(child: Text(
              l.recapEmpty,
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
              textAlign: TextAlign.center,
            )),
          ],
        ),
      ),
    );
  }

  // ── Main content ────────────────────────────────────────

  Widget _buildContent(S l) {
    final recap = _recap!;
    final sections = RecapFormatter.format(recap, l);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.lg,
        vertical: MintSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period header ──────────────────────────────
          _buildPeriodHeader(recap, l),
          const SizedBox(height: MintSpacing.xl),

          // ── Budget hero number ─────────────────────────
          if (recap.budget != null) ...[
            _buildBudgetHero(recap.budget!, l),
            const SizedBox(height: MintSpacing.xl),
          ],

          // ── AI Narrative (when available) ──────────────
          if (_aiNarrative != null) ...[
            MintSurface(
              padding: const EdgeInsets.all(MintSpacing.md + 4),
              radius: 16,
              elevated: true,
              child: Text(
                _aiNarrative!,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textPrimary,
                ).copyWith(height: 1.6),
              ),
            ),
            const SizedBox(height: MintSpacing.xl),
          ],

          // ── Sections ──────────────────────────────────
          ...sections.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.md),
                child: _buildSection(section),
              )),

          // ── Disclaimer ────────────────────────────────
          const SizedBox(height: MintSpacing.lg),
          _buildDisclaimer(recap.disclaimer),
          const SizedBox(height: MintSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildPeriodHeader(WeeklyRecap recap, S l) {
    final startLabel = _shortDate(recap.weekStart);
    final endLabel = _shortDate(recap.weekEnd);

    return Text(
      l.recapPeriod(startLabel, endLabel),
      style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
    );
  }

  Widget _buildBudgetHero(RecapBudget budget, S l) {
    final savedFormatted = '${budget.savedAmount.round()} CHF';
    final ratePct = '${(budget.savingsRate * 100).toStringAsFixed(1)}\u00a0%';
    final color = budget.savingsRate >= 0.20
        ? MintColors.success
        : budget.savingsRate >= 0.05
            ? MintColors.textPrimary
            : MintColors.warning;

    return MintHeroNumber(
      value: savedFormatted,
      caption: '${l.recapBudgetSaved} · ${l.recapBudgetRate}\u00a0: $ratePct',
      color: color,
      semanticsLabel: '${l.recapBudgetSaved}: $savedFormatted',
    );
  }

  Widget _buildSection(RecapSection section) {
    final tone = _toneForType(section.type);

    return MintSurface(
      tone: tone,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: MintTextStyles.titleMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            section.content,
            style: MintTextStyles.bodyMedium(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Text(
      disclaimer,
      style: MintTextStyles.bodySmall(color: MintColors.textMuted),
      textAlign: TextAlign.center,
    );
  }

  // ── Helpers ─────────────────────────────────────────────

  MintSurfaceTone _toneForType(RecapSectionType type) {
    return switch (type) {
      RecapSectionType.budget => MintSurfaceTone.bleu,
      RecapSectionType.actions => MintSurfaceTone.sauge,
      RecapSectionType.progress => MintSurfaceTone.peche,
      RecapSectionType.highlights => MintSurfaceTone.porcelaine,
      RecapSectionType.nextFocus => MintSurfaceTone.craie,
    };
  }

  String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}';
  }
}
