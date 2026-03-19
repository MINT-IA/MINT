import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

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
              'Il m\'arrive quelque chose',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Choisis un evenement pour voir l\'impact financier',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              shrinkWrap: true,
              children: [
                _buildSection('Famille', [
                  const _LifeEvent('💍', 'Je me marie', 'Je me marie, quel impact financier ?'),
                  const _LifeEvent('💔', 'Je divorce', 'Je divorce, que se passe-t-il avec la LPP et les impots ?'),
                  const _LifeEvent('👶', 'J\'attends un enfant', 'J\'attends un enfant, quelles aides et deductions ?'),
                  const _LifeEvent('💑', 'On vit ensemble', 'On n\'est pas maries, comment se proteger ?'),
                  const _LifeEvent('🕊️', 'Deces d\'un proche', 'Deces d\'un proche, quelles demarches financieres ?'),
                ]),
                _buildSection('Professionnel', [
                  const _LifeEvent('🎓', 'Premier emploi', 'C\'est mon premier job, que dois-je savoir ?'),
                  const _LifeEvent('💼', 'Nouveau job', 'Je change d\'emploi, comment comparer les offres ?'),
                  const _LifeEvent('🚀', 'Independant', 'Je me mets a mon compte, quelles options de prevoyance ?'),
                  const _LifeEvent('📦', 'Perte d\'emploi', 'J\'ai perdu mon emploi, quelles sont mes indemnites ?'),
                  const _LifeEvent('🏖️', 'Retraite', 'Quand partir a la retraite et combien je toucherai ?'),
                ]),
                _buildSection('Patrimoine', [
                  const _LifeEvent('🏠', 'Achat immobilier', 'Est-ce que je peux acheter un bien immobilier ?'),
                  const _LifeEvent('🏷️', 'Vente immobiliere', 'Je vends mon bien, quel impot sur le gain ?'),
                  const _LifeEvent('🎁', 'Heritage', 'Je recois un heritage, quelles consequences fiscales ?'),
                  const _LifeEvent('💝', 'Donation', 'Je veux donner a mes enfants, quel impact fiscal ?'),
                ]),
                _buildSection('Mobilite', [
                  const _LifeEvent('🏔️', 'Demenagement cantonal', 'Je demenage de canton, quel impact fiscal ?'),
                  const _LifeEvent('✈️', 'Expatriation', 'Je pars a l\'etranger, que faire de ma prevoyance ?'),
                ]),
                _buildSection('Sante', [
                  const _LifeEvent('🩺', 'Invalidite', 'Suis-je bien couvert en cas d\'invalidite ?'),
                ]),
                _buildSection('Crise', [
                  const _LifeEvent('⚠️', 'Probleme de dettes', 'J\'ai des dettes, comment m\'en sortir ?'),
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
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 0.8,
            ),
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
              onTap: () => Navigator.of(context).pop(event.prompt),
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
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: MintColors.textPrimary,
                      ),
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
