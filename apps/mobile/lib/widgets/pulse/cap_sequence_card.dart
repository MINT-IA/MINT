import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────────
//  CAP SEQUENCE CARD
// ────────────────────────────────────────────────────────────────
//
//  Displays a CapSequence as a compact, scannable progress card
//  in the Pulse (Aujourd'hui) screen.
//
//  Layout:
//    ┌──────────────────────────────────────┐
//    │  N/M étapes clarifiées  ▓▓▓▓░░░░░░  │
//    │  ──────────────────────────────────  │
//    │  ✓ Étape 1 — Salaire brut            │
//    │  ▶ Étape 2 — Rente AVS  [Voir]       │  ← current (CTA)
//    │  ○ Étape 3 — Avoir LPP               │
//    │  ○ ...                               │
//    └──────────────────────────────────────┘
//
//  Shows at most [_kMaxVisibleSteps] steps to avoid cognitive overload.
//  The current step always visible; completed collapsed by default.
//
//  UX rules:
//  - No more than 4 steps visible at once (Hick's law)
//  - Current step has the only CTA
//  - Completed steps shown as faded rows (proof of progress)
//  - Blocked steps shown with lock icon
// ────────────────────────────────────────────────────────────────

const int _kMaxVisibleSteps = 4;

class CapSequenceCard extends StatelessWidget {
  final CapSequence sequence;

  const CapSequenceCard({
    super.key,
    required this.sequence,
  });

  @override
  Widget build(BuildContext context) {
    if (!sequence.hasSteps) return const SizedBox.shrink();

    final l = S.of(context)!;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      elevated: false,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: progress label + bar ──
          _buildHeader(context, l),

          if (sequence.isComplete) ...[
            const SizedBox(height: MintSpacing.sm),
            _buildCompleteRow(l),
          ] else ...[
            const SizedBox(height: MintSpacing.md),
            // ── Step rows ──
            ..._visibleSteps(sequence.steps).map(
              (step) => _StepRow(
                step: step,
                titleKey: step.titleKey,
                onTap: step.status == CapStepStatus.current &&
                        step.intentTag != null
                    ? () => context.go(step.intentTag!)
                    : null,
                l: l,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, S l) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l.capSequenceProgress(
              sequence.completedCount,
              sequence.totalCount,
            ),
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
        ),
        const SizedBox(width: MintSpacing.sm),
        SizedBox(
          width: 80,
          child: _ProgressBar(progress: sequence.progressPercent),
        ),
      ],
    );
  }

  // ── COMPLETE ROW ────────────────────────────────────────────

  Widget _buildCompleteRow(S l) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: MintColors.success,
        ),
        const SizedBox(width: MintSpacing.xs),
        Text(
          l.capSequenceComplete,
          style: MintTextStyles.bodyMedium(color: MintColors.success),
        ),
      ],
    );
  }

  // ── VISIBLE STEP SELECTION ──────────────────────────────────

  /// Pick at most [_kMaxVisibleSteps] steps to show.
  ///
  /// Strategy:
  /// 1. Always include the current step.
  /// 2. Show the 1 most recent completed step (proof of progress).
  /// 3. Fill remaining slots with upcoming steps.
  List<CapStep> _visibleSteps(List<CapStep> allSteps) {
    if (allSteps.isEmpty) return [];

    final completed =
        allSteps.where((s) => s.status == CapStepStatus.completed).toList();
    final current =
        allSteps.where((s) => s.status == CapStepStatus.current).toList();
    final upcoming =
        allSteps.where((s) => s.status == CapStepStatus.upcoming).toList();
    final blocked =
        allSteps.where((s) => s.status == CapStepStatus.blocked).toList();

    final visible = <CapStep>[];

    // Last completed (max 1) — proof of progress
    if (completed.isNotEmpty) {
      visible.add(completed.last);
    }

    // Current step(s) — always shown
    visible.addAll(current);

    // Fill with upcoming, then blocked
    final remaining = _kMaxVisibleSteps - visible.length;
    if (remaining > 0) {
      visible.addAll(upcoming.take(remaining));
    }
    final remaining2 = _kMaxVisibleSteps - visible.length;
    if (remaining2 > 0 && upcoming.length < remaining) {
      visible.addAll(blocked.take(remaining2));
    }

    // Sort by order for display
    visible.sort((a, b) => a.order.compareTo(b.order));

    return visible.take(_kMaxVisibleSteps).toList();
  }
}

