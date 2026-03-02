import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Minimal onboarding screen — 3 inputs only (Sprint S31).
///
/// Collects: salary, age, canton.
/// Navigates to chiffre choc screen on submit.
class OnboardingMinimalScreen extends StatefulWidget {
  const OnboardingMinimalScreen({super.key});

  @override
  State<OnboardingMinimalScreen> createState() =>
      _OnboardingMinimalScreenState();
}

class _OnboardingMinimalScreenState extends State<OnboardingMinimalScreen> {
  static const int _minAge = 18;
  static const int _maxAge = 70;

  // Salary presets (annual gross)
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

  double _selectedSalary = 80000;
  int _selectedAge = 35;
  int _selectedRetirementAge = 65;
  String? _selectedCanton;
  late final TextEditingController _ageController;
  bool _didTrackStart = false;

  bool get _canSubmit => _selectedCanton != null;

  /// Show retirement age question only for users 40+.
  bool get _showRetirementAge => _selectedAge >= 40;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: _selectedAge.toString());
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _setAge(int value) {
    final clamped = value.clamp(_minAge, _maxAge);
    setState(() => _selectedAge = clamped);
    final text = clamped.toString();
    _ageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _applyAgeFromInput() {
    final parsed = int.tryParse(_ageController.text.trim());
    if (parsed == null) {
      _ageController.text = _selectedAge.toString();
      return;
    }
    _setAge(parsed);
  }

  void _onSubmit() {
    if (!_canSubmit) return;
    final salaryBracket = _selectedSalary <= 60000
        ? '<=60k'
        : _selectedSalary <= 100000
            ? '60k-100k'
            : '>100k';
    final ageBracket = _selectedAge < 30
        ? '<30'
        : _selectedAge < 45
            ? '30-44'
            : '45+';
    AnalyticsService().trackEvent(
      'onboarding_minimal_submitted',
      category: 'conversion',
      data: {
        'salary_bracket': salaryBracket,
        'age_bracket': ageBracket,
        'canton': _selectedCanton,
      },
      screenName: 'onboarding_minimal',
    );
    context.push(
      '/onboarding/chiffre-choc',
      extra: {
        'age': _selectedAge,
        'grossSalary': _selectedSalary,
        'canton': _selectedCanton,
        if (_showRetirementAge && _selectedRetirementAge != 65)
          'targetRetirementAge': _selectedRetirementAge,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_didTrackStart) {
      _didTrackStart = true;
      AnalyticsService().trackEvent(
        'onboarding_minimal_started',
        category: 'engagement',
        screenName: 'onboarding_minimal',
      );
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Ton profil express',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Quelques infos suffisent pour te montrer un premier resultat personnalise.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- 1. SALARY ---
                  const _SectionTitle(label: 'Ton salaire brut annuel'),
                  const SizedBox(height: 12),
                  _SalarySelector(
                    presets: _salaryPresets,
                    labels: _salaryLabels,
                    selectedValue: _selectedSalary,
                    onChanged: (v) => setState(() => _selectedSalary = v),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'CHF\u00A0${_formatNumber(_selectedSalary.round())}',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- 2. AGE ---
                  const _SectionTitle(label: 'Ton age'),
                  const SizedBox(height: 12),
                  _AgePicker(
                    value: _selectedAge,
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

                  // --- 3. CANTON ---
                  const _SectionTitle(label: 'Ton canton'),
                  const SizedBox(height: 12),
                  _CantonDropdown(
                    value: _selectedCanton,
                    onChanged: (v) => setState(() => _selectedCanton = v),
                  ),

                  // --- 4. RETIREMENT AGE (conditionally shown for 40+) ---
                  if (_showRetirementAge) ...[
                    const SizedBox(height: 32),
                    const _SectionTitle(label: 'Age de retraite souhaite'),
                    const SizedBox(height: 8),
                    Text(
                      'Anticipation possible des 63 ans (LAVS art. 40). '
                      'Certaines caisses LPP permettent des 58 ans.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RetirementAgePicker(
                      value: _selectedRetirementAge,
                      onChanged: (v) =>
                          setState(() => _selectedRetirementAge = v),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // --- CTA ---
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canSubmit ? _onSubmit : null,
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
                    'Les estimations sont basees sur les baremes actuels et peuvent varier.',
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

  static String _formatNumber(int value) {
    final str = value.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
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
//  SALARY SELECTOR — custom slider with labeled stops
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
    // Map selectedValue to slider index
    int currentIndex = presets.indexOf(selectedValue);
    if (currentIndex < 0) {
      // Find closest preset
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
            children: labels.map((label) {
              final isSelected = labels.indexOf(label) == currentIndex;
              return Text(
                label,
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
//  AGE PICKER — fast selector (slider + quick presets)
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
//  CANTON DROPDOWN — 26 Swiss cantons
// ════════════════════════════════════════════════════════════════════════════

class _CantonDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CantonDropdown({required this.value, required this.onChanged});

  Future<void> _openCantonPicker(BuildContext context) async {
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
              final haystack = '$code $name'.toLowerCase();
              return haystack.contains(query.toLowerCase());
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
                      onChanged: (value) =>
                          setModalState(() => query = value.trim()),
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
                                'Aucun canton trouve',
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
        onTap: () => _openCantonPicker(context),
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
//  RETIREMENT AGE PICKER — quick chips for 58-70
// ════════════════════════════════════════════════════════════════════════════

class _RetirementAgePicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RetirementAgePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const minAge = 58;
    const maxAge = 70;
    const quickAges = [58, 60, 62, 63, 64, 65, 67, 70];

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
                Text('58',
                    style:
                        TextStyle(fontSize: 11, color: MintColors.textMuted)),
                Text('65',
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
