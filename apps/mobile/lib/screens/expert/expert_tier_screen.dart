/// Expert Tier Screen — V3.3
///
/// Displays 3 specialist types (Planificateur financier, Fiscaliste, Notaire),
/// generates a privacy-safe dossier via [DossierPreparationService],
/// and shows a dossier preview with a CTA for requesting an appointment.
///
/// COMPLIANCE (NON-NEGOTIABLE):
/// - Disclaimer banner always visible: "MINT prepare le dossier, le specialiste donne le conseil"
/// - Term "conseiller" is BANNED — always "specialiste"
/// - Price shown clearly: 129 CHF / session, no hidden costs
/// - No-Advice: MINT prepares; the specialist advises
///
/// Design: Decision Canvas (DESIGN_SYSTEM.md category B)
/// Colors: MintColors tokens only — no hardcoded hex
/// Text: ALL via ARB (6 languages)
///
/// Outil educatif — ne constitue pas un conseil financier (LSFin art. 3).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/expert/advisor_specialization.dart';
import 'package:mint_mobile/services/expert/dossier_preparation_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// ════════════════════════════════════════════════════════════════
//  SPECIALIST TYPE MODEL
// ════════════════════════════════════════════════════════════════

/// Maps a user-facing specialist type to the underlying [AdvisorSpecialization].
class _SpecialistType {
  final IconData icon;
  final String Function(S l) title;
  final String Function(S l) description;
  final AdvisorSpecialization specialization;

  const _SpecialistType({
    required this.icon,
    required this.title,
    required this.description,
    required this.specialization,
  });
}

final List<_SpecialistType> _specialistTypes = [
  _SpecialistType(
    icon: Icons.account_balance_outlined,
    title: (l) => l.expertTierFinancialPlanner,
    description: (l) => l.expertTierFinancialPlannerDesc,
    specialization: AdvisorSpecialization.retirement,
  ),
  _SpecialistType(
    icon: Icons.receipt_long_outlined,
    title: (l) => l.expertTierTaxSpecialist,
    description: (l) => l.expertTierTaxSpecialistDesc,
    specialization: AdvisorSpecialization.taxOptimization,
  ),
  _SpecialistType(
    icon: Icons.gavel_outlined,
    title: (l) => l.expertTierNotary,
    description: (l) => l.expertTierNotaryDesc,
    specialization: AdvisorSpecialization.succession,
  ),
];

// ════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════

class ExpertTierScreen extends StatefulWidget {
  const ExpertTierScreen({super.key});

  @override
  State<ExpertTierScreen> createState() => _ExpertTierScreenState();
}

class _ExpertTierScreenState extends State<ExpertTierScreen> {
  /// Which specialist the user selected (null = selection phase).
  _SpecialistType? _selected;

  /// Generated dossier (null until preparation completes).
  AdvisorDossier? _dossier;

  /// Whether dossier generation is in progress.
  bool _generating = false;

  // ── Lifecycle ──────────────────────────────────────────────

  void _selectSpecialist(_SpecialistType type) {
    final provider = context.read<CoachProfileProvider>();
    if (!provider.hasProfile) {
      // Redirect to onboarding if no profile exists.
      context.push('/onboarding/quick');
      return;
    }

    setState(() {
      _selected = type;
      _generating = true;
    });

    // Generate dossier asynchronously (the service is synchronous but we
    // wrap in a post-frame callback to show the loading state).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l = S.of(context)!;
      final profile = provider.profile!;
      final dossier = DossierPreparationService.prepare(
        profile: profile,
        specialization: type.specialization,
        l: l,
      );
      setState(() {
        _dossier = dossier;
        _generating = false;
      });
    });
  }

  void _goBack() {
    setState(() {
      _selected = null;
      _dossier = null;
      _generating = false;
    });
  }

  void _requestAppointment() {
    final l = S.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MintColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l.expertTierComingSoonTitle,
          style: MintTextStyles.titleMedium(),
        ),
        content: Text(
          l.expertTierComingSoon,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l.expertTierOk,
              style: MintTextStyles.bodySmall(color: MintColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () {
            if (_selected != null) {
              _goBack();
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          l.expertTierScreenTitle,
          style: MintTextStyles.titleMedium(),
        ),
        centerTitle: true,
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        child: Column(
          children: [
            // Disclaimer banner — always visible (compliance).
            _DisclaimerBanner(text: l.expertTierDisclaimerBanner),
            Expanded(
              child: MintEntrance(child: _selected == null
                  ? _SpecialistSelectionView(
                      onSelect: _selectSpecialist,
                    )
                  : _generating
                      ? _LoadingView(text: l.expertTierDossierGenerating)
                      : _dossier != null
                          ? _DossierPreviewView(
                              dossier: _dossier!,
                              specialist: _selected!,
                              onBack: _goBack,
                              onRequest: _requestAppointment,
                            )
                          : _LoadingView(
                              text: l.expertTierDossierGenerating,
                            ),
            )),
          ],
        ),
      ))),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  DISCLAIMER BANNER
// ════════════════════════════════════════════════════════════════

