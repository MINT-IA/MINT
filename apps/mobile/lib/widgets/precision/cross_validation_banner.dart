import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/precision/precision_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Dismissible banner showing a cross-validation alert.
///
/// Appears above a form when [PrecisionService.crossValidate] detects
/// an inconsistency in the user's financial data.
///
/// - **warning** severity: amber background
/// - **error** severity: red background
///
/// Each banner shows the alert message, a suggestion, and can be dismissed.
///
/// Usage:
/// ```dart
/// final alerts = PrecisionService.crossValidate(profile);
/// Column(
///   children: alerts.map((a) => CrossValidationBanner(alert: a)).toList(),
/// )
/// ```
class CrossValidationBanner extends StatefulWidget {
  final CrossValidationAlert alert;

  /// Called when the user dismisses the banner.
  final VoidCallback? onDismiss;

  /// Called when the user taps on the suggestion to take action.
  final VoidCallback? onAction;

  const CrossValidationBanner({
    super.key,
    required this.alert,
    this.onDismiss,
    this.onAction,
  });

  @override
  State<CrossValidationBanner> createState() => _CrossValidationBannerState();
}

class _CrossValidationBannerState extends State<CrossValidationBanner>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() => _dismissed = true);
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final isError = widget.alert.severity == 'error';
    final color = isError ? MintColors.error : MintColors.warning;
    final icon = isError ? Icons.error_outline : Icons.warning_amber_rounded;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(isError ? 18 : 22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + message + dismiss button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.alert.message,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                Semantics(
                  label: 'Fermer',
                  button: true,
                  child: InkWell(
                    onTap: _dismiss,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Suggestion
            Semantics(
              label: widget.alert.suggestion,
              button: true,
              child: InkWell(
                onTap: widget.onAction,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.alert.suggestion,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (widget.onAction != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: MintColors.textMuted,
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

/// Convenience widget that takes a profile map, runs cross-validation,
/// and renders all resulting banners.
class CrossValidationBannerList extends StatelessWidget {
  final Map<String, dynamic> profile;
  final void Function(CrossValidationAlert alert)? onAlertAction;

  const CrossValidationBannerList({
    super.key,
    required this.profile,
    this.onAlertAction,
  });

  @override
  Widget build(BuildContext context) {
    final alerts = PrecisionService.crossValidate(profile);
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts
          .map(
            (alert) => CrossValidationBanner(
              alert: alert,
              onAction:
                  onAlertAction != null ? () => onAlertAction!(alert) : null,
            ),
          )
          .toList(),
    );
  }
}
