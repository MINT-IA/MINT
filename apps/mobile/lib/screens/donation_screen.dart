import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/donation_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:provider/provider.dart';

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

  // Anchors for scroll-to-first-missing when the situation is incomplete.
  final _cantonKey = GlobalKey();
  final _nbEnfantsKey = GlobalKey();
  final _fortuneKey = GlobalKey();
  final _regimeKey = GlobalKey();

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

  // ── P2 « gate dur » : provenance par fait, ré-évaluée à chaque notify ──
  // Un fait de SITUATION n'est CONFIRMÉ que s'il vient des données réelles :
  // soit amorcé depuis un champ profil réellement fourni
  // (`userProvidedFields`), soit touché par l'utilisateur. Une valeur égale à
  // un défaut fabriqué reste ASSUMED (jamais confirmée). Pas de latch global
  // `_prefilled` : `loadFromWizard` notifie jusqu'à 5× (cache→frais→fusionné),
  // un latch au notify #1 échouerait un champ dont la donnée arrive au #2.
  CoachProfileProvider? _profileProvider;
  bool _donateurAgeTouched = false; // âge : confort seul, ne gate jamais.
  bool _cantonTouched = false;
  bool _cantonSeeded = false; // provenance = userProvidedFields('canton').
  bool _nbEnfantsTouched = false; // pas de clé → confirmable au touch seul.
  bool _fortuneTouched = false;
  bool _fortuneSeeded = false; // provenance = userProvidedFields('liquidSavings').
  bool _regimeTouched = false; // pas de clé → confirmable au touch seul.

  // Le résultat n'existe qu'après un calcul explicite ; un changement de fait
  // déterminant le remet à null (stale-result invalidation).
  bool _hasComputed = false;
  bool _lastUnionComplete = false;

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

  /// P2 (zéro donnée inventée) : amorce la situation réelle du donateur depuis
  /// le profil. On s'abonne au provider car `loadFromWizard()` hydrate le profil
  /// de façon asynchrone : l'écran peut être monté avant l'arrivée des données.
  /// Un champ édité par l'utilisateur (touched) n'est jamais réécrasé par une
  /// hydratation tardive ; un champ absent garde son défaut éditable.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    CoachProfileProvider? provider;
    try {
      provider = context.read<CoachProfileProvider>();
    } on ProviderNotFoundException {
      provider = null; // tests unitaires isolés : on garde les défauts.
    }
    if (!identical(provider, _profileProvider)) {
      _profileProvider?.removeListener(_seedFromProfile);
      _profileProvider = provider;
      _profileProvider?.addListener(_seedFromProfile);
    }
    _seedFromProfile();
    // Baseline for the incomplete→complete announce (no spurious announce on
    // first build when the profile already confirms every fact).
    _lastUnionComplete = _unionGate(context).complete;
  }

  /// Provenance-gated seed, re-run on EVERY provider notify (no global latch).
  /// A field seeds — and thereby counts as confirmed — only when its
  /// provenance is real: a `userProvidedFields` key, never value≠default.
  void _seedFromProfile() {
    final profile = _profileProvider?.profile;
    var changed = false; // valeur OU provenance a bougé → rebuild.
    var valueChanged = false; // une valeur CONSOMMÉE par le calcul a bougé.

    if (profile == null) {
      // Profil absent : soit pas encore hydraté (le listener rejouera), soit
      // effacé pendant que l'écran est monté (logout / reset → clear()). Dans
      // les deux cas la provenance issue du profil disparaît : les faits
      // seededFromProfile retombent à non confirmés (un fait TOUCHÉ reste
      // valide, c'est une donnée user). Tout chiffre qui reposait sur une
      // donnée seedée est invalidé — aucun résultat ne survit à sa source.
      if (_cantonSeeded) {
        _cantonSeeded = false;
        changed = true;
      }
      if (_fortuneSeeded) {
        _fortuneSeeded = false;
        changed = true;
      }
      if (changed) {
        _invalidateResult();
        if (mounted) setState(() {});
      }
      return;
    }

    // Âge : non gaté, mais consommé par DonationService.calculate → invalide
    // un résultat déjà calculé s'il change.
    if (!_donateurAgeTouched) {
      final age = profile.ageOrNull;
      if (age != null) {
        final v = age.clamp(18, 95);
        if (v != _donateurAge) {
          _donateurAge = v;
          changed = true;
          valueChanged = true;
        }
      }
    }

    // Canton : provenance RÉ-ÉVALUÉE à chaque notify (jamais latch). Confirmé
    // seulement si l'utilisateur a réellement fourni un canton valide ; si un
    // profil ultérieur ne porte plus la clé, la provenance retombe et le gate
    // se referme.
    if (!_cantonTouched) {
      final c = profile.canton;
      final valid = profile.userProvidedFields.contains('canton') &&
          c.isNotEmpty &&
          c != 'unknown' &&
          _cantons.contains(c);
      if (_cantonSeeded != valid) {
        _cantonSeeded = valid;
        changed = true;
      }
      if (valid && c != _canton) {
        _canton = c;
        changed = true;
        valueChanged = true;
      }
    }

    // Nombre d'enfants : AUCUNE clé userProvidedFields → confirmable au touch
    // seul. On amorce la VALEUR (confort) quand > 0 ; ne confirme jamais le
    // fait (le gate reste tant que non touché).
    if (!_nbEnfantsTouched && profile.nombreEnfants > 0) {
      final v = profile.nombreEnfants.clamp(0, 6);
      if (v != _nbEnfants) {
        _nbEnfants = v;
        changed = true;
        valueChanged = true;
      }
    }

    // Fortune nette : provenance RÉ-ÉVALUÉE à chaque notify (jamais latch).
    // Patrimoine NET (actifs - dettes), accesseur canonique. Un net ≤ 0 est un
    // zéro légitime : la valeur reflète la donnée réelle dès la provenance.
    if (!_fortuneTouched) {
      final hasKey = profile.userProvidedFields.contains('liquidSavings');
      if (_fortuneSeeded != hasKey) {
        _fortuneSeeded = hasKey;
        changed = true;
      }
      if (hasKey) {
        final net =
            profile.patrimoine.patrimoineNet(profile.dettes.totalDettes);
        final v = net.clamp(0.0, 5000000.0);
        if (v != _fortuneTotaleDonateur) {
          _fortuneTotaleDonateur = v;
          changed = true;
          valueChanged = true;
        }
      }
    }

    // Une valeur consommée qui bouge (typiquement une hydratation tardive)
    // invalide tout résultat déjà calculé : sinon un chiffre calculé sur un
    // défaut fabriqué pourrait s'afficher quand le gate s'ouvre plus tard.
    if (valueChanged) _invalidateResult();

    if (changed && mounted) setState(() {});
  }

  /// Un résultat n'est valide que pour les entrées avec lesquelles il a été
  /// calculé. Toute entrée (situation OU scénario) qui bouge le remet à null →
  /// aucun chiffre périmé ne survit à un changement d'entrée.
  void _invalidateResult() {
    _result = null;
    _hasComputed = false;
  }

  // ── P2 provenance getters (live, non-latching) ──
  FactProvenance get _cantonProvenance => _cantonTouched
      ? FactProvenance.touched
      : (_cantonSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _nbEnfantsProvenance =>
      _nbEnfantsTouched ? FactProvenance.touched : FactProvenance.assumed;

  FactProvenance get _fortuneProvenance => _fortuneTouched
      ? FactProvenance.touched
      : (_fortuneSeeded
          ? FactProvenance.seededFromProfile
          : FactProvenance.assumed);

  FactProvenance get _regimeProvenance =>
      _regimeTouched ? FactProvenance.touched : FactProvenance.assumed;

  // ── Per-output gates (determinative facts only) ──
  // Gift tax (cantonal) is determined by canton alone.
  SituationGate _taxGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'canton',
          label: (c) => S.of(c)!.donationGateFactCanton,
          why: (c) => S.of(c)!.donationGateWhyCanton,
          provenance: _cantonProvenance,
          onComplete: () => _scrollToKey(_cantonKey),
        ),
      ]);

  // Réserve / quotité are determined by children count, net wealth, régime.
  SituationGate _reserveGate(BuildContext context) => SituationGate([
        SituationFact(
          key: 'nbEnfants',
          label: (c) => S.of(c)!.donationGateFactEnfants,
          why: (c) => S.of(c)!.donationGateWhyEnfants,
          provenance: _nbEnfantsProvenance,
          onComplete: () => _scrollToKey(_nbEnfantsKey),
        ),
        SituationFact(
          key: 'fortune',
          label: (c) => S.of(c)!.donationGateFactFortune,
          why: (c) => S.of(c)!.donationGateWhyFortune,
          provenance: _fortuneProvenance,
          onComplete: () => _scrollToKey(_fortuneKey),
        ),
        SituationFact(
          key: 'regime',
          label: (c) => S.of(c)!.donationGateFactRegime,
          why: (c) => S.of(c)!.donationGateWhyRegime,
          provenance: _regimeProvenance,
          onComplete: () => _scrollToKey(_regimeKey),
        ),
      ]);

  // Union used by the CTA counter + scroll routing (canton first on screen).
  SituationGate _unionGate(BuildContext context) => SituationGate([
        ..._taxGate(context).facts,
        ..._reserveGate(context).facts,
      ]);

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  void _scrollToFirstMissing() {
    final missing = _unionGate(context).missing;
    if (missing.isEmpty) return;
    missing.first.onComplete?.call();
  }

  /// Situation-fact edit hook: invalidate any stale figure (a displayed number
  /// must never outlive a fact change) and announce a gate lift for VoiceOver.
  void _afterFactChanged() {
    _invalidateResult();
    final nowComplete = _unionGate(context).complete;
    if (nowComplete && !_lastUnionComplete) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        S.of(context)!.situationGateAnnounceComplete,
        Directionality.of(context),
      );
    }
    _lastUnionComplete = nowComplete;
  }

  @override
  void dispose() {
    _profileProvider?.removeListener(_seedFromProfile);
    _scrollController.dispose();
    super.dispose();
  }

  /// @visibleForTesting : valeurs amorcées (preuve du seed profil, P2).
  @visibleForTesting
  int get debugDonateurAge => _donateurAge;
  @visibleForTesting
  String get debugCanton => _canton;
  @visibleForTesting
  int get debugNbEnfants => _nbEnfants;
  @visibleForTesting
  double get debugFortuneTotale => _fortuneTotaleDonateur;

  void _simulate() {
    final taxComplete = _taxGate(context).complete;
    final reserveComplete = _reserveGate(context).complete;

    // Compute-time gate : if no output has its determinative facts confirmed,
    // produce NO figure at all — surface the gate + scroll to the first gap.
    if (!taxComplete && !reserveComplete) {
      setState(() {
        _result = null;
        _hasComputed = true;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToFirstMissing());
      return;
    }

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
      _hasComputed = true;
    });

    final unionComplete = taxComplete && reserveComplete;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (unionComplete && _resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      } else {
        // A partially-gated compute still nudges the user to the next gap.
        _scrollToFirstMissing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final union = _unionGate(context);
    final bothOutputsUnlocked = _result != null &&
        _taxGate(context).complete &&
        _reserveGate(context).complete;
    // ILLOG-02 fix: screen-root Semantics container (rente_vs_capital pattern).
    // Without this the iOS AX bridge collapses the whole route into a single
    // header node and `idb ui describe-all` reports "1 element".
    return Semantics(
      identifier: 'donation_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
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
              MintEntrance(
                delay: const Duration(milliseconds: 100),
                child: _buildIntroCard(),
              ),
              const SizedBox(height: 24),
              MintEntrance(
                delay: const Duration(milliseconds: 150),
                child: _buildDonationSection(),
              ),
              const SizedBox(height: 12),
              MintEntrance(
                delay: const Duration(milliseconds: 200),
                child: _buildSuccessionContextSection(),
              ),
              const SizedBox(height: 24),
              _buildSimulateButton(union),
              const SizedBox(height: 24),
              if (_hasComputed) ...[
                Container(key: _resultsKey),
                // Gift-tax output slot (gated on canton).
                MintEntrance(child: _buildTaxSlot()),
                const SizedBox(height: 24),
                // Réserve / quotité output slot (gated on nbEnfants+fortune+régime).
                MintEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: _buildReserveSlot(),
                ),
                const SizedBox(height: 24),
                // Secondary cards need BOTH outputs (they cite the quotité).
                if (bothOutputsUnlocked) ...[
                  MintEntrance(
                    delay: const Duration(milliseconds: 200),
                    child: _buildImpactSuccessionCard(),
                  ),
                  const SizedBox(height: 24),
                  if (_result!.alerts.isNotEmpty) ...[
                    MintEntrance(
                      delay: const Duration(milliseconds: 350),
                      child: _buildAlertsSection(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  MintEntrance(
                    delay: const Duration(milliseconds: 400),
                    child: _buildChecklistSection(),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
              _buildEducationalFooter(),
              const SizedBox(height: 24),
              _buildDisclaimer(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Gift-tax output: the figure only when its determinative fact (canton) is
  /// confirmed and a result exists; otherwise the gate card.
  Widget _buildTaxSlot() {
    if (_result != null && _taxGate(context).complete) {
      return _buildTaxCard();
    }
    return SituationGateCard(
      title: S.of(context)!.donationGateTitle,
      gate: _taxGate(context),
    );
  }

  /// Réserve / quotité output: both figures together, or the gate card.
  Widget _buildReserveSlot() {
    if (_result != null && _reserveGate(context).complete) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReserveCard(),
          const SizedBox(height: 24),
          _buildQuotiteCard(),
        ],
      );
    }
    return SituationGateCard(
      title: S.of(context)!.donationGateTitle,
      gate: _reserveGate(context),
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
          MintAmountField(
            label: S.of(context)!.donationMontantLabel,
            value: _montant,
            formatValue: (v) => _chfFmt(v),
            onChanged: (v) => setState(() {
              _montant = v;
              _invalidateResult();
            }),
            min: 10000,
            max: 2000000,
          ),
          const SizedBox(height: 16),
          _buildLienParenteChips(),
          const SizedBox(height: 16),
          _buildCantonDropdown(),
          const SizedBox(height: 16),
          _buildTypeDonationChips(),
          if (_typeDonation == 'immobilier') ...[
            const SizedBox(height: 16),
            MintAmountField(
              label: S.of(context)!.donationValeurImmobiliere,
              value: _valeurImmobiliere,
              formatValue: (v) => _chfFmt(v),
              onChanged: (v) => setState(() {
                _valeurImmobiliere = v;
                _invalidateResult();
              }),
              min: 100000,
              max: 3000000,
            ),
          ],
          const SizedBox(height: 16),
          _buildSwitch(
            label: S.of(context)!.donationAvancementHoirie,
            value: _avancementHoirie,
            onChanged: (v) => setState(() {
              _avancementHoirie = v;
              _invalidateResult();
            }),
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
          MintPickerTile(
            label: S.of(context)!.donationAgeLabel,
            value: _donateurAge,
            minValue: 18,
            maxValue: 95,
            formatValue: (v) => '$v ans',
            onChanged: (v) => setState(() {
              _donateurAgeTouched = true;
              _donateurAge = v;
              _invalidateResult();
            }),
          ),
          const SizedBox(height: 16),
          MintPickerTile(
            key: _nbEnfantsKey,
            label: S.of(context)!.donationNbEnfants,
            value: _nbEnfants,
            minValue: 0,
            maxValue: 6,
            formatValue: (v) => '$v',
            onChanged: (v) => setState(() {
              _nbEnfantsTouched = true;
              _nbEnfants = v;
              _afterFactChanged();
            }),
          ),
          const SizedBox(height: 16),
          MintAmountField(
            key: _fortuneKey,
            label: S.of(context)!.donationFortuneTotale,
            value: _fortuneTotaleDonateur,
            formatValue: (v) => _chfFmt(v),
            onChanged: (v) => setState(() {
              _fortuneTouched = true;
              _fortuneSeeded = false; // touched supersede le seed → donnée user,
              // immunisée à un clear de profil.
              _fortuneTotaleDonateur = v;
              _afterFactChanged();
            }),
            min: 0,
            max: 5000000,
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
                onTap: () => setState(() {
                  _lienParente = lien;
                  _invalidateResult();
                }),
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
                onTap: () => setState(() {
                  _typeDonation = type;
                  _invalidateResult();
                }),
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
      key: _regimeKey,
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
                key: ValueKey('donationRegime_$regime'),
                onTap: () => setState(() {
                  // Touching a régime chip (even the current one) confirms it.
                  _regimeMatrimonial = regime;
                  _regimeTouched = true;
                  _afterFactChanged();
                }),
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
  // Label morphs to « Compléter ma situation (N/total) » while any required
  // fact is unconfirmed; tapping then scrolls to the first gap instead of
  // computing on fabricated data. Never silently hard-disabled.
  Widget _buildSimulateButton(SituationGate union) {
    final complete = union.complete;
    final label = complete
        ? S.of(context)!.donationCalculer
        : S.of(context)!.donationCompleterSituation(
            union.confirmedCount,
            union.total,
          );
    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _simulate();
          },
          icon: Icon(
            complete ? Icons.calculate_outlined : Icons.edit_note,
            size: 20,
          ),
          label: Text(
            label,
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
      ),
    );
  }

  // ── Tax Card ──
  Widget _buildTaxCard() {
    final r = _result!;
    final hasTax = r.impotDonation > 0;
    final accentColor = hasTax ? MintColors.indigo : MintColors.success;
    return MintResultHeroCard(
      key: const Key('donationTaxCard'),
      eyebrow: S.of(context)!.donationImpotTitle,
      primaryValue: hasTax ? _chfFmt(r.impotDonation) : S.of(context)!.donationExoneree,
      primaryLabel: hasTax
          ? S.of(context)!.donationTauxCanton(
              (r.tauxImposition * 100).toStringAsFixed(0),
              _canton,
            )
          : '${S.of(context)!.donationMontantRow}\u00A0:\u00A0${_chfFmt(r.montantDonation)}',
      secondaryValue: hasTax ? _chfFmt(r.montantDonation) : null,
      secondaryLabel: hasTax ? S.of(context)!.donationMontantRow : null,
      narrative: '${S.of(context)!.donationLienRow}\u00A0:\u00A0${DonationService.lienParenteLabels[_lienParente] ?? _lienParente}',
      accentColor: accentColor,
      tone: MintSurfaceTone.porcelaine,
    );
  }

  // ── Reserve Card ──
  Widget _buildReserveCard() {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.peche,
      elevated: true,
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
            key: const Key('donationReserveFigure'),
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
            key: const Key('donationQuotiteFigure'),
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
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      elevated: true,
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
      key: _cantonKey,
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
                if (v != null) {
                  setState(() {
                    _cantonTouched = true;
                    _cantonSeeded = false; // touched supersede le seed → donnée
                    // user, immunisée à un clear de profil.
                    _canton = v;
                    _afterFactChanged();
                  });
                }
              },
            ),
          ),
        ),
      ],
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

}
