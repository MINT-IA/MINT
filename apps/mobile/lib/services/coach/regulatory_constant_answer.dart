import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

class RegulatoryConstantAnswer {
  const RegulatoryConstantAnswer({required this.text});

  final String text;
}

class CoachRegulatoryConstantAnswer {
  CoachRegulatoryConstantAnswer._();

  static const String _regulatoryYear = '2026';

  static RegulatoryConstantAnswer? resolve(String message, S l) {
    final normalized = _normalize(message);
    if (!_mentionsPillar3a(normalized) ||
        !_asksForCeiling(normalized) ||
        !_mentionsLpp(normalized)) {
      return null;
    }

    final ceiling =
        reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp).round();
    return RegulatoryConstantAnswer(
      text: l.coachRegulatory3aCeilingWithLpp(
        _formatChf(ceiling),
        _regulatoryYear,
      ),
    );
  }

  static bool _mentionsPillar3a(String value) =>
      RegExp(r'\b(3a|pilier\s*3|troisieme\s+pilier)\b').hasMatch(value);

  static bool _asksForCeiling(String value) =>
      RegExp(r'\b(plafond|maximum|max|limite|deduction|deductible)\b')
          .hasMatch(value);

  static bool _mentionsLpp(String value) =>
      RegExp(r'\b(lpp|2e\s+pilier|deuxieme\s+pilier|affilie)\b')
          .hasMatch(value);

  static String _formatChf(int value) {
    final raw = value.toString();
    return raw.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => "${match[1]}'",
    );
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u');
  }
}