class _DisclaimerBanner extends StatelessWidget {
  final String text;
  const _DisclaimerBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md,
        vertical: MintSpacing.sm,
      ),
      color: MintColors.saugeClaire.withValues(alpha: 0.4),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: MintColors.textSecondary,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.labelSmall(
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  PHASE 1 — SPECIALIST SELECTION
// ════════════════════════════════════════════════════════════════

class _SpecialistSelectionView extends StatelessWidget {
  final void Function(_SpecialistType) onSelect;
  const _SpecialistSelectionView({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return ListView.separated(
      padding: const EdgeInsets.all(MintSpacing.lg),
      itemCount: _specialistTypes.length,
      separatorBuilder: (_, __) => const SizedBox(height: MintSpacing.md),
      itemBuilder: (context, index) {
        final spec = _specialistTypes[index];
        return _SpecialistCard(
          icon: spec.icon,
          title: spec.title(l),
          description: spec.description(l),
          price: l.expertTierPrice,
          ctaLabel: l.expertTierSelectCta,
          onTap: () => onSelect(spec),
        );
      },
    );
  }
}

class _SpecialistCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String price;
  final String ctaLabel;
  final VoidCallback onTap;

  const _SpecialistCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.price,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: MintColors.primary, size: 24),
              ),
              const SizedBox(width: MintSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MintTextStyles.titleMedium(),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      price,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            description,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            button: true,
            label: ctaLabel,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  ctaLabel,
                  style: MintTextStyles.bodySmall(color: MintColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  LOADING STATE
// ════════════════════════════════════════════════════════════════

class _LoadingView extends StatelessWidget {
  final String text;
  const _LoadingView({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: MintColors.primary,
            strokeWidth: 2,
          ),
          const SizedBox(height: MintSpacing.md),
          Text(
            text,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  PHASE 2 — DOSSIER PREVIEW
// ════════════════════════════════════════════════════════════════

class _DossierPreviewView extends StatelessWidget {
  final AdvisorDossier dossier;
  final _SpecialistType specialist;
  final VoidCallback onBack;
  final VoidCallback onRequest;

  const _DossierPreviewView({
    required this.dossier,
    required this.specialist,
    required this.onBack,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final completenessPercent =
        (dossier.profileCompleteness * 100).round().toString();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(MintSpacing.lg),
            children: [
              // Header with specialist name + completeness
              _DossierHeader(
                specialist: specialist,
                completenessLabel:
                    l.expertTierCompleteness(completenessPercent),
                completeness: dossier.profileCompleteness,
              ),
              const SizedBox(height: MintSpacing.md),

              // Dossier sections
              for (final section in dossier.sections) ...[
                _DossierSectionCard(section: section),
                const SizedBox(height: MintSpacing.md),
              ],

              // Missing data warnings
              if (dossier.missingDataWarnings.isNotEmpty) ...[
                _MissingDataCard(
                  title: l.expertTierMissingDataTitle,
                  warnings: dossier.missingDataWarnings,
                ),
                const SizedBox(height: MintSpacing.md),
              ],

              // Disclaimer
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm),
                child: Text(
                  dossier.disclaimer,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Bottom CTA bar
        _BottomCtaBar(
          onBack: onBack,
          onRequest: onRequest,
          backLabel: l.expertTierBack,
          requestLabel: l.expertTierRequestCta,
        ),
      ],
    );
  }
}

// ── Dossier Header ────────────────────────────────────────────

class _DossierHeader extends StatelessWidget {
  final _SpecialistType specialist;
  final String completenessLabel;
  final double completeness;

  const _DossierHeader({
    required this.specialist,
    required this.completenessLabel,
    required this.completeness,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: MintColors.primary,
                size: 20,
              ),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expertTierDossierPreviewTitle,
                style: MintTextStyles.titleMedium(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            specialist.title(l),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.md),
          // Completeness bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completeness,
                    backgroundColor:
                        MintColors.textPrimary.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completeness >= 0.8
                          ? MintColors.success
                          : completeness >= 0.5
                              ? MintColors.warning
                              : MintColors.error,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Text(
                completenessLabel,
                style: MintTextStyles.labelSmall(
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dossier Section Card ──────────────────────────────────────

class _DossierSectionCard extends StatelessWidget {
  final DossierSection section;
  const _DossierSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: MintTextStyles.bodySmall(color: MintColors.primary),
          ),
          const SizedBox(height: MintSpacing.sm),
          for (int i = 0; i < section.items.length; i++) ...[
            _DossierItemRow(item: section.items[i], estimatedLabel: l.expertTierEstimated),
            if (i < section.items.length - 1)
              Divider(
                height: MintSpacing.md,
                color: MintColors.textPrimary.withValues(alpha: 0.05),
              ),
          ],
        ],
      ),
    );
  }
}

class _DossierItemRow extends StatelessWidget {
  final DossierItem item;
  final String estimatedLabel;
  const _DossierItemRow({required this.item, required this.estimatedLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              item.label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    item.value,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.end,
                  ),
                ),
                if (item.isEstimated) ...[
                  const SizedBox(width: MintSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      estimatedLabel,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.warning,
                      ).copyWith(fontSize: 9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Missing Data Card ─────────────────────────────────────────

class _MissingDataCard extends StatelessWidget {
  final String title;
  final List<String> warnings;
  const _MissingDataCard({required this.title, required this.warnings});

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      tone: MintSurfaceTone.peche,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: MintColors.warning,
                size: 18,
              ),
              const SizedBox(width: MintSpacing.sm),
              Text(
                title,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      w,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
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

// ── Bottom CTA Bar ────────────────────────────────────────────

class _BottomCtaBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRequest;
  final String backLabel;
  final String requestLabel;

  const _BottomCtaBar({
    required this.onBack,
    required this.onRequest,
    required this.backLabel,
    required this.requestLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MintSpacing.lg,
        MintSpacing.md,
        MintSpacing.lg,
        MintSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: MintColors.white,
        border: Border(
          top: BorderSide(
            color: MintColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: requestLabel,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onRequest,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                requestLabel,
                style: MintTextStyles.bodySmall(color: MintColors.white),
              ),
            ),
          ),
          ),
          const SizedBox(height: MintSpacing.sm),
          TextButton(
            onPressed: onBack,
            child: Text(
              backLabel,
              style: MintTextStyles.labelSmall(
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
