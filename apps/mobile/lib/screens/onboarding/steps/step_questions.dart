import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Step 1 of the Smart Onboarding flow — 5 core questions.
///
/// Collects: grossSalary, age, employmentStatus, nationalityGroup, canton.
/// Calls [viewModel.compute()] then [onNext] when the user taps "Voir mon résultat".
///
/// AVS gap / lacunes → handled later via extrait AVS upload (StepOcrUpload),
/// not asked here. Literacy calibration moved to StepChiffreChoc (post-reveal).
///
/// Design rules:
/// - Material 3, GoogleFonts.montserrat headings, GoogleFonts.inter body
/// - MintColors palette throughout
/// - No emojis, French informal "tu"
class StepQuestions extends StatefulWidget {
  final SmartOnboardingViewModel viewModel;
  final VoidCallback onNext;
  final VoidCallback onInputChanged;

  const StepQuestions({
    super.key,
    required this.viewModel,
    required this.onNext,
    required this.onInputChanged,
  });

  @override
  State<StepQuestions> createState() => _StepQuestionsState();
}

class _StepQuestionsState extends State<StepQuestions> {
  static const int _minAge = 18;
  static const int _maxAge = 75;

  // Salary presets mirrored from onboarding_minimal_screen.dart
  static const List<double> _salaryPresets = [
    50000,
    60000,
    80000,
    100000,
    120000,
    150000,
  ];
  static const List<String> _salaryLabels = [
    '50k',
    '60k',
    '80k',
    '100k',
    '120k',
    '150k+',
  ];

  late TextEditingController _ageController;
  late TextEditingController _firstNameController;
  bool _didTrackStart = false;

