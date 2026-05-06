// ────────────────────────────────────────────────────────────
//  CROSS-SESSION OPENER BUILDER TESTS — Phase 91 / VIVANT-02
// ────────────────────────────────────────────────────────────
//
// Tests for [CrossSessionOpenerBuilder.buildWithLocalizations] :
//   01. No memory + no conversation → returns null (caller shows
//       the existing 4-chip opener).
//   02. CapMemory with `lastCompletedCapHeadline` → returns the FR
//       template with that headline as `{topic}`.
//   03. CapMemory with `lastCapServed` only (no headline) → maps the
//       cap id to its localized topic label (« lpp » → « 2e pilier »).
//   04. ConversationMemory with `frequentTopics` → uses the first
//       frequent topic when CapMemory is empty.
//   05. CapMemory headline takes priority over ConversationMemory.
//   06. Locale FR : « Re. La dernière fois, on parlait de ... »
//   07. Locale DE : « Hey, wieder da. Letztes Mal ... »
//   08. Long headline truncated at 80 chars + ellipsis.
//   09. Unknown cap id passes through (no map hit, no headline).
// ────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations_de.dart';
import 'package:mint_mobile/l10n/app_localizations_en.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/cross_session_opener_builder.dart';

void main() {
  // Shared FR localizations — matches existing test patterns
  // (precomputed_insights_service_test uses the same idiom).
  final lFr = SFr();
  final lDe = SDe();
  final lEn = SEn();

  // ── Helpers ──────────────────────────────────────────────────────────────
  ConversationMemory makeConv({
    List<String> frequentTopics = const [],
    List<String> recentTitles = const [],
    int totalConversations = 0,
  }) {
    return ConversationMemory(
      summary: '',
      frequentTopics: frequentTopics,
      totalConversations: totalConversations,
      totalMessages: 0,
      recentTitles: recentTitles,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  01. Empty stores → null
  // ════════════════════════════════════════════════════════════

  test('01 returns null when neither CapMemory nor ConversationMemory has '
      'any usable signal', () async {
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lFr,
      memoryOverride: const CapMemory(),
      convOverride: makeConv(),
    );
    expect(result, isNull);
  });

  // ════════════════════════════════════════════════════════════
  //  02. CapMemory.lastCompletedCapHeadline → topic
  // ════════════════════════════════════════════════════════════

  test('02 uses lastCompletedCapHeadline as topic when present', () async {
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lFr,
      memoryOverride: const CapMemory(
        lastCompletedCapHeadline: 'rachat LPP',
      ),
      convOverride: makeConv(),
    );
    expect(result, isNotNull);
    expect(result, contains('rachat LPP'));
    expect(result, contains('Re. La dernière fois, on parlait de'));
  });

  // ════════════════════════════════════════════════════════════
  //  03. lastCapServed only → cap-id mapped to localized label
  // ════════════════════════════════════════════════════════════

  test('03 maps lastCapServed to a localized topic label '
      '(lpp → "2e pilier")', () async {
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lFr,
      memoryOverride: const CapMemory(
        lastCapServed: 'lpp',
      ),
      convOverride: makeConv(),
    );
    expect(result, isNotNull);
    expect(result, contains('2e pilier'));
  });

  // ════════════════════════════════════════════════════════════
  //  04. ConversationMemory frequentTopics fallback
  // ════════════════════════════════════════════════════════════

  test('04 falls back to ConversationMemory.frequentTopics when '
      'CapMemory is empty', () async {
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lFr,
      memoryOverride: const CapMemory(),
      convOverride: makeConv(
        frequentTopics: ['3a', 'fiscal'],
        totalConversations: 3,
      ),
    );
    expect(result, isNotNull);
    expect(result, contains('3e pilier'));
  });

  // ════════════════════════════════════════════════════════════
  //  05. CapMemory headline takes priority over ConversationMemory
  // ════════════════════════════════════════════════════════════

  test('05 CapMemory.lastCompletedCapHeadline takes priority over '
      'ConversationMemory.frequentTopics', () async {
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lFr,
      memoryOverride: const CapMemory(
        lastCompletedCapHeadline: 'rachat LPP',
      ),
      convOverride: makeConv(
        frequentTopics: ['3a'],
        totalConversations: 2,
      ),
    );
    expect(result, isNotNull);
    expect(result, contains('rachat LPP'));
    expect(result, isNot(contains('3e pilier')));
  });

  // ════════════════════════════════════════════════════════════
  //  06. Locale FR template
  // ════════════════════════════════════════════════════════════

  test('06 FR template wraps topic with the expected « Re. La dernière '
      'fois ... » phrasing', () async {
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lFr,
      memoryOverride: const CapMemory(lastCapServed: '3a'),
      convOverride: makeConv(),
    );
    expect(result, isNotNull);
    expect(result, startsWith('Re. La dernière fois, on parlait de'));
    expect(result, endsWith('Tu veux qu\'on regarde la suite ?.'));
  });

  // ════════════════════════════════════════════════════════════
  //  07. Locale DE template
  // ════════════════════════════════════════════════════════════

  test('07 DE template wraps topic with the expected German phrasing',
      () async {
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lDe,
      memoryOverride: const CapMemory(lastCapServed: '3a'),
      convOverride: makeConv(),
    );
    expect(result, isNotNull);
    expect(result, startsWith('Hey, wieder da. Letztes Mal ging es um'));
    expect(result, endsWith('Sollen wir weitermachen?.'));
  });

  // ════════════════════════════════════════════════════════════
  //  08. Long headline truncated to 80 chars + ellipsis
  // ════════════════════════════════════════════════════════════

  test('08 truncates a very long headline to ≤ 80 chars + ellipsis',
      () async {
    final longHeadline =
        'a' * 200; // 200 chars, well over the 80-char cap.
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lFr,
      memoryOverride: CapMemory(
        lastCompletedCapHeadline: longHeadline,
      ),
      convOverride: makeConv(),
    );
    expect(result, isNotNull);
    // 79 'a' + ellipsis = 80 chars topic.
    expect(result, contains('a' * 79));
    expect(result, contains('…'));
    // The raw 200-char repeat must NOT appear verbatim.
    expect(result, isNot(contains('a' * 100)));
  });

  // ════════════════════════════════════════════════════════════
  //  09. Unknown cap id falls through to its raw form (truncated).
  // ════════════════════════════════════════════════════════════

  test('09 unknown cap id passes through raw when no map hit and no '
      'headline', () async {
    final result = await CrossSessionOpenerBuilder.buildWithLocalizations(
      l: lEn,
      memoryOverride: const CapMemory(
        lastCapServed: 'experimental_canton_zh_cap',
      ),
      convOverride: makeConv(),
    );
    expect(result, isNotNull);
    // EN template + raw tag — verifies the fall-through path.
    expect(result, startsWith('Welcome back. Last time we discussed'));
    expect(result, contains('experimental_canton_zh_cap'));
  });
}
