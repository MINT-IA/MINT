/// MintSceneLacunesAvs — W2 archetype-truth onboarding scene.
///
/// Asks whether the user spent years outside Switzerland so AVS gaps are
/// known instead of presumed « carrière-complète » (NEVER #7). Writes
/// `q_avs_lacunes_status` (and, when applicable, `q_avs_arrival_year` or
/// `q_avs_years_abroad`) to [CoachProfileProvider] via `mergeAnswers`
/// with the EXACT values `CoachProfile.fromWizardAnswers`
/// (coach_profile.dart:2802-2824) switches on:
///   - Non, toujours en Suisse     → `no_gaps`
///   - Oui, années à l'étranger    → `lived_abroad` (+ q_avs_years_abroad)
///   - Arrivé en Suisse plus tard  → `arrived_late` (+ q_avs_arrival_year)
///   - Je ne sais pas              → `unknown`
///
/// Two-step: first the status; if the answer needs a year/count, a small
/// numeric follow-up appears before `onAnswered` fires.
///
/// References:
/// - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md (W2)
/// - lib/models/coach_profile.dart:2802 (q_avs_lacunes_status reader)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/widgets/onboarding_choice_button.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Internal AVS-lacunes values matching `fromWizardAnswers` EXACTLY.
const String kAvsNoGaps = 'no_gaps';
const String kAvsLivedAbroad = 'lived_abroad';
const String kAvsArrivedLate = 'arrived_late';
const String kAvsUnknown = 'unknown';

class MintSceneLacunesAvs extends StatefulWidget {
  const MintSceneLacunesAvs({
    super.key,
    required this.onAnswered,
  });

  /// Called with the chosen `q_avs_lacunes_status` value AFTER the provider
  /// write completes, plus the optional numeric follow-up so the terminal
  /// onboarding flush can re-emit it (ReportPersistenceService.saveAnswers
  /// REPLACES the store, so the flush map must carry every captured key).
  /// [arrivalYear] is set for `arrived_late`; [yearsAbroad] for
  /// `lived_abroad`. The parent orchestrator advances on this callback.
  final void Function(
    String avsLacunesStatus, {
    int? arrivalYear,
    int? yearsAbroad,
  }) onAnswered;

  @override
  State<MintSceneLacunesAvs> createState() => _MintSceneLacunesAvsState();
}

class _MintSceneLacunesAvsState extends State<MintSceneLacunesAvs> {
  /// null while choosing status; set once a year/count follow-up is needed.
  String? _pendingStatus;
  final _numberController = TextEditingController();
  int? _parsedNumber;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _writeAndFinish(
    String status, {
    int? arrivalYear,
    int? yearsAbroad,
  }) async {
    final provider = context.read<CoachProfileProvider>();
    final answers = <String, dynamic>{'q_avs_lacunes_status': status};
    if (arrivalYear != null) answers['q_avs_arrival_year'] = arrivalYear;
    if (yearsAbroad != null) answers['q_avs_years_abroad'] = yearsAbroad;
    await provider.mergeAnswers(answers);
    widget.onAnswered(
      status,
      arrivalYear: arrivalYear,
      yearsAbroad: yearsAbroad,
    );
  }

  void _pickStatus(String status) {
    if (status == kAvsArrivedLate || status == kAvsLivedAbroad) {
      // Needs a numeric follow-up — switch to the second sub-step.
      setState(() {
        _pendingStatus = status;
        _parsedNumber = null;
        _numberController.clear();
      });
      return;
    }
    // no_gaps / unknown write immediately, no follow-up.
    _writeAndFinish(status);
  }

  void _submitFollowUp() {
    final status = _pendingStatus;
    final n = _parsedNumber;
    if (status == null || n == null) return;
    if (status == kAvsArrivedLate) {
      _writeAndFinish(status, arrivalYear: n);
    } else {
      _writeAndFinish(status, yearsAbroad: n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    if (_pendingStatus != null) return _buildFollowUp(context, l);
    return _buildStatusChoice(context, l);
  }

  Widget _buildStatusChoice(BuildContext context, S l) {
    // (value, label, key, semantics position hint)
    final options = <(String, String, String, String)>[
      (kAvsNoGaps, l.onboardingAvsNoGaps, 'onboarding-avs-no-gaps', '1 / 4'),
      (
        kAvsLivedAbroad,
        l.onboardingAvsLivedAbroad,
        'onboarding-avs-lived-abroad',
        '2 / 4',
      ),
      (
        kAvsArrivedLate,
        l.onboardingAvsArrivedLate,
        'onboarding-avs-arrived-late',
        '3 / 4',
      ),
      (kAvsUnknown, l.onboardingAvsUnknown, 'onboarding-avs-unknown', '4 / 4'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.onboardingAvsPrompt,
              style: MintTextStyles.headlineMedium(
                color: MintColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.xl),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                child: Semantics(
                  container: true,
                  label: l.onboardingAvsPrompt,
                  child: Column(
                    children: [
                      for (final (value, label, key, _) in options) ...[
                        OnboardingChoiceButton(
                          key: ValueKey(key),
                          label: label,
                          onPressed: () => _pickStatus(value),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUp(BuildContext context, S l) {
    final isArrival = _pendingStatus == kAvsArrivedLate;
    final prompt = isArrival
        ? l.onboardingAvsArrivalYearPrompt
        : l.onboardingAvsYearsAbroadPrompt;
    // Arrival year: 4 digits within a plausible range. Years abroad: 1-2
    // digits. Both validated before the Continue CTA enables.
    final maxLen = isArrival ? 4 : 2;
    final currentYear = DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              prompt,
              style: MintTextStyles.headlineMedium(
                color: MintColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            key: const ValueKey('onboarding-avs-number-field'),
            controller: _numberController,
            keyboardType: TextInputType.number,
            autofocus: true,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(maxLen),
            ],
            style: MintTextStyles.displayMedium(
              color: MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
            ),
            onChanged: (raw) {
              final n = int.tryParse(raw);
              setState(() {
                if (n == null) {
                  _parsedNumber = null;
                } else if (isArrival) {
                  // Plausible arrival year window.
                  _parsedNumber = (n >= 1950 && n <= currentYear) ? n : null;
                } else {
                  // Years abroad: 1..60.
                  _parsedNumber = (n >= 1 && n <= 60) ? n : null;
                }
              });
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Semantics(
              button: true,
              label: l.onboardingAvsContinue,
              child: FilledButton(
                // lint-ignore: prefer_mint_cta
                key: const ValueKey('onboarding-avs-continue'),
                onPressed: _parsedNumber == null ? null : _submitFollowUp,
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.textPrimary,
                  disabledBackgroundColor:
                      MintColors.textSecondary.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l.onboardingAvsContinue,
                  style: MintTextStyles.labelLarge(color: MintColors.white)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
