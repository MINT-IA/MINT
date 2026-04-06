import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Standardized error state widget with optional retry action.
///
/// Renders an error icon, [title], [body] text, and an optional
/// retry button. Matches the pattern of [MintEmptyState].
///
/// Usage:
/// ```dart
/// MintErrorState(
///   title: l10n.errorGenericTitle,
///   body: l10n.errorGenericBody,
///   retryLabel: l10n.errorRetry,
///   onRetry: () => ref.refresh(someProvider),
/// )
/// ```
class MintErrorState extends StatelessWidget {
  /// Error title displayed prominently.
  final String title;

  /// Error body text with details or instructions.
  final String body;

  /// Label for the retry button. Required when [onRetry] is provided.
  final String? retryLabel;

  /// Callback invoked when the retry button is tapped.
  /// If null, no retry button is shown.
  final VoidCallback? onRetry;

  const MintErrorState({
    super.key,
    required this.title,
    required this.body,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: MintColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: MintTextStyles.headlineMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: MintTextStyles.bodyMedium(
                color: MintColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: retryLabel,
                child: FilledButton(
                  onPressed: onRetry,
                  child: Text(retryLabel ?? ''),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
