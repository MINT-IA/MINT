import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/donation_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Swiss CHF formatter with apostrophe grouping.
String _formatChfSwiss(double value) {
  final intVal = value.round();
  final isNeg = intVal < 0;
  final str = intVal.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write("'");
    }
    buffer.write(str[i]);
  }
  return '${isNeg ? '-' : ''}${buffer.toString()}';
}

/// Swiss CHF formatter with prefix.
String _chfFmt(double value) {
  return 'CHF\u00A0${_formatChfSwiss(value)}';
}

/// Screen for simulating the tax and succession impact of a donation in Switzerland.
///
/// Covers cantonal donation tax, reserve hereditaire (2023), quotite disponible,
/// and impact on future succession.
/// Sprint S24 — Life Event: donation.
class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  // ── Input state ──
  double _montant = 100000;
  int _donateurAge = 55;
  String _lienParente = 'descendant';
  String _canton = 'VD';
  String _typeDonation = 'especes';
  double _valeurImmobiliere = 500000;
  bool _avancementHoirie = true;
  int _nbEnfants = 2;
  double _fortuneTotaleDonateur = 800000;
  String _regimeMatrimonial = 'participation_acquets';

  // Result
  DonationResult? _result;

  // Checklist state
  List<bool> _checklistState = [];

  static List<String> get _cantons => sortedCantonCodes;

  static const _typesDonation = ['especes', 'immobilier', 'titres'];
  static const _typesDonationLabels = {
    'especes': 'Espèces / Liquidités',
    'immobilier': 'Immobilier',
    'titres': 'Titres / Valeurs mobilières',
  };

  static const _liensParente = [
    'conjoint',
    'descendant',
    'parent',
    'fratrie',
    'concubin',
    'tiers',
  ];

  static const _regimesLabels = {
    'participation_acquets': 'Participation aux acquêts',
    'communaute_biens': 'Communauté de biens',
    'separation_biens': 'Séparation de biens',
  };

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
        if (profile.canton.isNotEmpty) {
          _canton = profile.canton;
        }
        if (profile.age > 0) {
          _donateurAge = profile.age;
        }
        if (profile.nombreEnfants > 0) {
          _nbEnfants = profile.nombreEnfants;
        }
        final totalPatrimoine = profile.patrimoine.totalPatrimoine;
        if (totalPatrimoine > 0) {
          _fortuneTotaleDonateur = totalPatrimoine;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _simulate() {
    setState(() {
      _result = DonationService.calculate(
        montant: _montant,
        donateurAge: _donateurAge,
        lienParente: _lienParente,
        canton: _canton,
        typeDonation: _typeDonation,
        valeurImmobiliere: _valeurImmobiliere,
        avancementHoirie: _avancementHoirie,
        nbEnfants: _nbEnfants,
        fortuneTotaleDonateur: _fortuneTotaleDonateur,
        regimeMatrimonial: _regimeMatrimonial,
      );
      _checklistState = List.filled(_result!.checklist.length, false);
    });

    // Smooth scroll to results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(S.of(context)!.donationAppBarTitle),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MintEntrance(child: _buildHeader()),
            const SizedBox(height: 24),
            MintEntrance(delay: const Duration(milliseconds: 100), child: _buildIntroCard()),
            const SizedBox(height: 24),
            MintEntrance(delay: const Duration(milliseconds: 200), child: _buildDonationSection()),
            const SizedBox(height: 12),
            MintEntrance(delay: const Duration(milliseconds: 300), child: _buildSuccessionContextSection()),
            const SizedBox(height: 24),
            MintEntrance(delay: const Duration(milliseconds: 400), child: _buildSimulateButton()),
            const SizedBox(height: 24),
            if (_result != null) ...[
              Container(key: _resultsKey),
              _buildTaxCard(),
              const SizedBox(height: 24),
              _buildReserveCard(),
              const SizedBox(height: 24),
              _buildQuotiteCard(),
              const SizedBox(height: 24),
              _buildImpactSuccessionCard(),
              const SizedBox(height: 24),
              if (_result!.alerts.isNotEmpty) ...[
                _buildAlertsSection(),
                const SizedBox(height: 24),
              ],
              _buildChecklistSection(),
              const SizedBox(height: 24),
            ],
            _buildEducationalFooter(),
            const SizedBox(height: 24),
            _buildDisclaimer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard,
                color: MintColors.indigo, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.donationHeaderTitle,
                  style: MintTextStyles.headlineMedium(),
                ),
                const SizedBox(height: 2),
                Text(
                  S.of(context)!.donationHeaderSubtitle,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Intro Card ──
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.indigo.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: MintColors.indigo.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.donationIntroText,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section: Donation ──
  Widget _buildDonationSection() {
    return SimulatorCard(
      title: S.of(context)!.donationSectionTitle,
      subtitle: S.of(context)!.donationSectionSubtitle,
      icon: Icons.card_giftcard,
      accentColor: MintColors.indigo,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.donationMontantLabel,
            value: _montant,
            min: 10000,
            max: 2000000,
            divisions: 199,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _montant = v),
          ),
          const SizedBox(height: 16),
          _buildLienParenteChips(),
          const SizedBox(height: 16),
          _buildCantonDropdown(),
          const SizedBox(height: 16),
          _buildTypeDonationChips(),
          if (_typeDonation == 'immobilier') ...[
            const SizedBox(height: 16),
            _buildSlider(
              label: S.of(context)!.donationValeurImmobiliere,
              value: _valeurImmobiliere,
              min: 100000,
              max: 3000000,
              divisions: 58,
              format: (v) => _chfFmt(v),
              onChanged: (v) => setState(() => _valeurImmobiliere = v),
            ),
          ],
          const SizedBox(height: 16),
          _buildSwitch(
            label: S.of(context)!.donationAvancementHoirie,
            value: _avancementHoirie,
            onChanged: (v) => setState(() => _avancementHoirie = v),
          ),
        ],
      ),
    );
  }

  // ── Section: Succession Context ──
  Widget _buildSuccessionContextSection() {
    return SimulatorCard(
      title: S.of(context)!.donationContexteSuccessoral,
      subtitle: S.of(context)!.donationContexteSubtitle,
      icon: Icons.family_restroom,
      accentColor: MintColors.indigo,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.donationAgeLabel,
            value: _donateurAge.toDouble(),
            min: 18,
            max: 95,
            divisions: 77,
            format: (v) => '${v.toInt()} ans',
            onChanged: (v) => setState(() => _donateurAge = v.toInt()),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.donationNbEnfants,
            value: _nbEnfants.toDouble(),
            min: 0,
            max: 6,
            divisions: 6,
            format: (v) => '${v.toInt()}',
            onChanged: (v) => setState(() => _nbEnfants = v.toInt()),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.donationFortuneTotale,
            value: _fortuneTotaleDonateur,
            min: 0,
            max: 5000000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) =>
                setState(() => _fortuneTotaleDonateur = v),
          ),
          const SizedBox(height: 16),
          _buildRegimeChips(),
        ],
      ),
    );
  }

  // ── Lien de Parente Chips ──
  Widget _buildLienParenteChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.donationLienParente,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.sm,
          children: _liensParente.map((lien) {
            final selected = _lienParente == lien;
            return Semantics(
              label: DonationService.lienParenteLabels[lien] ?? lien,
              button: true,
              selected: selected,
              child: GestureDetector(
                onTap: () => setState(() => _lienParente = lien),
                child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? MintColors.indigo.withValues(alpha: 0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? MintColors.indigo
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  DonationService.lienParenteLabels[lien] ?? lien,
                  style: MintTextStyles.labelSmall(
                    color: selected ? MintColors.indigo : MintColors.textSecondary,
                  ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Type Donation Chips ──
  Widget _buildTypeDonationChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.donationTypeDonation,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.sm,
          children: _typesDonation.map((type) {
            final selected = _typeDonation == type;
            return Semantics(
              label: _typesDonationLabels[type] ?? type,
              button: true,
              selected: selected,
              child: GestureDetector(
                onTap: () => setState(() => _typeDonation = type),
                child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? MintColors.indigo.withValues(alpha: 0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? MintColors.indigo
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  _typesDonationLabels[type] ?? type,
                  style: MintTextStyles.labelSmall(
                    color: selected ? MintColors.indigo : MintColors.textSecondary,
                  ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Regime Matrimonial Chips ──
  Widget _buildRegimeChips() {
    final regimes = ['participation_acquets', 'communaute_biens', 'separation_biens'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.donationRegimeMatrimonial,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.sm,
          children: regimes.map((regime) {
            final selected = _regimeMatrimonial == regime;
            return Semantics(
              label: _regimesLabels[regime] ?? regime,
              button: true,
              selected: selected,
              child: GestureDetector(
                onTap: () => setState(() => _regimeMatrimonial = regime),
                child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? MintColors.indigo.withValues(alpha: 0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? MintColors.indigo
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  _regimesLabels[regime] ?? regime,
                  style: MintTextStyles.labelSmall(
                    color: selected ? MintColors.indigo : MintColors.textSecondary,
                  ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Simulate Button ──
  Widget _buildSimulateButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _simulate,
        icon: const Icon(Icons.calculate_outlined, size: 20),
        label: Text(
          S.of(context)!.donationCalculer,
          style: MintTextStyles.titleMedium(color: MintColors.white),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ── Tax Card ──
  Widget _buildTaxCard() {
    final r = _result!;
    final hasTax = r.impotDonation > 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (hasTax ? MintColors.indigo : MintColors.success)
            .withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (hasTax ? MintColors.indigo : MintColors.success)
              .withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.donationImpotTitle,
            style: MintTextStyles.micro(color: hasTax ? MintColors.indigo : MintColors.success).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasTax ? _chfFmt(r.impotDonation) : S.of(context)!.donationExoneree,
            style: MintTextStyles.displayMedium(color: hasTax ? MintColors.indigo : MintColors.success),
          ),
          if (hasTax) ...[
            const SizedBox(height: 4),
            Text(
              S.of(context)!.donationTauxCanton(
                (r.tauxImposition * 100).toStringAsFixed(0),
                _canton,
              ),
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
            ),
          ],
          const SizedBox(height: MintSpacing.md),
          _buildResultRow(
            S.of(context)!.donationMontantRow,
            _chfFmt(r.montantDonation),
          ),
          const SizedBox(height: 4),
          _buildResultRow(
            S.of(context)!.donationLienRow,
            DonationService.lienParenteLabels[_lienParente] ?? _lienParente,
          ),
        ],
      ),
    );
  }

  // ── Reserve Card ──
  Widget _buildReserveCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: MintColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.donationReserveTitle,
                style: MintTextStyles.micro(color: MintColors.warning).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _chfFmt(r.reserveHereditaireTotale),
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.donationReserveProtege,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 12),
          // Visual bar: reserve vs quotite
          _buildReserveBar(r),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.donationReserveNote,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Reserve Bar Visual ──
  Widget _buildReserveBar(DonationResult r) {
    final fortune = _fortuneTotaleDonateur > 0
        ? _fortuneTotaleDonateur
        : r.montantDonation;
    final reservePct =
        fortune > 0 ? (r.reserveHereditaireTotale / fortune).clamp(0.0, 1.0) : 0.0;
    final quotitePct = 1.0 - reservePct;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            if (reservePct > 0)
              Flexible(
                flex: (reservePct * 100).toInt().clamp(1, 99),
                child: Container(
                  color: MintColors.warning,
                  alignment: Alignment.center,
                  child: reservePct > 0.15
                      ? Text(
                          'Réserve ${(reservePct * 100).toStringAsFixed(0)}%',
                          style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
              ),
            if (quotitePct > 0)
              Flexible(
                flex: (quotitePct * 100).toInt().clamp(1, 99),
                child: Container(
                  color: MintColors.success,
                  alignment: Alignment.center,
                  child: quotitePct > 0.15
                      ? Text(
                          'Disponible ${(quotitePct * 100).toStringAsFixed(0)}%',
                          style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Quotite Disponible Card ──
  Widget _buildQuotiteCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (r.donationDepasseQuotite ? MintColors.error : MintColors.success)
            .withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (r.donationDepasseQuotite
                  ? MintColors.error
                  : MintColors.success)
              .withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.donationDepasseQuotite
                    ? Icons.warning_amber_rounded
                    : Icons.edit_note,
                color: r.donationDepasseQuotite
                    ? MintColors.error
                    : MintColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.donationQuotiteTitle,
                style: MintTextStyles.micro(
                  color: r.donationDepasseQuotite ? MintColors.error : MintColors.success,
                ).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _chfFmt(r.quotiteDisponible),
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.donationQuotiteDesc,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          if (r.donationDepasseQuotite) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: MintColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.of(context)!.donationDepassement(_chfFmt(r.montantDepassement)),
                      style: MintTextStyles.bodySmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w600),
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

  // ── Impact Succession Card ──
  Widget _buildImpactSuccessionCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu, color: MintColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.donationImpactTitle,
                style: MintTextStyles.micro(color: MintColors.info).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            r.impactSuccession,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: MintColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _avancementHoirie
                        ? S.of(context)!.donationAvancementNote
                        : S.of(context)!.donationHorsPartNote,
                    style: MintTextStyles.labelSmall(color: MintColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Alerts Section ──
  Widget _buildAlertsSection() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.lifeEventPointsAttention,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...r.alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MintColors.warning.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert,
                        style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ── Checklist Section ──
  Widget _buildChecklistSection() {
    final r = _result!;
    return SimulatorCard(
      title: S.of(context)!.lifeEventActionsTitle,
      subtitle: S.of(context)!.lifeEventChecklistSubtitle,
      icon: Icons.checklist,
      accentColor: MintColors.indigo,
      child: Column(
        children: List.generate(r.checklist.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              label: r.checklist[index],
              button: true,
              toggled: _checklistState[index],
              child: InkWell(
                onTap: () {
                  setState(() {
                    _checklistState[index] = !_checklistState[index];
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _checklistState[index]
                        ? MintColors.success.withValues(alpha: 0.06)
                        : MintColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _checklistState[index]
                          ? MintColors.success.withValues(alpha: 0.3)
                          : MintColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _checklistState[index]
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: _checklistState[index]
                            ? MintColors.success
                            : MintColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          r.checklist[index],
                          style: MintTextStyles.bodySmall(
                            color: _checklistState[index]
                                ? MintColors.textSecondary
                                : MintColors.textPrimary,
                          ).copyWith(
                            decoration: _checklistState[index]
                                ? TextDecoration.lineThrough
                                : null,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
              ),
            ),
            ),
          );
        }),
      ),
    );
  }

  // ── Educational Footer ──
  Widget _buildEducationalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.lifeEventComprendre,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableTile(
          S.of(context)!.donationEduQuotiteTitle,
          S.of(context)!.donationEduQuotiteBody,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.donationEduAvancementTitle,
          S.of(context)!.donationEduAvancementBody,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.donationEduConcubinTitle,
          S.of(context)!.donationEduConcubinBody,
        ),
      ],
    );
  }

  // ── Expandable Tile ──
  Widget _buildExpandableTile(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: MintColors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500),
          ),
          children: [
            Text(
              content,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimer ──
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
          const Icon(Icons.info_outline, size: 18, color: MintColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _result?.disclaimer ??
                  'Cet outil éducatif fournit des estimations indicatives et '
                      'ne constitue pas un conseil juridique, fiscal ou notarial '
                      'personnalisé au sens de la LSFin. Consulte un·e spécialiste '
                      '(notaire) pour ta situation.',
              style: MintTextStyles.micro(color: MintColors.deepOrange).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Canton Dropdown ──
  Widget _buildCantonDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.donationCanton,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _canton,
              isExpanded: true,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
              dropdownColor: MintColors.white,
              items: _cantons.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text('$c \u2014 ${cantonFullNames[c] ?? c}'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _canton = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Result Row ──
  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Switch ──
  Widget _buildSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MintColors.primary,
        ),
      ],
    );
  }

  // ── Slider ──
  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required void Function(double) onChanged,
  }) {
    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      formatValue: format,
      onChanged: (v) {
        setState(() {
          onChanged(v);
        });
      },
    );
  }
}
