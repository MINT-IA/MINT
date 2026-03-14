import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';


/// Two-level focus selector for Pulse hero adaptation.
///
/// Level 1: 4 universal intentions (Comprendre, Protéger, Optimiser, Naviguer)
/// Level 2: 2-3 profile-filtered sub-options per intention
///
/// Each sub-option includes a mini chiffre aperçu computed from known profile data.
/// Tapping a sub-option calls [onFocusSelected] with the primaryFocus key.
class FocusSelector extends StatefulWidget {
  final CoachProfile profile;
  final void Function(String primaryFocus) onFocusSelected;

  const FocusSelector({
    super.key,
    required this.profile,
    required this.onFocusSelected,
  });

  @override
  State<FocusSelector> createState() => _FocusSelectorState();
}

class _FocusSelectorState extends State<FocusSelector> {
  String? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final categories = [
      _FocusCategory(
        key: 'comprendre',
        icon: Icons.explore_outlined,
        label: l.focusSelectorComprendre,
        subtitle: l.focusSelectorComprendreSubtitle,
        color: MintColors.info,
      ),
      _FocusCategory(
        key: 'proteger',
        icon: Icons.shield_outlined,
        label: l.focusSelectorProteger,
        subtitle: l.focusSelectorProtegerSubtitle,
        color: MintColors.success,
      ),
      _FocusCategory(
        key: 'optimiser',
        icon: Icons.trending_up_outlined,
        label: l.focusSelectorOptimiser,
        subtitle: l.focusSelectorOptimiserSubtitle,
        color: MintColors.warning,
      ),
      _FocusCategory(
        key: 'naviguer',
        icon: Icons.compass_calibration_outlined,
        label: l.focusSelectorNaviguer,
        subtitle: l.focusSelectorNaviguerSubtitle,
        color: MintColors.primary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l.focusSelectorTitle,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 2×2 grid — compact
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildGridTile(categories[0])),
                  const SizedBox(width: 10),
                  Expanded(child: _buildGridTile(categories[1])),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildGridTile(categories[2])),
                  const SizedBox(width: 10),
                  Expanded(child: _buildGridTile(categories[3])),
                ],
              ),
            ],
          ),
        ),
        // Expanded sub-options below grid
        if (_expandedCategory != null) ...[
          const SizedBox(height: 8),
          ..._buildSubOptions(_expandedCategory!),
        ],
      ],
    );
  }

  Widget _buildGridTile(_FocusCategory cat) {
    final isExpanded = _expandedCategory == cat.key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedCategory = isExpanded ? null : cat.key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isExpanded
              ? cat.color.withValues(alpha: 0.08)
              : MintColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded
                ? cat.color.withValues(alpha: 0.4)
                : MintColors.border.withValues(alpha: 0.5),
            width: isExpanded ? 1.5 : 1,
          ),
          boxShadow: [
            if (!isExpanded)
              BoxShadow(
                color: MintColors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(cat.icon, size: 18, color: cat.color),
            ),
            const SizedBox(height: 8),
            Text(
              cat.label,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
            Text(
              cat.subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // _buildCategoryCard removed — replaced by _buildGridTile

  List<Widget> _buildSubOptions(String categoryKey) {
    final profile = widget.profile;
    final age = profile.age;
    final isExpat = profile.nationality != null && profile.nationality != 'CH';
    final isCouple = profile.isCouple;
    final isIndependant = profile.employmentStatus == 'independant';
    final hasDebt = profile.dettes.hasDette;
    final l = S.of(context)!;

    List<_SubOption> options;

    switch (categoryKey) {
      case 'comprendre':
        options = [
          _SubOption(
            focus: 'comprendre_salaire',
            icon: Icons.receipt_long_outlined,
            label: l.focusSelectorSalary,
            apercu: _salaryApercu(profile),
          ),
          if (isExpat || age < 28)
            _SubOption(
              focus: 'comprendre_systeme',
              icon: Icons.account_balance_outlined,
              label: l.focusSelectorSystem,
              apercu: l.focusSelectorSystemApercu,
            ),
          _SubOption(
            focus: 'comprendre_situation',
            icon: Icons.pie_chart_outline,
            label: l.focusSelectorSituation,
            apercu: l.focusSelectorSituationApercu,
          ),
        ];
      case 'proteger':
        options = [
          _SubOption(
            focus: 'proteger_retraite',
            icon: Icons.beach_access_outlined,
            label: l.focusSelectorRetirement,
            apercu: _retirementApercu(profile),
          ),
          if (isCouple)
            _SubOption(
              focus: 'proteger_famille',
              icon: Icons.people_outline,
              label: l.focusSelectorFamily,
              apercu: l.focusSelectorFamilyApercu,
            ),
          if (hasDebt || isIndependant)
            _SubOption(
              focus: 'proteger_urgence',
              icon: Icons.warning_amber_outlined,
              label: hasDebt ? l.focusSelectorDebtRepay : l.focusSelectorSafetyNet,
              apercu: hasDebt ? l.focusSelectorDebtApercu : l.focusSelectorSafetyNetApercu,
            ),
        ];
      case 'optimiser':
        options = [
          _SubOption(
            focus: 'optimiser_fiscal',
            icon: Icons.savings_outlined,
            label: l.focusSelectorTaxes,
            apercu: _taxApercu(profile),
          ),
          _SubOption(
            focus: 'optimiser_patrimoine',
            icon: Icons.account_balance_wallet_outlined,
            label: l.focusSelectorPatrimoine,
            apercu: _patrimoineApercu(profile),
          ),
          if (age > 50)
            _SubOption(
              focus: 'optimiser_capital_rente',
              icon: Icons.compare_arrows_outlined,
              label: l.focusSelectorCapitalRente,
              apercu: l.focusSelectorCapitalRenteApercu,
            ),
        ];
      case 'naviguer':
        options = [
          if (isExpat)
            _SubOption(
              focus: 'naviguer_expat',
              icon: Icons.flight_land_outlined,
              label: l.focusSelectorExpat,
              apercu: l.focusSelectorExpatApercu,
            ),
          _SubOption(
            focus: 'naviguer_achat',
            icon: Icons.home_outlined,
            label: l.focusSelectorHousing,
            apercu: _housingApercu(profile),
          ),
          if (profile.employmentStatus != 'independant')
            _SubOption(
              focus: 'naviguer_independant',
              icon: Icons.business_center_outlined,
              label: l.focusSelectorIndependent,
              apercu: l.focusSelectorIndependentApercu,
            ),
          _SubOption(
            focus: 'naviguer_evenement',
            icon: Icons.family_restroom_outlined,
            label: l.focusSelectorFamilyEvent,
            apercu: l.focusSelectorFamilyEventApercu,
          ),
        ];
      default:
        options = [];
    }

    // Max 3 options
    if (options.length > 3) options = options.sublist(0, 3);

    return options.map((opt) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(top: 6),
      child: _buildSubOptionCard(opt),
    )).toList();
  }

  Widget _buildSubOptionCard(_SubOption opt) {
    return GestureDetector(
      onTap: () => widget.onFocusSelected(opt.focus),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MintColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(opt.icon, size: 18, color: MintColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  Text(
                    opt.apercu,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── Mini-aperçu helpers ──────────────────────────────────

  String _salaryApercu(CoachProfile p) {
    final l = S.of(context)!;
    if (p.salaireBrutMensuel <= 0) return l.focusSelectorSalaryApercu;
    final charges = (p.salaireBrutMensuel * 0.13).round();
    return l.focusSelectorChargesPerMonth('$charges');
  }

  String _retirementApercu(CoachProfile p) {
    final l = S.of(context)!;
    if (p.salaireBrutMensuel <= 0) return l.focusSelectorRetirementApercu;
    final replacement = (p.age < 55) ? '~65-75\u00a0%' : '~70-80\u00a0%';
    return l.focusSelectorKeepPercent(replacement);
  }

  String _taxApercu(CoachProfile p) {
    final l = S.of(context)!;
    if (p.salaireBrutMensuel <= 0) return l.focusSelectorTaxSavings;
    // Rough 3a tax saving estimate
    const marginalRate = 0.25; // ~25% average marginal rate
    final saving3a = (7258 * marginalRate).round();
    return l.focusSelectorTaxRecoverable('$saving3a');
  }

  String _patrimoineApercu(CoachProfile p) {
    final l = S.of(context)!;
    final total = p.patrimoine.totalPatrimoine +
        (p.prevoyance.avoirLppTotal ?? 0) +
        p.prevoyance.totalEpargne3a;
    if (total < 1000) return l.focusSelectorBuildPatrimoine;
    if (total >= 1000000) {
      return 'CHF ${(total / 1000000).toStringAsFixed(1)}M';
    }
    return 'CHF ${(total / 1000).round()}k';
  }

  String _housingApercu(CoachProfile p) {
    final l = S.of(context)!;
    if (p.salaireBrutMensuel <= 0) return l.focusSelectorHousingCapacity;
    // Rough affordability: gross salary * 12 / 0.05 * 0.80
    final capacity = (p.salaireBrutMensuel * 12 / 0.05 * 0.80 / 1000).round();
    return l.focusSelectorHousingPossible('$capacity');
  }
}

class _FocusCategory {
  final String key;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  const _FocusCategory({
    required this.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });
}

class _SubOption {
  final String focus;
  final IconData icon;
  final String label;
  final String apercu;

  const _SubOption({
    required this.focus,
    required this.icon,
    required this.label,
    required this.apercu,
  });
}
