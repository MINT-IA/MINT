import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/web/web_providers.dart';
import 'package:mint_mobile/web/web_theme.dart';
import 'package:mint_mobile/web/web_router.dart';
import 'package:mint_mobile/web/widgets/web_viewport_layout.dart';

/// Root widget for the MINT web application.
///
/// Uses its own [MaterialApp.router] with [webRouter] so that
/// mobile-only routes and native dependencies are never imported.
class MintWebApp extends StatelessWidget {
  const MintWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: webProviders(),
      child: Builder(
        builder: (context) {
          final localeProvider = context.watch<LocaleProvider>();
          return MaterialApp.router(
            title: 'Mint',
            debugShowCheckedModeBanner: false,
            theme: buildWebTheme(),
            themeMode: ThemeMode.light,
            routerConfig: webRouter,
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            locale: localeProvider.locale,
            builder: (context, child) {
              return WebViewportLayout(
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
