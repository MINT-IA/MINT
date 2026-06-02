// Phase 72 — `_EclairageCard` widget render.
//
// Renders a "Premier Éclairage" hero card from a backend payload (Phase 71b)
// in the anonymous chat flow. Layout, typography, color tokens and a11y
// behavior are LOCKED by `.planning/phases/72-eclairage-card-render/PANEL-VERDICT.md`.
//
// Defensive design: backend payload may be partial; render gracefully when
// CHF range bounds are missing, when softAccountHint is empty, or when
// headline / body are blank. The LSFin disclaimer is intentionally NOT
// rendered here — Phase 71a §1.4 above-input disclaimer is single source.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Premier Éclairage hero card surfaced after the 2nd coach turn in the
/// anonymous chat flow (gate ECL-01, Phase 71a state-machine).
///
/// Constructor takes a defensively-parsed backend payload as
/// `Map<String, dynamic>` (camelCase fields, see Phase 71b backend spec):
///
/// ```
/// {
///   'kind': String,            // 'fiscal_margin_3a' | 'lpp_gap' | 'tax_friction'
///   'headline': String,        // ≤ 80 chars
///   'body': String,            // ≤ 240 chars
///   'chfRangeLow': int?,       // nullable
///   'chfRangeHigh': int?,      // nullable
///   'chfRangePeriod': String,  // 'year' | 'month' | 'lifetime'
///   'softAccountHint': String, // ≤ 80 chars
///   'lsfinDisclaimer': String, // SKIPPED — above-input is single source
/// }
/// ```
class EclairageCard extends StatelessWidget {
  /// Backend payload, parsed defensively at render-time.
  final Map<String, dynamic> payload;

  const EclairageCard({required this.payload, super.key});

  // ── Defensive accessors ─────────────────────────────────────────────

