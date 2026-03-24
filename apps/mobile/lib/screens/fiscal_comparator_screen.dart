import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/data/commune_data.dart';
import 'package:mint_mobile/data/average_tax_multipliers.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/fiscal_service.dart';
import 'package:mint_mobile/services/wealth_tax_service.dart';
import 'package:mint_mobile/widgets/fiscal/canton_ranking_bar.dart';
import 'package:mint_mobile/widgets/fiscal/move_savings_card.dart';
import 'package:mint_mobile/widgets/coach/moving_true_cost_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// ────────────────────────────────────────────────────────────
//  FISCAL COMPARATOR SCREEN — Sprint S20 / 26 cantons
// ────────────────────────────────────────────────────────────
//
// Three-tab interactive screen:
//   Tab 1: "Mon impot"  — Tax estimate for one canton
//   Tab 2: "26 cantons" — Ranking with horizontal bar chart
//   Tab 3: "Demenager"  — Move simulation between cantons
//
// All text in French (informal "tu").
// Material 3, MintColors theme, MintTextStyles tokens.
// ────────────────────────────────────────────────────────────

class FiscalComparatorScreen extends StatefulWidget {
  const FiscalComparatorScreen({super.key});

  @override
  State<FiscalComparatorScreen> createState() => _FiscalComparatorScreenState();
}

