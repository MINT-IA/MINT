import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/preferences/coach_tone_preference.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Settings › Ton du coach — Phase 91 Plan 91-01 (VIVANT-04).
///
/// Lets the user pick the voice tone of the coach chat (Calme / Direct /
/// Sans filtre). Persisted via [CoachTonePreferenceStore] in
/// `coach_tone_preference` (default: calm). Replaces the inline chips that
/// used to live at `coach_chat_screen.dart:2340-2400`.
///
/// Single-select, three radio rows. Mirrors the [LangueSettingsScreen]
/// pattern (same MintSurface + InkWell row + check icon for the selected
/// option) — no new ARB keys (reuses `tonChooserTitle`, `tonChooserSubtitle`,
/// `tonSoftLabel`, `tonDirectLabel`, `tonUnfilteredLabel`,
/// `tonSoftExample`, `tonDirectExample`, `tonUnfilteredExample` — see
/// 91-CONTEXT.md decisions VIVANT-04).
///
/// Route: `/settings/coach-tone`.
class CoachToneScreen extends StatefulWidget {
  const CoachToneScreen({super.key, this.store = const CoachTonePreferenceStore()});

  /// Injectable for tests.
  final CoachTonePreferenceStore store;

  @override
  State<CoachToneScreen> createState() => _CoachToneScreenState();
}

class _CoachToneScreenState extends State<CoachToneScreen> {
  CoachTonePreference? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.store.load();
    if (mounted) {
      setState(() => _current = value);
    }
  }

  Future<void> _onSelect(CoachTonePreference value, S s) async {
    if (_current == value) return;
    HapticFeedback.selectionClick();
    setState(() => _current = value);
    final ok = await widget.store.save(value);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Reuses `voiceCursorPreferenceLabel` ("Ton") to label the
          // confirmation. No new ARB key per VIVANT-04.
          content: Text('${s.voiceCursorPreferenceLabel} : ${_label(value, s)}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _label(CoachTonePreference value, S s) {
    switch (value) {
      case CoachTonePreference.calm:
        return s.tonSoftLabel; // "Doux" — anti-shame, see ARB description.
      case CoachTonePreference.direct:
        return s.tonDirectLabel;
      case CoachTonePreference.sansFilter:
        return s.tonUnfilteredLabel;
    }
  }

  String _example(CoachTonePreference value, S s) {
    switch (value) {
      case CoachTonePreference.calm:
        return s.tonSoftExample;
      case CoachTonePreference.direct:
        return s.tonDirectExample;
      case CoachTonePreference.sansFilter:
        return s.tonUnfilteredExample;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final loaded = _current != null;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          s.tonChooserTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
            child: Text(
              s.tonChooserSubtitle,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          for (final value in CoachTonePreference.values) ...[
            _ToneRow(
              key: ValueKey('coach_tone_row_${value.name}'),
              value: value,
              label: _label(value, s),
              example: _example(value, s),
              selected: loaded && _current == value,
              onTap: loaded ? () => _onSelect(value, s) : null,
            ),
            const SizedBox(height: MintSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ToneRow extends StatelessWidget {
  const _ToneRow({
    super.key,
    required this.value,
    required this.label,
    required this.example,
    required this.selected,
    required this.onTap,
  });

  final CoachTonePreference value;
  final String label;
  final String example;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: MintSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        example,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MintSpacing.md),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? MintColors.primary : MintColors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
