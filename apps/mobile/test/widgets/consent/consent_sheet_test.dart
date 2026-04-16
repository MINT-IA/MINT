import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/widgets/consent/consent_sheet.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(body: Builder(builder: (_) => child)),
      );

  testWidgets('renders a row per purpose', (tester) async {
    await tester.pumpWidget(wrap(const ConsentSheet(purposes: [
      ConsentPurpose.visionExtraction,
      ConsentPurpose.persistence365d,
    ])));
    await tester.pumpAndSettle();
    // both purpose titles visible
    expect(find.text('Lecture IA de tes documents'), findsOneWidget);
    expect(find.text('Mémoire chiffrée 365 jours'), findsOneWidget);
    // Accept + Refuse actions present
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
  });

  testWidgets('show() returns true on accept', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return ElevatedButton(
        onPressed: () async {
          result = await ConsentSheet.show(ctx, purposes: const [
            ConsentPurpose.coupleProjection,
          ]);
        },
        child: const Text('open'),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(result, true);
  });

  testWidgets('show() returns false on refuse', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return ElevatedButton(
        onPressed: () async {
          result = await ConsentSheet.show(ctx, purposes: const [
            ConsentPurpose.coupleProjection,
          ]);
        },
        child: const Text('open'),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();
    expect(result, false);
  });

  testWidgets('renders all 4 purposes when all requested', (tester) async {
    // Use a large surface so the DraggableScrollableSheet renders all 4
    // purpose rows without needing to scroll in the test harness.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const ConsentSheet(purposes: [
      ConsentPurpose.visionExtraction,
      ConsentPurpose.persistence365d,
      ConsentPurpose.transferUsAnthropic,
      ConsentPurpose.coupleProjection,
    ])));
    await tester.pumpAndSettle();
    expect(find.text('Lecture IA de tes documents'), findsOneWidget);
    expect(find.text('Mémoire chiffrée 365 jours'), findsOneWidget);
    // The last two may be below the fold in test harness — scroll the list.
    await tester.dragUntilVisible(
      find.text('Projections de couple'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    expect(find.text('Traitement IA (Anthropic, US)'), findsOneWidget);
    expect(find.text('Projections de couple'), findsOneWidget);
  });
}
