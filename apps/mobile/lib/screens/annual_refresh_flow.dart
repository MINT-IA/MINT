import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/annual_refresh_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Annual Refresh Flow — Sprint S37.
///
/// 7-question lightweight form to update stale profiles.
/// Pre-filled with current values.
/// After completion: triggers [onComplete] callback for full recalculation.
///
/// Uses a PageView with one question per page, progress indicator at top,
/// and "Suivant" / "Terminer" navigation at bottom.
///
/// All text in French (informal "tu").
/// No banned terms ("garanti", "certain", "optimal", etc.).
class AnnualRefreshFlow extends StatefulWidget {
  final AnnualRefreshResult refreshData;
  final VoidCallback? onComplete;

  const AnnualRefreshFlow({
    super.key,
    required this.refreshData,
    this.onComplete,
  });

  @override
  State<AnnualRefreshFlow> createState() => _AnnualRefreshFlowState();
}

class _AnnualRefreshFlowState extends State<AnnualRefreshFlow> {
  late final PageController _pageController;
  int _currentPage = 0;

  // Answers stored by question key
  late final Map<String, String> _answers;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Pre-fill answers with current values
    _answers = {};
    for (final q in widget.refreshData.questions) {
      _answers[q.key] = q.currentValue ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _totalPages => widget.refreshData.questions.length;
  bool get _isLastPage => _currentPage == _totalPages - 1;

  void _goNext() {
    if (_isLastPage) {
      // Complete the flow
      widget.onComplete?.call();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button and progress
            _buildTopBar(),
            // Progress indicator
            _buildProgressIndicator(),
            // Question pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemCount: _totalPages,
                itemBuilder: (context, index) {
                  final question = widget.refreshData.questions[index];
                  return _buildQuestionPage(question, index);
                },
              ),
            ),
            // Bottom navigation
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
            onPressed: _goBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Check-up annuel',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${_currentPage + 1}/$_totalPages',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PROGRESS INDICATOR
  // ════════════════════════════════════════════════════════════════

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: const Borderconst Radius.circular(4),
        child: LinearProgressIndicator(
          value: (_currentPage + 1) / _totalPages,
          backgroundColor: MintColors.lightBorder,
          valueColor:
              const AlwaysStoppedAnimation<Color>(MintColors.coachAccent),
          minHeight: 4,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  QUESTION PAGE
  // ════════════════════════════════════════════════════════════════

  Widget _buildQuestionPage(RefreshQuestion question, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MintColors.coachAccent.withAlpha(20),
              borderRadius: const Borderconst Radius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.coachAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Question label
          Text(
            question.label,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
              height: 1.3,
            ),
          ),
          // Help text
          if (question.helpText != null) ...[
            const SizedBox(height: 12),
            Text(
              question.helpText!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 32),
          // Input widget
          _buildInputWidget(question),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  INPUT WIDGETS
  // ════════════════════════════════════════════════════════════════

  Widget _buildInputWidget(RefreshQuestion question) {
    switch (question.type) {
      case RefreshQuestionType.slider:
        return _buildSliderInput(question);
      case RefreshQuestionType.yesNo:
        return _buildYesNoInput(question);
      case RefreshQuestionType.select:
        return _buildSelectInput(question);
      case RefreshQuestionType.text:
        return _buildTextInput(question);
    }
  }

  /// Slider input with value label.
  Widget _buildSliderInput(RefreshQuestion question) {
    final currentVal =
        double.tryParse(_answers[question.key] ?? '0') ?? 0;
    final minVal = question.sliderMin ?? 0;
    final maxVal = question.sliderMax ?? 30000;
    final divisions = question.sliderDivisions ?? 300;

    return Column(
      children: [
        Text(
          '${currentVal.toInt()} CHF / mois',
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: MintColors.coachAccent,
          ),
        ),
        const SizedBox(height: 20),
        Slider(
          value: currentVal.clamp(minVal, maxVal),
          min: minVal,
          max: maxVal,
          divisions: divisions,
          activeThumbColor: MintColors.coachAccent,
          inactiveThumbColor: MintColors.coachAccent.withAlpha(40),
          label: '${currentVal.toInt()} CHF',
          onChanged: (v) {
            setState(() {
              _answers[question.key] = v.toStringAsFixed(0);
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${minVal.toInt()} CHF',
                style: GoogleFonts.inter(
                    fontSize: 12, color: MintColors.textMuted),
              ),
              Text(
                "${_formatSwissNumber(maxVal.toInt())} CHF",
                style: GoogleFonts.inter(
                    fontSize: 12, color: MintColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Yes/No toggle buttons.
  Widget _buildYesNoInput(RefreshQuestion question) {
    final current = _answers[question.key] ?? 'non';

    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'Oui',
            isSelected: current == 'oui',
            color: MintColors.coachAccent,
            onTap: () => setState(() => _answers[question.key] = 'oui'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ToggleButton(
            label: 'Non',
            isSelected: current == 'non',
            color: MintColors.coachAccent,
            onTap: () => setState(() => _answers[question.key] = 'non'),
          ),
        ),
      ],
    );
  }

  /// Chip selection for multiple options.
  Widget _buildSelectInput(RefreshQuestion question) {
    final current = _answers[question.key] ?? question.options.first;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: question.options.map((opt) {
        final isSelected = current == opt;
        return ChoiceChip(
          label: Text(_capitalizeFirst(opt)),
          selected: isSelected,
          onSelected: (_) =>
              setState(() => _answers[question.key] = opt),
          selectedColor: MintColors.coachAccent.withAlpha(30),
          checkmarkColor: MintColors.coachAccent,
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? MintColors.coachAccent
                : MintColors.textSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: const Borderconst Radius.circular(20),
            side: BorderSide(
              color:
                  isSelected ? MintColors.coachAccent : MintColors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        );
      }).toList(),
    );
  }

  /// Text field input with CHF suffix.
  Widget _buildTextInput(RefreshQuestion question) {
    return TextFormField(
      initialValue: _answers[question.key],
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        suffixText: 'CHF',
        suffixStyle: GoogleFonts.inter(
          fontSize: 14,
          color: MintColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: const Borderconst Radius.circular(12),
          borderSide: const BorderSide(color: MintColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const Borderconst Radius.circular(12),
          borderSide: const BorderSide(
            color: MintColors.coachAccent,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 18,
        color: MintColors.textPrimary,
      ),
      onChanged: (value) {
        _answers[question.key] = value;
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BOTTOM NAVIGATION
  // ════════════════════════════════════════════════════════════════

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _goNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: MintColors.coachAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: const Borderconst Radius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                _isLastPage ? 'Terminer' : 'Suivant',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Disclaimer on last page
          if (_isLastPage)
            Text(
              widget.refreshData.disclaimer,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatSwissNumber(int value) {
    final str = value.abs().toString();
    final buffer = StringBuffer();
    if (value < 0) buffer.write('-');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

// ════════════════════════════════════════════════════════════════
//  TOGGLE BUTTON WIDGET
// ════════════════════════════════════════════════════════════════

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(15) : MintColors.surface,
          borderRadius: const Borderconst Radius.circular(14),
          border: Border.all(
            color: isSelected ? color : MintColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? color : MintColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
