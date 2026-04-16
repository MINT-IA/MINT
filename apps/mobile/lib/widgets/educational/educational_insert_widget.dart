import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Widget de base pour tous les inserts éducatifs
/// Affiche un contenu didactique avec disclaimer obligatoire
class EducationalInsertWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final String disclaimer;
  final List<String> hypotheses;
  final VoidCallback? onLearnMore;
  final bool isExpanded;

  const EducationalInsertWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    required this.disclaimer,
    this.hypotheses = const [],
    this.onLearnMore,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MintColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MintColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: MintColors.info,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onLearnMore != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: MintColors.textMuted, size: 20),
                    onPressed: onLearnMore,
                  ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: DefaultTextStyle(
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
              child: content,
            ),
          ),
          
          // Hypotheses (si fournies)
          if (hypotheses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ExpansionTile(
                title: Text(
                  'Hypothèses de calcul',
                  style: MintTextStyles.labelMedium(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w500),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                children: hypotheses.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 12, color: MintColors.textMuted)),
                      Expanded(
                        child: Text(h, style: MintTextStyles.labelMedium(color: MintColors.textMuted).copyWith(height: 1.4)),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
          
          // Disclaimer (obligatoire)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(23)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: MintColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    disclaimer,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
