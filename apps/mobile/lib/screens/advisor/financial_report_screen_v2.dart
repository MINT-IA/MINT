import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/widgets/common/mint_empty_state.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:provider/provider.dart';

/// Écran de synthèse du rapport financier V2.
/// /rapport reste un récapitulatif exportable, pas un duplicat des dashboards.
class FinancialReportScreenV2 extends StatelessWidget {
  final Map<String, dynamic> wizardAnswers;
  final BudgetSnapshot? budgetSnapshot;

  const FinancialReportScreenV2({
    super.key,
    required this.wizardAnswers,
    this.budgetSnapshot,
  });

  // ── Route mapping by ActionCategory (replaces fragile keyword matching) ──
  String _routeForCategory(ActionCategory category) {
    return switch (category) {
      ActionCategory.protection => '/budget',
      ActionCategory.pillar3a => '/pilier-3a',
      ActionCategory.lpp => '/rachat-lpp',
      ActionCategory.avs => '/retraite',
      ActionCategory.tax => '/fiscal',
      ActionCategory.insurance => '/assurances/lamal',
      ActionCategory.investment => '/tools',
      ActionCategory.other => '/tools',
    };
  }

  void _leaveReport(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/mon-argent');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (wizardAnswers.isEmpty && !_hasReportFallback(context)) {
      return Scaffold(
        backgroundColor: MintColors.surface,
        appBar: AppBar(
          title: Text(S.of(context)!.reportTitleBilanFlash,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary)),
          backgroundColor: MintColors.white,
          foregroundColor: MintColors.textPrimary,
          elevation: 0,
          leading: Semantics(
            label: S.of(context)!.semanticsBackButton,
            button: true,
            onTap: () => _leaveReport(context),
            excludeSemantics: true,
            child: IconButton(
              tooltip: S.of(context)!.semanticsBackButton,
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => _leaveReport(context),
            ),
          ),
        ),
        body: MintEmptyState(
          icon: Icons.assessment_outlined,
          title: S.of(context)!.financialReportEmptyTitle,
          subtitle: S.of(context)!.financialReportEmptySubtitle,
          ctaLabel: S.of(context)!.financialReportEmptyCta,
          // B7-cascade fix 2026-05-09 : push (not go) so the user can
          // back-out of the coach without losing this empty-state screen.
          onCta: () => context.push('/coach/chat'),
        ),
      );
    }
    final reportService = FinancialReportService();
    final report =
        reportService.generateReport(wizardAnswers, l: S.of(context));
    Future<void> exportReportPdf() async {
      try {
        await PdfService.generateFinancialReportPdf(
          report,
          title: S.of(context)!.reportPdfExportTitle,
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.reportPdfExportError)),
        );
      }
    }

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        title: Text(S.of(context)!.reportTitleBilanFlash,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        leading: Semantics(
          label: S.of(context)!.semanticsBackButton,
          button: true,
          onTap: () => _leaveReport(context),
          excludeSemantics: true,
          child: IconButton(
            tooltip: S.of(context)!.semanticsBackButton,
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => _leaveReport(context),
          ),
        ),
        actions: [
          Semantics(
            label: S.of(context)!.reportSharePdfSemantics,
            button: true,
            onTap: exportReportPdf,
            excludeSemantics: true,
            child: IconButton(
              tooltip: S.of(context)!.reportSharePdfSemantics,
              icon: const Icon(Icons.share),
              onPressed: exportReportPdf,
            ),
          ),
        ],
      ),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Synthesis first: /rapport is a recap/export surface, not
                    // another dashboard competing with Mon Argent or Budget.
                    MintEntrance(
                        child: _reportSectionSemantics(
                      id: 'report_synthesis_summary',
                      label: _synthesisSemanticsLabel(
                          context, report, report.healthScore),
                      child: _buildSynthesisHero(
                          context, report, report.healthScore),
                    )),

                    const SizedBox(height: MintSpacing.lg),

                    // ── SoA Compliance Section ──
                    _reportSectionSemantics(
                      id: 'report_compliance_summary',
                      label: _complianceSemanticsLabel(context, report),
                      child: _buildSoaComplianceSection(context, report),
                    ),

                    const SizedBox(height: MintSpacing.lg),

                    // ── Disclaimer Footer ──
                    _reportSectionSemantics(
                      id: 'report_disclaimer_summary',
                      label: _disclaimerSemanticsLabel(context),
                      child: _buildDisclaimerFooter(context),
                    ),

                    const SizedBox(height: MintSpacing.xxl),
                  ],
                ),
              ))),
    );
  }

  bool _hasReportFallback(BuildContext context) {
    return budgetSnapshot != null ||
        _readMintStateBudgetIfAvailable(context) != null ||
        _readBudgetProviderIfAvailable(context)?.inputs != null;
  }

  Widget _reportSectionSemantics({
    required String id,
    required String label,
    required Widget child,
  }) {
    return Semantics(
      key: Key(id),
      identifier: id,
      container: true,
      explicitChildNodes: true,
      label: label,
      child: child,
    );
  }

  String _synthesisSemanticsLabel(BuildContext context, FinancialReport report,
      FinancialHealthScore healthScore) {
    final action =
        report.priorityActions.isNotEmpty ? report.priorityActions.first : null;
    final profile = report.profile;
    final profileSummary = profile.ageOrNull == null
        ? null
        : S.of(context)!.reportProfileSummary(
              profile.ageOrNull!,
              profile.canton,
              profile.civilStatus,
            );
    return [
      S.of(context)!.reportTitleBilanFlash,
      _statusMessage(context, healthScore),
      if (profileSummary != null) profileSummary,
      if (action != null) action.title,
      if (action != null) action.description,
    ].join('. ');
  }

  String _complianceSemanticsLabel(
      BuildContext context, FinancialReport report) {
    final nature = report.personalizedRoadmap.phases.isNotEmpty
        ? S
            .of(context)!
            .reportSoaEduPhases(report.personalizedRoadmap.phases.length)
        : S.of(context)!.reportSoaEduSimple;
    return [
      S.of(context)!.reportSoaTitle,
      '${S.of(context)!.reportSoaNature}: $nature',
      '${S.of(context)!.reportSoaHypotheses}: '
          '${[
        S.of(context)!.reportSoaHyp1,
        S.of(context)!.reportSoaHyp2,
        S.of(context)!.reportSoaHyp3,
        S.of(context)!.reportSoaHyp4,
      ].join('. ')}',
      '${S.of(context)!.reportSoaConflicts}: '
          '${[
        S.of(context)!.reportSoaNoConflict,
        S.of(context)!.reportSoaNoCommission,
      ].join('. ')}',
      '${S.of(context)!.reportSoaLimitations}: '
          '${[
        S.of(context)!.reportSoaLim1,
        S.of(context)!.reportSoaLim2,
        S.of(context)!.reportSoaLim3,
        S.of(context)!.reportSoaLim4,
      ].join('. ')}',
    ].join('. ');
  }

  String _disclaimerSemanticsLabel(BuildContext context) {
    return '${S.of(context)!.reportMentionLegale}. '
        '${S.of(context)!.reportDisclaimerText}';
  }

  // ════════════════════════════════════════════════════════════════
  //  HEADER — Greeting + contextual status (replaces numeric score)
  // ════════════════════════════════════════════════════════════════

  Widget _buildSynthesisHero(BuildContext context, FinancialReport report,
      FinancialHealthScore healthScore) {
    final action =
        report.priorityActions.isNotEmpty ? report.priorityActions.first : null;
    final profile = report.profile;
    final status = _statusMessage(context, healthScore);
    final profileSummary = profile.ageOrNull == null
        ? null
        : S.of(context)!.reportProfileSummary(
              profile.ageOrNull!,
              profile.canton,
              profile.civilStatus,
            );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.lg),
        radius: 16,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                style: MintTextStyles.headlineMedium(
                    color: MintColors.textPrimary),
              ),
              if (profileSummary != null) ...[
                const SizedBox(height: MintSpacing.sm),
                Text(
                  profileSummary,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: MintSpacing.lg),
                Divider(
                  color: MintColors.border.withValues(alpha: 0.6),
                  height: 1,
                ),
                const SizedBox(height: MintSpacing.lg),
                Text(
                  action.title,
                  style:
                      MintTextStyles.titleMedium(color: MintColors.textPrimary),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  action.description,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
                const SizedBox(height: MintSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push(_routeForCategory(action.category)),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(S.of(context)!.reportCommencer),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: MintColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusMessage(
      BuildContext context, FinancialHealthScore healthScore) {
    final level = healthScore.overallScore;
    if (level >= 70) {
      return S.of(context)!.reportStatusGood;
    }
    if (level >= 40) {
      return S.of(context)!.reportStatusMedium;
    }
    return S.of(context)!.reportStatusLow;
  }

  BudgetSnapshot? _readMintStateBudgetIfAvailable(BuildContext context) {
    try {
      final state = context.read<MintStateProvider>().state;
      return state?.dataSpineSnapshot?.budget ?? state?.budgetSnapshot;
    } on ProviderNotFoundException {
      return null;
    }
  }

  BudgetProvider? _readBudgetProviderIfAvailable(BuildContext context) {
    try {
      return context.read<BudgetProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  SOA COMPLIANCE SECTION — Transparence reglementaire
  // ════════════════════════════════════════════════════════════════

  Widget _buildSoaComplianceSection(
      BuildContext context, FinancialReport report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 20, color: MintColors.info),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(
                  S.of(context)!.reportSoaTitle,
                  style: MintTextStyles.headlineMedium(),
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            ),
            const SizedBox(height: 20),

            // Nature du service
            _buildSoaRow(
              S.of(context)!.reportSoaNature,
              report.personalizedRoadmap.phases.isNotEmpty
                  ? S.of(context)!.reportSoaEduPhases(
                      report.personalizedRoadmap.phases.length)
                  : S.of(context)!.reportSoaEduSimple,
            ),
            const SizedBox(height: 12),

            // Hypoth\u00e8ses de travail
            _buildSoaSubSection(
              S.of(context)!.reportSoaHypotheses,
              Icons.settings_suggest_outlined,
              [
                S.of(context)!.reportSoaHyp1,
                S.of(context)!.reportSoaHyp2,
                S.of(context)!.reportSoaHyp3,
                S.of(context)!.reportSoaHyp4,
              ],
            ),
            const SizedBox(height: 12),

            // Conflits d'int\u00e9r\u00eats
            _buildSoaSubSection(
              S.of(context)!.reportSoaConflicts,
              Icons.handshake_outlined,
              [
                S.of(context)!.reportSoaNoConflict,
                S.of(context)!.reportSoaNoCommission,
              ],
            ),
            const SizedBox(height: 12),

            // Limitations
            _buildSoaSubSection(
              S.of(context)!.reportSoaLimitations,
              Icons.info_outline,
              [
                S.of(context)!.reportSoaLim1,
                S.of(context)!.reportSoaLim2,
                S.of(context)!.reportSoaLim3,
                S.of(context)!.reportSoaLim4,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildSoaSubSection(
    String title,
    IconData icon,
    List<String> items,
  ) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(12),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: MintColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      '\u2022 ',
                      style: MintTextStyles.labelSmall(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DISCLAIMER FOOTER — Mention legale obligatoire
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimerFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 14, color: MintColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  S.of(context)!.reportMentionLegale,
                  style: MintTextStyles.labelSmall()
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.reportDisclaimerText,
              style: MintTextStyles.micro(),
            ),
          ],
        ),
      ),
    );
  }
}
