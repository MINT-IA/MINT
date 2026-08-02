import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(320, 700)]) {
    testWidgets('no overflow at ${size.width.toInt()}px and text scale 2', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MintNextDesignLabApp(
          locale: Locale('de'),
          textScaler: TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
      expect(
        find.byKey(const ValueKey('action:today_3a_intent.start')),
        findsOneWidget,
      );

      if (size.width == 320) {
        final action = find.byKey(
          const ValueKey('action:today_3a_intent.start'),
        );
        expect(tester.getTopLeft(action).dy, greaterThan(size.height));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(action).dy,
          lessThanOrEqualTo(size.height),
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('node:orientation')), findsOneWidget);
        final continueAction = find.byKey(
          const ValueKey('action:orientation.continue'),
        );
        await tester.ensureVisible(continueAction);
        await tester.pumpAndSettle();
        await tester.tap(continueAction);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('node:fact_tax_year')),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(
            const ValueKey('action:fact_tax_year.confirm_current_year'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('all interactive targets are at least 44 logical pixels', (
    tester,
  ) async {
    await tester.pumpWidget(const MintNextDesignLabApp(locale: Locale('fr')));
    final targets = find.byType(MintDesignLabAction);
    expect(targets, findsWidgets);
    for (final element in targets.evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('page changes move focus to a semantic heading', (tester) async {
    await tester.pumpWidget(const MintNextDesignLabApp(locale: Locale('fr')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Focus>(find.byKey(const ValueKey('heading:today_3a_intent')))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.start')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Focus>(find.byKey(const ValueKey('heading:orientation')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('reduced motion removes page and selection animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MintNextDesignLabApp(locale: Locale('fr')),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.start')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('action:orientation.continue')));
    await tester.pump();
    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      Duration.zero,
    );
  });

  testWidgets('tax year selection exposes a semantic tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MintNextDesignLabApp(locale: Locale('de')));
    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.start')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action:orientation.continue')));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(
      find.byKey(const ValueKey('action:fact_tax_year.confirm_current_year')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets(
    'safe exit overflow has a visible scrollbar and reachable leave action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MintNextDesignLabApp(
          locale: Locale('de'),
          textScaler: TextScaler.linear(2),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('action:today_3a_intent.open_safe_exit')),
      );
      await tester.pumpAndSettle();
      final scrollbar = tester.widget<Scrollbar>(
        find.descendant(
          of: find.byKey(const ValueKey('overlay:safe_exit')),
          matching: find.byType(Scrollbar),
        ),
      );
      expect(scrollbar.thumbVisibility, isTrue);
      final leave = find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      );
      await tester.ensureVisible(leave);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(leave).dy, lessThanOrEqualTo(700));
    },
  );
}