  /// P3-23: Guard against double-tap on submit button.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _ageController =
        TextEditingController(text: widget.viewModel.age.toString());
    _firstNameController =
        TextEditingController(text: widget.viewModel.firstName ?? '');
  }

  @override
  void dispose() {
    _ageController.dispose();
    _firstNameController.dispose();
    super.dispose();
  }

  void _setAge(int value) {
    final clamped = value.clamp(_minAge, _maxAge);
    widget.viewModel.setAge(clamped);
    widget.onInputChanged();
    final text = clamped.toString();
    _ageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _applyAgeFromInput() {
    final parsed = int.tryParse(_ageController.text.trim());
    if (parsed == null) {
      _ageController.text = widget.viewModel.age.toString();
      return;
    }
    _setAge(parsed);
  }

  void _onSubmit() {
    if (!widget.viewModel.canCompute) return;
    // P3-23: Double-tap guard
    if (_isSubmitting) return;
    _isSubmitting = true;
    final vm = widget.viewModel;
    final salaryBracket = vm.grossSalary <= 60000
        ? '<=60k'
        : vm.grossSalary <= 100000
            ? '60k-100k'
            : '>100k';
    final ageBracket = vm.age < 30
        ? '<30'
        : vm.age < 45
            ? '30-44'
            : '45+';
    AnalyticsService().trackEvent(
      'smart_onboarding_step1_submitted',
      category: 'conversion',
      data: {
        'salary_bracket': salaryBracket,
        'age_bracket': ageBracket,
        'employment_status': vm.employmentStatus,
        'canton': vm.canton,
      },
      screenName: 'smart_onboarding_step1',
    );
    vm.compute();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    if (!_didTrackStart) {
      _didTrackStart = true;
      AnalyticsService().trackEvent(
        'smart_onboarding_started',
        category: 'engagement',
        screenName: 'smart_onboarding_step1',
      );
    }

    final l = S.of(context)!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 24, bottom: 16, right: 24),
              title: Text(
                l.onboardingSmartTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: MintColors.background,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  MintEntrance(child: Text(
                    l.onboardingSmartSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  )),
                  const SizedBox(height: 28),

                  // ── 0. PRENOM (optionnel) ─────────────────────────────────
                  MintEntrance(delay: const Duration(milliseconds: 100), child: TextField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l.onboardingSmartFirstNameLabel,
                      hintText: l.onboardingSmartFirstNameHint,
                      filled: true,
                      fillColor: MintColors.background,
                      suffixIcon: _firstNameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: MintColors.textMuted),
                              onPressed: () {
                                _firstNameController.clear();
                                widget.viewModel.setFirstName(null);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: MintColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: MintColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: MintColors.primary),
                      ),
                    ),
                    onChanged: (v) {
                      widget.viewModel.setFirstName(v);
                      setState(() {}); // rebuild suffixIcon
                    },
                  )),
                  const SizedBox(height: 32),

                  // ── 1. SALAIRE ────────────────────────────────────────────
                  _SectionTitle(label: l.onboardingSmartSalaryLabel),
                  const SizedBox(height: 12),
                  _SalarySelector(
                    presets: _salaryPresets,
                    labels: _salaryLabels,
                    selectedValue: widget.viewModel.grossSalary,
                    onChanged: (v) {
                      widget.viewModel.setGrossSalary(v);
                      widget.onInputChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                  MintEntrance(delay: const Duration(milliseconds: 200), child: Center(
                    child: Text(
                      '${formatChfWithPrefix(widget.viewModel.grossSalary)}/an',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  )),
                  const SizedBox(height: 32),

                  // ── 2. AGE ────────────────────────────────────────────────
                  _SectionTitle(label: l.onboardingSmartAgeLabel),
                  const SizedBox(height: 12),
                  _AgePicker(
                    value: widget.viewModel.age,
                    onChanged: _setAge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      controller: _ageController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final age = int.tryParse(v);
                        if (age == null || age < 18 || age > 75) {
                          return l.onboardingAgeInvalid;
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: l.onboardingSmartAgeDirectInput,
                        suffixText: 'ans',
                        filled: true,
                        fillColor: MintColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MintColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MintColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MintColors.primary,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (_) => _applyAgeFromInput(),
                      onTapOutside: (_) {
                        FocusScope.of(context).unfocus();
                        _applyAgeFromInput();
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 3. SITUATION PROFESSIONNELLE ──────────────────────────
                  _SectionTitle(label: l.onboardingSmartEmploymentLabel),
                  const SizedBox(height: 12),
                  _EmploymentStatusChips(
                    value: widget.viewModel.employmentStatus,
                    onChanged: (v) {
                      widget.viewModel.setEmploymentStatus(v);
                      widget.onInputChanged();
                    },
                  ),
                  const SizedBox(height: 32),

                  // ── 4. NATIONALITE ─────────────────────────────────────────
                  _SectionTitle(label: l.onboardingSmartNationalityLabel),
                  const SizedBox(height: 12),
                  _NationalityChips(
                    value: widget.viewModel.nationalityGroup,
                    onChanged: (v) {
                      widget.viewModel.setNationalityGroup(v);
                      widget.onInputChanged();
                    },
                  ),
                  if (widget.viewModel.nationalityGroup == 'OTHER') ...[
                    const SizedBox(height: 16),
                    _CountryPicker(
                      value: widget.viewModel.nationalityCountry,
                      onChanged: (v) {
                        widget.viewModel.setNationalityCountry(v);
                        widget.onInputChanged();
                      },
                    ),
                  ],
                  // Permit type — shown for non-Swiss nationals
                  if (widget.viewModel.nationalityGroup != null &&
                      widget.viewModel.nationalityGroup != 'CH') ...[
                    const SizedBox(height: 24),
                    _SectionTitle(label: l.onboardingPermitTypeLabel),
                    const SizedBox(height: 12),
                    _PermitTypeChips(
                      value: widget.viewModel.permitType,
                      onChanged: (v) {
                        widget.viewModel.setPermitType(v);
                        widget.onInputChanged();
                      },
                    ),
                  ],
                  // IJM warning — shown for independants
                  if (widget.viewModel.employmentStatus == 'independant') ...[
                    const SizedBox(height: 24),
                    _IjmWarningCard(),
                  ],
                  const SizedBox(height: 32),

                  // ── 5. CANTON ─────────────────────────────────────────────
                  _SectionTitle(label: l.onboardingSmartCantonLabel),
                  const SizedBox(height: 12),
                  _CantonPicker(
                    value: widget.viewModel.canton,
                    onChanged: (v) {
                      widget.viewModel.setCanton(v);
                      widget.onInputChanged();
                    },
                  ),

                  const SizedBox(height: 48),

                  // ── CTA ───────────────────────────────────────────────────
                  MintEntrance(delay: const Duration(milliseconds: 300), child: Semantics(
                    button: true,
                    label: l.onboardingSmartSeeResult,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.viewModel.canCompute ? _onSubmit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: MintColors.primary,
                        foregroundColor: MintColors.background,
                        disabledBackgroundColor: MintColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        l.onboardingSmartSeeResult,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  )),
                  const SizedBox(height: 24),

                  // Disclaimer
                  MintEntrance(delay: const Duration(milliseconds: 400), child: Text(
                    l.onboardingSmartDisclaimer,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  )),
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
//  SECTION TITLE
// ════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: MintColors.textPrimary,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SALARY SELECTOR — CupertinoPicker (0–500k, step 5k)
// ════════════════════════════════════════════════════════════════════════════

class _SalarySelector extends StatefulWidget {
  final List<double> presets;
  final List<String> labels;
  final double selectedValue;
  final ValueChanged<double> onChanged;

  const _SalarySelector({
    required this.presets,
    required this.labels,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  State<_SalarySelector> createState() => _SalarySelectorState();
}

class _SalarySelectorState extends State<_SalarySelector> {
  // Salary range: 0 to 500'000 in steps of 5'000
  static const int _step = 5000;
  static const int _maxSalary = 500000;
  static final List<int> _values =
      List.generate((_maxSalary ~/ _step) + 1, (i) => i * _step);

  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    final index = _closestIndex(widget.selectedValue.round());
    _controller = FixedExtentScrollController(initialItem: index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _closestIndex(int salary) {
    final clamped = salary.clamp(0, _maxSalary);
    return (clamped / _step).round();
  }

  String _formatChf(int value) {
    return value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => "${m[1]}'");
  }

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      radius: 16,
      child: SizedBox(
        height: 150,
        child: CupertinoPicker(
          scrollController: _controller,
          itemExtent: 44,
          diameterRatio: 1.2,
          magnification: 1.1,
          squeeze: 1.0,
          selectionOverlay: Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: MintColors.primary.withAlpha(38),
                  width: 1,
                ),
              ),
            ),
          ),
          onSelectedItemChanged: (index) {
            widget.onChanged(_values[index].toDouble());
          },
          children: _values.map((salary) {
            final isSelected = salary == widget.selectedValue.round();
            return Center(
              child: Text(
                'CHF\u00a0${_formatChf(salary)}',
                style: GoogleFonts.montserrat(
                  fontSize: isSelected ? 22 : 17,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? MintColors.textPrimary
                      : MintColors.textMuted,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AGE PICKER — CupertinoPicker wheel + quick chips (18–75)
// ════════════════════════════════════════════════════════════════════════════

class _AgePicker extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _AgePicker({required this.value, required this.onChanged});

  @override
  State<_AgePicker> createState() => _AgePickerState();
}

class _AgePickerState extends State<_AgePicker> {
  static const int _minAge = 18;
  static const int _maxAge = 75;
  static const List<int> _quickAges = [25, 30, 35, 40, 45, 50, 55, 60, 65];

  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: widget.value - _minAge,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AgePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final targetItem = widget.value - _minAge;
      if (_controller.selectedItem != targetItem) {
        _controller.animateToItem(
          targetItem,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CupertinoPicker wheel
          SizedBox(
            height: 150,
            child: CupertinoPicker(
              scrollController: _controller,
              itemExtent: 44,
              diameterRatio: 1.2,
              magnification: 1.1,
              squeeze: 1.0,
              selectionOverlay: Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: MintColors.primary.withAlpha(38),
                      width: 1,
                    ),
                  ),
                ),
              ),
              onSelectedItemChanged: (index) {
                widget.onChanged(_minAge + index);
              },
              children: List.generate(
                _maxAge - _minAge + 1,
                (index) {
                  final age = _minAge + index;
                  final isSelected = age == widget.value;
                  return Center(
                    child: Text(
                      l.stepQuestionsAgeYears(age),
                      style: GoogleFonts.montserrat(
                        fontSize: isSelected ? 24 : 18,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected
                            ? MintColors.textPrimary
                            : MintColors.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Quick-select chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAges.map((age) {
              final isSelected = age == widget.value;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => widget.onChanged(age),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MintColors.primary.withAlpha(24)
                        : MintColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    l.stepQuestionsAgeYears(age),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  EMPLOYMENT STATUS CHIPS — 4 options impacting 3a/LPP/AVS
// ════════════════════════════════════════════════════════════════════════════

class _EmploymentStatusChips extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _EmploymentStatusChips({
    required this.value,
    required this.onChanged,
  });

  static const _keys = ['salarie', 'independant', 'sans_emploi', 'retraite'];

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final labels = [
      l.employmentSalarie,
      l.employmentIndependant,
      l.employmentSansEmploi,
      l.employmentRetraite,
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_keys.length, (i) {
        final key = _keys[i];
        final label = labels[i];
        final isSelected = key == value;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(isSelected ? null : key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? MintColors.primary.withAlpha(24)
                  : MintColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? MintColors.primary : MintColors.lightBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? MintColors.primary
                    : MintColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NATIONALITY CHIPS — CH / EU/AELE / Autre
// ════════════════════════════════════════════════════════════════════════════

class _NationalityChips extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _NationalityChips({
    required this.value,
    required this.onChanged,
  });

  static const _keys = ['CH', 'EU', 'OTHER'];

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final labels = [
      l.nationalitySuisse,
      l.nationalityEuAele,
      l.nationalityAutre,
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_keys.length, (i) {
        final key = _keys[i];
        final label = labels[i];
        final isSelected = key == value;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(isSelected ? null : key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? MintColors.primary.withAlpha(24)
                  : MintColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? MintColors.primary : MintColors.lightBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? MintColors.primary
                    : MintColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  COUNTRY PICKER — shown when nationalityGroup == 'OTHER'
// ════════════════════════════════════════════════════════════════════════════

class _CountryPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CountryPicker({required this.value, required this.onChanged});

  static const _countryCodes = ['US', 'GB', 'CA', 'IN', 'CN', 'BR', 'AU', 'JP'];

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final countryLabels = [
      l.stepQuestionsCountryUs,
      l.stepQuestionsCountryGb,
      l.stepQuestionsCountryCa,
      l.stepQuestionsCountryIn,
      l.stepQuestionsCountryCn,
      l.stepQuestionsCountryBr,
      l.stepQuestionsCountryAu,
      l.stepQuestionsCountryJp,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.onboardingSmartCountryOrigin,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_countryCodes.length, (i) {
            final code = _countryCodes[i];
            final label = countryLabels[i];
            final selected = value == code;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onChanged(selected ? null : code),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? MintColors.primary.withAlpha(24)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? MintColors.primary : MintColors.lightBorder,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? MintColors.primary : MintColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CANTON PICKER — search bottom sheet, 26 Swiss cantons
// ════════════════════════════════════════════════════════════════════════════

class _CantonPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CantonPicker({required this.value, required this.onChanged});

  Future<void> _open(BuildContext context) async {
    final l = S.of(context)!;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = sortedCantonCodes.where((code) {
              final name = cantonFullNames[code] ?? code;
              return '$code $name'.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return FractionallySizedBox(
              heightFactor: 0.82,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MintColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.onboardingSmartCantonTitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setModalState(() => query = v.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l.onboardingSmartCantonSearch,
                        filled: true,
                        fillColor: MintColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MintColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MintColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: MintColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                l.onboardingSmartCantonNotFound,
                                style: GoogleFonts.inter(
                                  color: MintColors.textMuted,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final code = filtered[index];
                                final name = cantonFullNames[code] ?? code;
                                final isSelected = code == value;
                                return ListTile(
                                  onTap: () => Navigator.of(context).pop(code),
                                  title: Text(
                                    '$code — $name',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: MintColors.textPrimary,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: MintColors.primary,
                                          size: 20,
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final selectedLabel = value == null
        ? l.onboardingSmartCantonLabel
        : '$value — ${cantonFullNames[value] ?? value}';

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      radius: 16,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18, color: MintColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selectedLabel,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: value == null
                        ? MintColors.textMuted
                        : MintColors.textPrimary,
                    fontWeight:
                        value == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: MintColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PERMIT TYPE CHIPS — shown for non-Swiss nationals (P1-A)
// ════════════════════════════════════════════════════════════════════════════

class _PermitTypeChips extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _PermitTypeChips({required this.value, required this.onChanged});

  static const _codes = ['C', 'B', 'G', 'L', 'other'];

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final labels = [
      l.onboardingPermitC,
      l.onboardingPermitB,
      l.onboardingPermitG,
      l.onboardingPermitL,
      l.onboardingPermitOther,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_codes.length, (i) {
        final code = _codes[i];
        final label = labels[i];
        final isSelected = value == code;
        return Semantics(
          label: label,
          selected: isSelected,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onChanged(isSelected ? null : code),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? MintColors.primary.withAlpha(24)
                    : MintColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isSelected ? MintColors.primary : MintColors.lightBorder,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? MintColors.primary
                      : MintColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  IJM WARNING CARD — shown for independants (P1-D)
// ════════════════════════════════════════════════════════════════════════════

class _IjmWarningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.onboardingIjmWarningTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.onboardingIjmWarningBody,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
