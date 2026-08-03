import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

import 'batch18_canton_fixture.g.dart';

const _entryActions = <String>[
  'action:today_3a_intent.start',
  'action:orientation.continue',
  'action:fact_tax_year.confirm_current_year',
  'action:fact_tax_year.continue',
  'action:fact_lpp_affiliation.choose_yes',
];

Finder _key(String value) => find.byKey(ValueKey<String>(value));
Finder _choice(String code) => _key('choice:fact_canton.$code');

Finder _editableUnder(Finder control) => find.descendant(
  of: control,
  matching: find.byType(EditableText),
  matchRoot: true,
);

EditableText _editableWidget(WidgetTester tester, Finder control) =>
    tester.widget<EditableText>(_editableUnder(control));

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final finder = _key(key);
  expect(finder, findsOneWidget, reason: 'precondition: $key must exist');
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openContribution(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp(
      locale: locale,
      currentYear: 2026,
      textScaler: textScaler,
    ),
  );
  for (final action in _entryActions) {
    await _tapVisible(tester, action);
  }
  expect(_key('node:fact_contribution'), findsOneWidget);
}

Future<void> _openCantonFromNo(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  TextScaler? textScaler,
}) async {
  await _openContribution(tester, locale: locale, textScaler: textScaler);
  await _tapVisible(tester, 'action:fact_contribution.choose_no');
  expect(_key('node:fact_canton'), findsOneWidget);
}

Future<void> _openCantonFromPositive(WidgetTester tester) async {
  await _openContribution(tester);
  await _tapVisible(tester, 'action:fact_contribution.choose_yes');
  await tester.enterText(
    _key('field:fact_contributed_amount.provider_name'),
    'Prestataire test',
  );
  await tester.enterText(_key('field:fact_contributed_amount.amount'), '1000');
  await _tapVisible(
    tester,
    'action:fact_contributed_amount.toggle_all_reviewed',
  );
  await _tapVisible(tester, 'action:fact_contributed_amount.continue');
  expect(_key('node:fact_canton'), findsOneWidget);
}

List<String> _renderedChoiceCodes(WidgetTester tester) => tester
    .widgetList<Widget>(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            ((widget.key! as ValueKey<String>).value).startsWith(
              'choice:fact_canton.',
            ),
      ),
    )
    .map(
      (widget) => (widget.key! as ValueKey<String>).value.substring(
        'choice:fact_canton.'.length,
      ),
    )
    .toList(growable: false);

Tristate _selected(WidgetTester tester, String code) => tester
    .getSemantics(_choice(code))
    .getSemanticsData()
    .flagsCollection
    .isSelected;

Tristate _actionSelected(WidgetTester tester, String action) => tester
    .getSemantics(_key(action))
    .getSemanticsData()
    .flagsCollection
    .isSelected;

VoidCallback? _semanticTapCallback(WidgetTester tester, Finder target) {
  final candidates = <Semantics>[
    ...tester.widgetList<Semantics>(
      find.descendant(of: target, matching: find.byType(Semantics)),
    ),
    ...tester.widgetList<Semantics>(
      find.ancestor(of: target, matching: find.byType(Semantics)),
    ),
    if (target.evaluate().single.widget case final Semantics semantics)
      semantics,
  ];
  return candidates
      .map((semantics) => semantics.properties.onTap)
      .whereType<VoidCallback>()
      .firstOrNull;
}

List<String> _primaryFocusPathKeys() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return const [];
  final keys = <String>[];
  void collect(Element element) {
    if (element.widget.key case final ValueKey<String> key) keys.add(key.value);
  }

  collect(context as Element);
  context.visitAncestorElements((element) {
    collect(element);
    return true;
  });
  return keys;
}

