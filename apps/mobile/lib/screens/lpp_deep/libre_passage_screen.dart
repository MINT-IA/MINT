import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';
import 'package:mint_mobile/widgets/coach/lpp_rescue_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        _age = profile.age;
        // Prefer libre passage total if available, otherwise fall back to LPP total
        final librePassage = profile.prevoyance.totalLibrePassage;
        if (librePassage > 0) {
          _avoir = librePassage;
        } else {
          final lpp = profile.prevoyance.avoirLppTotal;
          if (lpp != null && lpp > 0) {
            _avoir = lpp;
          }
        }
      });
    } catch (_) {
      // Provider not in tree (tests) — keep defaults
    }
  }

  LibrePassageResult get _result => LibrePassageAdvisor.analyze(
        statut: _statut,
        avoir: _avoir,
        age: _age,
        hasNewEmployer: _statut == LibrePassageStatut.changementEmploi
            ? _hasNewEmployer
            : false,
        daysSinceDeparture: 10,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text(
              l.librePassageAppBarTitle,
              style: MintTextStyles.headlineMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Situation selector
                MintEntrance(child: _buildSituationSelector(l)),
                const SizedBox(height: MintSpacing.md),

                // Profile inputs (age + avoir)
                MintEntrance(delay: Duration(milliseconds: 100), child: _buildProfileInputs(l)),
                const SizedBox(height: MintSpacing.md),

                // New employer toggle — only for job change
                if (_statut == LibrePassageStatut.changementEmploi) ...[
                  _buildNewEmployerToggle(l),
                  const SizedBox(height: MintSpacing.md),
                ],
                const SizedBox(height: MintSpacing.sm),

                // Alerts
                if (result.alerts.isNotEmpty) ...[
                  _buildAlertsSection(result.alerts, l),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Checklist
                MintEntrance(delay: Duration(milliseconds: 200), child: _buildChecklistSection(result.checklist, l)),
                const SizedBox(height: MintSpacing.lg),

                // Recommendations
                if (result.recommendations.isNotEmpty) ...[
                  _buildRecommendationsSection(result.recommendations, l),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // ── P7-D : Opération sauvetage 2e pilier ─────────
                MintEntrance(delay: Duration(milliseconds: 300), child: LppRescueWidget(
                  lppBalance: _avoir,
                  daysElapsed: 10,
                  options: [
                    LppTransferOption(
                      label: 'Compte libre passage',
                      emoji: '🏦',
                      description:
                          'Sécurité maximale, taux fixe 1-2%. Idéal si tu reprends un emploi rapidement.',
                      fiveYearGain: _avoir * 0.07,
                      legalRef: 'LFLP art. 3 — délai 6 mois',
                    ),
                    LppTransferOption(
                      label: 'Police d\'assurance',
                      emoji: '🛡️',
                      description:
                          'Protection décès et invalidité incluse. Rendement moyen lié aux taux techniques.',
                      fiveYearGain: _avoir * 0.04,
                      legalRef: 'OPP2 art. 10',
                    ),
                    LppTransferOption(
                      label: 'Fonds de placement',
                      emoji: '📈',
                      description:
                          'Potentiel de rendement supérieur. Risque de marché à accepter sur l\'horizon.',
                      fiveYearGain: _avoir * 0.15,
                      recommended: true,
                      legalRef: 'LFLP art. 4',
                    ),
                  ],
                )),
                const SizedBox(height: MintSpacing.lg),

                // Link to sfbvg.ch
                MintEntrance(delay: Duration(milliseconds: 400), child: _buildCentrale2ePilier(l)),
                const SizedBox(height: MintSpacing.lg),

                // nLPD / Privacy
                _buildPrivacyNote(l),
                const SizedBox(height: MintSpacing.lg),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSituationSelector(S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.librePassageSectionSituation,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Wrap(
            spacing: MintSpacing.sm,
            runSpacing: MintSpacing.sm,
            children: [
              _buildChoiceChip(
                label: l.librePassageChipChangementEmploi,
                selected: _statut == LibrePassageStatut.changementEmploi,
                onSelected: () => setState(
                    () => _statut = LibrePassageStatut.changementEmploi),
              ),
              _buildChoiceChip(
                label: l.librePassageChipDepartSuisse,
                selected: _statut == LibrePassageStatut.departSuisse,
                onSelected: () =>
                    setState(() => _statut = LibrePassageStatut.departSuisse),
              ),
              _buildChoiceChip(
                label: l.librePassageChipCessationActivite,
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
        style: MintTextStyles.labelSmall(
          color: selected ? MintColors.white : MintColors.textPrimary,
        ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
      ),
      selected: selected,
      selectedColor: MintColors.primary,
      backgroundColor: MintColors.surface,
      side: BorderSide(
        color: selected ? MintColors.primary : MintColors.border,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildProfileInputs(S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.librePassageSectionProfil,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          // Age slider
          MintPremiumSlider(
            label: l.librePassageLabelAge,
            value: _age.toDouble(),
            min: 18,
            max: 65,
            divisions: 47,
            formatValue: (v) => l.librePassageLabelAgeFormat(v.round()),
            onChanged: (v) => setState(() => _age = v.round()),
          ),
          const SizedBox(height: MintSpacing.sm),
          // Avoir slider
          MintPremiumSlider(
            label: l.librePassageLabelAvoir,
            value: _avoir,
            min: 0,
            max: 500000,
            divisions: 100,
            formatValue: (v) => 'CHF ${(v / 1000).toStringAsFixed(0)}k',
            onChanged: (v) => setState(() => _avoir = v),
          ),
        ],
      ),
    );
  }

  Widget _buildNewEmployerToggle(S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.librePassageLabelNouvelEmployeur, style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: MintSpacing.xs),
                Text(l.librePassageLabelNouvelEmployeurQuestion, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
              ],
            ),
          ),
          Semantics(
            label: l.librePassageLabelNouvelEmployeur,
            toggled: _hasNewEmployer,
            child: Switch(
              value: _hasNewEmployer,
              activeTrackColor: MintColors.primary,
              onChanged: (v) => setState(() => _hasNewEmployer = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(List<LibrePassageAlert> alerts, S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.librePassageSectionAlertes, style: MintTextStyles.bodySmall(color: MintColors.textMuted)),
        const SizedBox(height: MintSpacing.sm + 4),
        for (final alert in alerts)
          Container(
            margin: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: _urgencyColor(alert.urgency).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _urgencyColor(alert.urgency).withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: _urgencyColor(alert.urgency), size: 22),
                const SizedBox(width: MintSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title, style: MintTextStyles.bodySmall(color: _urgencyColor(alert.urgency)).copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: MintSpacing.xs),
                      Text(alert.message, style: MintTextStyles.labelSmall(color: _urgencyColor(alert.urgency))),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChecklistSection(List<ChecklistItem> items, S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.librePassageSectionChecklist, style: MintTextStyles.bodySmall(color: MintColors.textMuted)),
          const SizedBox(height: MintSpacing.md),
          for (int i = 0; i < items.length; i++) ...[
            _buildChecklistCard(items[i], i, l),
            if (i < items.length - 1) const SizedBox(height: MintSpacing.sm + 4),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistCard(ChecklistItem item, int index, S l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _urgencyColor(item.urgency), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.title, style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600))),
              _buildUrgencyBadge(item.urgency, l),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.description, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge(ChecklistUrgency urgency, S l) {
    final String label;
    switch (urgency) {
      case ChecklistUrgency.critique:
        label = l.librePassageUrgenceCritique;
      case ChecklistUrgency.haute:
        label = l.librePassageUrgenceHaute;
      case ChecklistUrgency.moyenne:
        label = l.librePassageUrgenceMoyenne;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _urgencyColor(urgency).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: MintTextStyles.micro(color: _urgencyColor(urgency))
            .copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
      ),
    );
  }

  Widget _buildRecommendationsSection(List<String> recommendations, S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.librePassageSectionRecommandations, style: MintTextStyles.bodySmall(color: MintColors.textMuted)),
          const SizedBox(height: MintSpacing.sm + 4),
          for (final rec in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18, color: MintColors.warning),
                  const SizedBox(width: 10),
                  Expanded(child: Text(rec, style: MintTextStyles.bodySmall(color: MintColors.textPrimary))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCentrale2ePilier(S l) {
    return Semantics(
      label: l.librePassageCentrale2eTitle,
      button: true,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse('https://www.sfbvg.ch');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.info.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: MintColors.info, size: 24),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.librePassageCentrale2eTitle, style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(l.librePassageCentrale2eSubtitle, style: MintTextStyles.labelSmall(color: MintColors.info)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: MintColors.info, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyNote(S l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 18, color: MintColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(l.librePassagePrivacyNote, style: MintTextStyles.labelSmall(color: MintColors.textMuted))),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(child: Text(disclaimer, style: MintTextStyles.micro(color: MintColors.textMuted))),
        ],
      ),
    );
  }

  Color _urgencyColor(ChecklistUrgency urgency) {
    switch (urgency) {
      case ChecklistUrgency.critique:
        return MintColors.error;
      case ChecklistUrgency.haute:
        return MintColors.warning;
      case ChecklistUrgency.moyenne:
        return MintColors.info;
    }
  }
}
