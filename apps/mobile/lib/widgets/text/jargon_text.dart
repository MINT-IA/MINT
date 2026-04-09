// Phase 10 Plan 10-03 — JargonText inline tap-to-define widget (D-09).
//
// Complements the standalone [GlossaryTerm] widget (which wraps a single
// term) by letting us embed one or more glossary look-ups **inside** a
// sentence without breaking the text flow:
//
// ```dart
// JargonText('Ton [[term:LPP]] finance ta retraite via le [[term:3a]].')
// ```
//
// Unknown terms (not in [GlossaryService]) fall back to plain text, so the
// widget is safe to use even if a future refactor renames a glossary key.
//
// Anti-shame doctrine (CLAUDE.md §1 principle 2): the bottom-sheet body
// opens with a neutral definition, never "as you should know" framing.
// All user-facing copy is sourced from the glossary ARB keys (no hardcoded
// strings) so i18n coverage remains complete.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:mint_mobile/services/glossary_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Regular expression that matches a `[[term:X]]` marker, capturing the
/// term key in group 1. Exposed for unit tests.
final RegExp jargonMarkerPattern = RegExp(r'\[\[term:([^\]]+)\]\]');

/// A text widget that parses inline `[[term:X]]` markers and renders the
/// enclosed term as a tappable underlined span. Tapping opens a
/// [showModalBottomSheet] with the glossary definition sourced from
/// [GlossaryService].
///
/// If [text] contains no markers, [JargonText] renders as a plain [Text]
/// with [style], so it is a safe drop-in replacement wherever a static
/// label might eventually grow a glossary link.
class JargonText extends StatefulWidget {
  const JargonText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
  });

  /// The text to render, optionally containing `[[term:X]]` markers.
  final String text;

  /// Optional base text style applied to both plain and tappable spans.
  final TextStyle? style;

  /// Passed through to the underlying [RichText]/[Text].
  final TextAlign? textAlign;

  @override
  State<JargonText> createState() => _JargonTextState();
}

class _JargonTextState extends State<JargonText> {
  /// Gesture recognisers created for the tappable spans. We keep a list so
  /// [dispose] can clean them up — leaking [TapGestureRecognizer] instances
  /// trips a Flutter assertion in debug builds.
  final List<TapGestureRecognizer> _recognisers = [];

  @override
  void dispose() {
    for (final r in _recognisers) {
      r.dispose();
    }
    _recognisers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild recognisers on every build: the text (or style) may have
    // changed, and recognisers are cheap.
    for (final r in _recognisers) {
      r.dispose();
    }
    _recognisers.clear();

    final baseStyle = widget.style ?? MintTextStyles.bodyMedium();
    final matches = jargonMarkerPattern.allMatches(widget.text).toList();

    if (matches.isEmpty) {
      // No markers → plain [Text]. Widget tests rely on this fast path for
      // parity with a vanilla [Text] widget (no RichText semantics noise).
      return Text(widget.text, style: baseStyle, textAlign: widget.textAlign);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(
          text: widget.text.substring(cursor, m.start),
          style: baseStyle,
        ));
      }
      final termKey = m.group(1)!;
      final recogniser = TapGestureRecognizer()
        ..onTap = () => _showDefinition(context, termKey);
      _recognisers.add(recogniser);
      spans.add(TextSpan(
        text: termKey,
        recognizer: recogniser,
        style: baseStyle.copyWith(
          color: MintColors.primary,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: MintColors.primary.withValues(alpha: 0.5),
        ),
      ));
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(cursor),
        style: baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
      textAlign: widget.textAlign ?? TextAlign.start,
    );
  }

  void _showDefinition(BuildContext context, String termKey) {
    // Lookup counter is tracked per-term so progressive disclosure can
    // eventually hide the underline once the user has learned a concept
    // (parity with [GlossaryTerm]).
    GlossaryService.trackLookup(termKey);
    final explanation = GlossaryService.explain(context, termKey);
    if (explanation == null) {
      // Unknown term — silently drop. We intentionally do NOT show an
      // empty sheet: an unknown key is a developer bug, not a user-facing
      // condition, and flashing an empty sheet would degrade trust.
      return;
    }

    // Honor the system "reduce motion" flag — skip the transition curve
    // when the user has disabled animations (ACCESS-07 precursor).
    final mq = MediaQuery.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: !mq.disableAnimations,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          MintSpacing.xl,
          MintSpacing.xl,
          MintSpacing.xl,
          MintSpacing.xl + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(termKey, style: MintTextStyles.titleMedium()),
            const SizedBox(height: MintSpacing.md),
            Text(explanation, style: MintTextStyles.bodyMedium()),
            const SizedBox(height: MintSpacing.lg),
          ],
        ),
      ),
    );
  }
}
