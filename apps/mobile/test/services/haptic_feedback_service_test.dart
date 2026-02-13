import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/haptic_feedback_service.dart';

/// Unit tests for HapticFeedbackService
///
/// HapticFeedbackService is a thin wrapper around Flutter's HapticFeedback
/// platform channel. Since the actual vibration is platform-dependent,
/// these tests verify:
///   - Each method exists and is callable
///   - Platform channel messages are sent correctly
///   - Method names match expected HapticFeedback methods
///   - Service provides the 4 feedback levels (light, medium, heavy, selection)
///   - No exceptions are thrown even when platform does not respond
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Track all platform channel calls to verify correct messages
  final List<MethodCall> hapticCalls = [];

  setUp(() {
    hapticCalls.clear();

    // Mock the SystemChannels.platform handler to intercept HapticFeedback calls.
    // HapticFeedback uses SystemChannels.platform with method "HapticFeedback.vibrate"
    // and a String argument indicating the type.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) {
      hapticCalls.add(call);
      return Future<dynamic>.value();
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 1. SERVICE STRUCTURE
  // ═══════════════════════════════════════════════════════════════════════

  group('Service structure', () {
    test('HapticFeedbackService class exists and is accessible', () {
      // Verify the class can be referenced (compile-time check)
      expect(HapticFeedbackService, isNotNull);
    });

    test('light() is a static method returning Future<void>', () async {
      // Should not throw
      await HapticFeedbackService.light();
    });

    test('medium() is a static method returning Future<void>', () async {
      await HapticFeedbackService.medium();
    });

    test('heavy() is a static method returning Future<void>', () async {
      await HapticFeedbackService.heavy();
    });

    test('selection() is a static method returning Future<void>', () async {
      await HapticFeedbackService.selection();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. PLATFORM CHANNEL VERIFICATION
  // ═══════════════════════════════════════════════════════════════════════

  group('Platform channel calls', () {
    test('light() sends HapticFeedback.vibrate with HapticFeedbackType.lightImpact', () async {
      await HapticFeedbackService.light();

      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.first.method, equals('HapticFeedback.vibrate'));
      expect(hapticCalls.first.arguments, equals('HapticFeedbackType.lightImpact'));
    });

    test('medium() sends HapticFeedback.vibrate with HapticFeedbackType.mediumImpact', () async {
      await HapticFeedbackService.medium();

      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.first.method, equals('HapticFeedback.vibrate'));
      expect(hapticCalls.first.arguments, equals('HapticFeedbackType.mediumImpact'));
    });

    test('heavy() sends HapticFeedback.vibrate with HapticFeedbackType.heavyImpact', () async {
      await HapticFeedbackService.heavy();

      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.first.method, equals('HapticFeedback.vibrate'));
      expect(hapticCalls.first.arguments, equals('HapticFeedbackType.heavyImpact'));
    });

    test('selection() sends HapticFeedback.vibrate with HapticFeedbackType.selectionClick', () async {
      await HapticFeedbackService.selection();

      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.first.method, equals('HapticFeedback.vibrate'));
      expect(hapticCalls.first.arguments, equals('HapticFeedbackType.selectionClick'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. MULTIPLE CALLS
  // ═══════════════════════════════════════════════════════════════════════

  group('Multiple calls', () {
    test('calling all 4 methods sequentially sends 4 platform messages', () async {
      await HapticFeedbackService.light();
      await HapticFeedbackService.medium();
      await HapticFeedbackService.heavy();
      await HapticFeedbackService.selection();

      expect(hapticCalls, hasLength(4));
    });

    test('calling same method multiple times sends correct count', () async {
      await HapticFeedbackService.light();
      await HapticFeedbackService.light();
      await HapticFeedbackService.light();

      expect(hapticCalls, hasLength(3));
      for (final call in hapticCalls) {
        expect(call.arguments, equals('HapticFeedbackType.lightImpact'));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. FEEDBACK TYPE MAPPING
  // ═══════════════════════════════════════════════════════════════════════

  group('Feedback type mapping', () {
    test('service provides exactly 4 feedback levels', () async {
      // Verify all 4 levels produce distinct platform calls
      final feedbackTypes = <String>{};

      await HapticFeedbackService.light();
      feedbackTypes.add(hapticCalls.last.arguments as String);

      await HapticFeedbackService.medium();
      feedbackTypes.add(hapticCalls.last.arguments as String);

      await HapticFeedbackService.heavy();
      feedbackTypes.add(hapticCalls.last.arguments as String);

      await HapticFeedbackService.selection();
      feedbackTypes.add(hapticCalls.last.arguments as String);

      // All 4 should be distinct
      expect(feedbackTypes, hasLength(4));
    });

    test('light is for selections and switches (lowest intensity)', () async {
      await HapticFeedbackService.light();
      expect(hapticCalls.first.arguments, contains('light'));
    });

    test('medium is for primary buttons (medium intensity)', () async {
      await HapticFeedbackService.medium();
      expect(hapticCalls.first.arguments, contains('medium'));
    });

    test('heavy is for success/error states (highest intensity)', () async {
      await HapticFeedbackService.heavy();
      expect(hapticCalls.first.arguments, contains('heavy'));
    });

    test('selection is for validated selections', () async {
      await HapticFeedbackService.selection();
      expect(hapticCalls.first.arguments, contains('selection'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. RESILIENCE
  // ═══════════════════════════════════════════════════════════════════════

  group('Resilience', () {
    test('methods complete without errors when platform handler is null', () async {
      // Remove the mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);

      // These should not throw even without a handler
      // (Flutter's HapticFeedback is fire-and-forget on unsupported platforms)
      await expectLater(HapticFeedbackService.light(), completes);
      await expectLater(HapticFeedbackService.medium(), completes);
      await expectLater(HapticFeedbackService.heavy(), completes);
      await expectLater(HapticFeedbackService.selection(), completes);
    });
  });
}
