import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/pillar_3a_deep_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';

/// Ecran comparateur de providers 3a (fintech / banque / assurance).
///
/// Compare les rendements, frais et capital final estimé de 5 providers.
/// Alerte rouge si assurance choisie avant 35 ans.
class ProviderComparatorScreen extends StatefulWidget {
  const ProviderComparatorScreen({super.key});

  @override
  State<ProviderComparatorScreen> createState() =>
      _ProviderComparatorScreenState();
}

class _ProviderComparatorScreenState extends State<ProviderComparatorScreen> {
  int _age = 30;
  double _versementAnnuel = pilier3aPlafondAvecLpp;
  int _duree = 35;
  ProfilRisque _profilRisque = ProfilRisque.dynamique;

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
        _duree = profile.anneesAvantRetraite.clamp(5, 45);
        // Map riskTolerance string to ProfilRisque enum
        final risk = profile.riskTolerance;
        if (risk != null) {
          switch (risk.toLowerCase()) {
            case 'prudent':
            case 'conservateur':
              _profilRisque = ProfilRisque.prudent;
            case 'equilibre':
            case 'modere':
              _profilRisque = ProfilRisque.equilibre;
            case 'dynamique':
            case 'agressif':
              _profilRisque = ProfilRisque.dynamique;
          }
        }
      });
    } catch (_) {
      // Provider not in tree (tests) — keep defaults
    }
  }

  ProviderComparisonResult get _result => ProviderComparator.compare(
        age: _age,
        versementAnnuel: _versementAnnuel,
        duree: _duree,
        profilRisque: _profilRisque,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.white,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => safePop(context),
            ),
            title: Text(
              l.providerComparatorAppBarTitle,
              style: MintTextStyles.headlineMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Chiffre choc
                _buildPremierEclairage(result, l),
                const SizedBox(height: MintSpacing.lg),

                // Inputs
                _buildInputsSection(l),
                const SizedBox(height: MintSpacing.lg),

                // Provider cards — gated in SafeMode (debt crisis)
                SafeModeGate(
                  hasDebt: context.watch<CoachProfileProvider>().profile?.isInDebtCrisis ?? false,
                  child: Column(
                    children: [
                      _buildProviderCards(result, l),
                      const SizedBox(height: MintSpacing.lg),
                      ..._buildAssuranceWarnings(result, l),
                    ],
                  ),
                ),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  Widget _buildPremierEclairage(ProviderComparisonResult result, S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.success.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            l.providerComparatorPremierEclairageLabel(_duree),
            style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            'CHF ${formatChf(result.differenceMax)}',
            style: MintTextStyles.displayMedium(color: MintColors.success),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            l.providerComparatorPremierEclairageSubtitle,
            style: MintTextStyles.labelSmall(color: MintColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsSection(S l) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintEntrance(child: Text(
            l.providerComparatorSectionParametres,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          )),
          const SizedBox(height: MintSpacing.md),

          // Age
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildSliderRow(
            label: l.providerComparatorLabelAge,
            value: _age.toDouble(),
            min: 18,
            max: 60,
            divisions: 42,
            format: l.providerComparatorLabelAgeFormat(_age),
            onChanged: (v) => setState(() {
              _age = v.round();
              _duree = (avsAgeReferenceHomme - _age).clamp(5, 45);
            }),
          )),
          const SizedBox(height: MintSpacing.sm + 4),

          // Versement
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildSliderRow(
            label: l.providerComparatorLabelVersement,
            value: _versementAnnuel,
            min: 1000,
            max: pilier3aPlafondAvecLpp,
            divisions: 62,
            format: 'CHF ${formatChf(_versementAnnuel)}',
            onChanged: (v) => setState(() => _versementAnnuel = v),
          )),
          const SizedBox(height: MintSpacing.sm + 4),

          // Duree
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildSliderRow(
            label: l.providerComparatorLabelDuree,
            value: _duree.toDouble(),
            min: 5,
            max: 45,
            divisions: 40,
            format: l.providerComparatorLabelDureeFormat(_duree),
            onChanged: (v) => setState(() => _duree = v.round()),
          )),
          const SizedBox(height: MintSpacing.md),

          // Profil de risque
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildProfilRisque(l)),
        ],
      ),
    );
  }

  Widget _buildProfilRisque(S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.providerComparatorLabelProfilRisque, style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
        const SizedBox(height: MintSpacing.sm),
        Row(
          children: ProfilRisque.values.map((profil) {
            final isSelected = _profilRisque == profil;
            final label = switch (profil) {
              ProfilRisque.prudent => l.providerComparatorProfilPrudent,
              ProfilRisque.equilibre => l.providerComparatorProfilEquilibre,
              ProfilRisque.dynamique => l.providerComparatorProfilDynamique,
            };
            return Expanded(
              child: Semantics(
                label: '${l.providerComparatorLabelProfilRisque}\u00a0: $label',
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _profilRisque = profil),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: MintSpacing.xs),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? MintColors.primary
                            : MintColors.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? MintColors.white
                            : MintColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String format,
    required ValueChanged<double> onChanged,
  }) {
    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      formatValue: (_) => format,
      onChanged: onChanged,
    );
  }

  Widget _buildProviderCards(ProviderComparisonResult result, S l) {
    // Trier par capital final descendant
    final sorted = List<ProviderResult>.from(result.providers)
      ..sort((a, b) => b.capitalFinal.compareTo(a.capitalFinal));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.providerComparatorSectionComparaison,
          style: MintTextStyles.bodySmall(color: MintColors.textMuted),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        for (final provider in sorted) ...[
          _buildProviderCard(provider, sorted.first.capitalFinal, l),
          const SizedBox(height: MintSpacing.sm + 4),
        ],
      ],
    );
  }

  Widget _buildProviderCard(ProviderResult result, double maxCapital, S l) {
    final isWarning = result.hasWarning;
    // Compliance: no "best" visual indicator — arbitrage must be side-by-side, never ranked.
    Color bgColor = MintColors.white;
    Color borderColor = MintColors.border;
    double borderWidth = 1;

    if (isWarning) {
      bgColor = MintColors.error.withValues(alpha: 0.06);
      borderColor = MintColors.error.withValues(alpha: 0.3);
      borderWidth = 2;
    }

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.provider.nom, style: MintTextStyles.titleMedium()),
                    Text(result.provider.description, style: MintTextStyles.labelSmall(color: MintColors.textMuted)),
                  ],
                ),
              ),
              // Badge display removed — compliance: no ranking indicator.
              if (isWarning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MintColors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.providerComparatorWarningLabel,
                    style: const TextStyle(
                      color: MintColors.white, fontSize: 9, fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.providerComparatorRendement, style: MintTextStyles.micro(color: MintColors.textMuted)),
                  Text(
                    '${(result.rendementNet * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.providerComparatorFrais, style: MintTextStyles.micro(color: MintColors.textMuted)),
                  Text(
                    '${(result.provider.fraisGestion * 100).toStringAsFixed(2)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l.providerComparatorCapitalFinal, style: MintTextStyles.micro(color: MintColors.textMuted)),
                  Text(
                    'CHF ${formatChf(result.capitalFinal)}',
                    style: MintTextStyles.titleMedium(
                      color: isWarning
                              ? MintColors.error
                              : MintColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Ranking badge removed — compliance: arbitrage side-by-side, never ranked.
        ],
      ),
    );
  }

  List<Widget> _buildAssuranceWarnings(ProviderComparisonResult result, S l) {
    final warnings = result.providers
        .where((p) => p.hasWarning && p.warningMessage != null)
        .toList();

    if (warnings.isEmpty) return [const SizedBox.shrink()];

    return [
      for (final w in warnings) ...[
        Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: MintColors.error, size: 24),
                  const SizedBox(width: MintSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      l.providerComparatorAssuranceTitle,
                      style: MintTextStyles.bodySmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.sm + 4),
              Text(w.warningMessage!, style: MintTextStyles.bodySmall(color: MintColors.error)),
              const SizedBox(height: MintSpacing.sm),
              Text(
                l.providerComparatorAssuranceNote,
                style: MintTextStyles.labelSmall(color: MintColors.error),
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.lg),
      ],
    ];
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
}
