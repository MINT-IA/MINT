import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/widgets/coach/llm_config_sheet.dart';

// ────────────────────────────────────────────────────────────
//  LLM CONFIG SHEET TESTS — Sprint C8
// ────────────────────────────────────────────────────────────

void main() {
  late LlmConfig config;
  late LlmConfig? savedConfig;

  setUp(() {
    config = LlmConfig.defaultOpenAI;
    savedConfig = null;
  });

  Widget buildTestWidget({LlmConfig? initialConfig}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => LlmConfigSheet(
                  config: initialConfig ?? config,
                  onSave: (newConfig) {
                    savedConfig = newConfig;
                    Navigator.of(context).pop();
                  },
                ),
              );
            },
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester, {LlmConfig? initialConfig}) async {
    await tester.pumpWidget(buildTestWidget(initialConfig: initialConfig));
    await tester.pump();
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
  }

  group('LlmConfigSheet', () {
    testWidgets('renders without crashing', (tester) async {
      await openSheet(tester);
      expect(find.byType(LlmConfigSheet), findsOneWidget);
    });

    testWidgets('shows Configuration API title', (tester) async {
      await openSheet(tester);
      expect(find.text('Configuration API'), findsOneWidget);
    });

    testWidgets('shows BYOK subtitle', (tester) async {
      await openSheet(tester);
      expect(find.text('Bring Your Own Key (BYOK)'), findsOneWidget);
    });

    testWidgets('shows provider selector with OpenAI and Anthropic',
        (tester) async {
      await openSheet(tester);
      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
    });

    testWidgets('shows API key field', (tester) async {
      await openSheet(tester);
      expect(find.text('Cle API'), findsOneWidget);
      // TextField for the API key (obscured)
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);
    });

    testWidgets('shows model selector label', (tester) async {
      await openSheet(tester);
      expect(find.text('Modele'), findsOneWidget);
    });

    testWidgets('shows test connection button', (tester) async {
      await openSheet(tester);
      expect(find.text('Tester la connexion'), findsOneWidget);
    });

    testWidgets('shows save button', (tester) async {
      await openSheet(tester);
      expect(find.text('Sauvegarder'), findsOneWidget);
    });

    testWidgets('shows privacy notice', (tester) async {
      await openSheet(tester);
      expect(
        find.textContaining('chiffr'),
        findsOneWidget,
      );
    });

    testWidgets('shows lock icon for privacy', (tester) async {
      await openSheet(tester);
      expect(find.byconst Icon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows key icon in API field', (tester) async {
      await openSheet(tester);
      expect(find.byconst Icon(Icons.key), findsOneWidget);
    });

    testWidgets('test connection shows result message', (tester) async {
      await openSheet(tester);

      // Tap test connection without API key
      await tester.tap(find.text('Tester la connexion'));
      await tester.pumpAndSettle();

      // Should show message about missing key
      expect(find.textContaining('cle API'), findsWidgets);
    });

    testWidgets('save button calls onSave callback', (tester) async {
      await openSheet(tester);

      // Tap save
      await tester.tap(find.text('Sauvegarder'));
      await tester.pumpAndSettle();

      // Callback should have been called
      expect(savedConfig, isNotNull);
      expect(savedConfig!.provider, LlmProvider.openai);
    });

    testWidgets('can switch provider to Anthropic', (tester) async {
      await openSheet(tester);

      // Tap Anthropic
      await tester.tap(find.text('Anthropic'));
      await tester.pump();

      // Save and check
      await tester.tap(find.text('Sauvegarder'));
      await tester.pumpAndSettle();

      expect(savedConfig, isNotNull);
      expect(savedConfig!.provider, LlmProvider.anthropic);
    });

    testWidgets('shows wifi tethering icon for test button', (tester) async {
      await openSheet(tester);
      expect(find.byconst Icon(Icons.wifi_tethering), findsOneWidget);
    });
  });
}
