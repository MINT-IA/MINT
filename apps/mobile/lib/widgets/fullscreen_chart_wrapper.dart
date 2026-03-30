import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Reusable wrapper that adds a fullscreen expand button to any chart widget.
///
/// Usage:
/// ```dart
/// FullscreenChartWrapper(
///   title: 'Decomposition revenus',
///   child: IncomeStackedBarChart(data: data),
/// )
/// ```
class FullscreenChartWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  final String? disclaimer;
  final Widget? legend;
  final bool allowLandscape;

  const FullscreenChartWrapper({
    super.key,
    required this.title,
    required this.child,
    this.disclaimer,
    this.legend,
    this.allowLandscape = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          right: 8,
          child: _ExpandButton(
            onTap: () => _openFullscreen(context),
          ),
        ),
      ],
    );
  }

  // Navigator.push is intentional here — fullscreen dialog overlay,
  // not a navigable route. GoRouter doesn't support fullscreenDialog well.
  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenChartPage(
          title: title,
          disclaimer: disclaimer,
          legend: legend,
          allowLandscape: allowLandscape,
          child: child,
        ),
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExpandButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'interactive element',
      button: true,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: MintColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: const Icon(
          Icons.fullscreen,
          size: 20,
          color: MintColors.textSecondary,
        ),
      ),
    ),);
  }
}

class _FullscreenChartPage extends StatefulWidget {
  final String title;
  final Widget child;
  final String? disclaimer;
  final Widget? legend;
  final bool allowLandscape;

  const _FullscreenChartPage({
    required this.title,
    required this.child,
    this.disclaimer,
    this.legend,
    this.allowLandscape = true,
  });

  @override
  State<_FullscreenChartPage> createState() => _FullscreenChartPageState();
}

class _FullscreenChartPageState extends State<_FullscreenChartPage> {
  @override
  void initState() {
    super.initState();
    if (widget.allowLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17),
        ),
        backgroundColor: MintColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: MintColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chart takes available space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: widget.child,
              ),
            ),

            // Legend
            if (widget.legend != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: widget.legend!,
              ),

            // Disclaimer
            if (widget.disclaimer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  widget.disclaimer!,
                  style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
