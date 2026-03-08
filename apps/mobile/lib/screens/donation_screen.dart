import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/donation_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';

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
        title: const Text('Donation — Simulateur'),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildIntroCard(),
            const SizedBox(height: 24),
            _buildDonationSection(),
            const SizedBox(height: 12),
            _buildSuccessionContextSection(),
            const SizedBox(height: 24),
            _buildSimulateButton(),
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
              color: Colors.indigo.shade600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.card_giftcard,
                color: Colors.indigo.shade600, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simuler une donation',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fiscalité, réserve héréditaire, impact',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
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
        color: Colors.indigo.shade600.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.indigo.shade600.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: Colors.indigo.shade600.withOpacity(0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les donations en Suisse sont soumises à un impôt cantonal '
              'qui varie selon le lien de parenté et le canton. Depuis '
              '2023, la réserve héréditaire a été réduite, te donnant plus '
              'de liberté. Cet outil t\'aide à estimer l\'impôt et à '
              'vérifier la compatibilité avec les droits des héritiers.',
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

  // ── Section: Donation ──
  Widget _buildDonationSection() {
    return SimulatorCard(
      title: 'DONATION',
      subtitle: 'Montant, bénéficiaire, type',
      icon: Icons.card_giftcard,
      accentColor: Colors.indigo.shade600,
      child: Column(
        children: [
          _buildSlider(
            label: 'Montant de la donation',
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
              label: 'Valeur immobilière',
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
            label: 'Avancement d\'hoirie',
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
      title: 'CONTEXTE SUCCESSORAL',
      subtitle: 'Famille, fortune, régime matrimonial',
      icon: Icons.family_restroom,
      accentColor: Colors.indigo.shade600,
      child: Column(
        children: [
          _buildSlider(
            label: 'Âge du donateur',
            value: _donateurAge.toDouble(),
            min: 18,
            max: 95,
            divisions: 77,
            format: (v) => '${v.toInt()} ans',
            onChanged: (v) => setState(() => _donateurAge = v.toInt()),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Nombre d\'enfants',
            value: _nbEnfants.toDouble(),
            min: 0,
            max: 6,
            divisions: 6,
            format: (v) => '${v.toInt()}',
            onChanged: (v) => setState(() => _nbEnfants = v.toInt()),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Fortune totale du donateur',
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
          'Lien de parenté',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _liensParente.map((lien) {
            final selected = _lienParente == lien;
            return GestureDetector(
              onTap: () => setState(() => _lienParente = lien),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.indigo.shade600.withOpacity(0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Colors.indigo.shade600
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  DonationService.lienParenteLabels[lien] ?? lien,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? Colors.indigo.shade600
                        : MintColors.textSecondary,
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
          'Type de donation',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _typesDonation.map((type) {
            final selected = _typeDonation == type;
            return GestureDetector(
              onTap: () => setState(() => _typeDonation = type),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.indigo.shade600.withOpacity(0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Colors.indigo.shade600
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  _typesDonationLabels[type] ?? type,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? Colors.indigo.shade600
                        : MintColors.textSecondary,
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
          'Régime matrimonial',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: regimes.map((regime) {
            final selected = _regimeMatrimonial == regime;
            return GestureDetector(
              onTap: () => setState(() => _regimeMatrimonial = regime),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.indigo.shade600.withOpacity(0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Colors.indigo.shade600
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  _regimesLabels[regime] ?? regime,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? Colors.indigo.shade600
                        : MintColors.textSecondary,
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
          'Calculer',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: Colors.white,
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
        color: (hasTax ? Colors.indigo.shade600 : MintColors.success)
            .withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (hasTax ? Colors.indigo.shade600 : MintColors.success)
              .withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            'IMPÔT SUR LA DONATION',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: hasTax ? Colors.indigo.shade600 : MintColors.success,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasTax ? _chfFmt(r.impotDonation) : 'Exonérée',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: hasTax ? Colors.indigo.shade600 : MintColors.success,
            ),
          ),
          if (hasTax) ...[
            const SizedBox(height: 4),
            Text(
              'Taux : ${(r.tauxImposition * 100).toStringAsFixed(0)}% '
              '(canton $_canton)',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildResultRow(
            'Montant de la donation',
            _chfFmt(r.montantDonation),
          ),
          const SizedBox(height: 4),
          _buildResultRow(
            'Lien de parenté',
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
        color: MintColors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.warning.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: MintColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'RÉSERVE HÉRÉDITAIRE (2023)',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MintColors.warning,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _chfFmt(r.reserveHereditaireTotale),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'montant protégé par la loi (intouchable)',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Visual bar: reserve vs quotite
          _buildReserveBar(r),
          const SizedBox(height: 12),
          Text(
            'Depuis 2023, les parents n\'ont plus de réserve. '
            'La réserve des descendants est de 50% de leur part légale '
            '(CC art. 471).',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
              height: 1.5,
            ),
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
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
            .withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (r.donationDepasseQuotite
                  ? MintColors.error
                  : MintColors.success)
              .withOpacity(0.15),
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
                'QUOTITÉ DISPONIBLE',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: r.donationDepasseQuotite
                      ? MintColors.error
                      : MintColors.success,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _chfFmt(r.quotiteDisponible),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'montant que tu peux librement donner',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          if (r.donationDepasseQuotite) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: MintColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dépassement de ${_chfFmt(r.montantDepassement)} — '
                      'risque d\'action en réduction',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.error,
                      ),
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
        color: MintColors.info.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.info.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, color: MintColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'IMPACT SUR LA SUCCESSION',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MintColors.info,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            r.impactSuccession,
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
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: MintColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _avancementHoirie
                        ? 'Avancement d\'hoirie : la donation sera rapportée '
                            'à la masse successorale.'
                        : 'Donation hors part : elle est imputée sur la '
                            'quotité disponible uniquement.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.info,
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

  // ── Alerts Section ──
  Widget _buildAlertsSection() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POINTS D\'ATTENTION',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...r.alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintColors.warning.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MintColors.warning.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                          height: 1.4,
                        ),
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
      title: 'Actions à entreprendre',
      subtitle: 'Checklist de préparation',
      icon: Icons.checklist,
      accentColor: Colors.indigo.shade600,
      child: Column(
        children: List.generate(r.checklist.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
                      ? MintColors.success.withOpacity(0.06)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _checklistState[index]
                        ? MintColors.success.withOpacity(0.3)
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
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _checklistState[index]
                              ? MintColors.textSecondary
                              : MintColors.textPrimary,
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
          'COMPRENDRE',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableTile(
          'Qu\'est-ce que la quotité disponible ?',
          'La quotité disponible est la part de ta fortune que tu peux '
              'librement donner ou léguer sans empiéter sur les réserves '
              'héréditaires. Depuis le 1er janvier 2023, la réserve des '
              'descendants a été réduite de 3/4 à 1/2 de leur part légale, '
              'et les parents n\'ont plus de réserve. Cela te donne plus '
              'de liberté pour effectuer des donations.',
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          'Avancement d\'hoirie vs donation hors part',
          'Une donation en avancement d\'hoirie est une avance sur '
              'la part successorale du bénéficiaire. Elle sera rapportée '
              'à la masse successorale lors du décès. Une donation hors '
              'part (ou préciput) est imputée uniquement sur la quotité '
              'disponible et n\'est pas rapportée. Le choix entre les deux '
              'a un impact majeur sur l\'équilibre entre les héritiers.',
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          'Donations et concubins',
          'Les concubins n\'ont aucun droit successoral légal en Suisse. '
              'Une donation est le moyen le plus direct de les avantager. '
              'Cependant, l\'impôt cantonal sur les donations entre concubins '
              'est généralement élevé (18-25% selon les cantons). Schwyz fait '
              'exception : aucun impôt sur les donations quel que soit le lien. '
              'Envisager un testament en complément pour une protection complète.',
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
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
          children: [
            Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _result?.disclaimer ??
                  'Cet outil éducatif fournit des estimations indicatives et '
                      'ne constitue pas un conseil juridique, fiscal ou notarial '
                      'personnalisé au sens de la LSFin. Consulte un·e spécialiste '
                      '(notaire) pour ta situation.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
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
          'Canton',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
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
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textPrimary,
              ),
              dropdownColor: Colors.white,
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
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
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
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: MintColors.primary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              format(value),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) {
              setState(() {
                onChanged(v);
              });
            },
          ),
        ),
      ],
    );
  }
}
