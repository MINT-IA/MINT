import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
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
  String? _selectedCanton;

  bool get _canSubmit => _selectedCanton != null;

  void _onSubmit() {
    if (!_canSubmit) return;
    context.push(
      '/onboarding/chiffre-choc',
      extra: {
        'age': _selectedAge,
        'grossSalary': _selectedSalary,
        'canton': _selectedCanton,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    '3 infos suffisent pour te montrer un premier resultat personnalise.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- 1. SALARY ---
                  _SectionTitle(label: 'Ton salaire brut annuel'),
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
                  _SectionTitle(label: 'Ton age'),
                  const SizedBox(height: 12),
                  _AgePicker(
                    value: _selectedAge,
                    onChanged: (v) => setState(() => _selectedAge = v),
                  ),
                  const SizedBox(height: 32),

                  // --- 3. CANTON ---
                  _SectionTitle(label: 'Ton canton'),
                  const SizedBox(height: 12),
                  _CantonDropdown(
                    value: _selectedCanton,
                    onChanged: (v) => setState(() => _selectedCanton = v),
                  ),
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
                          borderRadius: const Borderconst Radius.circular(16),
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
//  AGE PICKER — number selector with +/- buttons
// ════════════════════════════════════════════════════════════════════════════

class _AgePicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _AgePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const Borderconst Radius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleButton(
            icon: Icons.remove,
            onPressed: value > 18 ? () => onChanged(value - 1) : null,
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 80,
            child: Center(
              child: Text(
                '$value ans',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          _CircleButton(
            icon: Icons.add,
            onPressed: value < 70 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CircleButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled ? MintColors.primary : MintColors.border,
        ),
        child: Icon(
          icon,
          color: isEnabled ? Colors.white : MintColors.textMuted,
          size: 22,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const Borderconst Radius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        hint: Text(
          'Choisis ton canton',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textMuted,
          ),
        ),
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: MintColors.textSecondary),
        items: sortedCantonCodes.map((code) {
          final name = cantonFullNames[code] ?? code;
          return DropdownMenuItem<String>(
            value: code,
            child: Text(
              '$code — $name',
              style: GoogleFonts.inter(fontSize: 15),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
