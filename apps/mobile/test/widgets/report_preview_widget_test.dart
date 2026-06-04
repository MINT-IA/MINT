import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/clarity_state.dart';
import 'package:mint_mobile/widgets/report_preview_widget.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('uses Bilan wording instead of legacy Plan Mint title',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ReportPreviewWidget(
        state: const ClarityState(
          precisionIndex: 42,
          actions: [],
          unlockedBadges: [],
          safeMode: false,
        ),
        onComplete: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ton Bilan Flash'), findsOneWidget);
    expect(find.textContaining('Plan Mint'), findsNothing);
  });
}
