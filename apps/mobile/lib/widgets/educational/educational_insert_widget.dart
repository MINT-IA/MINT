import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';

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
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: MintColors.accentPastel.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: MintColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: MintColors.primary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MintColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onLearnMore != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: MintColors.primary),
                    onPressed: onLearnMore,
                    tooltip: 'En savoir plus',
                  ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
          
          // Hypotheses (si fournies)
          if (hypotheses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ExpansionTile(
                title: const Text(
                  'Hypothèses de calcul',
                  style: TextStyle(fontSize: 12, color: MintColors.textMuted),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                children: hypotheses.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 12, color: MintColors.textMuted)),
                      Expanded(
                        child: Text(h, style: const TextStyle(fontSize: 12, color: MintColors.textMuted)),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    disclaimer,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
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
