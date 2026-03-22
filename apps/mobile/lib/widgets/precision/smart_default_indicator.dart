import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Small badge shown next to an estimated value.
///
/// Displays a "~" prefix and an "Estime" badge in grey.
/// On tap, shows a tooltip explaining the estimation and
/// encouraging the user to provide the real value.
///
/// Usage:
/// ```dart
/// Row(
///   children: [
///     Text('CHF 143\'000'),
///     SmartDefaultIndicator(
///       source: 'Estimation depuis ton salaire et ton age',
///       confidence: 0.35,
///     ),
///   ],
/// )
/// ```
class SmartDefaultIndicator extends StatelessWidget {
  /// Human-readable description of how the default was computed.
  final String source;

  /// Confidence level 0.0 – 1.0 of the estimation.
  final double confidence;

  /// Called when the user taps "Preciser" in the tooltip.
  final VoidCallback? onPrecise;

  const SmartDefaultIndicator({
    super.key,
    required this.source,
    this.confidence = 0.25,
    this.onPrecise,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Valeur estimée',
      button: true,
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: MintColors.textMuted.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '~',
              style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 3),
            Text(
              'Estime',
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _showDetail(BuildContext context) {
    final confidencePct = (confidence * 100).round();

    showModalBottomSheet(
      context: context,
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: MintColors.textMuted.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_fix_high,
                      size: 18,
                      color: MintColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Valeur estimee',
                    style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                'Ce chiffre est une estimation basee sur ton profil. '
                'Precise-le pour un resultat plus fiable.',
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(height: 1.5),
              ),

              const SizedBox(height: 12),

              // Source
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base de l\'estimation',
                      style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source,
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 8),

                    // Confidence bar
                    Row(
                      children: [
                        Text(
                          'Fiabilite : $confidencePct %',
                          style: MintTextStyles.bodySmall(color: _confidenceColor(confidence)).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: confidence,
                        minHeight: 4,
                        backgroundColor: MintColors.border.withAlpha(80),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _confidenceColor(confidence),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (onPrecise != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ctx.pop();
                      onPrecise?.call();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      'Preciser ce chiffre',
                      style: MintTextStyles.bodySmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: MintColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Color _confidenceColor(double c) {
    if (c >= 0.70) return MintColors.success;
    if (c >= 0.40) return MintColors.warning;
    return MintColors.error;
  }
}

/// Wraps a value [Text] with a tilde prefix and the [SmartDefaultIndicator]
/// badge, forming a complete "estimated value" display.
///
/// Usage:
/// ```dart
/// SmartDefaultValue(
///   label: 'CHF 143\'000',
///   source: 'Estimation depuis ton salaire',
///   confidence: 0.35,
/// )
/// ```
class SmartDefaultValue extends StatelessWidget {
  final String label;
  final String source;
  final double confidence;
  final VoidCallback? onPrecise;

  const SmartDefaultValue({
    super.key,
    required this.label,
    required this.source,
    this.confidence = 0.25,
    this.onPrecise,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '~$label',
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        SmartDefaultIndicator(
          source: source,
          confidence: confidence,
          onPrecise: onPrecise,
        ),
      ],
    );
  }
}
