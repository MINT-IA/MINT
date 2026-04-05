/// NavigationShellState — global tab-switch callback registry.
///
/// Allows widgets outside the navigation shell to programmatically switch tabs.
/// Originally defined in pulse_screen.dart; extracted here as pulse_screen.dart
/// was a dead screen (replaced by MintHomeScreen in Wire Spec V2).
///
/// Usage:
///   NavigationShellState.switchTab(1); // opens Coach tab
class NavigationShellState {
  NavigationShellState._();

  static void Function(int index)? _switchTab;

  static void register(void Function(int index) callback) {
    _switchTab = callback;
  }

  static void unregister() {
    _switchTab = null;
  }

  static void switchTab(int index) {
    _switchTab?.call(index);
  }
}
