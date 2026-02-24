import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Progressive enrichment screen — additional questions in rounds.
///
/// Sprint S31 — Onboarding Redesign.
///
/// Round 2: Situation familiale, epargne actuelle, proprietaire/locataire.
/// Round 3: 3a existant, type caisse LPP, dettes en cours.
///
/// After EACH answer, recalculates chiffre choc in real-time.
/// User can stop at any point and proceed to main app.
class ProgressiveEnrichmentScreen extends StatefulWidget {
  const ProgressiveEnrichmentScreen({super.key});

  @override
  State<ProgressiveEnrichmentScreen> createState() =>
      _ProgressiveEnrichmentScreenState();
}

class _ProgressiveEnrichmentScreenState
    extends State<ProgressiveEnrichmentScreen>
    with SingleTickerProviderStateMixin {
  bool _didInit = false;

  // Base data from previous screen
  int _age = 35;
  double _grossSalary = 80000;
  String _canton = 'ZH';

  // Round 2 fields
  String _householdType = 'single';
  int _savingsRangeIndex = -1; // -1 = not set
  bool? _isPropertyOwner;

  // Round 3 fields
  bool? _has3a;
  double? _existing3a;
  String _lppCaisseType = 'base'; // 'base' or 'complementaire'
  bool? _hasDebts;
  double? _debtAmount;

  // Computed result
  ChiffreChoc? _chiffreChoc;

  late AnimationController _numberAnimController;
  late Animation<double> _numberScale;

  static const List<String> _householdOptions = [
    'single',
    'couple',
    'family',
  ];
  static const Map<String, String> _householdLabels = {
    'single': 'Celibataire',
    'couple': 'En couple',
    'family': 'Famille (avec enfant·s)',
  };

  static const List<String> _savingsRangeLabels = [
    'Moins de 10k',
    '10k - 50k',
    '50k - 100k',
    'Plus de 100k',
  ];
  static const List<double> _savingsRangeValues = [
    5000,
    30000,
    75000,
    150000,
  ];

  @override
  void initState() {
    super.initState();
    _numberAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _numberScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _numberAnimController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _initFromRouteExtra();
    }
  }

  void _initFromRouteExtra() {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _age = extra['age'] as int? ?? 35;
      _grossSalary = (extra['grossSalary'] as num?)?.toDouble() ?? 80000;
      _canton = extra['canton'] as String? ?? 'ZH';

      // Restore any already-set enrichment fields
      if (extra['householdType'] is String) {
        _householdType = extra['householdType'] as String;
      }
      if (extra['currentSavings'] is num) {
        // Find closest range
        final savings = (extra['currentSavings'] as num).toDouble();
        _savingsRangeIndex = _findClosestSavingsRange(savings);
      }
      if (extra['isPropertyOwner'] is bool) {
        _isPropertyOwner = extra['isPropertyOwner'] as bool;
      }
      if (extra['existing3a'] is num) {
        _has3a = true;
        _existing3a = (extra['existing3a'] as num).toDouble();
      }
      if (extra['existingLpp'] is num) {
        // Presence of existingLpp hints at complementaire
        _lppCaisseType = 'complementaire';
      }
    }
    _recompute();
  }

  int _findClosestSavingsRange(double savings) {
    double minDist = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < _savingsRangeValues.length; i++) {
      final dist = (savings - _savingsRangeValues[i]).abs();
      if (dist < minDist) {
        minDist = dist;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  void _recompute() {
    _recomputeAsync();
  }

  Future<void> _recomputeAsync() async {
    final savings = _savingsRangeIndex >= 0
        ? _savingsRangeValues[_savingsRangeIndex]
        : null;
    final existing3a = (_has3a == true) ? (_existing3a ?? 0) : null;

    try {
      final choc = await ApiService.computeOnboardingChiffreChoc(
        age: _age,
        grossSalary: _grossSalary,
        canton: _canton,
        householdType: _householdType,
        currentSavings: savings,
        isPropertyOwner: _isPropertyOwner,
        existing3a: existing3a,
        existingLpp: null,
      );

      if (!mounted) return;
      setState(() {
        _chiffreChoc = choc;
      });
    } catch (_) {
      final profile = MinimalProfileService.compute(
        age: _age,
        grossSalary: _grossSalary,
        canton: _canton,
        householdType: _householdType,
        currentSavings: savings,
        isPropertyOwner: _isPropertyOwner,
        existing3a: existing3a,
        existingLpp: null, // Let service estimate unless user provides
      );

      if (!mounted) return;
      setState(() {
        _chiffreChoc = ChiffreChocSelector.select(profile);
      });
    }

    // Animate number update
    _numberAnimController.forward(from: 0);
  }

  @override
  void dispose() {
    _numberAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choc = _chiffreChoc;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Affine ton profil',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // Live chiffre choc at top
          if (choc != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: ScaleTransition(
                  scale: _numberScale,
                  child: _LiveChiffreChocBanner(choc: choc),
                ),
              ),
            ),

          // Round 2: Situation familiale, epargne, proprietaire
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundHeader(number: 2, title: 'Ta situation'),
                  const SizedBox(height: 20),

                  // Household type
                  _QuestionLabel(text: 'Situation familiale'),
                  const SizedBox(height: 8),
                  _ToggleChips<String>(
                    options: _householdOptions,
                    labels: _householdOptions
                        .map((o) => _householdLabels[o] ?? o)
                        .toList(),
                    selectedValue: _householdType,
                    onSelected: (v) {
                      setState(() => _householdType = v);
                      _recompute();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Savings range
                  _QuestionLabel(text: 'Epargne actuelle'),
                  const SizedBox(height: 8),
                  _ToggleChips<int>(
                    options:
                        List.generate(_savingsRangeLabels.length, (i) => i),
                    labels: _savingsRangeLabels,
                    selectedValue:
                        _savingsRangeIndex >= 0 ? _savingsRangeIndex : null,
                    onSelected: (v) {
                      setState(() => _savingsRangeIndex = v);
                      _recompute();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Property owner
                  _QuestionLabel(text: 'Proprietaire ou locataire ?'),
                  const SizedBox(height: 8),
                  _ToggleChips<bool>(
                    options: const [false, true],
                    labels: const ['Locataire', 'Proprietaire'],
                    selectedValue: _isPropertyOwner,
                    onSelected: (v) {
                      setState(() => _isPropertyOwner = v);
                      _recompute();
                    },
                  ),
                ],
              ),
            ),
          ),

          // Round 3: 3a, LPP type, dettes
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundHeader(number: 3, title: 'Ta prevoyance'),
                  const SizedBox(height: 20),

                  // 3a existant
                  _QuestionLabel(text: 'As-tu un 3e pilier (3a) ?'),
                  const SizedBox(height: 8),
                  _ToggleChips<bool>(
                    options: const [false, true],
                    labels: const ['Non', 'Oui'],
                    selectedValue: _has3a,
                    onSelected: (v) {
                      setState(() {
                        _has3a = v;
                        if (!v) _existing3a = null;
                      });
                      _recompute();
                    },
                  ),
                  if (_has3a == true) ...[
                    const SizedBox(height: 12),
                    _AmountInput(
                      label: 'Solde approximatif 3a (CHF)',
                      initialValue: _existing3a,
                      onChanged: (v) {
                        _existing3a = v;
                        _recompute();
                      },
                    ),
                  ],
                  const SizedBox(height: 24),

                  // LPP caisse type
                  _QuestionLabel(text: 'Type de caisse LPP'),
                  const SizedBox(height: 8),
                  _ToggleChips<String>(
                    options: const ['base', 'complementaire'],
                    labels: const ['Base (minimum)', 'Complementaire'],
                    selectedValue: _lppCaisseType,
                    onSelected: (v) {
                      setState(() => _lppCaisseType = v);
                      _recompute();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Dettes
                  _QuestionLabel(text: 'As-tu des dettes en cours ?'),
                  const SizedBox(height: 8),
                  _ToggleChips<bool>(
                    options: const [false, true],
                    labels: const ['Non', 'Oui'],
                    selectedValue: _hasDebts,
                    onSelected: (v) {
                      setState(() {
                        _hasDebts = v;
                        if (!v) _debtAmount = null;
                      });
                      _recompute();
                    },
                  ),
                  if (_hasDebts == true) ...[
                    const SizedBox(height: 12),
                    _AmountInput(
                      label: 'Montant total des dettes (CHF)',
                      initialValue: _debtAmount,
                      onChanged: (v) {
                        _debtAmount = v;
                        _recompute();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom CTAs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/home'),
                      style: FilledButton.styleFrom(
                        backgroundColor: MintColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Continuer vers l\'app',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Outil educatif — ne constitue pas un conseil financier (LSFin). '
                    'Sources : LAVS art. 34, LPP art. 14-16, OPP3 art. 7, LIFD art. 38.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: MintColors.textMuted,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LIVE CHIFFRE CHOC BANNER — shows updated number at the top
// ════════════════════════════════════════════════════════════════════════════

class _LiveChiffreChocBanner extends StatelessWidget {
  final ChiffreChoc choc;
  const _LiveChiffreChocBanner({required this.choc});

  Color _colorForKey(String key) {
    return switch (key) {
      'error' => MintColors.error,
      'warning' => MintColors.warning,
      'success' => MintColors.success,
      'info' => MintColors.info,
      _ => MintColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForKey(choc.colorKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Text(
            choc.title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            choc.value,
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mis a jour en temps reel',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ROUND HEADER
// ════════════════════════════════════════════════════════════════════════════

class _RoundHeader extends StatelessWidget {
  final int number;
  final String title;
  const _RoundHeader({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: MintColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  QUESTION LABEL
// ════════════════════════════════════════════════════════════════════════════

class _QuestionLabel extends StatelessWidget {
  final String text;
  const _QuestionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: MintColors.textPrimary,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TOGGLE CHIPS — generic chip selector
// ════════════════════════════════════════════════════════════════════════════

class _ToggleChips<T> extends StatelessWidget {
  final List<T> options;
  final List<String> labels;
  final T? selectedValue;
  final ValueChanged<T> onSelected;

  const _ToggleChips({
    required this.options,
    required this.labels,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(options.length, (i) {
        final isSelected = options[i] == selectedValue;
        return GestureDetector(
          onTap: () => onSelected(options[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? MintColors.primary : MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? MintColors.primary : MintColors.lightBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              labels[i],
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : MintColors.textPrimary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AMOUNT INPUT — simple text field for CHF amounts
// ════════════════════════════════════════════════════════════════════════════

class _AmountInput extends StatefulWidget {
  final String label;
  final double? initialValue;
  final ValueChanged<double?> onChanged;

  const _AmountInput({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<_AmountInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue != null
          ? widget.initialValue!.round().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: widget.label,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: MintColors.textMuted,
        ),
        prefixText: 'CHF  ',
        prefixStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MintColors.textSecondary,
        ),
        filled: true,
        fillColor: MintColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: GoogleFonts.inter(fontSize: 14),
      onChanged: (value) {
        final raw = value.replaceAll("'", '').replaceAll(' ', '').trim();
        final parsed = double.tryParse(raw);
        widget.onChanged(parsed);
      },
    );
  }
}
