import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Top-level viewport wrapper for the web app.
///
/// Provides a subtle background colour and constrains the entire app
/// to [maxWidth] so it doesn't stretch edge-to-edge on ultra-wide monitors.
class WebViewportLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WebViewportLayout({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MintColors.appleSurface,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
