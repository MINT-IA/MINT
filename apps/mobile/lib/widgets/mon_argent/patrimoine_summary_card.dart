import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';

/// Patrimoine summary card for the Mon argent tab.
///
/// 5 states: loading, empty, error, partial, data.
/// StatelessWidget — parent passes data, no internal context.watch.
class PatrimoineSummaryCard extends StatelessWidget {
  final PatrimoineSummary? summary;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onScan;
  final void Function(String topic)? onTapAmount;

  const PatrimoineSummaryCard({
    super.key,
    this.summary,
    this.isLoading = false,
    this.hasError = false,
    this.onTap,
    this.onRetry,
    this.onScan,
    this.onTapAmount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    if (isLoading) return _buildLoading();
    if (hasError) return _buildError(l10n);
    if (summary == null || summary!.isEmpty) return _buildEmpty(l10n);
    return _buildData(l10n);
  }

  Widget _buildLoading() {
    return const MintSurface(
      child: Padding(
        padding: EdgeInsets.all(MintSpacing.lg),
        child: MintLoadingSkeleton(lineCount: 4),
      ),
    );
  }

  Widget _buildEmpty(S l10n) {
    return MintSurface(
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.monArgentPatrimoineTitle,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              l10n.monArgentPatrimoineEmpty,
              style: MintTextStyles.bodyMedium(color: MintColors.ardoise),
            ),
            const SizedBox(height: MintSpacing.md),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: Text(l10n.monArgentScan),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(S l10n) {
    return MintSurface(
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.monArgentPatrimoineTitle,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              l10n.monArgentPatrimoineError,
              style: MintTextStyles.bodyMedium(color: MintColors.ardoise),
            ),
            const SizedBox(height: MintSpacing.md),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.monArgentRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildData(S l10n) {
    final s = summary!;

    return Semantics(
      label: '${l10n.monArgentPatrimoineTitle}. '
          '${l10n.monArgentPatrimoineNet} ${_formatChf(s.net)}.',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: MintSurface(
          child: Padding(
            padding: const EdgeInsets.all(MintSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.monArgentPatrimoineTitle,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                    _PulseCircle(ratio: s.completionRatio),
                  ],
                ),
                const SizedBox(height: MintSpacing.md),
                if (s.lpp != null)
                  _buildTappableRow(
                    l10n.monArgentLpp,
                    s.lpp!.value,
                    'lpp',
                  ),
                if (s.pillar3a != null)
                  _buildTappableRow(
                    l10n.monArgentPillar3a,
                    s.pillar3a!.value,
                    '3a',
                  ),
                if (s.epargneLiquide != null)
                  _buildTappableRow(
                    l10n.monArgentEpargne,
                    s.epargneLiquide!.value,
                    'epargne',
                  ),
                if (s.isPartial)
                  Padding(
                    padding: const EdgeInsets.only(top: MintSpacing.xs),
                    child: Text(
                      l10n.monArgentPatrimoinePartial,
                      style: MintTextStyles.bodySmall(color: MintColors.ardoise),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: MintSpacing.sm),
                  child: Divider(height: 1, color: MintColors.lightBorder),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.monArgentPatrimoineNet,
                      style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      _formatChf(s.net),
                      style: MintTextStyles.headlineLarge(
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (s.lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: MintSpacing.sm),
                    child: Text(
                      _formatTimestamp(l10n, s),
                      style: MintTextStyles.bodySmall(color: MintColors.ardoise),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTappableRow(String label, double amount, String topic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.xs),
      child: GestureDetector(
        onTap: onTapAmount != null
            ? () {
                HapticFeedback.selectionClick();
                onTapAmount!(topic);
              }
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
            ),
            Text(
              _formatChf(amount),
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatChf(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => "${match[1]}'",
    );
    return "$formatted\u00a0CHF";
  }

  String _formatTimestamp(S l10n, PatrimoineSummary s) {
    final date = s.lastUpdated;
    if (date == null) return '';
    final day = date.day;
    final month = _monthAbbr(date.month);
    final source = s.lastUpdateSource ?? '';
    return 'MaJ $day $month · $source';
  }

  String _monthAbbr(int m) {
    const months = [
      'jan', 'fev', 'mar', 'avr', 'mai', 'juin',
      'juil', 'aout', 'sep', 'oct', 'nov', 'dec',
    ];
    return months[m - 1];
  }
}

/// Subtle circular progress indicator for patrimoine completion.
///
/// Shows what fraction of financial data is known (0.0 to 1.0).
/// Design: single arc, MintColors.primary at 15% opacity, 800ms ease-out.
class _PulseCircle extends StatefulWidget {
  final double ratio;
  const _PulseCircle({required this.ratio});

  @override
  State<_PulseCircle> createState() => _PulseCircleState();
}

class _PulseCircleState extends State<_PulseCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${(widget.ratio * 100).round()}\u00a0% des donnees connues',
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(28, 28),
            painter: _PulseCirclePainter(
              ratio: widget.ratio * _animation.value,
            ),
          );
        },
      ),
    );
  }
}

class _PulseCirclePainter extends CustomPainter {
  final double ratio;
  _PulseCirclePainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Track
    final trackPaint = Paint()
      ..color = MintColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (ratio > 0) {
      final arcPaint = Paint()
        ..color = MintColors.primary.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2, // start at top
        2 * 3.14159 * ratio,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseCirclePainter old) => old.ratio != ratio;
}
