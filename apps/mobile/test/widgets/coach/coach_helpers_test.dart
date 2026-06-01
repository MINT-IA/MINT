import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/widgets/coach/coach_helpers.dart';

void main() {
  test('tipRoute keeps unknown tips in Coach instead of opening Rapport', () {
    final tip = CoachingTip(
      id: 'unknown_tip',
      title: 'Unknown',
      category: 'unknown',
      priority: CoachingPriority.moyenne,
      message: 'Unknown',
      action: 'Open',
      source: 'test',
      icon: Icons.help_outline,
    );

    expect(tipRoute(tip), '/coach/chat');
  });
}
