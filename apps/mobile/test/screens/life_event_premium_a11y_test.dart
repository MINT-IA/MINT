// ────────────────────────────────────────────────────────────
//  LIFE-EVENT PREMIUM SCREENS — Accessibility (Semantics) contract
//
//  Surfaced 2026-07-25 building parcours_secondaires.yaml: on the visibly-
//  rendered /invalidite and /life-event/deces-proche, Maestro matched none of
//  their text anchors — the same OBSERVED symptom as ILLOG-02
//  (RenteVsCapitalScreen: Maestro/idb read ~1 element on a rendered screen).
//  VoiceOver was NOT measured; a Maestro text-match failure does not by itself
//  establish VoiceOver behaviour.
//
//  These screens lacked the screen-root
//  `Semantics(container: true, explicitChildNodes: true, identifier: ...)`
//  boundary that the healthy screens have (mirrors rente_vs_capital_screen.dart
//  :684-687). This test pins that NECESSARY boundary: each screen must expose a
//  semantics node carrying its `<screen>_screen` identifier with descendant
//  labels. RED without the wrapper (no such node), GREEN with it.
//
//  NOTE (0-TRUST): this contract is a necessary precondition, NOT proof the
//  screen is fully readable by Maestro/VoiceOver — asserting descendant labels
//  exist would be satisfied by a single AppBar label. Post-wrapper, invalidite
//  STILL fails Maestro on the sim, so a deeper collapse remains (see
//  .planning/audit/2026-07-life-event-screens-a11y-gap.md).
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
            '(necessary precondition for the ILLOG-02 a11y contract)');
    expect(node!.getSemanticsData().identifier, identifier);
    expect(labels, isNotEmpty,
        reason: 'no descendant labels under the "$identifier" boundary');
  }

  // AX iOS 26.2 (investigation AX invalidite, ADR 2026-07-31) : le contrat
  // ILLOG-02 est INVERSÉ pour cet écran. Le wrapper racine collapsant
  // `Semantics(container:true, explicitChildNodes:true,
  // identifier:'disability_gap_screen')` est RETIRÉ — sur une route poussée
  // iOS 26.2 il fait partie du motif firstJob qui effondre l'arbre AX (1er
  // déclencheur, cf. project_ios26_ax_tree_collapse). Nouveau contrat : (a) le
  // wrapper racine ne doit PLUS exister ; (b) l'ancre AppBar non-effondrante
  // `disability-anchor` porte le titre localisé. Le déclencheur de CONTENU du
  // fling-collapse (slider interne du countdown) est identifié par bisection
  // runtime (Probe D/E) et corrigé côté écran (`interactive:false`) ; ce widget
  // test ne peut PAS reproduire l'effondrement (bug du pont a11y iOS natif) —
  // il pinne uniquement la structure du motif non-effondrant.
  testWidgets(
      'DisabilityGapScreen drops the collapsing root wrapper and exposes a '
      'labeled disability-anchor (ADR AX iOS 26.2)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const DisabilityGapScreen()));
    await tester.pump();

    final root = _rootSemantics(tester);
    expect(_findByIdentifier(root, 'disability_gap_screen'), isNull,
        reason: 'the collapsing screen-root Semantics(container:true) wrapper '
            'must NOT be reintroduced (iOS 26.2 AX collapse, ADR 2026-07-31)');
    final anchor = _findByIdentifier(root, 'disability-anchor');
    expect(anchor, isNotNull, reason: 'disability-anchor (AppBar title) missing');
    expect(_labelsUnder(anchor!), isNotEmpty,
        reason: 'no descendant labels under disability-anchor');
    handle.dispose();
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