// ════════════════════════════════════════════════════════════════
//  STEP ROW
// ════════════════════════════════════════════════════════════════

/// A single step row inside the CapSequenceCard.
class _StepRow extends StatelessWidget {
  final CapStep step;
  final String titleKey;
  final VoidCallback? onTap;
  final S l;

  const _StepRow({
    required this.step,
    required this.titleKey,
    required this.l,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = step.status == CapStepStatus.current;
    final isCompleted = step.status == CapStepStatus.completed;
    final isBlocked = step.status == CapStepStatus.blocked;

    final titleText = _resolveTitle(l, titleKey);
    final textColor = isCompleted
        ? MintColors.textMuted
        : isBlocked
            ? MintColors.textMuted.withValues(alpha: 0.5)
            : MintColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status icon
          _StatusIcon(status: step.status),
          const SizedBox(width: MintSpacing.sm),

          // Step title
          Expanded(
            child: Text(
              titleText,
              style: isCurrent
                  ? MintTextStyles.titleMedium(color: textColor)
                  : MintTextStyles.bodyMedium(color: textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // CTA for current step
          if (isCurrent && onTap != null) ...[
            const SizedBox(width: MintSpacing.xs),
            _CtaChip(onTap: onTap!, l: l),
          ],
        ],
      ),
    );
  }

  /// Resolve ARB key to translated string.
  ///
  /// Uses a switch on the key string so the widget is fully i18n-pure
  /// without requiring BuildContext in the engine.
  String _resolveTitle(S l, String key) {
    return switch (key) {
      'capStepRetirement01Title' => l.capStepRetirement01Title,
      'capStepRetirement02Title' => l.capStepRetirement02Title,
      'capStepRetirement03Title' => l.capStepRetirement03Title,
      'capStepRetirement04Title' => l.capStepRetirement04Title,
      'capStepRetirement05Title' => l.capStepRetirement05Title,
      'capStepRetirement06Title' => l.capStepRetirement06Title,
      'capStepRetirement07Title' => l.capStepRetirement07Title,
      'capStepRetirement08Title' => l.capStepRetirement08Title,
      'capStepRetirement09Title' => l.capStepRetirement09Title,
      'capStepRetirement10Title' => l.capStepRetirement10Title,
      'capStepBudget01Title' => l.capStepBudget01Title,
      'capStepBudget02Title' => l.capStepBudget02Title,
      'capStepBudget03Title' => l.capStepBudget03Title,
      'capStepBudget04Title' => l.capStepBudget04Title,
      'capStepBudget05Title' => l.capStepBudget05Title,
      'capStepBudget06Title' => l.capStepBudget06Title,
      'capStepHousing01Title' => l.capStepHousing01Title,
      'capStepHousing02Title' => l.capStepHousing02Title,
      'capStepHousing03Title' => l.capStepHousing03Title,
      'capStepHousing04Title' => l.capStepHousing04Title,
      'capStepHousing05Title' => l.capStepHousing05Title,
      'capStepHousing06Title' => l.capStepHousing06Title,
      'capStepHousing07Title' => l.capStepHousing07Title,
      _ => key, // Fallback: show key (should never happen in production)
    };
  }
}

// ════════════════════════════════════════════════════════════════
//  STATUS ICON
// ════════════════════════════════════════════════════════════════

class _StatusIcon extends StatelessWidget {
  final CapStepStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      CapStepStatus.completed => const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: MintColors.success,
        ),
      CapStepStatus.current => Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: MintColors.primary,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 12,
            color: MintColors.white,
          ),
        ),
      CapStepStatus.upcoming => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: MintColors.border,
              width: 1.5,
            ),
          ),
        ),
      CapStepStatus.blocked => const Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: MintColors.textMuted,
        ),
    };
  }
}

// ════════════════════════════════════════════════════════════════
//  CTA CHIP
// ════════════════════════════════════════════════════════════════

class _CtaChip extends StatelessWidget {
  final VoidCallback onTap;
  final S l;

  const _CtaChip({required this.onTap, required this.l});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.sm,
          vertical: MintSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: MintColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          l.capSequenceCurrentStep,
          style: MintTextStyles.labelSmall(color: MintColors.white),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  PROGRESS BAR
// ════════════════════════════════════════════════════════════════

class _ProgressBar extends StatelessWidget {
  final double progress; // 0.0–1.0

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: MintColors.lightBorder,
        valueColor: const AlwaysStoppedAnimation<Color>(MintColors.success),
        minHeight: 6,
      ),
    );
  }
}
