import 'package:flutter/services.dart';

class HapticFeedbackService {
  /// Feedback léger (sélection, switch)
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Feedback moyen (bouton principal)
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Feedback lourd (succès, erreur)
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Feedback succès (sélection validée)
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }
}