class _FiscalComparatorScreenState extends State<FiscalComparatorScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Shared inputs ───────────────────────────────────────
  double _revenuBrut = 100000;
  String _canton = 'VD';
  String? _commune;
  String _etatCivil = 'celibataire';
  int _nombreEnfants = 0;

  // ── Wealth + Church tax inputs ────────────────────────
  double _fortune = 0;
  bool _isChurchMember = false;
  final TextEditingController _fortuneController =
      TextEditingController(text: '0');

  // ── Tab 1: Mon impot ───────────────────────────────────
  Map<String, dynamic>? _taxResult;
  Map<String, dynamic>? _wealthTaxResult;
  Map<String, dynamic>? _churchTaxResult;

  // ── Tab 2: 26 cantons ──────────────────────────────────
  List<Map<String, dynamic>> _allCantons = [];

  // ── Tab 3: Demenager ───────────────────────────────────
  String _cantonDepart = 'VD';
  String? _communeDepart;
  String _cantonArrivee = 'ZG';
  String? _communeArrivee;
  Map<String, dynamic>? _moveResult;

  // ── Move checklist ─────────────────────────────────────
  final Set<int> _moveChecked = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initFromProfile();
    _recalculate();
    // Charge les donnees communales (si pas deja chargees)
    if (!CommuneData.isLoaded) {
      CommuneData.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Pre-fill from onboarding profile if available
  void _initFromProfile() {
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;

    if (profile.revenuBrutAnnuel > 0) {
      _revenuBrut = profile.revenuBrutAnnuel;
    }
    if (profile.canton.isNotEmpty) {
      _canton = profile.canton;
      _cantonDepart = profile.canton;
    }
    if (profile.commune != null && profile.commune!.isNotEmpty) {
      _commune = profile.commune;
      _communeDepart = profile.commune;
    }
    _etatCivil = switch (profile.etatCivil) {
      CoachCivilStatus.marie => 'marie',
      CoachCivilStatus.concubinage => 'celibataire', // taxed individually
      _ => 'celibataire',
    };
    _nombreEnfants = profile.nombreEnfants;
    if (profile.patrimoine.investissements > 0 || profile.patrimoine.epargneLiquide > 0) {
      _fortune = profile.patrimoine.epargneLiquide + profile.patrimoine.investissements;
      _fortuneController.text = _fortune.toInt().toString();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fortuneController.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _taxResult = FiscalService.estimateTax(
        revenuBrut: _revenuBrut,
        canton: _canton,
        etatCivil: _etatCivil,
        nombreEnfants: _nombreEnfants,
        commune: _commune,
      );
      _allCantons = FiscalService.compareAllCantons(
        revenuBrut: _revenuBrut,
        etatCivil: _etatCivil,
        nombreEnfants: _nombreEnfants,
      );
      _moveResult = FiscalService.simulateMove(
        revenuBrut: _revenuBrut,
        cantonDepart: _cantonDepart,
        cantonArrivee: _cantonArrivee,
        etatCivil: _etatCivil,
        nombreEnfants: _nombreEnfants,
        communeDepart: _communeDepart,
        communeArrivee: _communeArrivee,
      );

      // Wealth tax
      _wealthTaxResult = WealthTaxService.estimateWealthTax(
        fortune: _fortune,
        canton: _canton,
        etatCivil: _etatCivil,
      );

      // Church tax (based on cantonal BASE tax, not full cantonal+communal)
      final impotCantonalCommunal =
          (_taxResult?['impotCantonalCommunal'] as double?) ?? 0.0;
      // Get the commune multiplier to extract base cantonal tax
      double communeMultiplier;
      if (_commune != null && CommuneData.isLoaded) {
        communeMultiplier =
            CommuneData.getCommuneMultiplier(_canton, _commune!)
                ?? AverageTaxMultipliers.get(_canton);
      } else {
        communeMultiplier = AverageTaxMultipliers.get(_canton);
      }
      _churchTaxResult = WealthTaxService.estimateChurchTax(
        impotCantonalCommunal: impotCantonalCommunal,
        canton: _canton,
        communeMultiplier: communeMultiplier,
      );
    });
    final bestCanton = _allCantons.isNotEmpty
        ? _allCantons.first['canton'] as String?
        : null;
    final maxSavings = _allCantons.isNotEmpty
        ? (_allCantons.last['chargeTotale'] as double) -
            (_allCantons.first['chargeTotale'] as double)
        : 0.0;
    ScreenCompletionTracker.markCompletedWithReturn(
      'fiscal_comparator',
      ScreenReturn.completed(
        route: '/fiscal-comparator',
        updatedFields: {
          'fiscalBestCanton': bestCanton,
          'fiscalMaxSavings': maxSavings,
        },
        confidenceDelta: 0.02,
        nextCapSuggestion: maxSavings > 5000 ? 'demenagement' : null,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(context, innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTab1MonImpot(),
            _buildTab2AllCantons(),
            _buildTab3Demenager(),
          ],
        ),
      ),
    );
  }

  // ── App Bar with Tabs ──────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 120,
      backgroundColor: MintColors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: MintSpacing.md),
        title: Text(
          S.of(context)!.fiscalComparatorTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: MintColors.primary,
        indicatorWeight: 3,
        labelColor: MintColors.textPrimary,
        unselectedLabelColor: MintColors.textMuted,
        labelStyle: MintTextStyles.bodySmall(),
        unselectedLabelStyle: MintTextStyles.bodySmall(color: MintColors.textMuted),
        tabs: [
          Tab(text: S.of(context)!.fiscalTabMyTax),
          Tab(text: S.of(context)!.fiscalTab26Cantons),
          Tab(text: S.of(context)!.fiscalTabMove),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: MON IMPOT
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1MonImpot() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        MintEntrance(child: _buildInputsCard()),
        const SizedBox(height: 20),
        if (_taxResult != null) ...[
          _buildTaxGauge(),
          const SizedBox(height: 20),
          _buildTaxBreakdownCard(),
          const SizedBox(height: 20),
          _buildNationalComparison(),
          const SizedBox(height: 20),
        ],
        MintEntrance(delay: const Duration(milliseconds: 100), child: _buildDisclaimer()),
      ],
    );
  }

  // ── Inputs card (shared across tabs) ───────────────────

  Widget _buildInputsCard() {
    final sortedCodes = FiscalService.sortedCantonCodes;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue slider
          MintPremiumSlider(
            label: S.of(context)!.fiscalGrossAnnualIncome,
            value: _revenuBrut,
            min: 30000,
            max: 500000,
            divisions: 94,
            formatValue: (v) => FiscalService.formatChf(v),
            onChanged: (v) {
              _revenuBrut = (v / 5000).round() * 5000.0;
              _recalculate();
            },
          ),
          const SizedBox(height: 20),

          // Canton dropdown
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.fiscalCanton,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _canton,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code — ${FiscalService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _canton = v;
                        _commune = null; // Reset commune when canton changes
                        _recalculate();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          // Commune dropdown (if commune data loaded)
          if (CommuneData.isLoaded) ...[
            const SizedBox(height: 16),
            _buildCommuneDropdown(
              value: _commune,
              cantonCode: _canton,
              onChanged: (v) {
                _commune = v;
                _recalculate();
              },
            ),
          ],
          const SizedBox(height: 16),

          // Civil status toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.fiscalCivilStatus,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                ),
              ),
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: MintColors.primary,
                  selectedForegroundColor: MintColors.white,
                  textStyle: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
                segments: [
                  ButtonSegment(
                    value: 'celibataire',
                    label: Text(S.of(context)!.fiscalSingle),
                  ),
                  ButtonSegment(
                    value: 'marie',
                    label: Text(S.of(context)!.fiscalMarried),
                  ),
                ],
                selected: {_etatCivil},
                onSelectionChanged: (v) {
                  _etatCivil = v.first;
                  _recalculate();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Children counter
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.fiscalChildren,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _nombreEnfants > 0
                        ? () {
                            _nombreEnfants--;
                            _recalculate();
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline, size: 24),
                    color: MintColors.primary,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$_nombreEnfants',
                      style: MintTextStyles.titleMedium().copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _nombreEnfants < 5
                        ? () {
                            _nombreEnfants++;
                            _recalculate();
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline, size: 24),
                    color: MintColors.primary,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 12),

          // Fortune (wealth) input
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.fiscalNetWealth,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _fortuneController,
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                  decoration: InputDecoration(
                    prefixText: 'CHF ',
                    prefixStyle: MintTextStyles.bodyMedium(),
                    filled: true,
                    fillColor: MintColors.appleSurface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: '0',
                    hintStyle: MintTextStyles.bodyMedium(),
                  ),
                  onChanged: (value) {
                    final parsed =
                        double.tryParse(value.replaceAll("'", '')) ?? 0;
                    _fortune = parsed;
                    _recalculate();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Church member switch
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.fiscalChurchMember,
                      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.of(context)!.fiscalChurchTax,
                      style: MintTextStyles.labelSmall(),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isChurchMember,
                activeTrackColor: MintColors.primary,
                onChanged: (v) {
                  _isChurchMember = v;
                  _recalculate();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tax gauge (effective rate circle) ──────────────────

  Widget _buildTaxGauge() {
    final tax = _taxResult;
    if (tax == null) return const SizedBox.shrink();
    final tauxEffectif = (tax['tauxEffectif'] as double);
    final avgAdjusted = FiscalService.estimateNationalAverageRate(
      revenuBrut: _revenuBrut,
      etatCivil: _etatCivil,
      nombreEnfants: _nombreEnfants,
    );
    final isBelow = tauxEffectif < avgAdjusted;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Rate circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isBelow
                  ? MintColors.success.withValues(alpha: 0.1)
                  : MintColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${tauxEffectif.toStringAsFixed(1)}%',
              style: MintTextStyles.displayMedium(
                color: isBelow ? MintColors.success : MintColors.error,
              ).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.fiscalEffectiveRate,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  isBelow
                      ? S.of(context)!.fiscalBelowAverage(avgAdjusted.toStringAsFixed(1))
                      : S.of(context)!.fiscalAboveAverage(avgAdjusted.toStringAsFixed(1)),
                  style: MintTextStyles.bodySmall(
                    color: isBelow ? MintColors.success : MintColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (tauxEffectif / 20.0).clamp(0.0, 1.0),
                    backgroundColor: MintColors.appleSurface,
                    color: isBelow ? MintColors.success : MintColors.error,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tax breakdown card ─────────────────────────────────

  Widget _buildTaxBreakdownCard() {
    final tax = _taxResult;
    if (tax == null) return const SizedBox.shrink();
    final wealthTax =
        (_wealthTaxResult?['impotFortune'] as double?) ?? 0.0;
    final churchTax =
        (_isChurchMember ? (_churchTaxResult?['impotEglise'] as double?) : null) ?? 0.0;

    final chargeTotaleAvecExtras =
        (tax['chargeTotale'] as double) + wealthTax + churchTax;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.fiscalBreakdownTitle,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow(
            S.of(context)!.fiscalFederalTax,
            tax['impotFederal'] as double,
            MintColors.blueBright,
          ),
          const SizedBox(height: 10),
          _buildBreakdownRow(
            S.of(context)!.fiscalCantonalCommunalTax,
            tax['impotCantonalCommunal'] as double,
            MintColors.purple,
          ),
          if (_fortune > 0) ...[
            const SizedBox(height: 10),
            _buildBreakdownRow(
              S.of(context)!.fiscalWealthTax,
              wealthTax,
              MintColors.orangeFlat,
            ),
          ],
          if (_isChurchMember && churchTax > 0) ...[
            const SizedBox(height: 10),
            _buildBreakdownRow(
              S.of(context)!.fiscalChurchTax,
              churchTax,
              MintColors.tealLight,
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.fiscalTotalBurden,
                style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                FiscalService.formatChf(chargeTotaleAvecExtras),
                style: MintTextStyles.headlineMedium(color: MintColors.primary),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${FiscalService.formatChf(chargeTotaleAvecExtras / 12)}${S.of(context)!.fiscalPerMonth}',
              style: MintTextStyles.bodySmall(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodyMedium(),
          ),
        ),
        Text(
          FiscalService.formatChf(amount),
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── National comparison ────────────────────────────────

  Widget _buildNationalComparison() {
    // Find rank of current canton
    final rank = _allCantons.indexWhere(
            (c) => c['canton'] == _canton) +
        1;
    final cheapest = _allCantons.isNotEmpty ? _allCantons.first : null;
    final mostExpensive =
        _allCantons.isNotEmpty ? _allCantons.last : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.fiscalNationalPosition,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: MintTextStyles.bodyMedium(),
              children: [
                TextSpan(
                  text: '${FiscalService.cantonNames[_canton]}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' ${S.of(context)!.fiscalRanks} '),
                TextSpan(
                  text: '${rank}e sur 26',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: rank <= 8
                        ? MintColors.success
                        : rank <= 18
                            ? MintColors.warning
                            : MintColors.error,
                  ),
                ),
                TextSpan(text: ' ${S.of(context)!.fiscalCantons}. '),
                if (cheapest != null) ...[
                  TextSpan(text: '${S.of(context)!.fiscalCheapest} : '),
                  TextSpan(
                    text: '${cheapest['cantonNom']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text:
                        ' (${FiscalService.formatChf(cheapest['chargeTotale'] as double)})',
                  ),
                  const TextSpan(text: '. '),
                ],
                if (mostExpensive != null) ...[
                  TextSpan(text: '${S.of(context)!.fiscalMostExpensive} : '),
                  TextSpan(
                    text: '${mostExpensive['cantonNom']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text:
                        ' (${FiscalService.formatChf(mostExpensive['chargeTotale'] as double)})',
                  ),
                  const TextSpan(text: '.'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: 26 CANTONS
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2AllCantons() {
    if (_allCantons.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final maxCharge = _allCantons.isNotEmpty
        ? (_allCantons.last['chargeTotale'] as double)
        : 1.0;
    final ecartMax = _allCantons.isNotEmpty
        ? (_allCantons.last['chargeTotale'] as double) -
            (_allCantons.first['chargeTotale'] as double)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Ecart max chiffre choc
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                FiscalService.formatChf(ecartMax),
                style: MintTextStyles.displayMedium(color: MintColors.white),
              ),
              const SizedBox(height: 6),
              Text(
                S.of(context)!.fiscalGapBetweenCantons,
                style: MintTextStyles.bodySmall(color: MintColors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Income info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  S.of(context)!.fiscalIncomeInfoLabel(
                    FiscalService.formatChf(_revenuBrut),
                    _etatCivil == 'marie' ? S.of(context)!.fiscalStatusMarried : S.of(context)!.fiscalStatusSingle,
                    _nombreEnfants > 0 ? S.of(context)!.fiscalChildrenSuffix(_nombreEnfants) : '',
                  ),
                  style: MintTextStyles.bodySmall(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ranking list
        MintSurface(
          tone: MintSurfaceTone.blanc,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: _allCantons.map((c) {
              return CantonRankingBar(
                cantonCode: c['canton'] as String,
                cantonName: c['cantonNom'] as String,
                rang: c['rang'] as int,
                chargeTotale: c['chargeTotale'] as double,
                tauxEffectif: c['tauxEffectif'] as double,
                maxCharge: maxCharge,
                isHighlighted: c['canton'] == _canton,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: DEMENAGER
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Demenager() {
    final sortedCodes = FiscalService.sortedCantonCodes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Intro
        MintEntrance(child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.swap_horiz, color: MintColors.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.of(context)!.fiscalMoveIntro,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 20),

        // Canton pickers
        MintEntrance(delay: const Duration(milliseconds: 100), child: MintSurface(
          tone: MintSurfaceTone.blanc,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // From
              _buildCantonPicker(
                label: S.of(context)!.fiscalCurrentCanton,
                icon: Icons.location_on_outlined,
                value: _cantonDepart,
                codes: sortedCodes,
                onChanged: (v) {
                  _cantonDepart = v;
                  _recalculate();
                },
              ),
              const SizedBox(height: 16),
              // Arrow
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: MintColors.appleSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.south,
                  color: MintColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 16),
              // To
              _buildCantonPicker(
                label: S.of(context)!.fiscalDestinationCanton,
                icon: Icons.flag_outlined,
                value: _cantonArrivee,
                codes: sortedCodes,
                onChanged: (v) {
                  _cantonArrivee = v;
                  _recalculate();
                },
              ),
            ],
          ),
        )),
        const SizedBox(height: 24),

        // Results
        if (_moveResult != null)
          MoveSavingsCard(
            cantonFrom: _cantonDepart,
            cantonFromName:
                FiscalService.cantonNames[_cantonDepart] ?? _cantonDepart,
            cantonTo: _cantonArrivee,
            cantonToName:
                FiscalService.cantonNames[_cantonArrivee] ?? _cantonArrivee,
            chargeFrom: _moveResult!['chargeDepart'] as double,
            chargeTo: _moveResult!['chargeArrivee'] as double,
            economieAnnuelle: _moveResult!['economieAnnuelle'] as double,
            economieMensuelle: _moveResult!['economieMensuelle'] as double,
            economie10Ans: _moveResult!['economie10Ans'] as double,
            chiffreChoc: _moveResult!['chiffreChoc'] as String,
          ),
        if (_fortune > 0) ...[
          const SizedBox(height: 16),
          _buildMoveWealthTaxComparison(),
        ],
        const SizedBox(height: 24),

        // Moving checklist
        MintEntrance(delay: const Duration(milliseconds: 200), child: _buildMoveChecklist()),
        const SizedBox(height: 24),

        // Education
        MintEntrance(delay: const Duration(milliseconds: 300), child: _buildMoveEducation()),
        const SizedBox(height: 24),

        // ── P12-B : Le vrai coût du déménagement cantonal ───
        MovingTrueCostWidget(
          fromCanton: _cantonDepart,
          toCanton: _cantonArrivee,
          movingFees: 3000,
          items: [
            MovingCostItem(
              label: S.of(context)!.fiscalIncomeTaxLabel,
              emoji: '🏛️',
              monthlyBefore:
                  (_moveResult?['chargeDepart'] as double? ?? _revenuBrut * 0.20) / 12,
              monthlyAfter:
                  (_moveResult?['chargeArrivee'] as double? ?? _revenuBrut * 0.15) / 12,
              note: S.of(context)!.fiscalEstimateNote,
            ),
            MovingCostItem(
              label: S.of(context)!.fiscalEstimatedRent,
              emoji: '🏠',
              monthlyBefore: _revenuBrut / 12 * 0.25,
              monthlyAfter: _revenuBrut / 12 * 0.30,
              note: S.of(context)!.fiscalRentNote,
            ),
            MovingCostItem(
              label: S.of(context)!.fiscalMovingCosts,
              emoji: '🚛',
              monthlyBefore: 0,
              monthlyAfter: 3000 / 24,
              note: S.of(context)!.fiscalMovingCostsNote,
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildMoveWealthTaxComparison() {
    final wealthDepart = WealthTaxService.estimateWealthTax(
      fortune: _fortune,
      canton: _cantonDepart,
      etatCivil: _etatCivil,
    );
    final wealthArrivee = WealthTaxService.estimateWealthTax(
      fortune: _fortune,
      canton: _cantonArrivee,
      etatCivil: _etatCivil,
    );
    final impotDepart = wealthDepart['impotFortune'] as double;
    final impotArrivee = wealthArrivee['impotFortune'] as double;
    final difference = impotDepart - impotArrivee;
    final isSaving = difference > 0;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.fiscalWealthTaxTitle,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.fiscalNetWealthAmount(FiscalService.formatChf(_fortune)),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      FiscalService.cantonNames[_cantonDepart] ?? _cantonDepart,
                      style: MintTextStyles.labelSmall(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FiscalService.formatChf(impotDepart),
                      style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: isSaving ? MintColors.success : MintColors.error,
                size: 20,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      FiscalService.cantonNames[_cantonArrivee] ??
                          _cantonArrivee,
                      style: MintTextStyles.labelSmall(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FiscalService.formatChf(impotArrivee),
                      style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              isSaving
                  ? S.of(context)!.fiscalWealthSaving(FiscalService.formatChf(difference))
                  : difference < 0
                      ? S.of(context)!.fiscalWealthSurcharge(FiscalService.formatChf(-difference))
                      : S.of(context)!.fiscalWealthEquivalent,
              style: MintTextStyles.bodyMedium(
                color: isSaving
                    ? MintColors.success
                    : difference < 0
                        ? MintColors.error
                        : MintColors.textSecondary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCantonPicker({
    required String label,
    required IconData icon,
    required String value,
    required List<String> codes,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MintColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
              items: codes.map((code) {
                return DropdownMenuItem(
                  value: code,
                  child: Text('$code — ${FiscalService.cantonNames[code]}'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Move checklist ─────────────────────────────────────

  Widget _buildMoveChecklist() {
    final items = [
      S.of(context)!.fiscalChecklist1,
      S.of(context)!.fiscalChecklist2,
      S.of(context)!.fiscalChecklist3,
      S.of(context)!.fiscalChecklist4,
      S.of(context)!.fiscalChecklist5,
      S.of(context)!.fiscalChecklist6,
    ];

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.fiscalChecklistTitle,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(items.length, (index) {
            final checked = _moveChecked.contains(index);
            return Semantics(
              label: items[index],
              button: true,
              child: GestureDetector(
              onTap: () {
                setState(() {
                  if (checked) {
                    _moveChecked.remove(index);
                  } else {
                    _moveChecked.add(index);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: checked
                            ? MintColors.success
                            : MintColors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: checked
                              ? MintColors.success
                              : MintColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: checked
                          ? const Icon(Icons.check,
                              size: 14, color: MintColors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[index],
                        style: MintTextStyles.bodyMedium(
                          color: checked
                              ? MintColors.textMuted
                              : MintColors.textPrimary,
                        ).copyWith(
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Move education ─────────────────────────────────────

  Widget _buildMoveEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.fiscalGoodToKnow,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEduCard(
          Icons.calendar_today_outlined,
          S.of(context)!.fiscalEduDateTitle,
          S.of(context)!.fiscalEduDateBody,
        ),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.fiscalEduProrataTitle,
          S.of(context)!.fiscalEduProrataBody,
        ),
        _buildEduCard(
          Icons.home_outlined,
          S.of(context)!.fiscalEduRentTitle,
          S.of(context)!.fiscalEduRentBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintSurface(
              padding: const EdgeInsets.all(8),
              radius: 10,
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  /// Commune dropdown reusable widget.
  /// Shows a list of communes for the given canton, sorted by multiplier.
  Widget _buildCommuneDropdown({
    required String? value,
    required String cantonCode,
    required ValueChanged<String?> onChanged,
  }) {
    final communes = CommuneData.listCommunes(cantonCode);
    if (communes.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Text(
            S.of(context)!.fiscalCommune,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: value,
                isExpanded: true,
                hint: Text(
                  S.of(context)!.fiscalCapitalDefault,
                  style: MintTextStyles.bodySmall(),
                ),
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      S.of(context)!.fiscalCapitalDefault,
                      style: MintTextStyles.bodySmall(),
                    ),
                  ),
                  ...communes.map((c) {
                    final name = c['name'] as String;
                    final mult = c['multiplier'] as double;
                    return DropdownMenuItem<String?>(
                      value: name,
                      child: Text(
                        '$name (${mult.toStringAsFixed(2)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.fiscalDisclaimer,
              style: MintTextStyles.micro(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}

