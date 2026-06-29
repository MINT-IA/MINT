import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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
