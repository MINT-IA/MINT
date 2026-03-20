import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Carte avec effet de verre dépoli (Glassmorphism).
///
/// **DEPRECATED** — Use a standard Container with MintColors.white/surface background,
/// optional MintColors.border, and radiusLg (16px) instead.
/// See docs/DESIGN_SYSTEM.md §4.1 for the replacement pattern.
@Deprecated('Use standard Card pattern from DESIGN_SYSTEM.md §4.1. Will be removed in S55.')
class MintGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool hasShadow;

  const MintGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Semantics(
          label: 'interactive element',
          button: true,
          child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: padding ?? const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (color ?? MintColors.white).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: MintColors.white.withValues(alpha: 0.4),
                width: 1.0,
              ),
              boxShadow: hasShadow
                  ? [
                      BoxShadow(
                        color: MintColors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),),
      ),
    );
  }
}

/// Header typographique premium.
///
/// **DEPRECATED** — Uses Outfit font and UPPERCASE subtitles, both banned by DESIGN_SYSTEM.md.
/// Replace with Montserrat headings via MintTextStyles and sentence case.
@Deprecated('Uses Outfit + UPPERCASE. Migrate to MintTextStyles. Will be removed in S55.')
class MintHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLarge;
  final Color? textColor;

  const MintHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.isLarge = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!.toUpperCase(),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          title,
          style: MintTextStyles.headlineLarge(color: textColor ?? MintColors.textPrimary).copyWith(fontSize: isLarge ? 34 : 24, fontWeight: FontWeight.w600, letterSpacing: -1.0, height: 1.1),
        ),
      ],
    );
  }
}

/// Animation d'entrée avec délai (Stateful pour gérer le délai)
class MintAnimateFadeUp extends StatefulWidget {
  final Widget child;
  final int delayInMs;
  final double distance;
  final Duration duration;

  const MintAnimateFadeUp({
    super.key,
    required this.child,
    this.delayInMs = 0,
    this.distance = 20.0,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<MintAnimateFadeUp> createState() => _MintAnimateFadeUpState();
}

class _MintAnimateFadeUpState extends State<MintAnimateFadeUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translateY;

  // Timer optionnel pour nettoyer si besoin, mais Future.delayed suffit souvent

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _translateY = Tween<double>(begin: widget.distance, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.delayInMs == 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayInMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _translateY.value),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Bouton Premium "Glossy" style Apple OS26.
///
/// **DEPRECATED** — Use FilledButton with MintColors.primary background instead.
/// See docs/DESIGN_SYSTEM.md §4.2 for button patterns.
@Deprecated('Use FilledButton + MintColors.primary. Will be removed in S55.')
class MintPremiumButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isLoading;

  const MintPremiumButton({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'interactive element',
      button: true,
      child: GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 72, // Fixed height for consistency with the design
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MintColors.darkSurface, // Dark grey top
              MintColors.darkApple, // Darker grey bottom
            ],
          ),
          boxShadow: [
            // Drop shadow
            BoxShadow(
              color: MintColors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            // Inner highlight (top bevel)
            BoxShadow(
              color: MintColors.white.withValues(alpha: 0.1),
              blurRadius: 0,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: MintColors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // "Gloss" overlay (optional, subtle gradient)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MintColors.white.withValues(alpha: 0.03),
                      MintColors.transparent,
                    ],
                    stops: const [0.0, 0.5],
                  ),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: MintTextStyles.bodySmall(color: MintColors.white.withValues(alpha: 0.6)).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Arrow Circle
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MintColors.white.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: MintColors.white.withValues(alpha: 0.9),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                     color: MintColors.black.withValues(alpha: 0.3),
                     borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(MintColors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),);
  }
}
