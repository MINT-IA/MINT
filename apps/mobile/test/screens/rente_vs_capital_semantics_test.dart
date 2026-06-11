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
//  This test pins the canonical screen-root contract that the healthy
//  screens satisfy and the RvC screen (pre-fix) violates : a single
//  `rente_vs_capital_screen` semantics boundary that is a container with
//  explicit child nodes AND is an ancestor of the screen body (title,
//  estimate-mode control, LPP-total field) — the exact labels the
//  regression flow bug__ILLOG02__rvc_ax_tree_empty.yaml asserts on.
//
//  Labels reuse the AppLocalizations strings already rendered visually —
//  no new ARB key is introduced (wave 7 parallelism constraint).
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

/// Collect labels/values within the subtree rooted at [node].
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

      final root = tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
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
        'screen-root identifier is a container ancestor of the body '
        '(canonical iOS-safe boundary)', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildWrapped(const RenteVsCapitalScreen()));
      await tester.pump();

      final root =
          tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;

      final screenNode = _findByIdentifier(root, 'rente_vs_capital_screen');
      handle.dispose();

      // The screen identifier must exist.
      expect(
        screenNode,
        isNotNull,
        reason: 'rente_vs_capital_screen identifier missing from AX tree.',
      );

      // CANONICAL CONTRACT (matches mon_argent_screen / budget_screen) :
      // the identified screen-root boundary must be an *ancestor container*
      // wrapping the body — NOT a leaf on the AppBar title. The body labels
      // (estimate mode + LPP field) must live UNDER the identified node so
      // the iOS bridge cannot collapse the route to that single node.
      final underScreen = _labelsUnder(screenNode!);
      expect(
        underScreen.any((l) => l.contains('Estimer pour moi')) &&
            underScreen.any((l) => l.contains('Ton avoir LPP actuel')),
        isTrue,
        reason: 'The rente_vs_capital_screen Semantics node must be an '
            'ancestor of the screen body (estimate-mode control + LPP field). '
            'Pre-fix it sits on the AppBar title leaf, so the iOS bridge '
            'collapses the route to one element (the idb "1 element" '
            'symptom). Labels under screen node: ${underScreen.join(" | ")}',
      );
    });
  });
}