  String get _headline => (payload['headline'] as String? ?? '').trim();
  String get _body => (payload['body'] as String? ?? '').trim();
  int? get _chfRangeLow {
    final v = payload['chfRangeLow'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  int? get _chfRangeHigh {
    final v = payload['chfRangeHigh'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  String get _softAccountHint =>
      (payload['softAccountHint'] as String? ?? '').trim();

  /// Swiss thousand-separator (apostrophe).
  /// `1500` → `1'500`, `1500000` → `1'500'000`.
  static String formatChf(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => "${m.group(1)}'",
      );

  /// VoiceOver-friendly range read-out.
  ///
  /// VoiceOver reads apostrophe-separated numerals as garbage; pass plain
  /// digits + literal "francs par an" so screen reader output is clean.
  String get _rangeReadable {
    final low = _chfRangeLow;
    final high = _chfRangeHigh;
    if (low != null && high != null) {
      return 'entre $low et $high francs par an';
    }
    if (low == null && high != null) {
      return "jusqu'à $high francs par an";
    }
    if (high == null && low != null) {
      return 'à partir de $low francs par an';
    }
    return '';
  }

  bool get _hasRange => _chfRangeLow != null || _chfRangeHigh != null;

  @override
  Widget build(BuildContext context) {
    // §5 row 3 — render-guard: if either headline or body is empty, omit
    // the card entirely. Caller is expected to skip this when payload is
    // null already, but we guard regardless (defensive).
    if (_headline.isEmpty || _body.isEmpty) {
      return const SizedBox.shrink();
    }

    const eyebrow = 'Premier éclairage';
    final semanticsLabel =
        '$eyebrow. $_headline. ${_rangeReadable.isNotEmpty ? '$_rangeReadable. ' : ''}$_body.';

    return Padding(
      // §1 — margin top 8 / bottom 16 (visual separation from coach bubble).
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Semantics(
        container: true,
        label: semanticsLabel,
        button: false,
        child: ExcludeSemantics(
          // The Semantics label above already reads the full card; skip
          // the inner Text widgets to avoid double read-out by VoiceOver.
          // softAccountHint sits OUTSIDE this ExcludeSemantics (own
          // Semantics block below) so it remains tappable and announced
          // as a separate button.
          excluding: false,
          child: Container(
            // §1 — full chat row width (caller should provide row context;
            // we just stretch to parent constraints).
            width: double.infinity,
            decoration: BoxDecoration(
              color: MintColors.craieHandoff,
              border: Border.all(
                color: MintColors.borderSubtle,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(16),
              // §1 — NO shadow.
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // §1 — 3px mintForest left accent ribbon, full height.
                    Container(
                      width: 3,
                      color: MintColors.mintForest,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1 — Eyebrow
                            _buildEyebrow(eyebrow),
                            const SizedBox(height: 6),
                            // 2 — Headline
                            _buildHeadline(),
                            // 3 — CHF range (omitted if both bounds null)
                            if (_hasRange) ...[
                              const SizedBox(height: 12),
                              _buildRangeRow(),
                            ],
                            // 4 — Body
                            const SizedBox(height: 12),
                            _buildBody(),
                            // 5 — softAccountHint (omitted if empty)
                            if (_softAccountHint.isNotEmpty)
                              _buildSoftAccountHint(context),
                            // 6 — disclaimer SKIPPED (Phase 71a §1.4).
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section builders ────────────────────────────────────────────────

  Widget _buildEyebrow(String text) {
    return Text(
      text.toUpperCase(),
      style: MintTextStyles.labelSmall(color: MintColors.mintForest).copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildHeadline() {
    return Text(
      _headline,
      style: MintTextStyles.titleLarge(color: MintColors.inkPrimary).copyWith(
        fontFamily: 'Gambarino',
        fontWeight: FontWeight.w500,
        // §7 row 1 — italic OFF.
        fontStyle: FontStyle.normal,
      ),
    );
  }

  /// CHF range visual — three null-fallback paths per §2.
  Widget _buildRangeRow() {
    final low = _chfRangeLow;
    final high = _chfRangeHigh;

    final numberStyle =
        MintTextStyles.displaySmall(color: MintColors.inkPrimary).copyWith(
      letterSpacing: -0.3,
      height: 1.0,
    );

    final chfBadgeStyle = MintTextStyles.labelMedium(
      color: MintColors.mintForest,
    ).copyWith(fontWeight: FontWeight.w600);

    final periodStyle =
        MintTextStyles.bodySmall(color: MintColors.textSecondaryAaa);

    final prefixStyle =
        MintTextStyles.bodySmall(color: MintColors.textSecondaryAaa);

    // Fallback A — both bounds present : `[CHF] 1'500 – 2'500 / an`
    // Wrap (instead of Row) so very narrow widths flow to a 2nd line
    // gracefully instead of throwing RenderFlex overflow.
    if (low != null && high != null) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: Text('CHF', style: chfBadgeStyle),
          ),
          Text(formatChf(low), style: numberStyle),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '–', // en-dash U+2013
              style: numberStyle.copyWith(
                fontWeight: FontWeight.w400,
                color: MintColors.textSecondaryAaa,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(formatChf(high), style: numberStyle),
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Text(' / an', style: periodStyle),
          ),
        ],
      );
    }

    // Fallback B — only high present : `jusqu'à CHF 2'500 / an`
    if (low == null && high != null) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            child: Text("jusqu'à", style: prefixStyle),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: Text('CHF', style: chfBadgeStyle),
          ),
          Text(formatChf(high), style: numberStyle),
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Text(' / an', style: periodStyle),
          ),
        ],
      );
    }

    // Fallback C — only low present : `dès CHF 1'500 / an`
    if (high == null && low != null) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            child: Text('dès', style: prefixStyle),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: Text('CHF', style: chfBadgeStyle),
          ),
          Text(formatChf(low), style: numberStyle),
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Text(' / an', style: periodStyle),
          ),
        ],
      );
    }

    // Both null — caller never reaches here (guarded by _hasRange).
    return const SizedBox.shrink();
  }

  Widget _buildBody() {
    return Text(
      _body,
      style: MintTextStyles.bodyMedium(color: MintColors.inkPrimary),
      // §5 row 1 — NO maxLines, NO ellipsis. Card grows vertically.
    );
  }

  /// softAccountHint inline-pull row : marginTop 14, min-height 44dp.
  Widget _buildSoftAccountHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        button: true,
        label: _softAccountHint,
        hint: 'Crée un compte',
        excludeSemantics: false,
        child: Material(
          color: MintColors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push(
                '/auth/register?redirect=/anonymous/chat',
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _softAccountHint,
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.mintForest,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: MintColors.mintForest,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
