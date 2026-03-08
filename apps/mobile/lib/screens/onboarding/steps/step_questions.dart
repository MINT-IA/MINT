import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Step 1 of the Smart Onboarding flow — 5 required questions.
///
/// Collects: grossSalary, age, employmentStatus, nationality, canton.
/// Calls [viewModel.compute()] then [onNext] when the user taps "Voir mon résultat".
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
  static const int _maxAge = 70;

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
  bool _didTrackStart = false;

  @override
  void initState() {
    super.initState();
    _ageController =
        TextEditingController(text: widget.viewModel.age.toString());
  }

  @override
  void dispose() {
    _ageController.dispose();
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
                'D\u00e9couvre ta situation retraite en 30 secondes',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
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
                  Text(
                    'Quelques infos suffisent pour un premier aper\u00e7u personnalis\u00e9.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 1. SALAIRE ────────────────────────────────────────────
                  const _SectionTitle(label: 'Ton salaire brut annuel'),
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
                  Center(
                    child: Text(
                      '${formatChfWithPrefix(widget.viewModel.grossSalary)}/an',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 2. AGE ────────────────────────────────────────────────
                  const _SectionTitle(label: 'Ton \u00e2ge'),
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
                      decoration: InputDecoration(
                        labelText: 'Saisie directe',
                        suffixText: 'ans',
                        filled: true,
                        fillColor: Colors.white,
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
                      onTapOutside: (_) => _applyAgeFromInput(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 3. SITUATION PROFESSIONNELLE ──────────────────────────
                  const _SectionTitle(label: 'Ta situation professionnelle'),
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
                  const _SectionTitle(label: 'Ta nationalite'),
                  const SizedBox(height: 12),
                  _NationalityChips(
                    value: widget.viewModel.nationalityGroup,
                    onChanged: (v) {
                      widget.viewModel.setNationalityGroup(v);
                      widget.onInputChanged();
                    },
                  ),
                  // Suisse ayant vécu à l'étranger — déclenche le calcul LPP/AVS correct
                  if (widget.viewModel.showAbroadQuestion) ...[
                    const SizedBox(height: 16),
                    const _SectionTitle(
                        label: 'As-tu interrompu tes cotisations AVS/LPP ?'),
                    const SizedBox(height: 4),
                    Text(
                      'Séjour à l\'étranger, période sans emploi…',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AbroadQuestion(
                      value: widget.viewModel.hasLivedAbroad,
                      onChanged: (v) {
                        widget.viewModel.setHasLivedAbroad(v);
                        widget.onInputChanged();
                      },
                    ),
                  ],
                  if (widget.viewModel.showArrivalYear) ...[
                    const SizedBox(height: 16),
                    _SectionTitle(
                      label: widget.viewModel.nationalityGroup == 'CH'
                          ? 'Depuis quelle année cotises-tu en Suisse ?'
                          : 'Depuis quand es-tu en Suisse ?',
                    ),
                    const SizedBox(height: 12),
                    _ArrivalYearPicker(
                      value: widget.viewModel.arrivalYear,
                      onChanged: (v) {
                        widget.viewModel.setArrivalYear(v);
                        widget.onInputChanged();
                      },
                    ),
                  ],
                  const SizedBox(height: 32),

                  // ── 5. CANTON ─────────────────────────────────────────────
                  const _SectionTitle(label: 'Ton canton'),
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.viewModel.canCompute ? _onSubmit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: MintColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: MintColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Voir mon resultat',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Disclaimer
                  Text(
                    'Outil educatif — ne constitue pas un conseil financier (LSFin). '
                    'Les estimations sont basees sur les baremes 2025 et peuvent varier.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      height: 1.4,
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
//  SALARY SELECTOR — preset slider with labeled stops (30k–250k, step 5k)
// ════════════════════════════════════════════════════════════════════════════

class _SalarySelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Map selectedValue to the closest preset index
    int currentIndex = presets.indexOf(selectedValue);
    if (currentIndex < 0) {
      double minDist = double.infinity;
      for (int i = 0; i < presets.length; i++) {
        final dist = (presets[i] - selectedValue).abs();
        if (dist < minDist) {
          minDist = dist;
          currentIndex = i;
        }
      }
    }

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.lightBorder,
            thumbColor: MintColors.primary,
            overlayColor: MintColors.primary.withAlpha(30),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
          ),
          child: Slider(
            value: currentIndex.toDouble(),
            min: 0,
            max: (presets.length - 1).toDouble(),
            divisions: presets.length - 1,
            onChanged: (v) => onChanged(presets[v.round()]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.asMap().entries.map((entry) {
              final isSelected = entry.key == currentIndex;
              return Text(
                entry.value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? MintColors.textPrimary
                      : MintColors.textMuted,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AGE PICKER — slider + quick chips (18–70)
// ════════════════════════════════════════════════════════════════════════════

class _AgePicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _AgePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const minAge = 18;
    const maxAge = 70;
    const quickAges = [25, 30, 35, 40, 45, 50, 55, 60];

    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '$value ans',
              style: GoogleFonts.montserrat(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Glisse pour ajuster rapidement',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.lightBorder,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withAlpha(28),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value.toDouble(),
              min: minAge.toDouble(),
              max: maxAge.toDouble(),
              divisions: maxAge - minAge,
              label: '$value ans',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('18',
                    style:
                        TextStyle(fontSize: 11, color: MintColors.textMuted)),
                Text('70',
                    style:
                        TextStyle(fontSize: 11, color: MintColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickAges.map((age) {
              final isSelected = age == value;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onChanged(age),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MintColors.primary.withAlpha(24)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    '$age ans',
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

  static const _options = [
    ('salarie', 'Salarie\u00b7e'),
    ('independant', 'Independant\u00b7e'),
    ('sans_emploi', 'Sans emploi'),
    ('retraite', 'Retraite\u00b7e'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _options.map((option) {
        final (key, label) = option;
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
      }).toList(),
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

  static const _options = [
    ('CH', 'Suisse'),
    ('EU', 'EU/AELE'),
    ('OTHER', 'Autre'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _options.map((option) {
        final (key, label) = option;
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
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ABROAD QUESTION — binary toggle for Swiss nationals who lived abroad
// ════════════════════════════════════════════════════════════════════════════

class _AbroadQuestion extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _AbroadQuestion({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AbroadChip(
          label: 'Oui',
          selected: value == true,
          onTap: () => onChanged(value == true ? null : true),
        ),
        const SizedBox(width: 10),
        _AbroadChip(
          label: 'Non',
          selected: value == false,
          onTap: () => onChanged(value == false ? null : false),
        ),
      ],
    );
  }
}

class _AbroadChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AbroadChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? MintColors.primary : MintColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ARRIVAL YEAR PICKER — year dropdown for non-Swiss residents
// ════════════════════════════════════════════════════════════════════════════

class _ArrivalYearPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _ArrivalYearPicker({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(50, (i) => currentYear - i);
    final displayValue = value != null ? '$value' : 'Annee d\'arrivee';

    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final selected = await showModalBottomSheet<int>(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) {
              return FractionallySizedBox(
                heightFactor: 0.4,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Annee d\'arrivee en Suisse',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: years.length,
                        itemBuilder: (_, i) {
                          final year = years[i];
                          final isSelected = year == value;
                          return ListTile(
                            onTap: () => Navigator.of(ctx).pop(year),
                            title: Text(
                              '$year',
                              style: GoogleFonts.inter(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: MintColors.textPrimary,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: MintColors.primary, size: 20)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          if (selected != null) onChanged(selected);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 18, color: MintColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayValue,
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
              const Icon(Icons.keyboard_arrow_down,
                  color: MintColors.textSecondary),
            ],
          ),
        ),
      ),
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
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                      'Choisis ton canton',
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
                        hintText: 'Rechercher (ex: VD, Vaud)',
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
                                'Aucun canton trouv\u00e9',
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
    final selectedLabel = value == null
        ? 'Choisis ton canton'
        : '$value — ${cantonFullNames[value] ?? value}';

    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
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
