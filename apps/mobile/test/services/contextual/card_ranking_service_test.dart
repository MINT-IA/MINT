import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/contextual/card_ranking_service.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_signal.dart';

ContextualAlertCard _alert(String id, Gravity g) => ContextualAlertCard(
      signal: MintAlertSignal(
        gravity: g,
        factKey: 'mintAlertDebtFact',
        causeKey: 'mintAlertDebtCause',
        nextMomentKey: 'mintAlertDebtNextMoment',
        topicTag: 'debt',
        alertId: id,
      ),
    );

ContextualHeroCard _hero(String label) => ContextualHeroCard(
      label: label,
      value: '0',
      narrative: '',
      route: '/',
    );

ContextualActionCard _action(String title) => ContextualActionCard(
      title: title,
      body: '',
      route: '/',
      icon: Icons.add,
      priorityScore: 0.5,
    );

void main() {
  group('rankCards', () {
    test('empty input returns empty list', () {
      expect(rankCards(const []), isEmpty);
    });

    test('floats every G3 card to the front of the list', () {
      final hero = _hero('hero');
      final g3 = _alert('a1', Gravity.g3);
      final action = _action('act');
      final g2 = _alert('a2', Gravity.g2);
      final g3b = _alert('a3', Gravity.g3);

      final out = rankCards([hero, g3, action, g2, g3b]);

      // First two are the G3 cards, in input order.
      expect(out.indexOf(g3), 0);
      expect(out.indexOf(g3b), 1);
      // G2 follows.
      expect(out.indexOf(g2), 2);
      // Ungraded cards keep their relative order at the end.
      expect(out.indexOf(hero), lessThan(out.indexOf(action)));
    });

    test('stable: preserves input order within each tier', () {
      final cards = [
        _alert('g3-1', Gravity.g3),
        _alert('g3-2', Gravity.g3),
        _alert('g3-3', Gravity.g3),
      ];

      final out = rankCards(cards).whereType<ContextualAlertCard>().toList();

      expect(out.map((c) => c.signal.alertId), ['g3-1', 'g3-2', 'g3-3']);
    });

    test('no G3 → list reorders only G2 ahead of ungraded', () {
      final hero = _hero('hero');
      final g2 = _alert('g2', Gravity.g2);
      final action = _action('act');

      final out = rankCards([hero, g2, action]);

      expect(out.first, g2);
      expect(out.indexOf(hero), lessThan(out.indexOf(action)));
    });

    test('does not mutate input list', () {
      final input = [_alert('a', Gravity.g3), _hero('h')];
      final inputCopy = List<ContextualCard>.from(input);
      rankCards(input);
      expect(input, inputCopy);
    });
  });
}