String _reachableSnapshot(WidgetTester tester) {
  final rows = _renderedChoiceCodes(tester);
  final selected = <String>[
    for (final code in rows)
      if (_selected(tester, code) == Tristate.isTrue) code,
  ];
  final search = _key('field:fact_canton.search');
  final query = search.evaluate().isEmpty
      ? '<missing>'
      : _editableWidget(tester, search).controller.text;
  final keys =
      tester.allWidgets
          .map((widget) => widget.key)
          .whereType<ValueKey<String>>()
          .map((key) => key.value)
          .where(
            (key) =>
                key.startsWith('node:') ||
                key.startsWith('action:fact_canton.') ||
                key.startsWith('choice:fact_canton.') ||
                key.startsWith('receipt:fact_canton.') ||
                key.startsWith('status:fact_canton.'),
          )
          .toList()
        ..sort();
  final text = tester
      .widgetList<Text>(
        find.descendant(
          of: _key('node:fact_canton'),
          matching: find.byType(Text),
        ),
      )
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .toList(growable: false);
  final scrollOffsets = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((state) => state.position.hasPixels)
      .map((state) => state.position.pixels)
      .toList(growable: false);
  final context = _key('node:fact_canton').evaluate().single;
  final navigator = Navigator.of(context);
  final groupSemantics = _key('group:fact_canton.choices').evaluate().isEmpty
      ? '<missing>'
      : tester
            .getSemantics(_key('group:fact_canton.choices'))
            .getSemanticsData()
            .toString();
  return jsonEncode({
    'query': query,
    'rows': rows,
    'selected': selected,
    'keys': keys,
    'text': text,
    'focusPath': _primaryFocusPathKeys(),
    'scroll': scrollOffsets,
    'groupSemantics': groupSemantics,
    'navigatorCanPop': navigator.canPop(),
    'navigatorDiagnostics': (navigator.context as Element).toStringDeep(),
  });
}

bool _searchOwnsPrimaryFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget.key ==
      const ValueKey<String>('field:fact_canton.search')) {
    return true;
  }
  var found = false;
  (context as Element).visitAncestorElements((element) {
    found =
        element.widget.key ==
        const ValueKey<String>('field:fact_canton.search');
    return !found;
  });
  return found;
}

void _expectR1EntrySurface(WidgetTester tester) {
  expect(
    _key('field:fact_canton.search'),
    findsOneWidget,
    reason: '[R1_03] missing local canton search on the reached runtime node',
  );
  expect(_key('group:fact_canton.choices'), findsOneWidget);
  expect(_key('status:fact_canton.privacy'), findsOneWidget);
  expect(_key('action:fact_canton.back'), findsOneWidget);
  expect(_renderedChoiceCodes(tester), hasLength(26));
}

class _CountingHttpOverrides extends HttpOverrides {
  int clientsCreated = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientsCreated += 1;
    return super.createHttpClient(context);
  }
}

