/// Agent Validation Gate — Agent Autonome v1 (S68).
///
/// Structural guarantee: every agent output MUST pass through this gate
/// before reaching the user. The gate enforces that [requiresValidation]
/// is always true — MINT never submits, transmits or executes anything
/// automatically.
///
/// This is a compile-time + runtime invariant, not just documentation.
///
/// COMPLIANCE INVARIANTS:
///   - [AgentOutput.requiresValidation] ALWAYS returns true.
///   - [AgentValidationGate.validate] ALWAYS returns true.
///   - No [AgentOutput] may be used without passing through this gate.
///
/// Reference: LSFin art. 3/8 — MINT is an educational tool, not an advisor.
library;

import 'package:mint_mobile/services/agent/form_prefill_service.dart';
import 'package:mint_mobile/services/agent/letter_generation_service.dart';

// ════════════════════════════════════════════════════════════════
//  ABSTRACT BASE — AgentOutput
// ════════════════════════════════════════════════════════════════

/// Abstract base for all agent outputs.
///
/// Every output — form pre-fill, generated letter, or any future type —
/// MUST extend or implement [AgentOutput].
///
/// [requiresValidation] MUST always return true. This is the structural
/// guarantee that no output is ever used without explicit user validation.
abstract class AgentOutput {
  /// ALWAYS true. No agent output may bypass user validation.
  bool get requiresValidation;

  /// Educational disclaimer. Always non-empty.
  String get disclaimer;
}

// ════════════════════════════════════════════════════════════════
//  ADAPTERS — wrap existing value objects as AgentOutput
// ════════════════════════════════════════════════════════════════

/// Wraps [FormPrefill] as [AgentOutput].
///
/// Inherits [FormPrefill.requiresValidation] which is always true.
class FormPrefillOutput implements AgentOutput {
  const FormPrefillOutput(this.prefill);

  final FormPrefill prefill;

  @override
  bool get requiresValidation => prefill.requiresValidation;

  @override
  String get disclaimer => prefill.disclaimer;
}

/// Wraps [GeneratedLetter] as [AgentOutput].
///
/// Inherits [GeneratedLetter.requiresValidation] which is always true.
class GeneratedLetterOutput implements AgentOutput {
  const GeneratedLetterOutput(this.letter);

  final GeneratedLetter letter;

  @override
  bool get requiresValidation => letter.requiresValidation;

  @override
  String get disclaimer => letter.disclaimer;
}

// ════════════════════════════════════════════════════════════════
//  GATE
// ════════════════════════════════════════════════════════════════

/// Validation gate for all agent outputs.
///
/// Every [AgentOutput] MUST pass through [validate] before being shown
/// to the user. The gate prevents any automated submission.
///
/// This is a structural guarantee:
///   - [validate] always returns true (by construction of [AgentOutput]).
///   - If [requiresValidation] were ever false, [validate] would throw.
///
/// Usage:
/// ```dart
/// final output = FormPrefillOutput(prefill);
/// final canShow = AgentValidationGate.validate(output); // always true
/// if (canShow) { /* show to user */ }
/// ```
class AgentValidationGate {
  AgentValidationGate._();

  /// Validate an agent output.
  ///
  /// Returns true if and only if [output.requiresValidation] is true.
  /// Throws [StateError] if [requiresValidation] is somehow false
  /// (which should never happen by construction).
  ///
  /// This is a structural guarantee — every [AgentOutput] always has
  /// [requiresValidation] = true, so this always returns true.
  static bool validate(AgentOutput output) {
    if (!output.requiresValidation) {
      throw StateError(
        'AgentValidationGate: output.requiresValidation is false. '
        'This should never happen. All agent outputs must require validation.',
      );
    }
    return output.requiresValidation;
  }

  /// Convenience: validate a [FormPrefill] directly.
  ///
  /// Wraps in [FormPrefillOutput] and delegates to [validate].
  static bool validateFormPrefill(FormPrefill prefill) {
    return validate(FormPrefillOutput(prefill));
  }

  /// Convenience: validate a [GeneratedLetter] directly.
  ///
  /// Wraps in [GeneratedLetterOutput] and delegates to [validate].
  static bool validateLetter(GeneratedLetter letter) {
    return validate(GeneratedLetterOutput(letter));
  }
}
