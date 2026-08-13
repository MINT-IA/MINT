// Registre officiel des communes suisses — identité du fait « domicile ».
//
// Pourquoi ce fichier existe : le parcours domicile demandait un canton dans
// une liste PUIS une commune en texte libre. Deux saisies pour une seule
// information, puisqu'une commune suisse appartient à un et un seul canton ;
// et la seconde n'était rattachée à rien — le champ `communeBfs` du fait
// existait mais restait toujours nul en production.
//
// Ici, on ne peut enregistrer qu'une commune CHOISIE dans le registre fédéral.
// Le canton en est dérivé, jamais demandé. Le numéro OFS est stocké : c'est la
// seule clé qui survit à un changement de nom, à une fusion ou à un transfert
// de canton (Moutier : BE 700 jusqu'au 31.12.2025, puis JU 6831).
//
// Asset généré par `tools/data/build_commune_registry.py` depuis le registre
// de l'OFS. Il porte sa date d'instantané : ce qu'il décrit est vrai À CETTE
// DATE, pas éternellement.

import 'package:flutter/services.dart';

/// Une commune du registre fédéral, à la date de l'instantané embarqué.
class CommuneEntry {
  const CommuneEntry({
    required this.bfs,
    required this.officialName,
    required this.canton,
    required this.validFrom,
    this.aliases = const [],
  });

  /// Numéro OFS — l'identité engagée du fait.
  final int bfs;

  /// Nom officiel fédéral. Il porte DÉJÀ le suffixe cantonal quand il résout
  /// un homonyme (« Rickenbach (LU) ») : c'est la convention du registre, pas
  /// une mise en forme ajoutée par MINT. Mesuré sur l'instantané du
  /// 2026-08-13 : 35 noms partagés par 77 communes, zéro cas où ce suffixe ne
  /// suffit pas.
  final String officialName;

  /// Canton DÉRIVÉ de la commune — jamais saisi.
  final String canton;

  final String validFrom;

  /// Formes servant UNIQUEMENT à la recherche (« Morat » pour Murten,
  /// « Bienne » pour Biel/Bienne). Jamais affichées à la place du nom officiel.
  final List<String> aliases;
}

class CommuneRegistry {
  CommuneRegistry._();

  static const String assetPath = 'assets/data/commune_registry.txt';

  static List<CommuneEntry> _entries = const [];
  static Map<int, CommuneEntry> _byBfs = const {};
  static List<String> _needles = const [];
  static String _snapshot = '';

  /// Les 26 codes cantonaux officiels — un registre qui en contient un autre
  /// n'est pas le registre suisse.
  static const Set<String> officialCantons = {
    'AG',
    'AI',
    'AR',
    'BE',
    'BL',
    'BS',
    'FR',
    'GE',
    'GL',
    'GR',
    'JU',
    'LU',
    'NE',
    'NW',
    'OW',
    'SG',
    'SH',
    'SO',
    'SZ',
    'TG',
    'TI',
    'UR',
    'VD',
    'VS',
    'ZG',
    'ZH',
  };

  /// Plancher de couverture nationale. La Suisse compte ~2110 communes ; un
  /// asset qui en contiendrait quelques centaines serait tronqué, et un champ
  /// de recherche répondant « aucune commune » à presque tout est pire qu'un
  /// champ absent — il fait porter la faute à la personne.
  static const int minimumNationalCoverage = 1900;

  static bool get isLoaded => _entries.isNotEmpty;

  /// Date de l'instantané fédéral embarqué, au format JJ-MM-AAAA.
  static String get snapshotDate => _snapshot;

