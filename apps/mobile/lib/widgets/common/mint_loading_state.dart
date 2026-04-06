import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Standardized loading state widget.
///
/// Renders a centered [CircularProgressIndicator] with an optional
/// [message] text below it. Matches the pattern of [MintEmptyState].
///
/// Usage:
/// ```dart
/// MintLoadingState(message: AppLocalizations.of(context)!.loadingDefault)
/// ```
class MintLoadingState extends StatelessWidget {
  /// Optional message displayed below the loading indicator.
  final String? message;

  const MintLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message ?? 'Loading',
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: MintColors.primary),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
