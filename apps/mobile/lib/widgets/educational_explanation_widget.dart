import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Widget explicatif didactique réutilisable
/// Affiche une explication détaillée avec sections dépliables
class EducationalExplanationWidget extends StatefulWidget {
  final String title;
  final String shortExplanation;
  final List<ExplanationSection> sections;
  final Color accentColor;

  const EducationalExplanationWidget({
    super.key,
    required this.title,
    required this.shortExplanation,
    required this.sections,
    this.accentColor = MintColors.primary,
  });

  @override
  State<EducationalExplanationWidget> createState() =>
      _EducationalExplanationWidgetState();
}

class _EducationalExplanationWidgetState
    extends State<EducationalExplanationWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header cliquable
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: widget.accentColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.accentColor,
                          ),
                        ),
                        if (!_isExpanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.shortExplanation,
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.accentColor.withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.accentColor,
                  ),
                ],
              ),
            ),
          ),

          // Contenu détaillé (dépliable)
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Explication courte (toujours visible)
                  Text(
                    widget.shortExplanation,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // Sections détaillées
                  ...widget.sections
                      .map((section) => _buildSection(section))
                      ,
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(ExplanationSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de section
          if (section.title != null) ...[
            Text(
              section.title!,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Contenu
          if (section.content != null)
            Text(
              section.content!,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),

          // Exemple concret (si fourni)
          if (section.example != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MintColors.orangeRetroWarm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate,
                          color: MintColors.warning, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Exemple concret',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: MintColors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.example!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: MintColors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Points clés (si fournis)
          if (section.keyPoints != null && section.keyPoints!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...section.keyPoints!.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        point.isPositive ? Icons.check_circle : Icons.warning,
                        color: point.isPositive
                            ? MintColors.categoryGreen
                            : MintColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point.text,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

/// Section d'explication
class ExplanationSection {
  final String? title;
  final String? content;
  final String? example;
  final List<KeyPoint>? keyPoints;

  const ExplanationSection({
    this.title,
    this.content,
    this.example,
    this.keyPoints,
  });
}

/// Point clé (positif ou warning)
class KeyPoint {
  final String text;
  final bool isPositive;

  const KeyPoint(this.text, {this.isPositive = true});
}
