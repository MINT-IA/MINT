import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';

/// Calendrier de retraits screen — compare withdrawing everything at once
/// vs staggering withdrawals over multiple years.
///
/// Sprint S33 — Arbitrage Phase 2.
/// THE WOW SCREEN — big chiffre choc, timeline visualization.
///
/// NEVER ranks options. Side-by-side comparison only.
/// All text in French, informal "tu".
/// No banned terms.
class CalendrierRetraitsScreen extends StatefulWidget {
  const CalendrierRetraitsScreen({super.key});

  @override
  State<CalendrierRetraitsScreen> createState() =>
      _CalendrierRetraitsScreenState();
}

class _CalendrierRetraitsScreenState extends State<CalendrierRetraitsScreen> {
  // ── Dynamic asset list ──
  final List<_AssetEntry> _assets = [
    _AssetEntry(type: '3a', amountCtrl: TextEditingController(text: '150000'), age: 60),
    _AssetEntry(type: 'lpp', amountCtrl: TextEditingController(text: '400000'), age: 65),
  ];

  String _canton = 'VD';
  bool _isMarried = false;
  final int _ageRetraite = 65;

  ArbitrageResult? _result;

  // ── CoachProfile auto-fill (P8 Phase 4) ──
  bool _didAutoFill = false;
  Map<String, ProfileDataSource> _dataSources = {};
  bool _hasEstimatedValues = false;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFill) {
      _didAutoFill = true;
      _autoFillFromProfile();
    }
  }

  void _autoFillFromProfile() {
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;

    bool changed = false;
    // Pre-fill 3a from profile
    final epargne3a = profile.prevoyance.totalEpargne3a;
    if (epargne3a > 0 && _assets.isNotEmpty) {
      _assets[0].amountCtrl.text = epargne3a.round().toString();
      changed = true;
    }
    // Pre-fill LPP from profile
    final lpp = profile.prevoyance.avoirLppTotal;
    if (lpp != null && lpp > 0 && _assets.length >= 2) {
      _assets[1].amountCtrl.text = lpp.round().toString();
      changed = true;
    }
    // Pre-fill conjoint assets if couple
    if (profile.isCouple && profile.conjoint != null) {
      final conj = profile.conjoint!;
      final conjLpp = conj.prevoyance?.avoirLppTotal;
      if (conjLpp != null && conjLpp > 0) {
        _assets.add(_AssetEntry(
          type: 'lpp',
          amountCtrl: TextEditingController(text: conjLpp.round().toString()),
          age: conj.effectiveRetirementAge,
          label: 'LPP ${conj.firstName ?? "conjoint\u00b7e"}',
        ));
        changed = true;
      }
      final conj3a = conj.prevoyance?.totalEpargne3a ?? 0;
      if (conj3a > 0) {
        _assets.add(_AssetEntry(
          type: '3a',
          amountCtrl: TextEditingController(text: conj3a.round().toString()),
          age: conj.effectiveRetirementAge - 2,
          label: '3a ${conj.firstName ?? "conjoint\u00b7e"}',
        ));
        changed = true;
      }
    }
    if (profile.canton.isNotEmpty) {
      _canton = profile.canton;
    }
    _isMarried = profile.etatCivil == CoachCivilStatus.marie;
    _dataSources = profile.dataSources;
    _hasEstimatedValues = changed;
    if (changed) _recalculate();
  }

  @override
  void dispose() {
    for (final a in _assets) {
      a.amountCtrl.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    final assets = _assets.map((a) {
      final amount =
          double.tryParse(a.amountCtrl.text.replaceAll("'", '')) ?? 0;
      return RetirementAsset(
        type: a.type,
        amount: amount,
        earliestWithdrawalAge: a.age,
      );
    }).where((a) => a.amount > 0).toList();

    final result = ArbitrageEngine.compareCalendrierRetraits(
      assets: assets,
      ageRetraite: _ageRetraite,
      canton: _canton,
      isMarried: _isMarried,
      dataSources: _dataSources,
    );

    setState(() => _result = result);
  }

  void _addAsset() {
    setState(() {
      _assets.add(_AssetEntry(
        type: 'libre_passage',
        amountCtrl: TextEditingController(text: '50000'),
        age: 60,
      ));
    });
    _recalculate();
  }

  void _removeAsset(int index) {
    if (_assets.length <= 1) return;
    setState(() {
      _assets[index].amountCtrl.dispose();
      _assets.removeAt(index);
    });
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ──
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: MintColors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Calendrier de retraits',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MintColors.primary, MintColors.accent],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Assets input ──
                _buildAssetsSection(),
                const SizedBox(height: 16),

                // ── Settings row ──
                _buildSettingsRow(),
                const SizedBox(height: 24),

                // ── Results ──
                if (_result != null && _result!.options.isNotEmpty) ...[
                  // ── Indicatif banner (P8 Phase 4) ──
                  IndicatifBanner(
                    confidenceScore: _result!.confidenceScore,
                    topEnrichmentCategory: 'lpp',
                  ),
                  if (_hasEstimatedValues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SmartDefaultIndicator(
                        source: 'Valeurs pré-remplies depuis ton profil',
                        confidence: _result!.confidenceScore / 100,
                      ),
                    ),
                  // ── BIG CHIFFRE CHOC ──
                  _buildBigChiffreChoc(),
                  const SizedBox(height: 24),

                  // ── Side-by-side cards ──
                  _buildComparisonCards(),
                  const SizedBox(height: 24),

                  // ── Timeline visualization ──
                  _buildTimelineVisualization(),
                  const SizedBox(height: 24),

                  ArbitrageTornadoSection(
                    result: _result!,
                    subtitle:
                        'Impact des hypothèses sur l\'écart fiscal entre retrait unique et retraits étalés.',
                  ),
                  const SizedBox(height: 24),

                  // ── Hypotheses list ──
                  _buildHypothesesSection(),
                  const SizedBox(height: 20),

                  // ── Disclaimer ──
                  _buildDisclaimerCard(),
                  const SizedBox(height: 32),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ASSETS INPUT SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAssetsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tes avoirs de prévoyance',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ajoute chaque compte (3a, LPP, libre passage) avec le montant '
            'et l\'âge au plus tôt pour le retrait.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          for (int i = 0; i < _assets.length; i++) ...[
            _buildAssetRow(i),
            if (i < _assets.length - 1) const SizedBox(height: 12),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addAsset,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    'Ajouter un avoir',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MintColors.primary,
                    side: const BorderSide(color: MintColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _recalculate,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Comparer les calendriers',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetRow(int index) {
    final asset = _assets[index];
    final typeColor = _colorForType(asset.type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Color marker
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Type dropdown
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: MintColors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: asset.type,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textPrimary,
                    ),
                    items: const [
                      DropdownMenuItem(value: '3a', child: Text('Pilier 3a')),
                      DropdownMenuItem(value: 'lpp', child: Text('LPP')),
                      DropdownMenuItem(
                          value: 'libre_passage',
                          child: Text('Libre passage')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => asset.type = v);
                        _recalculate();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Remove button
              if (_assets.length > 1)
                IconButton(
                  onPressed: () => _removeAsset(index),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: MintColors.textMuted,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Amount field
              Expanded(
                flex: 3,
                child: TextField(
                  controller: asset.amountCtrl,
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: MintColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    hintText: 'Montant CHF',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textMuted,
                    ),
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
              const SizedBox(width: 8),
              // Age selector
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: MintColors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<int>(
                    value: asset.age,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textPrimary,
                    ),
                    items: List.generate(11, (i) => 55 + i)
                        .map((age) => DropdownMenuItem(
                              value: age,
                              child: Text('$age ans'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => asset.age = v);
                        _recalculate();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SETTINGS ROW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSettingsRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Canton',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _canton,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: sortedCantonCodes.map((code) {
                    final name = cantonFullNames[code] ?? code;
                    return DropdownMenuItem(
                      value: code,
                      child: Text(
                        '$code - $name',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _canton = v;
                      _recalculate();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marie\u00b7e',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Switch(
              value: _isMarried,
              activeTrackColor: MintColors.primary,
              onChanged: (v) {
                _isMarried = v;
                _recalculate();
              },
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BIG CHIFFRE CHOC
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBigChiffreChoc() {
    if (_result == null) return const SizedBox.shrink();

    // Calculate tax savings
    double taxToutEnUn = 0;
    double taxEtale = 0;
    if (_result!.options.length >= 2) {
      taxToutEnUn = _result!.options[0].cumulativeTaxImpact;
      taxEtale = _result!.options[1].cumulativeTaxImpact;
    }
    final taxSaved = taxToutEnUn - taxEtale;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.accent,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withAlpha(40),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            taxSaved > 0
                ? 'Tu économiserais'
                : 'Écart d\'impôt',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatChf(taxSaved.abs()),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            taxSaved > 0
                ? 'd\'impôt en étalant tes retraits'
                : 'entre les deux stratégies',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _result!.displaySummary,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.white.withAlpha(200),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  COMPARISON CARDS (side-by-side)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildComparisonCards() {
    if (_result == null || _result!.options.length < 2) {
      return const SizedBox.shrink();
    }

    final toutEnUn = _result!.options[0];
    final etale = _result!.options[1];

    return Row(
      children: [
        Expanded(
          child: _buildOptionCard(
            title: 'Tout en une fois',
            icon: Icons.bolt_rounded,
            iconColor: MintColors.warning,
            netValue: toutEnUn.terminalValue,
            taxPaid: toutEnUn.cumulativeTaxImpact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOptionCard(
            title: 'Étalé',
            icon: Icons.timeline_rounded,
            iconColor: MintColors.success,
            netValue: etale.terminalValue,
            taxPaid: etale.cumulativeTaxImpact,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required double netValue,
    required double taxPaid,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Net',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
          Text(
            _formatChf(netValue),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Impôt',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
          Text(
            _formatChf(taxPaid),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.error,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TIMELINE VISUALIZATION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTimelineVisualization() {
    final sortedAssets = List<_AssetEntry>.from(_assets)
      ..sort((a, b) => a.age.compareTo(b.age));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calendrier de retraits étalé',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chaque avoir est retiré à l\'âge indiqué pour limiter la progressivité.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Vertical timeline
          for (int i = 0; i < sortedAssets.length; i++) ...[
            _buildTimelineItem(
              asset: sortedAssets[i],
              isFirst: i == 0,
              isLast: i == sortedAssets.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required _AssetEntry asset,
    required bool isFirst,
    required bool isLast,
  }) {
    final typeColor = _colorForType(asset.type);
    final typeLabel = asset.label ?? _labelForType(asset.type);
    final amount =
        double.tryParse(asset.amountCtrl.text.replaceAll("'", '')) ?? 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Line above dot
                if (!isFirst)
                  Container(width: 2, height: 8, color: MintColors.lightBorder),
                // Dot
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: MintColors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withAlpha(40),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                // Line below dot
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: MintColors.lightBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withAlpha(40)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MintColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${asset.age} ans',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatChf(amount),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HYPOTHESES EXPANDABLE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHypothesesSection() {
    if (_result == null) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        'Hypothèses utilisées',
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: MintColors.textPrimary,
        ),
      ),
      children: [
        for (final h in _result!.hypotheses)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('  \u2022  ',
                    style: TextStyle(color: MintColors.textMuted)),
                Expanded(
                  child: Text(
                    h,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DISCLAIMER CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDisclaimerCard() {
    if (_result == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: MintColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Avertissement',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _result!.disclaimer,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sources : ${_result!.sources.join(' | ')}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════

  Color _colorForType(String type) {
    switch (type) {
      case '3a':
        return MintColors.retirement3a;
      case 'lpp':
        return MintColors.retirementLpp;
      case 'libre_passage':
        return MintColors.retirementAvs;
      default:
        return MintColors.textMuted;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case '3a':
        return 'Pilier 3a';
      case 'lpp':
        return 'LPP (2e pilier)';
      case 'libre_passage':
        return 'Libre passage';
      default:
        return type;
    }
  }

  static String _formatChf(double value) {
    final intVal = value.round().abs();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${value < 0 ? '-' : ''}${buffer.toString()}';
  }
}

// ═══════════════════════════════════════════════════════════════
//  HELPER CLASS — Mutable asset entry for the input form
// ═══════════════════════════════════════════════════════════════

class _AssetEntry {
  String type;
  final TextEditingController amountCtrl;
  int age;
  String? label; // Optional display label (e.g. "LPP Lauren")

  _AssetEntry({
    required this.type,
    required this.amountCtrl,
    required this.age,
    this.label,
  });
}
