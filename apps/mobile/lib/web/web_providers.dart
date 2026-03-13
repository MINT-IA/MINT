import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/providers/household_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';

/// Returns the provider list for the web app.
///
/// Same as app.dart providers BUT excluding:
/// - `DocumentProvider` (uses dart:io)
/// - `SlmProvider` (depends on flutter_gemma / dart:io via slm_engine)
List<SingleChildWidget> webProviders() {
  return [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => ProfileProvider()),
    ChangeNotifierProvider(create: (_) => BudgetProvider()),
    ChangeNotifierProvider(create: (_) {
      final provider = ByokProvider();
      provider.loadSavedKey();
      return provider;
    }),
    ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
    ChangeNotifierProvider(create: (_) => HouseholdProvider()),
    ChangeNotifierProvider(create: (_) {
      final provider = CoachProfileProvider();
      provider.loadFromWizard();
      return provider;
    }),
    ChangeNotifierProvider(create: (_) {
      final provider = LocaleProvider();
      provider.load();
      return provider;
    }),
    ChangeNotifierProvider(create: (_) {
      final provider = UserActivityProvider();
      provider.loadAll();
      return provider;
    }),
  ];
}
