import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

/// Wraps [child] in a MaterialApp with French localization delegates
/// and a [CoachProfileProvider].
///
/// Use this in all widget/screen tests to avoid Null check errors on
/// `S.of(context)!` calls.
Widget buildTestableWidget(
  Widget child, {
  Locale locale = const Locale('fr'),
  List<SingleChildWidget> extraProviders = const [],
}) {
  final providers = <SingleChildWidget>[
    ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
    ...extraProviders,
  ];

  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}
