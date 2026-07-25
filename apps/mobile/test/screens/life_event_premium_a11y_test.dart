// ────────────────────────────────────────────────────────────
//  LIFE-EVENT PREMIUM SCREENS — Accessibility (Semantics) contract
//
//  Same class of bug as ILLOG-02 (RenteVsCapitalScreen): these premium
//  life-event screens rendered pixels but their route subtree collapsed on
//  the iOS accessibility bridge, so Maestro (and VoiceOver) could read almost
//  nothing. Surfaced 2026-07-25 building parcours_secondaires.yaml: three
//  distinct text anchors all failed against visibly-rendered /invalidite and
//  /life-event/deces-proche.
//
//  Root cause (identical to ILLOG-02): no screen-root
//  `Semantics(container: true, explicitChildNodes: true)` boundary above the
//  Scaffold, so the iOS bridge collapses the subtree into a single node.
//  Fix: wrap each screen's Scaffold in that boundary with a stable
//  `identifier` (mirrors rente_vs_capital_screen.dart:684-687 post-fix).
//
//  This test pins the contract: each screen must expose a semantics node
//  carrying its `<screen>_screen` identifier, and the screen's body labels
//  must live UNDER that boundary. RED without the wrapper (no such node),
//  GREEN with it.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/deces_proche_screen.dart';
import 'package:mint_mobile/screens/demenagement_cantonal_screen.dart';

SemanticsNode _rootSemantics(WidgetTester tester) {
  return tester.binding.renderViews
      .map((view) => view.owner?.semanticsOwner?.rootSemanticsNode)
      .whereType<SemanticsNode>()
      .first;
}

SemanticsNode? _findByIdentifier(SemanticsNode root, String identifier) {
  SemanticsNode? found;
  void visit(SemanticsNode node) {
    if (found != null) return;
    if (node.getSemanticsData().identifier == identifier) {
      found = node;
      return;
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return found;
}

List<String> _labelsUnder(SemanticsNode node) {
  final labels = <String>[];
  void visit(SemanticsNode n) {
    final data = n.getSemanticsData();
    if (data.label.isNotEmpty) labels.add(data.label);
    if (data.value.isNotEmpty) labels.add(data.value);
    n.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(node);
  return labels;
}

Widget _wrap(Widget screen) {
  return ChangeNotifierProvider<CoachProfileProvider>(
    create: (_) => CoachProfileProvider(),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: screen,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> expectScreenRootContract(
    WidgetTester tester,
    Widget screen,
    String identifier,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(screen));
    await tester.pump();

    final root = _rootSemantics(tester);
    final node = _findByIdentifier(root, identifier);
    final labels = node == null ? const <String>[] : _labelsUnder(node);
    handle.dispose();

    expect(node, isNotNull,
        reason: 'screen-root Semantics boundary "$identifier" missing '
            '(ILLOG-02 collapse) — VoiceOver/Maestro cannot read the screen');
    expect(node!.getSemanticsData().identifier, identifier);
    expect(labels, isNotEmpty,
        reason: 'no body labels under the "$identifier" boundary');
  }

  testWidgets('DisabilityGapScreen exposes a screen-root semantics boundary',
      (tester) async {
    await expectScreenRootContract(
        tester, const DisabilityGapScreen(), 'disability_gap_screen');
  });

  testWidgets('DecesProcheScreen exposes a screen-root semantics boundary',
      (tester) async {
    await expectScreenRootContract(
        tester, const DecesProcheScreen(), 'deces_proche_screen');
  });

  testWidgets('DemenagementCantonalScreen exposes a screen-root semantics boundary',
      (tester) async {
    await expectScreenRootContract(tester, const DemenagementCantonalScreen(),
        'demenagement_cantonal_screen');
  });
}
