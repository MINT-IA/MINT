// ────────────────────────────────────────────────────────────────────
//  MintLifeLineSlider — Handoff 2 atomic primitive
// ────────────────────────────────────────────────────────────────────
//
//  Horizontal slider with an « épuisement » vertical marker. Used by
//  Niveau 2 scenes (rente vs capital, rachat LPP, etc.) to let the
//  user drag « espérance de vie » and see the live consequence on
//  the side-by-side numbers.
//
//  Source of truth: Downloads/handoff 2/03-components.md §3 +
//  prototype/chat-vivant/scene-rente-capital.jsx (`LifeLine`).
//
//  Anatomy (top to bottom):
//    1. Header row: « 70 ans » | « Espérance de vie » centered |
//                   « 100 ans » — labelSmall textMutedAaa
//    2. Track: 4px tall, lightBorder fill, rounded
//    3. Fill: from 0 to age%, color = retirementLpp if age > epuisement
//             else retirement3a (peche-toned in our palette)
//    4. Vertical marker at epuisement: 1.5px line, opacity 0.5,
//       label « capital épuisé » below in 9.5pt
//    5. Thumb: 16x16 white circle, 2px border in fill color,
//       subtle shadow
//
//  State: pure — caller owns `age`. Widget is StatelessWidget.
//  The interactive Slider underneath is a Material `Slider` with
//  invisible track (we draw our own).
//
//  Haptics: light impact on integer tick (delegated to
//  HapticFeedback — no platform channel required from caller).
// ────────────────────────────────────────────────────────────────────

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// MintLifeLineSlider — horizontal age slider with epuisement marker.
///
/// `age` is owned by the caller (typically a Stateful parent scene).
/// The slider emits `onAgeChanged(int)` on every drag tick.
///
/// `ageEpuisement` is the static x-axis marker showing where the
/// capital placé runs out — drives both the marker position AND the
/// fill color (sauge if rente wins, peche if capital wins).
class MintLifeLineSlider extends StatelessWidget {
  /// Current age (typically 70..100). Caller-owned.
  final int age;

  /// Callback fired on every slider tick.
  final ValueChanged<int> onAgeChanged;

  /// Age at which the « capital placé » runs out (drives marker).
  final int ageEpuisement;

  /// Min slider bound. Default 70.
  final int min;

  /// Max slider bound. Default 100.
  final int max;

  /// Whether to fire haptic feedback on every integer tick. Default true.
  /// Disabled in tests (where HapticFeedback is a no-op anyway).
  final bool haptic;

  /// Optional [Semantics] label. When omitted, the slider exposes
  /// « Espérance de vie : N ans » to screen readers.
  final String? semanticsLabel;

  const MintLifeLineSlider({
    super.key,
    required this.age,
    required this.onAgeChanged,
    required this.ageEpuisement,
    this.min = 70,
    this.max = 100,
    this.haptic = true,
    this.semanticsLabel,
  });

  bool get _avantageRente => age > ageEpuisement;

  Color get _fillColor =>
      _avantageRente ? MintColors.retirementLpp : MintColors.pecheDouce;

  double get _agePct => ((age - min) / (max - min)).clamp(0.0, 1.0);
  double get _epuisementPct =>
      ((ageEpuisement - min) / (max - min)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      value: 'Espérance de vie : $age ans',
      label: semanticsLabel ?? 'Curseur espérance de vie',
      increasedValue: age < max ? '${age + 1} ans' : null,
      decreasedValue: age > min ? '${age - 1} ans' : null,
      onIncrease: age < max ? () => onAgeChanged(age + 1) : null,
      onDecrease: age > min ? () => onAgeChanged(age - 1) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row.
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$min ans',
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMutedAaa,
                  ),
                ),
                Text(
                  'Espérance de vie',
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondaryAaa,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$max ans',
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMutedAaa,
                  ),
                ),
              ],
            ),
          ),
          // Track + fill + marker + thumb (custom-painted).
          SizedBox(
            height: 36,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final fillWidth = width * _agePct;
                final markerLeft = (width * _epuisementPct).clamp(0.0, width);
                final thumbLeft = (fillWidth - 8).clamp(0.0, width - 16);
                return Stack(
                  children: [
                    // Background track.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 16,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: MintColors.lightBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Filled portion (animated via implicit AnimatedContainer).
                    Positioned(
                      left: 0,
                      top: 16,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 4,
                        width: fillWidth,
                        decoration: BoxDecoration(
                          color: _fillColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Vertical epuisement marker.
                    Positioned(
                      left: markerLeft - 0.75,
                      top: 10,
                      child: Container(
                        width: 1.5,
                        height: 16,
                        color:
                            MintColors.textMutedAaa.withValues(alpha: 0.5),
                      ),
                    ),
                    // « capital épuisé » label.
                    Positioned(
                      left: markerLeft - 35,
                      top: 28,
                      width: 70,
                      child: Text(
                        'capital épuisé',
                        textAlign: TextAlign.center,
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textMutedAaa,
                        ).copyWith(fontSize: 9.5, height: 1.0),
                        overflow: TextOverflow.visible,
                      ),
                    ),
                    // Visual thumb (decorative — actual hit target is the Slider).
                    Positioned(
                      left: thumbLeft,
                      top: 10,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _fillColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Invisible Material Slider for hit testing + a11y.
                    // SliderTheme strips all visual chrome — the visible
                    // track + thumb are drawn above.
                    Positioned.fill(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Colors.transparent,
                          overlayColor: Colors.transparent,
                          trackHeight: 36,
                          thumbShape: SliderComponentShape.noThumb,
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 0),
                          showValueIndicator: ShowValueIndicator.never,
                        ),
                        child: Slider(
                          min: min.toDouble(),
                          max: max.toDouble(),
                          divisions: max - min,
                          value: age.toDouble().clamp(
                                min.toDouble(),
                                max.toDouble(),
                              ),
                          onChanged: (v) {
                            final next = v.round();
                            if (next != age) {
                              if (haptic) HapticFeedback.selectionClick();
                              onAgeChanged(next);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