  /// La même date, en tant que date — pour être écrite dans la langue de la
  /// personne plutôt qu'en chiffres séparés par des traits.
  static DateTime? get snapshotDay {
    final parts = _snapshot.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  static int get communeCount => _entries.length;

  /// Seam de test : remplace la lecture de l'asset. C'est la seule façon
  /// d'avoir un oracle sur la branche la plus risquée — asset absent, lecture
  /// lente, contenu corrompu — puisque le bundle d'assets n'est pas monté en
  /// test unitaire.
  static Future<String> Function()? debugLoader;

  /// Charge et VALIDE le registre embarqué. Lève si l'asset est absent,
  /// tronqué ou incohérent : un registre à moitié lu ne doit jamais se faire
  /// passer pour le registre fédéral.
  static Future<void> load() async {
    if (isLoaded) return;
    final content =
        await (debugLoader?.call() ?? rootBundle.loadString(assetPath));
    final parsed = _parseStrict(content);
    _assertNationalCoverage(parsed.entries);
    _publish(parsed);
  }

  /// Seam de test : injecte un registre sans passer par l'asset. Applique les
  /// mêmes contrôles structurels que `load`, sans exiger la couverture
  /// nationale — un extrait est légitime en test.
  static void parse(String content) => _publish(_parseStrict(content));

  static void debugReset() {
    _entries = const [];
    _byBfs = const {};
    _needles = const [];
    _snapshot = '';
  }

  static void _publish(_ParsedRegistry parsed) {
    // Publication ATOMIQUE : les structures ne sont assignées qu'une fois
    // l'analyse entièrement validée, jamais au fil de la lecture.
    _entries = parsed.entries;
    _snapshot = parsed.snapshot;
    _byBfs = {for (final e in parsed.entries) e.bfs: e};
    // Aiguille de recherche pré-calculée : le nom officiel et ses alias,
    // normalisés une seule fois au chargement plutôt qu'à chaque frappe. Les
    // formes sont jointes par la barre verticale — séparateur du fichier, donc
    // impossible dans un nom — pour qu'un DÉBUT de forme se teste sans se
    // confondre avec un début de mot interne.
    _needles = [
      for (final e in parsed.entries)
        '${normalise(e.officialName)}|${e.aliases.map(normalise).join('|')}',
    ];
  }

  // Les messages de `FormatException` ci-dessous ne sont jamais rendus : ils
  // partent dans le journal de développement quand l'asset est corrompu.
  // lint-ignore
  static _ParsedRegistry _parseStrict(String content) {
    final entries = <CommuneEntry>[];
    final seen = <int>{};
    var snapshot = '';
    var lineNumber = 0;
    for (final line in content.split(RegExp(r'\r?\n'))) {
      lineNumber++;
      if (line.startsWith('#')) {
        final marker = RegExp(r'^#\s*Instantané\s*:\s*(.+)$')  // lint-ignore
            .firstMatch(line); // lint-ignore
        if (marker != null) snapshot = marker.group(1)!.trim();
        continue;
      }
      if (line.trim().isEmpty) continue;
      final parts = line.split('|');
      // Une ligne mal formée est une CORRUPTION, pas une ligne à sauter en
      // silence : l'ignorer produirait un registre amputé qui se croit entier.
      if (parts.length != 5) {
        throw FormatException(
            // lint-ignore
            'ligne $lineNumber : ${parts.length} champs au lieu de 5',  // lint-ignore
            line); // lint-ignore
      }
      final bfs = int.tryParse(parts[0]);
      if (bfs == null || bfs <= 0) {
        throw FormatException(
            'ligne $lineNumber : numéro OFS invalide', line); // lint-ignore
      }
      if (!seen.add(bfs)) {
        throw FormatException(
            // lint-ignore
            'ligne $lineNumber : numéro OFS $bfs en double',  // lint-ignore
            line); // lint-ignore
      }
      if (parts[1].trim().isEmpty) {
        throw FormatException(
            'ligne $lineNumber : nom vide', line); // lint-ignore
      }
      if (!officialCantons.contains(parts[2])) {
        throw FormatException(
            // lint-ignore
            'ligne $lineNumber : canton « ${parts[2]} » hors des 26',  // lint-ignore
            line); // lint-ignore
      }
      entries.add(CommuneEntry(
        bfs: bfs,
        officialName: parts[1],
        canton: parts[2],
        validFrom: parts[3],
        aliases: parts[4].isEmpty ? const [] : parts[4].split(','),
      ));
    }
    if (entries.isEmpty) {
      throw const FormatException('registre vide'); // lint-ignore
    }
    // Sans date, le registre ne dit pas QUAND il est vrai — or il vieillit à
    // chaque fusion de communes.
    if (!RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(snapshot)) {
      throw FormatException(
          'date d\'instantané absente ou invalide', snapshot); // lint-ignore
    }
    return _ParsedRegistry(entries, snapshot);
  }

  static void _assertNationalCoverage(List<CommuneEntry> entries) {
    if (entries.length < minimumNationalCoverage) {
      throw FormatException(// lint-ignore
          'registre tronqué : ${entries.length} communes, minimum attendu ' // lint-ignore
          '$minimumNationalCoverage');
    }
    final cantons = entries.map((e) => e.canton).toSet();
    if (cantons.length != officialCantons.length) {
      throw FormatException(// lint-ignore
          '${cantons.length} cantons couverts au lieu de ${officialCantons.length}'); // lint-ignore
    }
  }

  /// Retrouve une commune par son identité fédérale.
  static CommuneEntry? byBfs(int bfs) => _byBfs[bfs];

  /// Recherche tolérante aux accents, à la casse et à la ponctuation.
  ///
  /// Les correspondances par DÉBUT de nom passent avant les correspondances
  /// internes : taper « bern » doit proposer Bern avant « Bremgarten bei
  /// Bern ». À égalité, l'ordre alphabétique du registre est conservé.
  static List<CommuneEntry> search(String query, {int limit = 8}) {
    final needle = normalise(query);
    if (needle.isEmpty) return const [];
    final starts = <CommuneEntry>[];
    final contains = <CommuneEntry>[];
    for (var i = 0; i < _entries.length; i++) {
      final haystack = _needles[i];
      // Un début de nom OU un début d'alias : les formes étant séparées par
      // la barre verticale, « bienne » compte comme un début pour
      // « Biel/Bienne » sans que « bern » remonte « Bremgarten bei Bern ».
      if (haystack.startsWith(needle) || haystack.contains('|$needle')) {
        starts.add(_entries[i]);
      } else if (haystack.contains(needle)) {
        contains.add(_entries[i]);
      }
      if (starts.length >= limit) break;
    }
    final results = [...starts, ...contains];
    return results.length <= limit ? results : results.sublist(0, limit);
  }

  /// Forme comparable d'un nom : minuscules, sans diacritiques, et toute
  /// ponctuation ramenée à une espace unique.
  ///
  /// C'est ce dernier point qui fait la différence entre trouver et ne pas
  /// trouver : le nom officiel est « St. Gallen », et personne ne tape le
  /// point. « St Gallen », « St.Gallen » et « st.  gallen » convergent tous
  /// vers « st gallen ». Même chose pour les apostrophes typographiques
  /// (« L'Abbaye »), les traits d'union et les barres obliques.
  static String normalise(String value) {
    final folded = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      folded.write(_foldings[rune] ?? String.fromCharCode(rune));
    }
    return folded.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static final Map<int, String> _foldings = {
    for (final entry in const {
      'àáâãäåa': 'a', // lint-ignore
      'ç': 'c', // lint-ignore
      'èéêë': 'e', // lint-ignore
      'ìíîï': 'i', // lint-ignore
      'ñ': 'n', // lint-ignore
      'òóôõöø': 'o', // lint-ignore
      'ùúûü': 'u', // lint-ignore
      'ýÿ': 'y', // lint-ignore
      'œ': 'oe', // lint-ignore
      'æ': 'ae', // lint-ignore
      'ß': 'ss', // lint-ignore
    }.entries)
      for (final rune in entry.key.runes) rune: entry.value,
  };
}

class _ParsedRegistry {
  const _ParsedRegistry(this.entries, this.snapshot);
  final List<CommuneEntry> entries;
  final String snapshot;
}
