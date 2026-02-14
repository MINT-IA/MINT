/// Constantes de navigation MINT
///
/// Centralise toutes les valeurs numériques pour faciliter la maintenance
class NavigationConstants {
  NavigationConstants._(); // Private constructor to prevent instantiation

  // FAB Mentor positioning
  static const double fabBottomOffset = 90.0;
  static const double fabRightOffset = 20.0;
  static const double fabSize = 56.0;

  // Bottom navigation
  static const double bottomNavHeight = 72.0;
  static const double bottomNavPaddingH = 16.0;
  static const double bottomNavPaddingV = 8.0;
  static const double bottomNavIconSize = 24.0;
  static const double bottomNavLabelSize = 10.0;

  // Animations
  static const Duration tabSwitchDuration = Duration(milliseconds: 300);
  static const Duration modalAnimationDuration = Duration(milliseconds: 250);
  static const Duration fabAnimationDuration = Duration(milliseconds: 200);

  // Breakpoints (responsive design)
  static const double phoneBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  static const double spacingXXXL = 32.0;

  // Border radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;

  // Modal
  static const double modalHeightRatio = 0.6;
  static const double modalHandleWidth = 40.0;
  static const double modalHandleHeight = 4.0;
}
