import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class CircleTransitionWidget extends StatefulWidget {
  final String nextSectionName;
  final String description;
  final String? progressLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onComplete;
  final Duration autoAdvanceAfter;

  const CircleTransitionWidget({
    super.key,
    required this.nextSectionName,
    required this.description,
    this.progressLabel,
    required this.icon,
    required this.color,
    required this.onComplete,
    this.autoAdvanceAfter = const Duration(milliseconds: 2600),
  });

  @override
  State<CircleTransitionWidget> createState() => _CircleTransitionWidgetState();
}

class _CircleTransitionWidgetState extends State<CircleTransitionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _autoAdvanceTimer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)));

    _controller.forward();
    _autoAdvanceTimer = Timer(widget.autoAdvanceAfter, _complete);

    // User advances via "Continuer" button or tap
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _complete,
      child: Container(
        color: MintColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 80, color: widget.color),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _opacityAnimation,
                child: Column(
                  children: [
                    Text(
                      'Prochaine étape',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MintColors.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (widget.progressLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.progressLabel!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      widget.nextSectionName,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        widget.description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: MintColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    FilledButton(
                      onPressed: _complete,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.color,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Continuer',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
