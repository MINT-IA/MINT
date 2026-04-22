// fixture — correctly i18n-routed widget for GUARD-03 tests.
Widget build(BuildContext context) {
  return Text(AppLocalizations.of(context)!.greeting);
}

// lefthook-allow:hardcoded-fr: debug-only error fallback
final debugLabel = 'ERR';
