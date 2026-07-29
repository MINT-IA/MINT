import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:provider/provider.dart';

/// PR-G (revue Codex P2) — le badge de la franchise recommandée est neutralisé
/// (« TOP » → « Fréquent » et ses équivalents ×6). Avant, il était un enfant
/// NON contraint devant deux `Expanded` : sa largeur naturelle s'ajoutait telle
/// quelle à la Row et pouvait la faire déborder (a11y D7/D8). Correctif : badge
/// enveloppé dans `Flexible` (flex:3, loose) + `Text` `maxLines:1 +
/// TextOverflow.ellipsis` → le badge CÈDE sous la pression au lieu d'ajouter sa
/// largeur.
///
/// CONSTAT MESURÉ (hors périmètre PR-G) : à 320 px × textScale 1.3, la Row de
/// franchise déborde d'~31 px À CAUSE DES COLONNES NUMÉRIQUES (CHF / prime /
/// coût), même avec un badge d'un seul caractère — donc INDÉPENDAMMENT du badge
/// (dette a11y préexistante des colonnes chiffrées, signalée pour une passe
/// séparée). Ces tests jugent donc le BADGE, pas la dette numérique : (1) le
/// correctif est structurellement présent ; (2) à largeur téléphone standard
/// (390) la Row TIENT parce que le badge cède — un badge non contraint la ferait
/// déborder ; (3) quand il y a la place (600) le label s'affiche entier. Harnais
/// repris de `first_job_lucidite_test.dart`.

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

CoachProfile _profile() {
  return CoachProfile(
    birthYear: 2001, // âge 25 au 2026 (fenêtre premier emploi)
    canton: 'VD',
    salaireBrutMensuel: 6500,
    userProvidedFields: const {'salary', 'age', 'canton'},
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2066),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: _FakeProvider(_profile()),
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const FirstJobScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Draine les exceptions de layout PRÉEXISTANTES (colonnes chiffrées + autres
/// sections de l'écran à faible largeur) — hors périmètre PR-G.
void _drainPreexistingLayoutExceptions(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

/// Débordement horizontal de la Row de franchise (somme des largeurs d'enfants
/// − largeur de la Row). ≤ 0 = tient.
double _franchiseRowOverflow(WidgetTester tester, Finder badge) {
  final row = find.ancestor(of: badge, matching: find.byType(Row)).first;
  final flex = tester.renderObject<RenderFlex>(row);
  var childrenExtent = 0.0;
  flex.visitChildren((child) => childrenExtent += (child as RenderBox).size.width);
  return childrenExtent - flex.size.width;
}

void main() {
  testWidgets(
    'badge : correctif présent (Flexible + ellipsis + maxLines:1) — 320 × 1.3',
    (tester) async {
      await _pump(tester, size: const Size(320, 60000), textScale: 1.3);

      final badge = find.text('Fréquent');
      expect(badge, findsOneWidget,
          reason: 'la franchise recommandée porte le badge neutre');
      expect(find.ancestor(of: badge, matching: find.byType(Flexible)),
          findsWidgets,
          reason: 'le badge est contraint par un Flexible (il cède)');
      final badgeText = tester.widget<Text>(badge);
      expect(badgeText.maxLines, 1);
      expect(badgeText.overflow, TextOverflow.ellipsis);

      _drainPreexistingLayoutExceptions(tester);
    },
  );

  testWidgets(
    'badge : la Row de franchise TIENT sur largeur téléphone standard (390) — '
    'le badge cède ; un badge non contraint la ferait déborder',
    (tester) async {
      await _pump(tester, size: const Size(390, 60000), textScale: 1.0);

      final badge = find.text('Fréquent');
      expect(badge, findsOneWidget);
      expect(_franchiseRowOverflow(tester, badge), lessThanOrEqualTo(1.0),
          reason: 'à 390 px la Row ne déborde pas — le badge Flexible cède ; '
              'sans Flexible, le badge ajouterait sa largeur et ferait déborder');

      _drainPreexistingLayoutExceptions(tester);
    },
  );

  testWidgets(
    'badge : label entièrement visible quand il y a la place (600)',
    (tester) async {
      await _pump(tester, size: const Size(600, 60000), textScale: 1.0);

      final badge = find.text('Fréquent');
      expect(badge, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(badge);
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: 'le correctif ne tronque pas gratuitement : label entier '
              'quand la largeur le permet');

      _drainPreexistingLayoutExceptions(tester);
    },
  );
}
