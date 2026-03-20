import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class SimulatorCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final List<Widget>? actions;
  final Color? accentColor;

  const SimulatorCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.actions,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? MintColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(24),
        // Premium glass-like shadow "Float" effect
        boxShadow: [
          BoxShadow(
            color: MintColors.primary
                .withValues(alpha: 0.08), // Apple-like dark shadow
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: MintColors.border.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient header strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.3)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: MintColors.border.withValues(alpha: 0.5), height: 1),

          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),

          // Actions
          if (actions != null && actions!.isNotEmpty) ...[
            Divider(color: MintColors.border.withValues(alpha: 0.5), height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: MintColors.surface.withValues(alpha: 0.5),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
