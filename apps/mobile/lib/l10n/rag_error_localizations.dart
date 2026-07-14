import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';

/// Resolves RAG machine failures at a presentation boundary.
///
/// Backend `detail` values remain diagnostic-only. They are not trusted as
/// localized, user-safe copy.
extension RagErrorCodeLocalizations on RagErrorCode {
  String localizedRagMessage(S l10n, {required String fallback}) {
    return switch (this) {
      RagErrorCode.invalidKey => l10n.ragErrorInvalidKey,
      RagErrorCode.rateLimit => l10n.ragErrorRateLimit,
      RagErrorCode.badRequest => l10n.ragErrorBadRequest,
      RagErrorCode.serviceUnavailable => l10n.ragErrorServiceUnavailable,
      RagErrorCode.serverError ||
      RagErrorCode.visionError =>
        l10n.ragErrorServiceUnavailable,
      RagErrorCode.visionBadRequest => l10n.ragErrorVisionBadRequest,
      RagErrorCode.imageTooLarge => l10n.ragErrorImageTooLarge,
      RagErrorCode.statusError => l10n.ragErrorStatus,
      RagErrorCode.taxLocalOnly || RagErrorCode.unknown => fallback,
    };
  }

  String localizedCoachMessage(S l10n) {
    return switch (this) {
      RagErrorCode.invalidKey => l10n.coachErrorInvalidKey,
      RagErrorCode.rateLimit => l10n.coachErrorRateLimit,
      RagErrorCode.badRequest => l10n.coachErrorBadRequest,
      RagErrorCode.serviceUnavailable => l10n.coachErrorServiceUnavailable,
      _ => l10n.coachErrorGeneric,
    };
  }
}
