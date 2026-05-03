// ────────────────────────────────────────────────────────────────────
//  MintLifeLineSlider — widget tests
// ────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/widgets/chat_vivant/mint_life_line_slider.dart';

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

void main() {
  group('MintLifeLineSlider', () {
    testWidgets('renders header (min/max/title) + slider', (tester) async {
      await tester.pumpWidget(
        _harness(
          MintLifeLineSlider(
            age: 89,
            ageEpuisement: 80,
            onAgeChanged: (_) {},
            haptic: false,
          ),
        ),
      );
      expect(find.text('70 ans'), findsOneWidget);
      expect(find.text('100 ans'), findsOneWidget);
      expect(find.text('Espérance de vie'), findsOneWidget);
      expect(find.text('capital épuisé'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('slider onChanged emits int age', (tester) async {
      var lastAge = 89;
      await tester.pumpWidget(
        _harness(
          MintLifeLineSlider(
            age: lastAge,
            ageEpuisement: 80,
            haptic: false,
            onAgeChanged: (v) => lastAge = v,
          ),
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      // Material Slider with divisions=30 snaps to integer values;
      // onChanged emits an int via .round(). Drag to 75.0.
      slider.onChanged?.call(75.0);
      expect(lastAge, 75);

      // Drag to 76.4 — rounds to 76.
      slider.onChanged?.call(76.4);
      expect(lastAge, 76);
    });

    testWidgets('semantics exposes increase/decrease + slider role',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          MintLifeLineSlider(
            age: 80,
            ageEpuisement: 75,
            onAgeChanged: (_) {},
            haptic: false,
          ),
        ),
      );
      // The outermost Semantics wrapper carries slider: true.
      final semantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(MintLifeLineSlider),
          matching: find.byType(Semantics),
        ),
      );
      final hasSliderRole = semantics.any((s) => s.properties.slider == true);
      expect(hasSliderRole, isTrue);
    });

    testWidgets('age 70 → semantics decrease disabled', (tester) async {
      await tester.pumpWidget(
        _harness(
          MintLifeLineSlider(
            age: 70,
            ageEpuisement: 80,
            onAgeChanged: (_) {},
            haptic: false,
          ),
        ),
      );
      final semantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(MintLifeLineSlider),
          matching: find.byType(Semantics),
        ),
      );
      final wrapper = semantics.firstWhere((s) => s.properties.slider == true);
      // decreasedValue should be null at min
      expect(wrapper.properties.decreasedValue, isNull);
    });

    testWidgets('age 100 → semantics increase disabled', (tester) async {
      await tester.pumpWidget(
        _harness(
          MintLifeLineSlider(
            age: 100,
            ageEpuisement: 80,
            onAgeChanged: (_) {},
            haptic: false,
          ),
        ),
      );
      final semantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(MintLifeLineSlider),
          matching: find.byType(Semantics),
        ),
      );
      final wrapper = semantics.firstWhere((s) => s.properties.slider == true);
      expect(wrapper.properties.increasedValue, isNull);
    });
  });
}
