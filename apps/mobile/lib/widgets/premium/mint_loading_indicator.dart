import 'package:flutter/cupertino.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// MINT Design System — Loading Indicator.
///
/// Consistent loading state: CupertinoActivityIndicator (iOS-native)
/// with optional label. Replaces raw CircularProgressIndicator.
class MintLoadingIndicator extends StatelessWidget {
  final String? label;
  final double size;

  const MintLoadingIndicator({
    super.key,
    this.label,
    this.size = 24,
  });

  /// Full-screen centered loading state with optional message.
  static Widget fullScreen({String? label}) {
    return Center(
      child: MintLoadingIndicator(label: label, size: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoActivityIndicator(radius: size / 2, color: MintColors.primary),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label!,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
