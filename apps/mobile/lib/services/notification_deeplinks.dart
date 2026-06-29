/// Canonical GoRouter payloads emitted by local notifications.
class NotificationDeeplinks {
  NotificationDeeplinks._();

  static const monthlyCheckIn = '/home?screen=coach&intent=monthlyCheckIn';
  static const threeADeadline = '/pilier-3a';
  static const taxDeadline = '/home';

  static String commitmentReminder(Object commitmentId) =>
      '/home?screen=coach&intent=commitmentReminder'
      '&id=${Uri.encodeComponent(commitmentId.toString())}';

  static String freshStart(String landmarkType) =>
      '/home?screen=coach&intent=freshStart'
      '&type=${Uri.encodeComponent(landmarkType)}';
}
