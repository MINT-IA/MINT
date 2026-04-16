// Phase 28-04 — DocumentResultView
//
// Top-level progressive renderer for a single Stream<DocumentEvent>.
// Subscribes via DocumentProgressiveState, shows the "Tom Hanks reading"
// stream of stage + field reveals, then renders the right chat bubble
// when isComplete fires; if `needsFullReview()` returns true on the
// done event, also opens the ExtractionReviewSheet via post-frame
// callback.
//
// Designed to be embedded inside `document_scan_screen.dart` (post-flag)
// or in any future surface that wants to consume the streaming pipeline.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/document_event.dart';
import 'package:mint_mobile/services/document_progressive_state.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/document/ask_question_bubble.dart';
import 'package:mint_mobile/widgets/document/confirm_extraction_bubble.dart';
import 'package:mint_mobile/widgets/document/extraction_review_sheet.dart';
import 'package:mint_mobile/widgets/document/narrative_bubble.dart';
import 'package:mint_mobile/widgets/document/reject_bubble.dart';
import 'package:mint_mobile/widgets/document/third_party_chip.dart';

class DocumentResultView extends StatefulWidget {
  /// The stream to consume. Pass `null` if a parent provides
  /// DocumentProgressiveState via Provider already (state.consume() called
  /// elsewhere) — useful for tests.
  final Stream<DocumentEvent>? stream;

  /// Triggered when user accepts the confirm bubble or the sheet primary.
  final ValueChanged<List<ExtractedField>>? onConfirm;

  /// Triggered when user rejects (third-party path or reject bubble retry).
  final VoidCallback? onRetry;

  /// Triggered when commitment CTA is accepted in the narrative bubble.
  final void Function(String when, String where, String ifThen, String label)?
      onCommitmentAccepted;

  /// Optional label resolver (defaults to fieldName).
  final String Function(String)? labelFor;

  /// If true, auto-opens the ExtractionReviewSheet when needsFullReview
  /// returns true on the terminal event. Default true.
  final bool autoOpenSheet;

  const DocumentResultView({
    super.key,
    this.stream,
    this.onConfirm,
    this.onRetry,
    this.onCommitmentAccepted,
    this.labelFor,
    this.autoOpenSheet = true,
  });

  @override
  State<DocumentResultView> createState() => _DocumentResultViewState();
}

class _DocumentResultViewState extends State<DocumentResultView> {
  late final DocumentProgressiveState _state;
  bool _ownsState = false;
  bool _sheetShown = false;

  @override
  void initState() {
    super.initState();
    final existing = _maybeProvided();
    if (existing != null) {
      _state = existing;
    } else {
      _state = DocumentProgressiveState();
      _ownsState = true;
    }
    _state.addListener(_onStateChanged);
    if (widget.stream != null) {
      _state.consume(widget.stream!);
    }
  }

  DocumentProgressiveState? _maybeProvided() {
    try {
      return Provider.of<DocumentProgressiveState>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (_state.isComplete && widget.autoOpenSheet && !_sheetShown) {
      final result = _state.toResult();
      if (needsFullReview(result)) {
        _sheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ExtractionReviewSheet.show(
            context,
            result: result,
            onConfirm: (fields) => widget.onConfirm?.call(fields),
            onReject: () => widget.onRetry?.call(),
            labelFor: widget.labelFor,
          );
        });
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    if (_ownsState) {
      _state.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    if (!_state.isComplete) {
      return _ProgressiveReading(state: _state);
    }
    // Terminal — render bubble.
    final result = _state.toResult();
    final mode = _state.renderMode ?? RenderMode.narrative;
    final children = <Widget>[];

    if (_state.thirdPartyDetected) {
      children.add(ThirdPartyChip(
        name: _state.thirdPartyName,
        onYes: () {},
        onNo: () => widget.onRetry?.call(),
      ));
    }

    switch (mode) {
      case RenderMode.confirm:
        children.add(ConfirmExtractionBubble(
          fields: result.extractedFields,
          summary: _state.summary,
          onConfirm: () =>
              widget.onConfirm?.call(result.extractedFields),
          onCorrect: () {
            ExtractionReviewSheet.show(
              context,
              result: result,
              onConfirm: (fields) => widget.onConfirm?.call(fields),
              onReject: () => widget.onRetry?.call(),
              labelFor: widget.labelFor,
            );
          },
          labelFor: widget.labelFor,
        ));
      case RenderMode.ask:
        children.add(AskQuestionBubble(
          confirmedFields: result.extractedFields,
          questions: _state.questionsForUser,
          onAnswer: (_) => widget.onConfirm?.call(result.extractedFields),
          labelFor: widget.labelFor,
        ));
      case RenderMode.narrative:
        children.add(NarrativeBubble(
          narrative: _state.narrative ?? s.documentBubbleRejectMessage,
          commitment: _state.commitment,
          onCommitmentAccepted: widget.onCommitmentAccepted,
        ));
      case RenderMode.reject:
        children.add(RejectBubble(
          onRetry: () => widget.onRetry?.call(),
        ));
    }

    return Column(
      key: const Key('documentResultView'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _ProgressiveReading extends StatelessWidget {
  final DocumentProgressiveState state;

  const _ProgressiveReading({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final stageLabel = state.summary ??
        (state.issuerGuess != null
            ? s.documentScanFamiliarIssuer(state.issuerGuess!)
            : s.documentScanReadingStage);
    return Container(
      key: const Key('progressiveReading'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  stageLabel,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ),
            ],
          ),
          if (state.fields.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...state.fields.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    s.documentScanFieldFound(f.name, f.value?.toString() ?? '—'),
                    style: MintTextStyles.bodySmall(
                            color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
