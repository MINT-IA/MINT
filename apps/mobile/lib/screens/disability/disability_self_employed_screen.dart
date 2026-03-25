import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/disability_red_screen_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  P4 — INVALIDITÉ INDÉPENDANT
//  L'Écran rouge (C) + Compte à rebours (F)
//  Source : LAMal art. 67-77, CO art. 324a, LAI art. 28
// ────────────────────────────────────────────────────────────

class DisabilitySelfEmployedScreen extends StatefulWidget {
  const DisabilitySelfEmployedScreen({super.key});

  @override
  State<DisabilitySelfEmployedScreen> createState() =>
      _DisabilitySelfEmployedScreenState();
}

class _DisabilitySelfEmployedScreenState
    extends State<DisabilitySelfEmployedScreen> {
  double _monthlyRevenue = 8000;
  bool _hasPerteDegain = false;
  bool _seededFromProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromProfile) return;
    _seededFromProfile = true;
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;
    setState(() {
      final salary = profile.salaireBrutMensuel;
      if (salary > 0) _monthlyRevenue = salary.clamp(2000.0, 25000.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.redBgLight, // fond rouge très pale
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                MintEntrance(child: _buildRevenueSlider()),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 100), child: DisabilityRedScreenWidget(
                  monthlyExpenses: _monthlyRevenue * 0.70,
                  hasPerteDegain: _hasPerteDegain,
                )),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 200), child: DisabilityCountdownWidget(
                  monthlyExpenses: _monthlyRevenue * 0.70,
                  initialSavings: _monthlyRevenue * 3, // hypothèse 3 mois
                )),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 300), child: _buildPerteDegainToggle()),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 400), child: EduDisclaimer(
                  text: S.of(context)!.disabilitySelfEmployedDisclaimer,
                )),
                const SizedBox(height: 8),
                EduLegalSources(
                  sources: S.of(context)!.disabilitySelfEmployedSources,
                ),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 150,
      floating: false,
      pinned: true,
      backgroundColor: MintColors.critical,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.critical, MintColors.deepRed],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MintColors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      S.of(context)!.disabilitySelfEmployedAlertLabel,
                      style: MintTextStyles.labelSmall(color: MintColors.white).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  Text(
                    S.of(context)!.disabilitySelfEmployedTitle,
                    style: MintTextStyles.headlineMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Text(
        S.of(context)!.disabilitySelfEmployedAppBarTitle,
        style: MintTextStyles.bodyLarge(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildRevenueSlider() {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.disabilitySelfEmployedRevenueTitle,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.disabilitySelfEmployedRevenueHint,
            style: MintTextStyles.labelSmall(),
          ),
          const SizedBox(height: 12),
          MintPremiumSlider(
            label: S.of(context)!.disabilitySelfEmployedRevenueLabel,
            value: _monthlyRevenue,
            min: 2000,
            max: 25000,
            divisions: 46,
            formatValue: (v) => "CHF ${_fmtChf(v)}",
            activeColor: MintColors.critical,
            onChanged: (v) => setState(() => _monthlyRevenue = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPerteDegainToggle() {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.disabilitySelfEmployedInsuranceQuestion,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildToggleChip(S.of(context)!.disabilitySelfEmployedYes, _hasPerteDegain,
                    () => setState(() => _hasPerteDegain = true),
                    color: MintColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleChip(S.of(context)!.disabilitySelfEmployedNo, !_hasPerteDegain,
                    () => setState(() => _hasPerteDegain = false),
                    color: MintColors.critical),
              ),
            ],
          ),
          if (!_hasPerteDegain) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MintColors.warningBgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      S.of(context)!.disabilitySelfEmployedApgTip,
                      style: MintTextStyles.labelSmall(color: MintColors.amberDark).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label, bool selected, VoidCallback onTap,
      {required Color color}) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : MintColors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : MintColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(
              color: selected ? color : MintColors.textSecondary,
            ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
      ),
      ),
    );
  }

  static String _fmtChf(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }
}
