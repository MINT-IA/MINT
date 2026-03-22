import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_motion.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_ligne.dart';

// ────────────────────────────────────────────────────────────
//  MINT COUNT UP — Revelation en 5 temps
// ────────────────────────────────────────────────────────────
//
//  The signature moment: when MINT reveals a number for the first time.
//
//  Sequence (Design Manifesto 2027 — validated by UX audit):
//  1. Setup text      (350ms fade-in)
//  2. Silence          (800ms — nothing moves)
//  3. CountUp          (600ms, digit by digit, Swiss apostrophe)
//  4. MINT Ligne       (400ms, draws left-to-right under the number)
//  5. Context + lever  (350ms fade-in)
//
//  Total: ~2.5s first time. Respects reduceMotion.
//
//  Usage:
//  ```dart
//  MintCountUp(
//    value: 539414,
//    prefix: 'CHF\u00a0',
//    setupText: 'Ton rachat maximum',
//    contextText: 'Soit +180 CHF/mois à la retraite',
//  )
//  ```
// ────────────────────────────────────────────────────────────

class MintCountUp extends StatefulWidget {
  /// The numeric value to animate towards.
  final double value;

  /// Text prepended to the formatted number (e.g. 'CHF\u00a0').
  final String prefix;

  /// Text appended to the formatted number (e.g. '\u00a0%').
  final String suffix;

  /// Setup text shown before the number (step 1). Optional.
  final String? setupText;

  /// Context text shown after the number (step 5). Optional.
  final String? contextText;

  /// Override number color. Falls back to [MintColors.textPrimary].
  final Color? color;

  /// Number of decimal places. Defaults to 0 for CHF amounts.
  final int decimals;

  /// Whether to show the MINT Ligne under the number.
  final bool showLigne;

  /// Whether to play the full 5-step revelation or just count up.
  /// Set to false for subsequent reveals of the same number.
  final bool fullReveal;

  /// Accessibility label override.
  final String? semanticsLabel;

  const MintCountUp({
    super.key,
    required this.value,
    this.prefix = 'CHF\u00a0',
    this.suffix = '',
    this.setupText,
    this.contextText,
    this.color,
    this.decimals = 0,
    this.showLigne = true,
    this.fullReveal = true,
    this.semanticsLabel,
  });

  @override
  State<MintCountUp> createState() => _MintCountUpState();
}

class _MintCountUpState extends State<MintCountUp>
    with TickerProviderStateMixin {
  // Step controllers
  late AnimationController _setupController;
  late AnimationController _countUpController;
  late AnimationController _contextController;

  // Step animations
  late Animation<double> _setupOpacity;
  late Animation<double> _countUpValue;
  late Animation<double> _contextOpacity;

  // Ligne trigger
  bool _showLigne = false;

  // Silence timer
  bool _silenceDone = false;

  // Cancellable timers for test safety
  final List<Timer> _pendingTimers = [];

  @override
  void initState() {
    super.initState();

    // Step 1: Setup text fade-in (350ms)
    _setupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _setupOpacity = CurvedAnimation(
      parent: _setupController,
      curve: MintMotion.curveEnter,
    );

    // Step 3: CountUp (600ms)
    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _countUpValue = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(
        parent: _countUpController,
        curve: MintMotion.curveStandard,
      ),
    );

    // Step 5: Context fade-in (350ms)
    _contextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _contextOpacity = CurvedAnimation(
      parent: _contextController,
      curve: MintMotion.curveEnter,
    );

    _startReveal();
  }

  void _startReveal() {
    final reduceMotion = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    ).disableAnimations;

    if (reduceMotion || !widget.fullReveal) {
      // Skip all delays — show everything immediately
      _setupController.value = 1.0;
      _silenceDone = true;
      _countUpController.value = 1.0;
      _showLigne = true;
      _contextController.value = 1.0;
      return;
    }

    // Step 1: Setup text
    _setupController.forward().then((_) {
      // Step 2: Silence (800ms)
      _pendingTimers.add(Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() => _silenceDone = true);

        // Step 3: CountUp
        _countUpController.forward().then((_) {
          if (!mounted) return;

          // Step 4: MINT Ligne
          setState(() => _showLigne = true);

          // Step 5: Context (after Ligne starts — 200ms overlap)
          _pendingTimers.add(Timer(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            _contextController.forward();
          }));
        });
      }));
    });
  }

  @override
  void didUpdateWidget(MintCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      // Re-animate count-up only (not the full reveal)
      _countUpValue = Tween<double>(
        begin: oldWidget.value,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _countUpController,
        curve: MintMotion.curveStandard,
      ));
      _countUpController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _setupController.dispose();
    _countUpController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numberColor = widget.color ?? MintColors.textPrimary;
    final formattedFinal =
        '${widget.prefix}${_formatSwiss(widget.value)}${widget.suffix}';

    return Semantics(
      label: widget.semanticsLabel ?? formattedFinal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step 1: Setup text
          if (widget.setupText != null)
            FadeTransition(
              opacity: _setupOpacity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                child: Text(
                  widget.setupText!,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
            ),

          // Step 3: CountUp number
          if (_silenceDone || !widget.fullReveal)
            AnimatedBuilder(
              animation: _countUpController,
              builder: (context, _) {
                final v = _countUpValue.value;
                return Text(
                  '${widget.prefix}${_formatSwiss(v)}${widget.suffix}',
                  style: MintTextStyles.displayLarge(color: numberColor)
                      .copyWith(fontSize: 56, height: 1.0),
                );
              },
            ),

          // Step 4: MINT Ligne
          if (widget.showLigne && _showLigne)
            Padding(
              padding: const EdgeInsets.only(top: MintSpacing.sm),
              child: MintLigne(animate: widget.fullReveal),
            ),

          // Step 5: Context text
          if (widget.contextText != null)
            FadeTransition(
              opacity: _contextOpacity,
              child: Padding(
                padding: const EdgeInsets.only(top: MintSpacing.sm),
                child: Text(
                  widget.contextText!,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Formats [n] with Swiss thousand-separator (typographic apostrophe).
  /// 677847 → "677\u2019847", 1000 → "1\u2019000", 42.5 → "43"
  String _formatSwiss(double n) {
    final fixed = n.toStringAsFixed(widget.decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? '.${parts[1]}' : '';

    if (intPart.length <= 3) return '$intPart$decPart';

    // Reverse, insert apostrophe every 3 digits, reverse back
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      buffer.write(intPart[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('\u2019'); // Right single quotation mark (Swiss standard)
      }
    }
    return '${buffer.toString().split('').reversed.join()}$decPart';
  }
}