void main() {
  group('R1a_catalog_origin_and_generation', () {
    testWidgets('R1_01 baseline both legacy origins reach fact_canton', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      expect(_key('node:fact_canton'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _openCantonFromPositive(tester);
      expect(_key('node:fact_canton'), findsOneWidget);
    });

    testWidgets('R1_01 exact immutable receipt and Back for both origins', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      expect(
        _key('receipt:fact_canton.origin.no'),
        findsOneWidget,
        reason: '[R1_01] no-contribution origin must be explicit and immutable',
      );
      expect(_key('receipt:fact_canton.origin.positive'), findsNothing);
      await tester.enterText(_key('field:fact_canton.search'), 'Genève');
      await tester.pump();
      await _tapVisible(tester, 'choice:fact_canton.GE');
      expect(_key('receipt:fact_canton.origin.no'), findsOneWidget);
      expect(_key('receipt:fact_canton.origin.positive'), findsNothing);
      await _tapVisible(tester, 'action:fact_canton.back');
      expect(_key('node:fact_contribution'), findsOneWidget);
      expect(
        _actionSelected(tester, 'action:fact_contribution.choose_no'),
        Tristate.isTrue,
        reason: '[R1_01] no-contribution origin receipt must survive Back',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _openCantonFromPositive(tester);
      expect(
        _key('receipt:fact_canton.origin.positive'),
        findsOneWidget,
        reason: '[R1_01] positive committed origin must be explicit',
      );
      expect(_key('receipt:fact_canton.origin.no'), findsNothing);
      await tester.enterText(_key('field:fact_canton.search'), 'Zurich');
      await tester.pump();
      await _tapVisible(tester, 'choice:fact_canton.ZH');
      expect(_key('receipt:fact_canton.origin.positive'), findsOneWidget);
      expect(_key('receipt:fact_canton.origin.no'), findsNothing);
      await _tapVisible(tester, 'action:fact_canton.back');
      expect(_key('node:fact_contributed_amount'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              _key('field:fact_contributed_amount.provider_name'),
            )
            .controller!
            .text,
        'Prestataire test',
      );
      expect(
        tester
            .widget<TextFormField>(_key('field:fact_contributed_amount.amount'))
            .controller!
            .text,
        '1000',
      );
    });

    testWidgets('R1_02 entry is unset without fallback or recommendation', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      expect(
        _renderedChoiceCodes(tester),
        hasLength(26),
        reason: '[R1_02] unset state is not observable without the choices',
      );
      expect(
        _renderedChoiceCodes(
          tester,
        ).where((code) => _selected(tester, code) == Tristate.isTrue),
        isEmpty,
      );
      expect(_key('status:fact_canton.recommendation'), findsNothing);
      expect(_key('status:fact_canton.inference'), findsNothing);
    });

    testWidgets('R1_03 exact beginner copy and R1-only surface', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      expect(
        find.text('Dans quel canton es-tu imposé pour 2026 ?'),
        findsOneWidget,
        reason: '[R1_03] reviewed beginner heading is absent',
      );
      expect(
        find.text(
          'Choisis le canton fiscal applicable à ta situation fiscale simple pour 2026, '
          'pas l’endroit où se trouve ton appareil aujourd’hui. La commune sera demandée '
          'ensuite. Aucun résultat fiscal personnel n’est encore calculé à cette étape. '
          'Si tu as déménagé ou si ta situation est plus complexe, choisis « Je ne sais '
          'pas / ma situation est complexe ».',
        ),
        findsOneWidget,
      );
      _expectR1EntrySurface(tester);
      expect(
        find.text(
          'Choix temporaire et non envoyé. Il est effacé quand tu quittes ce parcours, '
          'même si tu conserves une référence générale, ou après 30 minutes d’inactivité.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(_key('field:fact_canton.search')).label,
        contains('Rechercher un canton'),
      );
      expect(
        tester.getSemantics(_key('action:fact_canton.back')).label,
        'Retour',
      );
      expect(_key('action:fact_canton.continue'), findsNothing);
      expect(_key('action:fact_canton.unknown'), findsNothing);
      expect(_key('node:fact_commune'), findsNothing);
      expect(_key('node:canton_unknown_help'), findsNothing);
      expect(find.byKey(const ValueKey('result:personal_tax')), findsNothing);
    });

    testWidgets('R1_05 exact six-locale catalog, labels, codes and order', (
      tester,
    ) async {
      for (final locale in batch18CantonOrder.keys) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _openCantonFromNo(tester, locale: Locale(locale));
        final rendered = _renderedChoiceCodes(tester);
        expect(
          rendered,
          batch18CantonOrder[locale],
          reason: '[R1_05] $locale must render the reviewed 26-code order',
        );
        expect(rendered.toSet(), batch18AllowedCantonCodes);
        for (final code in rendered) {
          final semantics = tester.getSemantics(_choice(code));
          expect(semantics.label, batch18CantonLabels[locale]![code]);
          expect(semantics.label, isNot(contains(code)));
        }
      }
    });

    testWidgets('R1_11 every old-generation R1 callback is a total no-op', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      final search = _key('field:fact_canton.search');
      expect(
        search,
        findsOneWidget,
        reason: '[R1_11] generation-guarded R1 callbacks are absent',
      );
      await tester.enterText(_editableUnder(search), 'Genève');
      await tester.pump();
      final oldSelect = _semanticTapCallback(tester, _choice('GE'));
      final oldQuery = _editableWidget(tester, search).onChanged;
      final oldClear = _semanticTapCallback(
        tester,
        _key('action:fact_canton.clear_search'),
      );
      final oldBack = _semanticTapCallback(
        tester,
        _key('action:fact_canton.back'),
      );
      expect(oldSelect, isNotNull, reason: 'positive control: select is wired');
      expect(oldQuery, isNotNull, reason: 'positive control: query is wired');
      expect(oldClear, isNotNull, reason: 'positive control: clear is wired');
      expect(oldBack, isNotNull, reason: 'positive control: Back is wired');

      oldQuery!('Zurich');
      await tester.pump();
      expect(_renderedChoiceCodes(tester), ['ZH']);
      oldClear!();
      await tester.pump();
      expect(_renderedChoiceCodes(tester), batch18CantonOrder['fr']);
      oldSelect!();
      await tester.pump();
      expect(_selected(tester, 'GE'), Tristate.isTrue);
      oldBack!();
      await tester.pumpAndSettle();
      expect(_key('node:fact_contribution'), findsOneWidget);
      await _tapVisible(tester, 'action:fact_contribution.choose_no');
      final before = _reachableSnapshot(tester);
      oldQuery('Genève');
      oldClear();
      oldSelect();
      oldBack();
      await tester.pump();
      expect(
        _reachableSnapshot(tester),
        before,
        reason:
            '[R1_11] callbacks captured in an old generation must do nothing',
      );
    });
  });

  group('R1b_local_search_privacy', () {
    testWidgets('R1_04 bounded normalized labels-only local search', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      final search = _key('field:fact_canton.search');
      expect(
        search,
        findsOneWidget,
        reason: '[R1_04] search control is absent',
      );
      const cases = <String, List<String>>{
        'Rhodes-Extérieures': ['AR'],
        'arg': ['AG'],
        'Neuchâtel': ['NE'],
        'Zurich': ['ZH'],
        'GENE\u0300VE': ['GE'],
        'ｚｕｒｉｃｈ': ['ZH'],
        'wald': ['NW', 'OW'],
        'AG': [],
        'Aargau': [],
        'no-reviewed-label-matches-this': [],
      };
      for (final entry in cases.entries) {
        await tester.enterText(_editableUnder(search), entry.key);
        await tester.pump();
        expect(
          _editableWidget(tester, search).controller.text,
          entry.key,
          reason: '[R1_04] normalized matching must preserve the raw query',
        );
        expect(
          _renderedChoiceCodes(tester),
          entry.value,
          reason: '[R1_04/R1_06] query=${entry.key}',
        );
      }
      final exactly64CodePoints = '${'A' * 63}😀';
      await tester.enterText(_editableUnder(search), exactly64CodePoints);
      await tester.pump();
      expect(
        _editableWidget(tester, search).controller.text,
        exactly64CodePoints,
      );
      await tester.enterText(_editableUnder(search), '${exactly64CodePoints}B');
      await tester.pump();
      expect(
        _editableWidget(tester, search).controller.text,
        exactly64CodePoints,
        reason: '[R1_04] input must be bounded to 64 Unicode code points',
      );
      final combining64CodePoints = '${'A' * 62}e\u0301';
      await tester.enterText(_editableUnder(search), combining64CodePoints);
      await tester.pump();
      expect(
        _editableWidget(tester, search).controller.text,
        combining64CodePoints,
        reason: '[R1_04] combining marks count as Unicode code points',
      );
      await tester.enterText(_editableUnder(search), 'Arg');
      await tester.enterText(_editableUnder(search), 'Zurich');
      await tester.enterText(_editableUnder(search), 'no-match');
      await tester.enterText(_editableUnder(search), 'Genève');
      await tester.pump();
      expect(_renderedChoiceCodes(tester), ['GE']);
    });

    testWidgets('R1_06 first middle last no-match clear and rapid query', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      final search = _key('field:fact_canton.search');
      expect(
        search,
        findsOneWidget,
        reason: '[R1_06] required search cases cannot run without search',
      );
      for (final entry in const <String, List<String>>{
        'Rhodes-Extérieures': ['AR'],
        'Neuchâtel': ['NE'],
        'Zurich': ['ZH'],
        'no-reviewed-label-matches-this': [],
      }.entries) {
        await tester.enterText(_editableUnder(search), entry.key);
        await tester.pump();
        expect(_renderedChoiceCodes(tester), entry.value);
      }
      await _tapVisible(tester, 'action:fact_canton.clear_search');
      expect(_renderedChoiceCodes(tester), batch18CantonOrder['fr']);
      await tester.enterText(_editableUnder(search), 'Argovie');
      await tester.enterText(_editableUnder(search), 'Zurich');
      await tester.enterText(_editableUnder(search), 'no-match');
      await tester.enterText(_editableUnder(search), 'Genève');
      await tester.pump();
      expect(_renderedChoiceCodes(tester), ['GE']);
    });

    testWidgets('R1_07 clear restores list selection and search focus', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      expect(
        _choice('GE'),
        findsOneWidget,
        reason: '[R1_07] reviewed choices are absent',
      );
      await _tapVisible(tester, 'choice:fact_canton.GE');
      final selectedBefore = _renderedChoiceCodes(
        tester,
      ).where((code) => _selected(tester, code) == Tristate.isTrue).toList();
      final search = _key('field:fact_canton.search');
      await tester.enterText(
        _editableUnder(search),
        'no-reviewed-label-matches-this',
      );
      await tester.pump();
      expect(_key('status:fact_canton.no_match'), findsOneWidget);
      expect(_renderedChoiceCodes(tester), isEmpty);
      await _tapVisible(tester, 'action:fact_canton.clear_search');
      expect(_renderedChoiceCodes(tester), batch18CantonOrder['fr']);
      expect(
        _renderedChoiceCodes(
          tester,
        ).where((code) => _selected(tester, code) == Tristate.isTrue).toList(),
        selectedBefore,
        reason: '[R1_07] Clear must not create or change a selection',
      );
      expect(_searchOwnsPrimaryFocus(), isTrue);
      expect(_key('node:fact_canton'), findsOneWidget);
    });

    testWidgets('R1_10 query changes and clear never mutate selection', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      expect(
        _choice('GE'),
        findsOneWidget,
        reason: '[R1_10] reviewed choices are absent',
      );
      await _tapVisible(tester, 'choice:fact_canton.GE');
      final search = _key('field:fact_canton.search');
      for (final query in ['Zurich', 'Genève']) {
        await tester.enterText(_editableUnder(search), query);
        await tester.pump();
        expect(
          tester.getSemantics(_key('group:fact_canton.choices')).value,
          'Genève',
          reason:
              '[R1_10] selected value must remain observable while filtered',
        );
        if (query == 'Genève') {
          expect(_selected(tester, 'GE'), Tristate.isTrue);
          expect(
            _renderedChoiceCodes(
              tester,
            ).where((code) => _selected(tester, code) == Tristate.isTrue),
            ['GE'],
          );
        }
      }
      await _tapVisible(tester, 'action:fact_canton.clear_search');
      expect(_choice('GE'), findsOneWidget);
      await tester.ensureVisible(_choice('GE'));
      expect(_selected(tester, 'GE'), Tristate.isTrue);
    });

    testWidgets('R1_12 search exposes no learning or clipboard capability', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      final search = _key('field:fact_canton.search');
      expect(
        search,
        findsOneWidget,
        reason: '[R1_12] privacy-configured local search is absent',
      );
      final field = _editableWidget(tester, search);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.autofillHints, isEmpty);
      expect(field.enableInteractiveSelection, isFalse);
      expect(
        field.controller.text,
        isEmpty,
        reason: '[R1_12] query starts ephemeral and empty',
      );

      final network = _CountingHttpOverrides();
      final logs = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = oldDebugPrint);
      var clipboardCalls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method.startsWith('Clipboard.')) clipboardCalls += 1;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await HttpOverrides.runZoned(() async {
        HttpClient().close(force: true);
      }, createHttpClient: network.createHttpClient);
      expect(
        network.clientsCreated,
        1,
        reason: 'positive control: network spy',
      );
      network.clientsCreated = 0;
      await SystemChannels.platform.invokeMethod<Object?>(
        'Clipboard.getData',
        'text/plain',
      );
      expect(clipboardCalls, 1, reason: 'positive control: clipboard spy');
      clipboardCalls = 0;
      debugPrint('positive-control');
      expect(logs, ['positive-control'], reason: 'positive control: log spy');
      logs.clear();
      await HttpOverrides.runZoned(() async {
        await tester.enterText(_editableUnder(search), 'Genève');
        await tester.pump();
        await _tapVisible(tester, 'choice:fact_canton.GE');
        await _tapVisible(tester, 'action:fact_canton.clear_search');
      }, createHttpClient: network.createHttpClient);
      expect(
        network.clientsCreated,
        0,
        reason: '[R1_12] local search used network',
      );
      expect(clipboardCalls, 0, reason: '[R1_12] local search used clipboard');
      expect(logs, isEmpty, reason: '[R1_12] query or selection was logged');
      await tester.pumpWidget(const SizedBox.shrink());
      await _openCantonFromNo(tester);
      expect(_editableWidget(tester, search).controller.text, isEmpty);
      expect(
        _renderedChoiceCodes(
          tester,
        ).where((code) => _selected(tester, code) == Tristate.isTrue),
        isEmpty,
        reason: '[R1_12] query or selection persisted into a fresh app',
      );
    });
  });

  group('R1c_selection_semantics_and_layout', () {
    testWidgets('R1_08 selection commits one allowed ephemeral code only', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      expect(
        _choice('GE'),
        findsOneWidget,
        reason: '[R1_08] selectable reviewed rows are absent',
      );
      await _tapVisible(tester, 'choice:fact_canton.GE');
      expect(_selected(tester, 'GE'), Tristate.isTrue);
      expect(
        _renderedChoiceCodes(
          tester,
        ).where((code) => _selected(tester, code) == Tristate.isTrue),
        ['GE'],
      );
      expect(_key('node:fact_canton'), findsOneWidget);
      expect(_key('node:fact_commune'), findsNothing);
      expect(find.byKey(const ValueKey('result:personal_tax')), findsNothing);
    });

    testWidgets('R1_09 same-code reselection is byte-equivalent no-op', (
      tester,
    ) async {
      await _openCantonFromNo(tester);
      expect(
        _choice('GE'),
        findsOneWidget,
        reason: '[R1_09] selectable reviewed rows are absent',
      );
      await _tapVisible(tester, 'choice:fact_canton.GE');
      final before = _reachableSnapshot(tester);
      await _tapVisible(tester, 'choice:fact_canton.GE');
      expect(
        _reachableSnapshot(tester),
        before,
        reason: '[R1_09] same-code reselect must not mutate reachable state',
      );
    });

    testWidgets('R1_13 all R1 targets and single-select semantics are usable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _openCantonFromNo(tester, textScaler: const TextScaler.linear(2));
      expect(
        _renderedChoiceCodes(tester),
        hasLength(26),
        reason: '[R1_13] all 26 semantic rows must exist',
      );
      final search = _key('field:fact_canton.search');
      await tester.enterText(_editableUnder(search), 'Genève');
      await tester.pump();
      final clear = _key('action:fact_canton.clear_search');
      expect(clear, findsOneWidget);
      final clearSize = tester.getSize(clear);
      expect(clearSize.width, greaterThanOrEqualTo(48));
      expect(clearSize.height, greaterThanOrEqualTo(48));
      await _tapVisible(tester, 'action:fact_canton.clear_search');
      for (final key in <String>[
        'field:fact_canton.search',
        'action:fact_canton.back',
        ...batch18CantonOrder['fr']!.map((code) => 'choice:fact_canton.$code'),
      ]) {
        final finder = _key(key);
        await tester.ensureVisible(finder);
        await tester.pump();
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        if (key.startsWith('choice:fact_canton.')) {
          final code = key.split('.').last;
          final semantics = tester.getSemantics(finder).getSemanticsData();
          expect(semantics.label, batch18CantonLabels['fr']![code]);
          expect(semantics.hasAction(SemanticsAction.tap), isTrue);
          expect(semantics.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        }
      }
      final ge = tester.getSemantics(_choice('GE'));
      expect(ge.label, batch18CantonLabels['fr']!['GE']);
      expect(ge.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(
        ge.getSemanticsData().flagsCollection.isInMutuallyExclusiveGroup,
        isTrue,
      );
      await _tapVisible(tester, 'choice:fact_canton.GE');
      expect(_selected(tester, 'GE'), Tristate.isTrue);
      await _tapVisible(tester, 'choice:fact_canton.ZH');
      expect(_selected(tester, 'ZH'), Tristate.isTrue);
      expect(
        _renderedChoiceCodes(
          tester,
        ).where((code) => _selected(tester, code) == Tristate.isTrue),
        ['ZH'],
        reason: '[R1_13] semantics must expose exactly one selected row',
      );
    });
  });

  test('R1_14 registry keeps R1 before R2 and excludes later evidence', () {
    final registry = File(
      '../../batch18/runtime-gates.yaml',
    ).readAsStringSync();
    expect(registry, contains('state: expected_red'));
    expect(registry, contains('next_gate: R2'));
    expect(registry, contains('later_gate_evidence_counts_for_R1: false'));
    expect(
      registry.indexOf('  R1:'),
      lessThan(registry.indexOf('  R2:')),
      reason: '[R1_14] R1 must remain the first targeted runtime gate',
    );
  });
}
