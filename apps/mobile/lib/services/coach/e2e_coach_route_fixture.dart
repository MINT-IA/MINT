import 'package:flutter/foundation.dart';

import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/rag_service.dart';

/// Debug-only Coach route fixture for deterministic Maestro Row 16 proof.
///
/// This bypasses live LLM/backend only when explicitly enabled by
/// `--dart-define=MINT_E2E_COACH_ROUTE_FIXTURE=retirement_choice`.
/// It must never activate in release builds.
abstract final class E2eCoachRouteFixture {
  static const _fixtureName =
      String.fromEnvironment('MINT_E2E_COACH_ROUTE_FIXTURE');

  static OrchestratorChatFn? orchestratorOrNull() {
    return orchestratorFor(_fixtureName, debugMode: kDebugMode);
  }

  @visibleForTesting
  static OrchestratorChatFn? orchestratorFor(
    String fixtureName, {
    required bool debugMode,
  }) {
    if (!debugMode) return null;
    if (fixtureName != 'retirement_choice') return null;

    return ({
      required userMessage,
      required history,
      required ctx,
      byokConfig,
      memoryBlock,
      language = 'fr',
      cashLevel = 3,
      isLoggedIn = false,
    }) async {
      return const CoachResponse(
        message: 'Ouvre le bon outil pour comparer.',
        disclaimer: 'Outil educatif.',
        toolCalls: [
          RagToolCall(
            name: 'route_to_screen',
            input: {
              'intent': 'retirement_choice',
              'confidence': 0.9,
              'context_message':
                  'Compare la rente et le capital avec tes donnees.',
            },
          ),
        ],
      );
    };
  }
}
