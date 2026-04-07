/// PremierEclairageCard — first-time user insight card (Plan 03-03, D-04).
///
/// Shows the persisted PremierEclairage number, title, subtitle, and a Comprendre
/// CTA derived from [ReportPersistenceService.loadPremierEclairageSnapshot].
///
/// States:
///   - Normal: number + title + subtitle + Comprendre CTA + dismiss
///   - Pedagogical: number in muted color + estimate label + Personnaliser CTA
///   - Error: empty-profile fallback with Personnaliser CTA
///
/// Threat T-03-07: reads only display fields from snapshot (no PII).
/// Threat T-03-08: mandatory [premierEclairageDisclaimer] per CLAUDE.md §6.
library;

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_motion.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Widget that shows the first personalized insight after intent selection.
///
/// Constructor:
///   [onDismiss] — called when the user taps the dismiss "×" icon.
///   [onNavigate] — called with the suggestedRoute when the CTA is tapped.
class PremierEclairageCard extends StatefulWidget {
  final VoidCallback onDismiss;
  final void Function(String route) onNavigate;

  const PremierEclairageCard({
    super.key,
    required this.onDismiss,
    required this.onNavigate,
  });

  @override
  State<PremierEclairageCard> createState() => _PremierEclairageCardState();
}

class _PremierEclairageCardState extends State<PremierEclairageCard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _snapshot;
  bool _loaded = false;

  // Animation controllers
  late final AnimationController _animCtrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: MintMotion.slow,
    );
    _opacity = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    final snapshot = await ReportPersistenceService.loadPremierEclairageSnapshot();
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
        _loaded = true;
      });
      _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final l10n = S.of(context)!;

    if (_snapshot == null) {
      return _buildErrorState(context, l10n);
    }

    final isPedagogical = _snapshot!['confidenceMode'] == 'pedagogical';
    return _buildNormalState(context, l10n, isPedagogical);
  }

  // ── Error state (null snapshot) ─────────────────────────────────────────────

  Widget _buildErrorState(BuildContext context, S l10n) {
    return _CardShell(
      onDismiss: widget.onDismiss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: l10n.premierEclairageCardErrorTitle,
            child: Text(
              l10n.premierEclairageCardErrorTitle,
              style: MintTextStyles.headlineSmall(),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l10n.premierEclairageCardErrorBody,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.md),
          _CtaButton(
            label: l10n.premierEclairageCardCtaPersonalize,
            onTap: () => widget.onNavigate('/onboarding/quick-start'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _DisclaimerText(text: l10n.premierEclairageDisclaimer),
        ],
      ),
    );
  }

  // ── Normal / Pedagogical state ──────────────────────────────────────────────

  Widget _buildNormalState(BuildContext context, S l10n, bool isPedagogical) {
    final snapshot = _snapshot!;
    final value = snapshot['value']?.toString() ?? '---';
    final title = snapshot['title']?.toString() ?? '';
    final subtitle = snapshot['subtitle']?.toString();
    final suggestedRoute =
        snapshot['suggestedRoute']?.toString() ?? '/bilan-retraite';

    final numberColor =
        isPedagogical ? MintColors.textMuted : MintColors.textPrimary;

    return _CardShell(
      onDismiss: widget.onDismiss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Number ──
          Semantics(
            label: '$value — $title',
            child: Text(
              value,
              style: MintTextStyles.displayMedium(color: numberColor),
            ),
          ),

          // ── Pedagogical estimate label ──
          if (isPedagogical) ...[
            const SizedBox(height: MintSpacing.xs),
            Text(
              l10n.premierEclairageCardEstimate,
              style: MintTextStyles.labelSmall(color: MintColors.warning),
            ),
          ],

          const SizedBox(height: MintSpacing.sm),

          // ── Title ──
          if (title.isNotEmpty)
            Text(
              title,
              style: MintTextStyles.headlineSmall(),
            ),

          // ── Subtitle ──
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.xs),
            Text(
              subtitle,
              style: MintTextStyles.bodyMedium(
                color: MintColors.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: MintSpacing.md),

          // ── CTA ──
          Semantics(
            button: true,
            label: l10n.premierEclairageCardCta,
            child: _CtaButton(
              label: l10n.premierEclairageCardCta,
              onTap: () => widget.onNavigate(suggestedRoute),
            ),
          ),

          const SizedBox(height: MintSpacing.sm),

          // ── Session hint ──
          Text(
            l10n.premierEclairageCardSessionHint,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),

          const SizedBox(height: MintSpacing.sm),

          // ── Mandatory disclaimer (T-03-08, CLAUDE.md §6) ──
          _DisclaimerText(text: l10n.premierEclairageDisclaimer),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Shared sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// Card shell with accent bar, dismiss button, and rounded border.
class _CardShell extends StatelessWidget {
  final VoidCallback onDismiss;
  final Widget child;

  const _CardShell({required this.onDismiss, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left accent bar ──
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: MintColors.saugeClaire,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),

            // ── Content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(MintSpacing.md),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: MintSpacing.lg),
                      child: child,
                    ),

                    // ── Dismiss button ──
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Semantics(
                        button: true,
                        label: l10n.premierEclairageCardDismiss,
                        child: GestureDetector(
                          onTap: onDismiss,
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: MintColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width CTA button with accent fill.
class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CtaButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.accent,
          foregroundColor: MintColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
        ),
        child: Text(
          label,
          style: MintTextStyles.titleMedium(color: MintColors.white),
        ),
      ),
    );
  }
}

/// Small disclaimer text (mandatory per CLAUDE.md §6, T-03-08).
class _DisclaimerText extends StatelessWidget {
  final String text;
  const _DisclaimerText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MintTextStyles.labelTiny(color: MintColors.textMuted),
    );
  }
}
