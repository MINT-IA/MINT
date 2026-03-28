import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Bottom sheet displaying the 18 life events as quick triggers.
///
/// When a user taps an event, it returns the event's suggested prompt
/// so the coach can respond with a contextual Response Card.
class LifeEventSheet extends StatelessWidget {
  const LifeEventSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.transparent,
      builder: (_) => const LifeEventSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: MintColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              s.lifeEventSheetTitle,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              s.lifeEventSheetSubtitle,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              shrinkWrap: true,
              children: [
                _buildSection(s.lifeEventSheetSectionFamille, [
                  _LifeEvent('💍', s.lifeEventLabelMariage, s.lifeEventPromptMariage),
                  _LifeEvent('💔', s.lifeEventLabelDivorce, s.lifeEventPromptDivorce),
                  _LifeEvent('👶', s.lifeEventLabelNaissance, s.lifeEventPromptNaissance),
                  _LifeEvent('💑', s.lifeEventLabelConcubinage, s.lifeEventPromptConcubinage),
                  _LifeEvent('🕊️', s.lifeEventLabelDeces, s.lifeEventPromptDeces),
                ]),
                _buildSection(s.lifeEventSheetSectionPro, [
                  _LifeEvent('🎓', s.lifeEventLabelPremierEmploi, s.lifeEventPromptPremierEmploi),
                  _LifeEvent('💼', s.lifeEventLabelNouveauJob, s.lifeEventPromptNouveauJob),
                  _LifeEvent('🚀', s.lifeEventLabelIndependant, s.lifeEventPromptIndependant),
                  _LifeEvent('📦', s.lifeEventLabelPerteEmploi, s.lifeEventPromptPerteEmploi),
                  _LifeEvent('🏖️', s.lifeEventLabelRetraite, s.lifeEventPromptRetraite),
                ]),
                _buildSection(s.lifeEventSheetSectionPatrimoine, [
                  _LifeEvent('🏠', s.lifeEventLabelAchatImmo, s.lifeEventPromptAchatImmo),
                  _LifeEvent('🏷️', s.lifeEventLabelVenteImmo, s.lifeEventPromptVenteImmo),
                  _LifeEvent('🎁', s.lifeEventLabelHeritage, s.lifeEventPromptHeritage),
                  _LifeEvent('💝', s.lifeEventLabelDonation, s.lifeEventPromptDonation),
                ]),
                _buildSection(s.lifeEventSheetSectionMobilite, [
                  _LifeEvent('🏔️', s.lifeEventLabelDemenagement, s.lifeEventPromptDemenagement),
                  _LifeEvent('✈️', s.lifeEventLabelExpatriation, s.lifeEventPromptExpatriation),
                ]),
                _buildSection(s.lifeEventSheetSectionSante, [
                  _LifeEvent('🩺', s.lifeEventLabelInvalidite, s.lifeEventPromptInvalidite),
                ]),
                _buildSection(s.lifeEventSheetSectionCrise, [
                  _LifeEvent('⚠️', s.lifeEventLabelDettes, s.lifeEventPromptDettes),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_LifeEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
          child: Text(
            title,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
        ),
        ...events.map((e) => _buildEventTile(e)),
      ],
    );
  }

  Widget _buildEventTile(_LifeEvent event) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: MintColors.transparent,
          child: Semantics(
            label: event.label,
            button: true,
            child: InkWell(
              onTap: () => context.pop(event.prompt),
              borderRadius: BorderRadius.circular(12),
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(event.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.label,
                      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: MintColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _LifeEvent {
  final String emoji;
  final String label;
  final String prompt;

  const _LifeEvent(this.emoji, this.label, this.prompt);
}
