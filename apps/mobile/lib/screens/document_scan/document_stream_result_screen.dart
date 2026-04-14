// Phase 28-04 — DocumentStreamResultScreen
//
// Lightweight scaffold that hosts a DocumentResultView fed by an SSE
// Stream<DocumentEvent> from `DocumentService.understandDocumentStream`.
//
// Used when DOCUMENTS_V2_ENABLED is on for the user. The legacy
// ExtractionReviewScreen survives as a deep-link fallback (28-04 plan).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/models/document_event.dart';
import 'package:mint_mobile/services/commitment_service.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/document/document_result_view.dart';

class DocumentStreamResultScreen extends StatelessWidget {
  /// The live stream of SSE events from the backend pipeline.
  final Stream<DocumentEvent> stream;

  /// Optional label resolver for human field labels.
  final String Function(String)? labelFor;

  const DocumentStreamResultScreen({
    super.key,
    required this.stream,
    this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: MintColors.textPrimary),
          onPressed: () => safePop(context),
        ),
        title: Text(
          'Lecture du document',
          style: MintTextStyles.bodyLarge(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: DocumentResultView(
              stream: stream,
              labelFor: labelFor,
              onConfirm: (List<ExtractedField> fields) {
                // For now, navigate back; downstream screens will wire
                // persistence (Phase 29 consent gate + biography save).
                safePop(context);
              },
              onRetry: () {
                safePop(context);
              },
              onCommitmentAccepted: (when, where, ifThen, label) {
                // Wire to Phase 14 commitment service.
                CommitmentService().acceptCommitment(
                  whenText: when,
                  whereText: where,
                  ifThenText: ifThen,
                  reminderTitle: label,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to push the streaming result screen from anywhere with a stream.
Future<void> pushDocumentStreamResult(
  BuildContext context,
  Stream<DocumentEvent> stream, {
  String Function(String)? labelFor,
}) async {
  await context.push<void>(
    '/scan/stream-result',
    extra: <String, dynamic>{
      'stream': stream,
      'labelFor': labelFor,
    },
  );
}
