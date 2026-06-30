import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';

/// Shell-aware navigation helper replacing safePop.
///
/// MintNav.back() pops if the stack has depth, otherwise navigates
/// to a caller-owned fallback route. Shell screens default to /home;
/// onboarding/first-value screens can pass /onb to avoid crossing the
/// auth/profile guards on an empty stack.
class MintNav {
  MintNav._();

  static const shellFallbackRoute = '/home';
  static const onboardingFallbackRoute = '/onb';
  static const _shellBranchRoots = {
    '/home',
    '/mon-argent',
    '/coach/chat',
    '/explore',
  };

  static String coachFallbackRouteFor(AuthLifecycleState lifecycle) {
    return lifecycle.allowsMainNavigation
        ? shellFallbackRoute
        : onboardingFallbackRoute;
  }

  static bool isShellBranchRoot(String route) {
    return _shellBranchRoots.contains(route.split('?').first);
  }

  static Future<T?> open<T extends Object?>(
    BuildContext context,
    String route, {
    Object? extra,
  }) {
    if (isShellBranchRoot(route)) {
      context.go(route, extra: extra);
      return SynchronousFuture<T?>(null);
    }
    return context.push<T>(route, extra: extra);
  }

  /// Navigate back. If stack is empty, go to the caller-owned [fallbackRoute].
  static void back(
    BuildContext context, {
    String fallbackRoute = shellFallbackRoute,
  }) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }
}
