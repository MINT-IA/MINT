import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/segments_service.dart';

// ────────────────────────────────────────────────────────────
//  FRONTALIER SCREEN — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────
//
// Country selector with fiscal regime, 3a eligibility,
// LPP rules, AVS rules for cross-border workers.
// Includes quasi-resident GE section and checklist.
// ────────────────────────────────────────────────────────────

class FrontalierScreen extends StatefulWidget {
  const FrontalierScreen({super.key});

  @override
  State<FrontalierScreen> createState() => _FrontalierScreenState();
}

class _FrontalierScreenState extends State<FrontalierScreen> {
  // ── State ──────────────────────────────────────────────────
  PaysResidence _selectedPays = PaysResidence.fr;
  String _cantonTravail = 'GE';
  double _revenuBrut = 90000;
  EtatCivilFrontalier _etatCivil = EtatCivilFrontalier.celibataire;

  FrontalierResult? _result;
  bool _quasiResidentExpanded = false;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    final input = FrontalierInput(
      paysResidence: _selectedPays,
      cantonTravail: _cantonTravail,
      revenuBrut: _revenuBrut,
      etatCivil: _etatCivil,
    );
    setState(() {
      _result = FrontalierService.analyse(input: input);
    });
  }

  // ── Country data ───────────────────────────────────────────

  String _getFlagLabel(PaysResidence pays) {
    switch (pays) {
      case PaysResidence.fr: return 'FR';
      case PaysResidence.de: return 'DE';
      case PaysResidence.it: return 'IT';
      case PaysResidence.at: return 'AT';
      case PaysResidence.li: return 'LI';
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(),
                const SizedBox(height: 20),
                _buildIntro(),
                const SizedBox(height: 24),

                // Country selector
                _buildCountrySelector(),
                const SizedBox(height: 24),

                // Canton selector
                _buildCantonSelector(),
                const SizedBox(height: 24),

                // Results
                if (_result != null) ...[
                  // Rules by category
                  _buildRulesSection(),
                  const SizedBox(height: 20),

                  // Quasi-resident section (GE only)
                  if (_result!.quasiResident != null) ...[
                    _buildQuasiResidentSection(),
                    const SizedBox(height: 20),
                  ],

                  // Checklist
                  _buildChecklist(),
                  const SizedBox(height: 20),
                ],

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 16),

                // Sources
                _buildSourcesFooter(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'PARCOURS FRONTALIER',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.language,
            color: Colors.blue.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Travailleur frontalier',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Droits et obligations par pays',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les regles fiscales, de prevoyance et d\'assurance '
              'varient selon votre pays de residence et votre canton '
              'de travail. Selectionnez votre situation pour voir '
              'les regles applicables.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Country selector ───────────────────────────────────────

  Widget _buildCountrySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pays de residence',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: PaysResidence.values.map((pays) {
              final isSelected = _selectedPays == pays;
              final label = FrontalierService.getPaysLabel(pays);
              final flag = _getFlagLabel(pays);
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    _selectedPays = pays;
                    _compute();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MintColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? MintColors.primary
                            : MintColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          flag,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : MintColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : MintColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Canton selector ────────────────────────────────────────

  Widget _buildCantonSelector() {
    final cantons = ['GE', 'VD', 'BS', 'BL', 'TI', 'ZH', 'AG', 'SG', 'TG', 'SH', 'JU', 'NE', 'VS', 'GR'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Canton de travail',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: cantons.map((canton) {
              final isSelected = _cantonTravail == canton;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(canton),
                  selected: isSelected,
                  onSelected: (_) {
                    _cantonTravail = canton;
                    _compute();
                  },
                  selectedColor: MintColors.primary,
                  backgroundColor: MintColors.surface,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : MintColors.textPrimary,
                  ),
                  side: BorderSide(
                    color: isSelected ? MintColors.primary : MintColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Rules section ──────────────────────────────────────────

  Widget _buildRulesSection() {
    final result = _result!;
    final categories = <String, List<FrontalierRule>>{};
    for (final rule in result.rules) {
      categories.putIfAbsent(rule.category, () => []).add(rule);
    }

    final categoryLabels = {
      'fiscal': 'Regime fiscal',
      '3a': '3e pilier',
      'lpp': 'LPP / Libre passage',
      'avs': 'AVS / Coordination',
    };

    final categoryIcons = {
      'fiscal': Icons.receipt_long,
      '3a': Icons.savings_outlined,
      'lpp': Icons.account_balance,
      'avs': Icons.people_outline,
    };

    final categoryColors = {
      'fiscal': Colors.green.shade700,
      '3a': Colors.amber.shade700,
      'lpp': const Color(0xFF4F46E5),
      'avs': Colors.teal.shade700,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.gavel_outlined, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'REGLES APPLICABLES — ${result.paysLabel.toUpperCase()}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...categories.entries.map((entry) {
          final catLabel = categoryLabels[entry.key] ?? entry.key;
          final catIcon = categoryIcons[entry.key] ?? Icons.info;
          final catColor = categoryColors[entry.key] ?? MintColors.primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRuleCategoryCard(
              category: catLabel,
              icon: catIcon,
              color: catColor,
              rules: entry.value,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRuleCategoryCard({
    required String category,
    required IconData icon,
    required Color color,
    required List<FrontalierRule> rules,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  category,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: MintColors.border.withOpacity(0.4), height: 1),

          // Rules
          ...rules.map((rule) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rule.isAlert)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: MintColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Attention',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MintColors.warning,
                      ),
                    ),
                  ),
                Text(
                  rule.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rule.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.source,
                  style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Quasi-resident section ─────────────────────────────────

  Widget _buildQuasiResidentSection() {
    final qr = _result!.quasiResident!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.info.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _quasiResidentExpanded = !_quasiResidentExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MintColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel, color: MintColors.info, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statut quasi-resident (GE)',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MintColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Appuyez pour en savoir plus',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _quasiResidentExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: MintColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_quasiResidentExpanded) ...[
            Divider(color: MintColors.border.withOpacity(0.4), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    qr.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MintColors.success.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: MintColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Condition : >= 90% des revenus du menage provenant de Suisse',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: MintColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    qr.source,
                    style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: MintColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Checklist frontalier',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...result.checklist.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: MintColors.border),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les informations presentees sont generales et peuvent '
              'varier selon votre situation personnelle. Les conventions '
              'fiscales internationales sont complexes. Consultez un '
              'fiduciaire ou un conseiller fiscal specialise en '
              'situations transfrontalieres.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'CDI CH-FR / CDI CH-DE art. 15a / Accord frontalier CH-IT 2020 / '
          'CDI CH-AT / LPP art. 2 / LFLP art. 25f / LAVS / '
          'Reglement CE 883/2004 / LIPP GE art. 6 / LIFD art. 83',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
