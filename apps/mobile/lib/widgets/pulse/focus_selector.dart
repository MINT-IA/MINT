import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';


// TODO: add Semantics for accessibility

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
    final categories = [
      const _FocusCategory(
        key: 'comprendre',
        icon: Icons.explore_outlined,
        label: 'Comprendre',
        subtitle: 'Mon argent',
        color: MintColors.info,
      ),
      const _FocusCategory(
        key: 'proteger',
        icon: Icons.shield_outlined,
        label: 'Protéger',
        subtitle: 'Retraite, famille',
        color: MintColors.success,
      ),
      const _FocusCategory(
        key: 'optimiser',
        icon: Icons.trending_up_outlined,
        label: 'Optimiser',
        subtitle: 'Impôts, épargne',
        color: MintColors.warning,
      ),
      const _FocusCategory(
        key: 'naviguer',
        icon: Icons.compass_calibration_outlined,
        label: 'Naviguer',
        subtitle: 'Changement de vie',
        color: MintColors.primary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Qu'est-ce qui t'occupe ?",
            style: GoogleFonts.outfit(
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
              style: GoogleFonts.outfit(
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

    List<_SubOption> options;

    switch (categoryKey) {
      case 'comprendre':
        options = [
          _SubOption(
            focus: 'comprendre_salaire',
            icon: Icons.receipt_long_outlined,
            label: 'Où va mon salaire ?',
            apercu: _salaryApercu(profile),
          ),
          if (isExpat || age < 28)
            const _SubOption(
              focus: 'comprendre_systeme',
              icon: Icons.account_balance_outlined,
              label: 'Le système suisse ?',
              apercu: 'AVS + LPP + 3a = ?',
            ),
          const _SubOption(
            focus: 'comprendre_situation',
            icon: Icons.pie_chart_outline,
            label: 'Ma situation financière ?',
            apercu: 'Score de visibilité',
          ),
        ];
      case 'proteger':
        options = [
          _SubOption(
            focus: 'proteger_retraite',
            icon: Icons.beach_access_outlined,
            label: 'Ma retraite',
            apercu: _retirementApercu(profile),
          ),
          if (isCouple)
            const _SubOption(
              focus: 'proteger_famille',
              icon: Icons.people_outline,
              label: 'Ma famille / mon couple',
              apercu: 'Vue combinée à deux',
            ),
          if (hasDebt || isIndependant)
            _SubOption(
              focus: 'proteger_urgence',
              icon: Icons.warning_amber_outlined,
              label: hasDebt ? 'Rembourser mes dettes' : 'Construire mon filet',
              apercu: hasDebt ? 'Plan de remboursement' : 'LPP + assurances',
            ),
        ];
      case 'optimiser':
        options = [
          _SubOption(
            focus: 'optimiser_fiscal',
            icon: Icons.savings_outlined,
            label: 'Mes impôts',
            apercu: _taxApercu(profile),
          ),
          _SubOption(
            focus: 'optimiser_patrimoine',
            icon: Icons.account_balance_wallet_outlined,
            label: 'Mon patrimoine',
            apercu: _patrimoineApercu(profile),
          ),
          if (age > 50)
            const _SubOption(
              focus: 'optimiser_capital_rente',
              icon: Icons.compare_arrows_outlined,
              label: 'Capital ou Rente ?',
              apercu: 'Comparer les deux options',
            ),
        ];
      case 'naviguer':
        options = [
          if (isExpat)
            const _SubOption(
              focus: 'naviguer_expat',
              icon: Icons.flight_land_outlined,
              label: "J'arrive en Suisse",
              apercu: 'Droits, lacunes, pièges',
            ),
          _SubOption(
            focus: 'naviguer_achat',
            icon: Icons.home_outlined,
            label: "J'achète un bien",
            apercu: _housingApercu(profile),
          ),
          if (profile.employmentStatus != 'independant')
            const _SubOption(
              focus: 'naviguer_independant',
              icon: Icons.business_center_outlined,
              label: 'Je deviens indépendant·e',
              apercu: 'Filet sans employeur',
            ),
          const _SubOption(
            focus: 'naviguer_evenement',
            icon: Icons.family_restroom_outlined,
            label: 'Un événement familial',
            apercu: 'Mariage, naissance, divorce...',
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
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── Mini-aperçu helpers ──────────────────────────────────

  String _salaryApercu(CoachProfile p) {
    if (p.salaireBrutMensuel <= 0) return 'Découvre ta fiche de paie';
    final charges = (p.salaireBrutMensuel * 0.13).round();
    return '~CHF $charges/mois de charges';
  }

  String _retirementApercu(CoachProfile p) {
    if (p.salaireBrutMensuel <= 0) return 'Estime ta retraite';
    final replacement = (p.age < 55) ? '~65-75%' : '~70-80%';
    return 'Tu gardes $replacement de ton revenu';
  }

  String _taxApercu(CoachProfile p) {
    if (p.salaireBrutMensuel <= 0) return 'Économies potentielles';
    // Rough 3a tax saving estimate
    const marginalRate = 0.25; // ~25% average marginal rate
    final saving3a = (7258 * marginalRate).round();
    return '~CHF $saving3a/an récupérables';
  }

  String _patrimoineApercu(CoachProfile p) {
    final total = p.patrimoine.totalPatrimoine +
        (p.prevoyance.avoirLppTotal ?? 0) +
        p.prevoyance.totalEpargne3a;
    if (total < 1000) return 'Construis ton patrimoine';
    if (total >= 1000000) {
      return 'CHF ${(total / 1000000).toStringAsFixed(1)}M';
    }
    return 'CHF ${(total / 1000).round()}k';
  }

  String _housingApercu(CoachProfile p) {
    if (p.salaireBrutMensuel <= 0) return 'Calcule ta capacité';
    // Rough affordability: gross salary * 12 / 0.05 * 0.80
    final capacity = (p.salaireBrutMensuel * 12 / 0.05 * 0.80 / 1000).round();
    return '~CHF ${capacity}k possibles';
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
