import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/widgets/coach/debt_survival_widget.dart';
import 'package:mint_mobile/widgets/common/debt_tools_nav.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Ecran de planification du remboursement de dettes.
///
/// Compare les strategies avalanche (taux haut d'abord) et
/// boule de neige (petit solde d'abord).
class RepaymentScreen extends StatefulWidget {
  const RepaymentScreen({super.key});

  @override
  State<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends State<RepaymentScreen> {
  bool _hasUserInteracted = false;
  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
      _hydrateFromProfile();
      // Beads -g5v (4) : si le profil charge APRÈS la première frame
      // (hydratation async), ré-hydrater tant que l'utilisateur n'a pas
      // commencé à éditer — sinon l'écran reste sur l'état vide/défauts.
      try {
        _profileProvider = context.read<CoachProfileProvider>();
        _profileProvider!.addListener(_onProfileChanged);
      } catch (_) {
        // Pas de provider (harnais isolé) : hydratation one-shot.
      }
    });
  }

  CoachProfileProvider? _profileProvider;

  void _onProfileChanged() {
    if (!mounted || _hasUserInteracted) return;
    _hydrateFromProfile();
  }

  @override
  void dispose() {
    _profileProvider?.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {
      // Not navigated via GoRouter or no extra — stay Tier B.
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      final screenReturn = ScreenReturn.abandoned(
        route: '/debt/repayment',
        runId: _seqRunId,
        stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      ScreenCompletionTracker.markCompletedWithReturn('repayment', screenReturn);
      return;
    }

    final result = _result;
    final screenReturn = ScreenReturn.completed(
      route: '/debt/repayment',
      stepOutputs: {
        'horizon_mois': result?.avalanche.moisJusquaLiberation ?? 0,
        'versement_mensuel': _budgetMensuel,
      },
      runId: _seqRunId,
      stepId: _seqStepId,
      eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
    );
    ScreenCompletionTracker.markCompletedWithReturn('repayment', screenReturn);
  }

  // beads MINT_nosync-64r (ILLOG-01) : plus AUCUNE dette fictive par défaut.
  // La liste est hydratée depuis profile.dettes ; sans dette connue, l'écran
  // affiche un état vide explicite — jamais du fictif indiscernable du réel.
  final List<_DebtInput> _dettes = [];

  double _budgetMensuel = 800;
  // -g5v r2 : le déficit réel exige que le BUDGET ait été saisi — éditer
  // un taux ne fait pas du 800 par défaut un budget voulu.
  bool _budgetTouched = false;
  double _monthlyIncome = 0;

  void _hydrateFromProfile() {
    if (!mounted) return;
    final CoachProfile? profile;
    try {
      profile = context.read<CoachProfileProvider>().profile;
    } catch (_) {
      // Pas de provider au-dessus (harnais de test isolé, deeplink froid) :
      // l'écran reste utilisable avec sa liste vide — jamais de fiction.
      return;
    }
    if (profile == null) return;
    final CoachProfile p = profile;
    final s = S.of(context)!;
    final d = p.dettes;
    setState(() {
      _monthlyIncome = p.salaireBrutMensuel * p.nombreDeMois / 12;
      // Panel -g5v : hydratation IDEMPOTENTE — le listener re-déclenche à
      // chaque notify du provider ; sans clear, les dettes se dupliquaient
      // (Σmin doublée -> tous les chiffres faux).
      _dettes.clear();
      if ((d.creditConsommation ?? 0) > 0) {
        _dettes.add(_DebtInput(
          nom: s.repaymentDebtCreditConso,
          montant: d.creditConsommation!,
          // Taux inconnu -> hypothèse visible ET éditable dans le champ
          // (taux conso suisse typique), pas une valeur cachée.
          tauxAnnuel: d.tauxCreditConso ?? 9.9,
          mensualiteMin: d.mensualiteCreditConso ??
              (d.creditConsommation! * 0.02).roundToDouble(),
          tauxEstime: d.tauxCreditConso == null,
          mensualiteEstimee: d.mensualiteCreditConso == null,
        ));
      }
      if ((d.leasing ?? 0) > 0) {
        _dettes.add(_DebtInput(
          nom: s.repaymentDebtLeasing,
          montant: d.leasing!,
          tauxAnnuel: d.tauxLeasing ?? 4.9,
          mensualiteMin:
              d.mensualiteLeasing ?? (d.leasing! * 0.03).roundToDouble(),
          tauxEstime: d.tauxLeasing == null,
          mensualiteEstimee: d.mensualiteLeasing == null,
        ));
      }
      if ((d.autresDettes ?? 0) > 0) {
        _dettes.add(_DebtInput(
          nom: s.repaymentDebtAutres,
          montant: d.autresDettes!,
          tauxAnnuel: 5.0,
          mensualiteMin: (d.autresDettes! * 0.02).roundToDouble(),
          tauxEstime: true,
          mensualiteEstimee: true,
        ));
      }
    });
  }

  double get _sumMensualitesMin =>
      _dettes.fold<double>(0, (s, d) => s + d.mensualiteMin);

  /// Budget réellement utilisé par le planner : jamais sous les minimums
  /// contractuels (miroir de RepaymentPlanner max(budget, sumMin)) —
  /// beads -g5v, l'UI doit montrer CE montant quand il diffère du saisi.
  double get _budgetEffectif => _budgetMensuel > _sumMensualitesMin
      ? _budgetMensuel
      : _sumMensualitesMin;

  RepaymentComparisonResult? get _result {
    if (_dettes.isEmpty) return null;
    final dettes = _dettes
        .where((d) => d.montant > 0)
        .map((d) => Debt(
              nom: d.nom,
              montant: d.montant,
              tauxAnnuel: d.tauxAnnuel / 100,
              mensualiteMin: d.mensualiteMin,
            ))
        .toList();
    if (dettes.isEmpty) return null;
    return RepaymentPlanner.plan(
      dettes: dettes,
      budgetMensuelRemboursement: _budgetMensuel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
      backgroundColor: MintColors.white,
      // AX iOS 26.2 (ADR 2026-07-30, tranche AX 3) : AppBar classique fixe en
      // `Scaffold.appBar`, plus de SliverAppBar dans le CustomScrollView (2e
      // déclencheur d'effondrement de l'arbre AX des routes poussées au scroll).
      appBar: AppBar(
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: MintColors.textPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => safePop(context),
            ),
            title: Text(
              S.of(context)!.repaymentTitle,
              style: MintTextStyles.titleMedium(),
            ),
          ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── P10-F : Mode survie MINT ──────────────────────
                // Rendu UNIQUEMENT sur des dettes réelles (profil ou
                // saisies) — jamais « libéré/critique » sur du fictif.
                if (_dettes.isNotEmpty) ...[
                  // Beads -g5v : marge basée sur le budget EFFECTIF du
                  // planner (max(budget, Σminimums)) — l'ancien calcul
                  // « budget saisi − minimums » devenait négatif sur le
                  // placeholder 800 et pilotait un état « critique » fictif.
                  MintEntrance(child: DebtSurvivalWidget(
                    totalDebt:
                        _dettes.fold<double>(0, (s, d) => s + d.montant),
                    // Budget SAISI insuffisant -> déficit RÉEL (négatif
                    // légitime, mode critique mérité). Placeholder jamais
                    // touché -> budget effectif (pas de critique fictif).
                    monthlyMargin: _budgetTouched
                        ? _budgetMensuel - _sumMensualitesMin
                        : _budgetEffectif - _sumMensualitesMin,
                    daysSinceLastLate: 0,
                    monthlyIncome: _monthlyIncome,
                  )),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Chiffre choc
                if (result != null) ...[
                  MintEntrance(delay: const Duration(milliseconds: 100), child: _buildPremierEclairage(result)),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Liste des dettes
                MintEntrance(delay: const Duration(milliseconds: 150), child: _buildDettesSection()),
                const SizedBox(height: MintSpacing.lg),

                // Budget mensuel
                _buildBudgetSection(),
                const SizedBox(height: MintSpacing.lg),

                // Comparaison strategies
                if (result != null) ...[
                  MintEntrance(child: _buildComparisonSection(result)),
                  const SizedBox(height: MintSpacing.sm + 4),
                  _buildStrategyNote(),
                  const SizedBox(height: MintSpacing.lg),

                  // Timeline
                  MintEntrance(delay: const Duration(milliseconds: 100), child: _buildTimelineSection(result)),
                  const SizedBox(height: MintSpacing.lg),

                  // Disclaimer
                  _buildDisclaimer(result.disclaimer),
                ] else
                  _buildEmptyState(),

                const SizedBox(height: MintSpacing.lg),

                // Navigation croisée dette
                const DebtToolsNav(currentRoute: '/debt/repayment'),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildPremierEclairage(RepaymentComparisonResult result) {
    final color = switch (result.premierEclairage.niveau) {
      DebtRiskLevel.vert => MintColors.success,
      DebtRiskLevel.orange => MintColors.warning,
      DebtRiskLevel.rouge => MintColors.error,
    };

    // Show the shorter duration between both strategies (no ranking)
    final strategiePrioritaire = result.avalanche.moisJusquaLiberation <=
            result.bouleDeNeige.moisJusquaLiberation
        ? result.avalanche
        : result.bouleDeNeige;

    final tone = switch (result.premierEclairage.niveau) {
      DebtRiskLevel.vert => MintSurfaceTone.sauge,
      DebtRiskLevel.orange => MintSurfaceTone.peche,
      DebtRiskLevel.rouge => MintSurfaceTone.blanc,
    };

    return MintSurface(
      tone: tone,
      padding: const EdgeInsets.all(24),
      child: Semantics(
        label: S.of(context)!.semanticsRepaymentFreeIn(strategiePrioritaire.moisJusquaLiberation),
        child: Column(
          children: [
            Text(
              S.of(context)!.repaymentLibereDans,
              style: MintTextStyles.bodySmall(color: color)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: MintSpacing.sm),
            MintHeroNumber(
              value: '${strategiePrioritaire.moisJusquaLiberation}',
              caption: 'mois',
              color: color,
            ),
            const SizedBox(height: 4),
            if (result.economieInterets > 0)
              Text(
                S.of(context)!.repaymentDiffStrategies(formatChf(result.economieInterets)),
                style: MintTextStyles.labelMedium(color: color),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDettesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.repaymentMesDettes,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: MintColors.primary),
                onPressed: _addDebt,
                tooltip: S.of(context)!.repaymentAddDebtTooltip,
              ),
            ],
          ),
          const SizedBox(height: 8),

          for (int i = 0; i < _dettes.length; i++) ...[
            _buildDebtCard(i),
            if (i < _dettes.length - 1) const SizedBox(height: 12),
          ],

          // Cardinalité état vide (panel + review -64r) : quand la liste est
          // vide, l'UNIQUE invite est repaymentEmptyState en bas d'écran —
          // pas de hint dupliqué ici.
        ],
      ),
    );
  }

  Widget _buildDebtCard(int index) {
    final dette = _dettes[index];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: nom éditable + supprimer
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: dette.nom,
                  // Review #992 r2 : armer le gel dès la PRISE DE FOCUS —
                  // un notify pendant la frappe du nom réhydratait la liste
                  // (clear+rebuild) et orphelinait ce champ.
                  onTap: () => _hasUserInteracted = true,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: S.of(context)!.repaymentDebtNameHint,
                    hintStyle: TextStyle(
                      color: MintColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                  onChanged: (v) => setState(() { _hasUserInteracted = true; dette.nom = v; }),
                ),
              ),
              Semantics(
                button: true,
                label: S.of(context)!.semanticsRepaymentDeleteDebt(dette.nom),
                child: GestureDetector(
                  // -g5v : la suppression est une INTERACTION — sans le
                  // flag, la dette ressuscitait au prochain notify.
                  onTap: () => setState(() {
                    _hasUserInteracted = true;
                    _dettes.removeAt(index);
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: MintColors.redBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const ExcludeSemantics(child: Icon(Icons.close,
                        color: MintColors.redMedium, size: 14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 inline value fields
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildInlineValue(
                  label: S.of(context)!.repaymentFieldAmount,
                  display: 'CHF\u00a0${formatChf(dette.montant)}',
                  onTap: () => _showValueEditor(
                    label: S.of(context)!.repaymentFieldAmountLabel,
                    currentValue: dette.montant,
                    min: 500,
                    max: 100000,
                    prefix: 'CHF',
                    onChanged: (v) => setState(() { _hasUserInteracted = true; dette.montant = v; }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildInlineValue(
                  label: dette.tauxEstime
                      ? S.of(context)!.repaymentFieldRateEstimated
                      : S.of(context)!.repaymentFieldRate,
                  display: '${dette.tauxAnnuel.toStringAsFixed(1)}\u00a0%',
                  onTap: () => _showValueEditor(
                    label: S.of(context)!.repaymentFieldRateLabel,
                    currentValue: dette.tauxAnnuel,
                    min: 0.5,
                    max: 20.0,
                    prefix: '',
                    suffix: '%',
                    decimals: true,
                    onChanged: (v) => setState(() {
                      _hasUserInteracted = true;
                      dette.tauxAnnuel = v;
                      dette.tauxEstime = false;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildInlineValue(
                  label: dette.mensualiteEstimee
                      ? S.of(context)!.repaymentFieldInstallmentEstimated
                      : S.of(context)!.repaymentFieldInstallment,
                  display: 'CHF\u00a0${formatChf(dette.mensualiteMin)}',
                  onTap: () => _showValueEditor(
                    label: S.of(context)!.repaymentFieldInstallmentLabel,
                    currentValue: dette.mensualiteMin,
                    min: 50,
                    max: 3000,
                    prefix: 'CHF',
                    onChanged: (v) => setState(() {
                      _hasUserInteracted = true;
                      dette.mensualiteMin = v;
                      dette.mensualiteEstimee = false;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Champ inline tappable — label + valeur.
  Widget _buildInlineValue({
    required String label,
    required String display,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: MintTextStyles.labelSmall(
                color: MintColors.textMuted,
              ).copyWith(letterSpacing: 0.5),
            ),
            const SizedBox(height: 3),
            Text(
              display,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet pour saisie précise au clavier.
  void _showValueEditor({
    required String label,
    required double currentValue,
    required double min,
    required double max,
    required String prefix,
    String? suffix,
    bool decimals = false,
    required ValueChanged<double> onChanged,
  }) {
    // -g5v r2 : dès l'ouverture d'un éditeur, geler l'hydratation — un
    // notify pendant la saisie reconstruisait la liste et orphelinait
    // l'objet dette capturé (la saisie disparaissait).
    _hasUserInteracted = true;
    final controller = TextEditingController(
      text: decimals
          ? currentValue.toStringAsFixed(1)
          : currentValue.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                label,
                style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: MintSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (prefix.isNotEmpty)
                    Text(
                      '$prefix ',
                      style: MintTextStyles.headlineMedium(color: MintColors.textMuted)
                          ,
                    ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: decimals,
                      ),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: MintTextStyles.displayMedium(color: MintColors.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (suffix != null)
                    Text(
                      ' $suffix',
                      style: MintTextStyles.headlineMedium(color: MintColors.textMuted)
                          ,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context)!.repaymentMinMax(
                  decimals ? min.toStringAsFixed(1) : formatChf(min),
                  decimals ? max.toStringAsFixed(1) : formatChf(max),
                ),
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: S.of(context)!.semanticsRepaymentValidate,
                child: SizedBox(
                width: double.infinity,
                // Bouton pré-existant déplacé par ce diff — MintCTA arrive en
                // Phase MVP-CTA-UNIFICATION-V1.
                child: FilledButton( // lint-ignore: prefer_mint_cta
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final parsed = double.tryParse(
                      controller.text
                          .replaceAll("'", '')
                          .replaceAll(',', '.')
                          .replaceAll(RegExp(r"[^0-9.]"), ''),
                    );
                    if (parsed != null) {
                      onChanged(parsed.clamp(min, max));
                    }
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    S.of(context)!.repaymentValidate,
                    style: MintTextStyles.labelLarge(),
                  ),
                ),
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _addDebt() {
    _hasUserInteracted = true;
    setState(() {
      _dettes.add(_DebtInput(
        nom: S.of(context)!.repaymentNewDebt,
        montant: 5000,
        tauxAnnuel: 5.0,
        mensualiteMin: 100,
      ));
    });
  }

  Widget _buildBudgetSection() {
    return GestureDetector(
      onTap: () => _showValueEditor(
        label: S.of(context)!.repaymentBudgetEditorLabel,
        currentValue: _budgetMensuel,
        min: 200,
        max: 5000,
        prefix: 'CHF',
        onChanged: (v) => setState(() { _hasUserInteracted = true; _budgetTouched = true; _budgetMensuel = v; }),
      ),
      child: Semantics(
        button: true,
        label: _dettes.isNotEmpty && _budgetEffectif > _budgetMensuel
            ? S.of(context)!.semanticsRepaymentBudgetEffective(
                formatChf(_budgetMensuel), formatChf(_budgetEffectif))
            : S.of(context)!.semanticsRepaymentBudget(
                formatChf(_budgetMensuel)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              ExcludeSemantics(child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_outlined,
                    color: MintColors.primary, size: 22),
              )),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.repaymentBudgetLabel,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.of(context)!.repaymentBudgetDisplay(formatChf(_budgetMensuel)),
                      style: MintTextStyles.headlineMedium(color: MintColors.primary),
                    ),
                    if (_dettes.isNotEmpty &&
                        _budgetEffectif > _budgetMensuel) ...[
                      const SizedBox(height: 2),
                      // -g5v : les minimums contractuels dépassent le budget
                      // saisi — le plan calcule sur ce montant, le dire.
                      Text(
                        S.of(context)!.repaymentBudgetEffectiveNote(
                            formatChf(_budgetEffectif)),
                        style: MintTextStyles.labelSmall(
                            color: MintColors.warningAaa),
                      ),
                    ],
                  ],
                ),
              ),
              const ExcludeSemantics(child: Icon(Icons.edit_outlined,
                  color: MintColors.textMuted, size: 18)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonSection(RepaymentComparisonResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.repaymentComparaisonStrategies,
          style: MintTextStyles.bodySmall(color: MintColors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStrategyCard(
                title: S.of(context)!.repaymentAvalancheTitle,
                subtitle: S.of(context)!.repaymentAvalancheSubtitle,
                pro: S.of(context)!.repaymentAvalanchePro,
                mois: result.avalanche.moisJusquaLiberation,
                interets: result.avalanche.interetsTotaux,
                icon: Icons.trending_down,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStrategyCard(
                title: S.of(context)!.repaymentSnowballTitle,
                subtitle: S.of(context)!.repaymentSnowballSubtitle,
                pro: S.of(context)!.repaymentSnowballPro,
                mois: result.bouleDeNeige.moisJusquaLiberation,
                interets: result.bouleDeNeige.interetsTotaux,
                icon: Icons.ac_unit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildComparisonRow(
                S.of(context)!.repaymentRowLiberation,
                S.of(context)!.repaymentDurationDisplay(result.avalanche.moisJusquaLiberation),
                S.of(context)!.repaymentDurationDisplay(result.bouleDeNeige.moisJusquaLiberation),
              ),
              const SizedBox(height: 8),
              _buildComparisonRow(
                S.of(context)!.repaymentRowInterets,
                S.of(context)!.repaymentInteretsDisplay(formatChf(result.avalanche.interetsTotaux)),
                S.of(context)!.repaymentInteretsDisplay(formatChf(result.bouleDeNeige.interetsTotaux)),
              ),
              if (result.economieInterets > 0) ...[
                const Divider(height: 16),
                Text(
                  S.of(context)!.repaymentDifference(formatChf(result.economieInterets)),
                  style: MintTextStyles.bodySmall(
                    color: MintColors.success,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyCard({
    required String title,
    required String subtitle,
    required String pro,
    required int mois,
    required double interets,
    required IconData icon,
  }) {
    return Semantics(
      label: S.of(context)!.semanticsRepaymentStrategy(title, mois, formatChf(interets)),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 6),
              Text(
                title,
                style: MintTextStyles.micro(color: MintColors.textMuted)
                    .copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            S.of(context)!.repaymentDurationDisplay(mois),
            style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.repaymentInteretsDisplay(formatChf(interets)),
            style: MintTextStyles.labelSmall(color: MintColors.redDeep),
          ),
          const SizedBox(height: 8),
          Text(
            '✓ $pro',
            style: MintTextStyles.micro(color: MintColors.textSecondary),
          ),
        ],
      ),
    ));
  }

  Widget _buildComparisonRow(
      String label, String valueA, String valueB) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            valueA,
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            valueB,
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        S.of(context)!.repaymentStrategyNote,
        style: MintTextStyles.labelSmall(color: MintColors.textSecondary)
            .copyWith(fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTimelineSection(RepaymentComparisonResult result) {
    // Show avalanche timeline as example
    final timeline = result.avalanche.timeline;
    if (timeline.isEmpty) return const SizedBox.shrink();

    // Sample: show every N months to avoid too many rows
    final step = timeline.length > 24 ? (timeline.length ~/ 12) : 1;
    final sampled = <RepaymentMonth>[];
    for (int i = 0; i < timeline.length; i += step) {
      sampled.add(timeline[i]);
    }
    // Always include last month
    if (sampled.last.mois != timeline.last.mois) {
      sampled.add(timeline.last);
    }

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      elevated: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.repaymentTimelineTitle,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(S.of(context)!.repaymentTimelineMois,
                    style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(S.of(context)!.repaymentTimelinePaiement,
                    style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
              Expanded(
                child: Text(S.of(context)!.repaymentTimelineSolde,
                    style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(height: 16),

          // Scrollable rows
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sampled.length,
              itemBuilder: (context, index) {
                final month = sampled[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${month.mois}',
                          style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'CHF ${formatChf(month.paiementTotal)}',
                          style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'CHF ${formatChf(month.soldeTotal)}',
                          style: MintTextStyles.labelSmall(
                            color: month.soldeTotal <= 0.01
                                ? MintColors.success
                                : MintColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: MintColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.repaymentEmptyState,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
          Expanded(
            child: Text(
              disclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modele mutable pour les inputs de dette
class _DebtInput {
  String nom;
  double montant;
  double tauxAnnuel; // en % (ex: 9.9)
  double mensualiteMin;

  /// Provenance (review -64r) : true quand la valeur est une hypothèse MINT
  /// (taux/mensualité absents du profil) et non une donnée de l'utilisateur.
  /// Remise à false dès que l'utilisateur édite la valeur.
  bool tauxEstime;
  bool mensualiteEstimee;

  _DebtInput({
    required this.nom,
    required this.montant,
    required this.tauxAnnuel,
    required this.mensualiteMin,
    this.tauxEstime = false,
    this.mensualiteEstimee = false,
  });
}
