import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';

/// Ecran de conseil en libre passage.
///
/// Affiche une checklist, des alertes et des recommandations
/// selon la situation de depart (changement d'emploi, depart de Suisse,
/// cessation d'activite).
/// Base legale : LFLP, OLP.
class LibrePassageScreen extends StatefulWidget {
  const LibrePassageScreen({super.key});

  @override
  State<LibrePassageScreen> createState() => _LibrePassageScreenState();
}

class _LibrePassageScreenState extends State<LibrePassageScreen> {
  LibrePassageStatut _statut = LibrePassageStatut.changementEmploi;
  bool _hasNewEmployer = true;
  double _avoir = 150000;
  int _age = 35;

  LibrePassageResult get _result => LibrePassageAdvisor.analyze(
        statut: _statut,
        avoir: _avoir,
        age: _age,
        hasNewEmployer: _hasNewEmployer,
        daysSinceDeparture: 10,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'LIBRE PASSAGE',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Situation selector
                _buildSituationSelector(),
                const SizedBox(height: 16),

                // New employer toggle
                _buildNewEmployerToggle(),
                const SizedBox(height: 24),

                // Alerts
                if (result.alerts.isNotEmpty) ...[
                  _buildAlertsSection(result.alerts),
                  const SizedBox(height: 24),
                ],

                // Checklist
                _buildChecklistSection(result.checklist),
                const SizedBox(height: 24),

                // Recommendations
                if (result.recommendations.isNotEmpty) ...[
                  _buildRecommendationsSection(result.recommendations),
                  const SizedBox(height: 24),
                ],

                // Link to sfbvg.ch
                _buildCentrale2ePilier(),
                const SizedBox(height: 24),

                // nLPD / Privacy
                _buildPrivacyNote(),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSituationSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SITUATION',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                label: 'Changement d\'emploi',
                selected: _statut == LibrePassageStatut.changementEmploi,
                onSelected: () => setState(
                    () => _statut = LibrePassageStatut.changementEmploi),
              ),
              _buildChoiceChip(
                label: 'Depart de Suisse',
                selected: _statut == LibrePassageStatut.departSuisse,
                onSelected: () =>
                    setState(() => _statut = LibrePassageStatut.departSuisse),
              ),
              _buildChoiceChip(
                label: 'Cessation d\'activite',
                selected: _statut == LibrePassageStatut.cessationActivite,
                onSelected: () => setState(
                    () => _statut = LibrePassageStatut.cessationActivite),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? Colors.white : MintColors.textPrimary,
        ),
      ),
      selected: selected,
      selectedColor: MintColors.primary,
      backgroundColor: MintColors.appleSurface,
      side: BorderSide(
        color: selected ? MintColors.primary : MintColors.border,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildNewEmployerToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Nouvel employeur',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Avez-vous deja un nouvel employeur ?',
                  style: TextStyle(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _hasNewEmployer,
            activeThumbColor: MintColors.primary,
            onChanged: (v) => setState(() => _hasNewEmployer = v),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(List<LibrePassageAlert> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALERTES',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        for (final alert in alerts)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _urgencyBgColor(alert.urgency),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _urgencyBorderColor(alert.urgency)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: _urgencyColor(alert.urgency),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _urgencyColor(alert.urgency),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: _urgencyColor(alert.urgency),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChecklistSection(List<ChecklistItem> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHECKLIST',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < items.length; i++) ...[
            _buildChecklistCard(items[i], i),
            if (i < items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistCard(ChecklistItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _urgencyColor(item.urgency),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildUrgencyBadge(item.urgency),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge(ChecklistUrgency urgency) {
    String label;
    switch (urgency) {
      case ChecklistUrgency.critique:
        label = 'Critique';
        break;
      case ChecklistUrgency.haute:
        label = 'Haute';
        break;
      case ChecklistUrgency.moyenne:
        label = 'Moyenne';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _urgencyColor(urgency).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _urgencyColor(urgency),
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection(List<String> recommendations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECOMMANDATIONS',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          for (final rec in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rec,
                      style: const TextStyle(
                        fontSize: 13,
                        color: MintColors.textPrimary,
                        height: 1.4,
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

  Widget _buildCentrale2ePilier() {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse('https://www.sfbvg.ch');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.blue.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Centrale du 2e pilier (sfbvg.ch)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Recherchez des avoirs de libre passage oublies',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: Colors.blue.shade400, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 18, color: MintColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vos donnees restent sur votre appareil. Aucune information '
              'n\'est transmise a des tiers. Conforme a la nLPD.',
              style: TextStyle(
                fontSize: 11,
                color: MintColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _urgencyColor(ChecklistUrgency urgency) {
    switch (urgency) {
      case ChecklistUrgency.critique:
        return Colors.red.shade700;
      case ChecklistUrgency.haute:
        return Colors.orange.shade700;
      case ChecklistUrgency.moyenne:
        return Colors.blue.shade700;
    }
  }

  Color _urgencyBgColor(ChecklistUrgency urgency) {
    switch (urgency) {
      case ChecklistUrgency.critique:
        return Colors.red.shade50;
      case ChecklistUrgency.haute:
        return Colors.orange.shade50;
      case ChecklistUrgency.moyenne:
        return Colors.blue.shade50;
    }
  }

  Color _urgencyBorderColor(ChecklistUrgency urgency) {
    switch (urgency) {
      case ChecklistUrgency.critique:
        return Colors.red.shade200;
      case ChecklistUrgency.haute:
        return Colors.orange.shade200;
      case ChecklistUrgency.moyenne:
        return Colors.blue.shade200;
    }
  }
}
