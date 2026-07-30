// ────────────────────────────────────────────────────────────
//  RENTE VS CAPITAL — Accessibility (Semantics) tree test
//
//  ILLOG-02 (W5, P1 a11y) : RenteVsCapitalScreen renders pixels but its
//  accessibility tree was (almost) EMPTY. Triangulated 2026-06-11 on
//  iPhone 16e staging build : `idb ui describe-all` returned 1 element on
//  a fully rendered screen, Maestro assertVisible("Rente ou capital.*")
//  FAILED on the visible title, reproduced cold+warm.
//
//  Root cause (Task 1 diagnostic, file:line) :
//  rente_vs_capital_screen.dart:610-617 places the `rente_vs_capital_screen`
//  `Semantics(key:, identifier:, child: Text())` node directly on the
//  SliverAppBar *title* — a leaf inside the route `header`. It carries
//  NO `container: true` and NO `explicitChildNodes: true`. The two healthy
//  sibling screens that DO surface to `idb` wrap their whole Scaffold in
//  `Semantics(identifier:, container: true, explicitChildNodes: true,
//  child: Scaffold(...))` (mon_argent_screen.dart:141-145,
//  budget_screen.dart:219-223). Without `explicitChildNodes` on a screen-root
//  boundary, the iOS accessibility bridge collapses the route subtree into
//  the single identified header node — which is exactly the
//  `idb ui describe-all` "1 element" symptom triangulated on device, even
//  though the Dart-level semantics tree is fully populated.
//
//  ── SUPERSEDED by the AX iOS 26.2 pilot (ADR 2026-07-30) ──────────────
//  Instrumented re-diagnosis (8 sim builds, iPhone 16e / iOS 26.2 /
//  Flutter 3.41.6, cf. project_ios26_ax_tree_collapse) proved the OPPOSITE
//  of the ILLOG-02 conclusion: on iOS 26.2 the screen-root
//  `Semantics(container:true, explicitChildNodes:true)` boundary does NOT
//  prevent the collapse — it CAUSES it, by doubling the `scopesRoute`
//  boundary that ModalRoute already places on a pushed route. The pilot
//  removes that root wrapper (back to the framework default) and re-gates
//  flows/tests on INTERNAL ids (`rvc_route_state`, title, fields).
//
//  So Test 1 below keeps its value (the Dart semantics tree must stay
//  populated — that never depended on the wrapper). Test 2 is FLIPPED: it
//  now locks the pilot contract (no root container boundary; the internal
//  arrival anchor survives) instead of the old ILLOG-02 container contract.
//  Labels reuse AppLocalizations strings already rendered visually — no new
//  ARB key is introduced.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';

/// Non-deprecated accessor for the compiled root semantics node (mirrors
/// test/semantics_test_helpers.dart — avoids the deprecated
/// `binding.pipelineOwner`).
SemanticsNode _rootSemantics(WidgetTester tester) {
  return tester.binding.renderViews
      .map((view) => view.owner?.semanticsOwner?.rootSemanticsNode)
      .whereType<SemanticsNode>()
      .first;
}

Widget _buildWrapped(Widget screen) {
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

/// Collect every non-empty label / value / hint string in the compiled
/// semantics tree — this is what VoiceOver and `idb ui describe-all` read,
/// NOT what `find.text()` finds (the widget tree).
List<String> _collectSemanticLabels(SemanticsNode root) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.label.isNotEmpty) labels.add(data.label);
    if (data.value.isNotEmpty) labels.add(data.value);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return labels;
}

/// Find the first node carrying [identifier] anywhere in the subtree.
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RenteVsCapitalScreen — accessibility tree (ILLOG-02)', () {
    testWidgets(
        'exposes a populated semantics tree (title + estimate mode + LPP field)',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildWrapped(const RenteVsCapitalScreen()));
      await tester.pump();

      final root = _rootSemantics(tester);
      final labels = _collectSemanticLabels(root);
      final joined = labels.join(' | ');

      // Dispose BEFORE the assertions so a real assertion failure surfaces as
      // the test verdict (rather than being masked by the leaked-handle check
      // that runs ahead of tearDowns).
      handle.dispose();

      // 1. The AppBar title must surface to the accessibility tree.
      //    Regression flow asserts extendedWaitUntil text "Rente ou capital.*".
      expect(
        labels.any((l) => l.contains('Rente ou capital')),
        isTrue,
        reason: 'AX tree must expose the app bar title. Tree labels: $joined',
      );

      // 2. The estimate-mode control must be reachable.
      //    Regression flow asserts assertVisible "Estimer pour moi".
      expect(
        labels.any((l) => l.contains('Estimer pour moi')),
        isTrue,
        reason: 'AX tree must expose the estimate-mode control. '
            'Tree labels: $joined',
      );

      // 3. The LPP-total input label must be reachable.
      //    Regression flow asserts assertVisible "Ton avoir LPP actuel (CHF)".
      expect(
        labels.any((l) => l.contains('Ton avoir LPP actuel')),
        isTrue,
        reason: 'AX tree must expose the LPP-total field label. '
            'Tree labels: $joined',
      );

      // 4. Sanity guard against the "1 element" idb symptom : a real screen
      //    must expose far more than a single labelless node.
      expect(
        labels.length,
        greaterThan(5),
        reason: 'AX tree is near-empty (the ILLOG-02 symptom). '
            'Found ${labels.length} labelled/valued nodes: $joined',
      );
    });

    testWidgets(
        'no screen-root container boundary; body stays reachable '
        '(iOS 26.2 collapse fix, ADR 2026-07-30)', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildWrapped(const RenteVsCapitalScreen()));
      await tester.pump();

      final root = _rootSemantics(tester);
      final removedRoot = _findByIdentifier(root, 'rente_vs_capital_screen');
      final labels = _collectSemanticLabels(root);
      handle.dispose();

      // 1. The collapsing screen-root container is GONE. ILLOG-02 had wrapped
      //    the Scaffold in Semantics(container:true, explicitChildNodes:true)
      //    carrying this identifier; on iOS 26.2 that boundary doubles
      //    ModalRoute.scopesRoute and collapses the pushed route to one AX
      //    node. The pilot removes it — the identifier must no longer exist.
      expect(
        removedRoot,
        isNull,
        reason: 'The screen-root rente_vs_capital_screen container boundary '
            'must be removed (iOS 26.2 AX collapse fix, ADR 2026-07-30) — '
            'rely on ModalRoute.scopesRoute instead of a redundant root '
            'container.',
      );

      // 2. Removing the wrapper must NOT empty the tree: the body labels stay
      //    reachable directly at the semantics root (framework-side guard).
      //    The re-gated runtime anchor rvc_route_state (proof-anchor, needs a
      //    GoRouter) is locked separately in rvc_real_route_public_test.
      expect(
        labels.any((l) => l.contains('Estimer pour moi')) &&
            labels.any((l) => l.contains('Ton avoir LPP actuel')),
        isTrue,
        reason: 'Body labels (estimate-mode control + LPP field) must remain '
            'reachable in the semantics tree after the root wrapper removal. '
            'Labels: ${labels.join(" | ")}',
      );
    });
  });
}
