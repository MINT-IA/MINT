// Phase 29-04 — RenderModeHandler (PRIV-08).
//
// Opaque router: given a DocumentUnderstandingResult, returns which
// bubble should be rendered when render_mode == confirm.
//
// Rule (D-PRIV-08):
//   - <=5 fields AND no humanReviewFlag           → BatchValidationBubble
//   - otherwise                                    → ExtractionReviewSheet
//
// The legacy ConfirmExtractionBubble path stays available for callers
// that haven't migrated; the default document_result_view routes confirm
// through this handler first.
import 'package:mint_mobile/services/document_understanding_result.dart';

enum ConfirmRoute {
  batchValidation,
  extractionReview,
}

class RenderModeHandler {
  /// Pick the confirm-mode route for a given extraction result.
  ///
  /// `maxBatchFields` is the cap above which we hand off to the heavier
  /// ExtractionReviewSheet. Kept configurable for tests; default 5 per
  /// plan 29-04 action.
  static ConfirmRoute routeConfirm(
    DocumentUnderstandingResult result, {
    int maxBatchFields = 5,
  }) {
    if (result.extractedFields.length > maxBatchFields) {
      return ConfirmRoute.extractionReview;
    }
    final hasHumanReview = result.extractedFields.any((f) => f.humanReviewFlag);
    if (hasHumanReview) {
      return ConfirmRoute.extractionReview;
    }
    return ConfirmRoute.batchValidation;
  }
}
