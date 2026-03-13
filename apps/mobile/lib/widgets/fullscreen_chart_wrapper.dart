import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

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

  void _openFullscreen(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => _FullscreenChartPage(
        title: title,
        child: child,
        disclaimer: disclaimer,
        legend: legend,
        allowLandscape: allowLandscape,
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExpandButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
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
          style: GoogleFonts.montserrat(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        backgroundColor: MintColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: MintColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
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
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: MintColors.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
