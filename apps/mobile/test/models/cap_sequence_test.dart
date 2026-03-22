import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/cap_sequence.dart';

// ────────────────────────────────────────────────────────────────
//  CAP SEQUENCE — Model Tests
// ────────────────────────────────────────────────────────────────
//
//  Validates:
//  - Construction from steps
//  - progressPercent accuracy
//  - isComplete flag
//  - currentStep / nextStep resolution
//  - CapSequence.fromSteps() auto-promotes first non-completed to current
//  - Edge cases: empty steps, all completed, all blocked, all upcoming
// ────────────────────────────────────────────────────────────────

CapStep _step({
  required String id,
  required int order,
  required CapStepStatus status,
  String? intentTag,
  double? impactEstimate,
}) {
  return CapStep(
    id: id,
    order: order,
    titleKey: 'capStepRetirement0${order}Title',
    status: status,
    intentTag: intentTag,
    impactEstimate: impactEstimate,
  );
}

void main() {
  // ── CapStep ──────────────────────────────────────────────────

  group('CapStep', () {
    test('withStatus returns new step with changed status', () {
      final step = _step(id: 's1', order: 1, status: CapStepStatus.upcoming);
      final promoted = step.withStatus(CapStepStatus.current);

      expect(promoted.id, equals('s1'));
      expect(promoted.order, equals(1));
      expect(promoted.titleKey, equals(step.titleKey));
      expect(promoted.status, equals(CapStepStatus.current));
    });

    test('withStatus preserves intentTag and impactEstimate', () {
      final step = _step(
        id: 's2',
        order: 2,
        status: CapStepStatus.upcoming,
        intentTag: '/avs',
        impactEstimate: 1250.0,
      );
      final completed = step.withStatus(CapStepStatus.completed);

      expect(completed.intentTag, equals('/avs'));
      expect(completed.impactEstimate, equals(1250.0));
    });
  });

  // ── CapSequence.fromSteps ────────────────────────────────────

  group('CapSequence.fromSteps — construction', () {
    test('empty steps produces empty sequence', () {
      final seq = CapSequence.fromSteps(goalId: 'test', steps: []);

      expect(seq.hasSteps, isFalse);
      expect(seq.completedCount, equals(0));
      expect(seq.totalCount, equals(0));
      expect(seq.progressPercent, equals(0.0));
      expect(seq.isComplete, isFalse);
      expect(seq.currentStep, isNull);
      expect(seq.nextStep, isNull);
    });

    test('sorts steps by order regardless of insertion order', () {
      final steps = [
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.steps[0].id, equals('s1'));
      expect(seq.steps[1].id, equals('s2'));
      expect(seq.steps[2].id, equals('s3'));
    });

    test('completedCount counts only completed steps', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.completed),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
        _step(id: 's4', order: 4, status: CapStepStatus.blocked),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.completedCount, equals(2));
      expect(seq.totalCount, equals(4));
    });

    test('progressPercent is correct fraction', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.completed),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
        _step(id: 's4', order: 4, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.progressPercent, equals(0.5));
    });
  });

  // ── CapSequence.fromSteps — auto-promotion ───────────────────

  group('CapSequence.fromSteps — auto-promotion', () {
    test('promotes first upcoming step to current when no current exists', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.upcoming),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.currentStep?.id, equals('s2'));
      expect(seq.currentStep?.status, equals(CapStepStatus.current));
    });

    test('preserves existing current step without double-promotion', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.current),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      final currentSteps =
          seq.steps.where((s) => s.status == CapStepStatus.current).toList();
      expect(currentSteps.length, equals(1));
      expect(currentSteps.first.id, equals('s2'));
    });

    test('does not promote blocked step to current', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.blocked),
        _step(id: 's3', order: 3, status: CapStepStatus.blocked),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.currentStep, isNull);
    });
  });

  // ── isComplete ───────────────────────────────────────────────

  group('CapSequence — isComplete', () {
    test('isComplete is true when all steps are completed', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.completed),
        _step(id: 's3', order: 3, status: CapStepStatus.completed),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.isComplete, isTrue);
      expect(seq.progressPercent, equals(1.0));
    });

    test('isComplete is false when one step remaining', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.completed),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.isComplete, isFalse);
    });

    test('isComplete is false for empty sequence', () {
      final seq = CapSequence.fromSteps(goalId: 'test', steps: []);
      expect(seq.isComplete, isFalse);
    });
  });

  // ── currentStep / nextStep ───────────────────────────────────

  group('CapSequence — currentStep and nextStep', () {
    test('currentStep returns the current-status step', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.current),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.currentStep?.id, equals('s2'));
    });

    test('nextStep returns the first upcoming step', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.current),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
        _step(id: 's4', order: 4, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.nextStep?.id, equals('s3'));
    });

    test('nextStep is null when all steps are completed', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.completed),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.nextStep, isNull);
    });

    test('currentStep is null when all steps are blocked', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.blocked),
        _step(id: 's2', order: 2, status: CapStepStatus.blocked),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.currentStep, isNull);
    });
  });

  // ── Edge cases ───────────────────────────────────────────────

  group('CapSequence — edge cases', () {
    test('single step sequence — promoted to current', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.totalCount, equals(1));
      expect(seq.completedCount, equals(0));
      expect(seq.currentStep?.id, equals('s1'));
    });

    test('all blocked — no promotion, no current', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.blocked),
        _step(id: 's2', order: 2, status: CapStepStatus.blocked),
        _step(id: 's3', order: 3, status: CapStepStatus.blocked),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.currentStep, isNull);
      expect(seq.progressPercent, equals(0.0));
    });

    test('goalId is preserved on sequence', () {
      final seq = CapSequence.fromSteps(
        goalId: 'retirement_choice',
        steps: [],
      );
      expect(seq.goalId, equals('retirement_choice'));
    });

    test('progressPercent is 0.0 for all-upcoming sequence', () {
      final steps = [
        _step(id: 's1', order: 1, status: CapStepStatus.upcoming),
        _step(id: 's2', order: 2, status: CapStepStatus.upcoming),
      ];
      final seq = CapSequence.fromSteps(goalId: 'test', steps: steps);

      expect(seq.progressPercent, equals(0.0));
    });
  });
}
