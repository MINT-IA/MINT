import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class FinancialDrawer extends StatefulWidget {
  final String title;
  final String subtitle;
  final String heroValue;
  final String? heroSuffix;
  final IconData icon;
  final Color accentColor;
  final Widget content;
  final VoidCallback? onEdit;
  final bool initiallyExpanded;

  const FinancialDrawer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.heroValue,
    this.heroSuffix,
    required this.icon,
    required this.accentColor,
    required this.content,
    this.onEdit,
    this.initiallyExpanded = false,
  });

  @override
  State<FinancialDrawer> createState() => _FinancialDrawerState();
}

class _FinancialDrawerState extends State<FinancialDrawer>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _chevronController;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _chevronController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: _isExpanded ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _chevronController.forward();
      } else {
        _chevronController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.content,
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 20, color: widget.accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.heroValue,
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.accentColor,
                        ),
                      ),
                      if (widget.heroSuffix != null)
                        TextSpan(
                          text: widget.heroSuffix,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: MintColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: Text(
                    widget.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                if (widget.onEdit != null)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      color: MintColors.textMuted,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: AnimatedBuilder(
                    animation: _chevronController,
                    builder: (context, child) => Transform.rotate(
                      angle: _chevronController.value * math.pi,
                      child: child,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
