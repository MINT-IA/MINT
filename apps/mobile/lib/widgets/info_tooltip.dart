import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/glossary.dart';
import 'package:mint_mobile/theme/colors.dart';

class InfoTooltip extends StatelessWidget {
  final String term;
  final Widget? child;

  const InfoTooltip({
    super.key,
    required this.term,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final glossaryTerm = GlossaryService.getTerm(term);
    
    if (glossaryTerm == null) return child ?? Text(term);

    return InkWell(
      onTap: () => _showDefinition(context, glossaryTerm),
      child: child ?? Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MintColors.primary, width: 1)),
        ),
        child: Text(
          term,
          style: const TextStyle(color: MintColors.primary, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _showDefinition(BuildContext context, GlossaryTerm term) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MintColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                term.term,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MintColors.primary,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                term.definition,
                style: const TextStyle(
                  fontSize: 16,
                  color: MintColors.textPrimary,
                  height: 1.5,
                ),
              ),
              if (term.context != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MintColors.accentPastel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: MintColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          term.context!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MintColors.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
