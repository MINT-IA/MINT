import 'package:flutter/material.dart';

/// Constrains child content to a max width for comfortable reading on wide
/// screens. Centres the content horizontally when the viewport exceeds
/// [maxContentWidth].
class WebResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;

  const WebResponsiveWrapper({
    super.key,
    required this.child,
    this.maxContentWidth = 960,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
