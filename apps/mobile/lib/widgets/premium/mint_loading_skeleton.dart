import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// Shimmer loading skeleton — replaces empty states during async computation.
///
/// Shows 3 animated rectangles (title + 2 body lines) with a soft shimmer
/// sweep. Used by every screen that awaits CapEngine, BudgetLivingEngine,
/// or any projection service.
///
/// Usage:
/// ```dart
/// if (isLoading) const MintLoadingSkeleton()
/// else RealContent(...)
/// ```
class MintLoadingSkeleton extends StatefulWidget {
  /// Number of body lines below the title bar.
  final int lineCount;

  /// Overall width — defaults to full parent width.
  final double? width;

  const MintLoadingSkeleton({
    super.key,
    this.lineCount = 2,
    this.width,
  });

  @override
  State<MintLoadingSkeleton> createState() => _MintLoadingSkeletonState();
}

class _MintLoadingSkeletonState extends State<MintLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmer = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title bar — wider
              _SkeletonBar(
                width: 0.55,
                height: 16,
                shimmerValue: _shimmer.value,
              ),
              const SizedBox(height: MintSpacing.sm),
              // Body lines — progressively shorter
              for (int i = 0; i < widget.lineCount; i++) ...[
                _SkeletonBar(
                  width: 0.85 - (i * 0.15),
                  height: 12,
                  shimmerValue: _shimmer.value,
                ),
                if (i < widget.lineCount - 1)
                  const SizedBox(height: MintSpacing.xs),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  final double shimmerValue;

  const _SkeletonBar({
    required this.width,
    required this.height,
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width.clamp(0.2, 1.0),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + 2.0 * shimmerValue, 0),
            end: Alignment(-0.5 + 2.0 * shimmerValue, 0),
            colors: [
              MintColors.surface,
              MintColors.border.withValues(alpha: 0.3),
              MintColors.surface,
            ],
          ),
        ),
      ),
    );
  }
}
