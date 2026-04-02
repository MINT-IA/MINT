// ────────────────────────────────────────────────────────────
//  REGIONAL VOICE SERVICE — Swiss linguistic identity
// ────────────────────────────────────────────────────────────
//
// Maps the user's canton to a Swiss linguistic region and
// returns structured hints for the coach AI system prompt.
//
// The goal is NOT to caricature. It's to make a Romand feel
// MINT is romand, a Zurichois feel MINT is alémanique, a
// Tessinois feel MINT is tessinois — through subtle cultural
// references, local expressions, and the specific relationship
// each region has with money, savings, and retirement.
//
// Pure functions, no side effects, no I/O.
//
// ARCH NOTE: LLM prompt context, intentionally FR — all French strings
// below are injected into the AI system prompt and must not be extracted
// to ARB files. They are coach identity guidance, not UI copy.
//
// References:
//   - docs/VOICE_SYSTEM.md §9 (Adaptation linguistique)
//   - CLAUDE.md §6 (Compliance rules)
// ────────────────────────────────────────────────────────────

/// Swiss linguistic regions.
enum SwissRegion {
  /// Suisse romande: VD, GE, NE, JU, VS, FR.
  romande,

  /// Deutschschweiz: ZH, BE, LU, ZG, AG, SG, BS, BL, SO, etc.
  deutschschweiz,

  /// Svizzera italiana: TI, parts of GR.
  italiana,

  /// Unknown or null canton — neutral, no regional flavor.
  unknown,
}

/// Regional voice flavor for coach AI prompt injection.
///
/// Contains the system prompt addition, local expressions,
/// financial culture notes, and humor style guidance for
/// a given Swiss linguistic region.
class RegionalFlavor {
  /// The Swiss linguistic region.
  final SwissRegion region;

  /// Paragraph injected into the coach system prompt.
  /// Written in the region's language to guide Claude's tone.
  final String promptAddition;

  /// Example local expressions the LLM can weave in naturally.
  final List<String> localExpressions;

  /// How this region relates to money, savings, retirement.
  final String financialCultureNote;

  /// Subtle humor guidance for this region.
  final String humorStyle;

  /// Canton-specific nuance (optional, for VS/GE/ZH/BE/TI etc.).
  final String cantonNote;

  const RegionalFlavor({
    required this.region,
    required this.promptAddition,
    required this.localExpressions,
    required this.financialCultureNote,
    required this.humorStyle,
    this.cantonNote = '',
  });

  /// Neutral flavor — no regional injection.
  static const empty = RegionalFlavor(
    region: SwissRegion.unknown,
    promptAddition: '',
    localExpressions: [],
    financialCultureNote: '',
    humorStyle: '',
  );
}

/// Service that maps a canton to regional voice flavor.
///
/// Pure static methods — no state, no I/O.
class RegionalVoiceService {
  RegionalVoiceService._();

  // ── Canton → Region mapping ────────────────────────────────

  /// Cantons in Suisse romande.
  static const _romandCantons = {'VD', 'GE', 'NE', 'JU', 'VS', 'FR'};

  /// Cantons in Deutschschweiz.
  static const _deutschschweizCantons = {
    'ZH', 'BE', 'LU', 'ZG', 'AG', 'SG', 'BS', 'BL', 'SO', //
    'TG', 'SH', 'AI', 'AR', 'GL', 'NW', 'OW', 'SZ', 'UR',
  };

  /// Cantons in Svizzera italiana.
  static const _italianaCantons = {'TI', 'GR'};

  /// Resolve region from canton code (2-letter uppercase).
  static SwissRegion regionForCanton(String? canton) {
    if (canton == null || canton.isEmpty) return SwissRegion.unknown;
    final upper = canton.toUpperCase().trim();
    if (_romandCantons.contains(upper)) return SwissRegion.romande;
    if (_deutschschweizCantons.contains(upper)) return SwissRegion.deutschschweiz;
    if (_italianaCantons.contains(upper)) return SwissRegion.italiana;
    return SwissRegion.unknown;
  }

  // ── Public API ─────────────────────────────────────────────

  /// Get regional voice flavor based on user's canton.
  ///
  /// Returns [RegionalFlavor.empty] for unknown/null cantons.
  static RegionalFlavor forCanton(String? canton) {
    final region = regionForCanton(canton);
    final cantonUpper =
        (canton ?? '').toUpperCase().trim();

    switch (region) {
      case SwissRegion.romande:
        return _buildRomande(cantonUpper);
      case SwissRegion.deutschschweiz:
        return _buildDeutschschweiz(cantonUpper);
      case SwissRegion.italiana:
        return _buildItaliana(cantonUpper);
      case SwissRegion.unknown:
        return RegionalFlavor.empty;
    }
  }

  // ── Romande ────────────────────────────────────────────────

  static RegionalFlavor _buildRomande(String canton) {
    final cantonNote = _romandeCantonNote(canton);

    return RegionalFlavor(
      region: SwissRegion.romande,
      promptAddition: 'COULEUR R\u00c9GIONALE (Suisse romande)\u00a0:\n'
          'Tu parles \u00e0 quelqu\u2019un de Suisse romande. '
          'Utilise naturellement \u00ab\u00a0septante\u00a0\u00bb et '
          '\u00ab\u00a0nonante\u00a0\u00bb (jamais soixante-dix ou quatre-vingt-dix). '
          'Tu peux glisser un \u00ab\u00a0c\u2019est un peu le chenit\u00a0\u00bb '
          'quand les finances sont compliqu\u00e9es, ou un '
          '\u00ab\u00a0on va pas en faire tout un fromage\u00a0\u00bb pour '
          'd\u00e9dramatiser. Le rapport \u00e0 l\u2019argent est pragmatique '
          'mais pas obsessionnel \u2014 on en parle plus librement qu\u2019outre-Sarine, '
          'mais sans \u00e9talage. '
          'Le r\u00f6stigraben, c\u2019est pas qu\u2019une blague\u00a0: '
          'ici on pr\u00e9f\u00e8re un bon mot \u00e0 un Powerpoint.'
          '${cantonNote.isNotEmpty ? "\n$cantonNote" : ""}',
      localExpressions: const [
        'septante',
        'nonante',
        'huitante',
        'le chenit',
        'cornet',
        'natel',
        'panosse',
        'on va pas en faire tout un fromage',
        'd\u00e9cailler', // payer (argot romand)
        'ça joue',
        'adieu', // salutation informelle
        'action', // promo en magasin
      ],
      financialCultureNote:
          'Les Romands ont un rapport pragmatique \u00e0 l\u2019argent\u00a0: '
          'moins tabou qu\u2019outre-Sarine, mais discret. '
          'Le 3a est r\u00e9pandu mais pas sacralis\u00e9. '
          'L\u2019immobilier reste le placement de c\u0153ur. '
          'La pr\u00e9voyance est un sujet de conversation '
          'qu\u2019on aborde volontiers autour d\u2019une raclette.',
      humorStyle:
          'Autodérision, litote, understatement. '
          'Prendre une r\u00e9alit\u00e9 bureaucratique et la constater '
          'avec calme. L\u2019esprit na\u00eet de l\u2019observation, '
          'pas de la blague. Ton Kucholl & Veillon, pas ton Gad Elmaleh.',
      cantonNote: cantonNote,
    );
  }

  static String _romandeCantonNote(String canton) {
    switch (canton) {
      case 'VS':
        return 'Canton\u00a0: Valais. Tu peux \u00eatre un peu plus direct, '
            'montagnard, \u00e9conome dans tes mots comme dans tes conseils. '
            'Le Valaisan ne tourne pas autour du pot \u2014 et il conna\u00eet '
            'la valeur d\u2019un franc. R\u00e9f\u00e9rence\u00a0: '
            'le fendant est un \u00e9tat d\u2019esprit.';
      case 'GE':
        return 'Canton\u00a0: Gen\u00e8ve. Un peu plus cosmopolite, '
            'international. Ici on c\u00f4toie l\u2019ONU et les banques priv\u00e9es '
            'au m\u00eame carrefour. Le Genevois est urbain, '
            'habitu\u00e9 \u00e0 la complexit\u00e9 fiscale (transfrontaliers, '
            'fonctionnaires internationaux). Tu peux \u00eatre un poil '
            'plus sophistiqu\u00e9 dans le vocabulaire.';
      case 'VD':
        return 'Canton\u00a0: Vaud. D\u00e9tendu, mod\u00e9r\u00e9, '
            'entre lac et vignoble. Le Vaudois prend son temps '
            'mais fait les choses bien. \u00ab\u00a0Huitante\u00a0\u00bb '
            'est une fiert\u00e9 locale. Le rapport \u00e0 l\u2019argent '
            'est d\u00e9contract\u00e9 \u2014 ni stress, ni indiff\u00e9rence.';
      case 'NE':
        return 'Canton\u00a0: Neuch\u00e2tel. Terre d\u2019horlogerie '
            'et de pr\u00e9cision. L\u2019esprit est vif, '
            'le ton peut \u00eatre un rien plus pince-sans-rire. '
            'Ici on appr\u00e9cie qu\u2019on aille droit au but.';
      case 'JU':
        return 'Canton\u00a0: Jura. Le plus jeune canton, '
            'fier de son ind\u00e9pendance. Un esprit franc, '
            'communautaire, pas d\u2019embrouille. '
            'La simplicit\u00e9 est une valeur.';
      case 'FR':
        return 'Canton\u00a0: Fribourg. \u00c0 cheval sur le r\u00f6stigraben, '
            'bilingue de c\u0153ur. Le Fribourgeois navigue entre '
            'deux cultures avec naturel. Tu peux glisser '
            'un clin d\u2019\u0153il \u00e0 cette dualit\u00e9.';
      default:
        return '';
    }
  }

  // ── Deutschschweiz ─────────────────────────────────────────

  static RegionalFlavor _buildDeutschschweiz(String canton) {
    final cantonNote = _deutschschweizCantonNote(canton);

    return RegionalFlavor(
      region: SwissRegion.deutschschweiz,
      promptAddition: 'REGIONALE F\u00c4RBUNG (Deutschschweiz)\u00a0:\n'
          'Du sprichst mit jemandem aus der Deutschschweiz. '
          'Du darfst subtil Schweizer Ausdr\u00fccke einstreuen\u00a0: '
          '\u00ab\u00a0das isch es Bitzeli kompliziert\u00a0\u00bb statt '
          '\u00ab\u00a0ein wenig\u00a0\u00bb, oder '
          '\u00ab\u00a0Feierabend machen\u00a0\u00bb wenn es ums Budget geht. '
          'Die Sparkultur ist hier tief verankert \u2014 der 3.\u00a0S\u00e4ule '
          'fast schon eine Pflicht, der Bausparvertrag ein Familienritual. '
          'Der Ton bleibt sachlich, aber nie kalt. '
          'Hier sch\u00e4tzt man Zuverl\u00e4ssigkeit mehr als '
          'sch\u00f6ne Worte \u2014 die Zahlen sollen f\u00fcr sich sprechen.'
          '${cantonNote.isNotEmpty ? "\n$cantonNote" : ""}',
      localExpressions: const [
        'es Bitzeli',
        'Feierabend',
        'Zn\u00fcni',
        'Zvieri',
        'grillieren', // vs barbecue
        'parkieren', // vs parquer
        'Sackgeld', // argent de poche
        'Steuern sparen', // le mantra
        '\u00e7a joue', // le seul romandisme qui passe le R\u00f6stigraben
        'gopfertami', // frustration mesur\u00e9e
        'Schaffe, schaffe, H\u00fcsli baue', // travailler, construire sa maison
      ],
      financialCultureNote:
          'L\u2019\u00e9pargne est quasi sacr\u00e9e en Suisse al\u00e9manique. '
          'Le 3a est un r\u00e9flexe \u2014 on cotise d\u00e8s le premier salaire. '
          'L\u2019acc\u00e8s \u00e0 la propri\u00e9t\u00e9 (Eigenheim) est un objectif '
          'de vie majeur. Les imp\u00f4ts sont un sujet technique, '
          'pas \u00e9motionnel \u2014 on optimise, on ne se plaint pas. '
          'L\u2019Ordnung s\u2019applique aussi aux finances\u00a0: '
          'classeurs \u00e9tiquet\u00e9s, certificats \u00e0 jour, planification sereine.',
      humorStyle:
          'Sec, pratique, jamais gratuit. L\u2019humour al\u00e9manique vient '
          'du d\u00e9calage entre la m\u00e9ticulosit\u00e9 et l\u2019absurdit\u00e9 '
          'du quotidien. Un \u00ab\u00a0gopfertami\u00a0\u00bb bien plac\u00e9 '
          'vaut mieux qu\u2019un long discours. Ton SRF, pas ton RTL.',
      cantonNote: cantonNote,
    );
  }

  static String _deutschschweizCantonNote(String canton) {
    switch (canton) {
      case 'ZH':
        return 'Kanton\u00a0: Z\u00fcrich. Urbain, finance-savvy, '
            'Paradeplatz oblige. Le Zurichois est pragmatique, '
            'connect\u00e9, habitu\u00e9 aux discussions financi\u00e8res. '
            'Tu peux \u00eatre un peu plus technique sans perdre personne.';
      case 'BE':
        return 'Kanton\u00a0: Bern. Gem\u00fctlich, pos\u00e9, '
            'jamais press\u00e9. Le Bernois r\u00e9fl\u00e9chit avant '
            'd\u2019agir \u2014 et c\u2019est une qualit\u00e9 '
            'pour les d\u00e9cisions financi\u00e8res. '
            'Le B\u00e4rndeutsch, c\u2019est un \u00e9tat d\u2019esprit.';
      case 'LU':
        return 'Kanton\u00a0: Luzern. Entre tradition et modernit\u00e9, '
            'le Lucernois est attach\u00e9 \u00e0 ses racines mais '
            'regarde vers l\u2019avant. Pilatus et pragmatisme.';
      case 'ZG':
        return 'Kanton\u00a0: Zug. La Crypto Valley, le paradis fiscal '
            'qui ne dit pas son nom. Le Zougois conna\u00eet '
            'la valeur de l\u2019optimisation \u2014 tu peux \u00eatre '
            'un brin plus pointu sur la fiscalit\u00e9.';
      case 'BS':
        return 'Kanton\u00a0: Basel-Stadt. Fasnacht, pharma, culture. '
            'Le B\u00e2lois a un esprit vif, une fiert\u00e9 locale '
            'marqu\u00e9e, et un rapport d\u00e9complex\u00e9 '
            'avec les grandes fortunes \u2014 c\u2019est la ville '
            'des fondations et du m\u00e9c\u00e9nat.';
      case 'SG':
        return 'Kanton\u00a0: St.\u00a0Gallen. Ville textile devenue '
            'p\u00f4le universitaire. Pragmatique, travailleurs, '
            'l\u2019Ostschweiz a les pieds sur terre.';
      case 'AG':
        return 'Kanton\u00a0: Aargau. Le canton des navetteurs \u2014 '
            'entre Z\u00fcrich, B\u00e2le et Berne, l\u2019Argovien '
            'optimise ses trajets comme ses imp\u00f4ts.';
      case 'BL':
        return 'Kanton\u00a0: Basel-Landschaft. Baselbieter '
            'Eigenst\u00e4ndigkeit, Kirschbl\u00fcte im Fr\u00fchling, '
            'Regio-Identit\u00e4t. Le Balbiennois a sa fiert\u00e9 propre '
            '\u2014 ni B\u00e2le-Ville, ni Argovie.';
      default:
        return '';
    }
  }

  // ── Italiana ───────────────────────────────────────────────

  static RegionalFlavor _buildItaliana(String canton) {
    final cantonNote = _italianaCantonNote(canton);

    return RegionalFlavor(
      region: SwissRegion.italiana,
      promptAddition: 'COLORE REGIONALE (Svizzera italiana)\u00a0:\n'
          'Parli con qualcuno della Svizzera italiana. '
          'Puoi usare un tono un po\u2019 pi\u00f9 caldo, '
          'mediterraneo ma preciso \u2014 '
          '\u00ab\u00a0come al grotto, semplice ma sostanzioso\u00a0\u00bb '
          'per descrivere un piano finanziario. '
          'Il rapporto con il risparmio \u00e8 familiare\u00a0: '
          'si risparmia per i figli, per la casa, per il futuro '
          'della famiglia. Il rigore svizzero con il calore del sud. '
          'Qui non si butta via niente \u2014 n\u00e9 il denaro, n\u00e9 le parole.'
          '${cantonNote.isNotEmpty ? "\n$cantonNote" : ""}',
      localExpressions: const [
        'grotto',
        'polenta',
        'ticinese',
        'il Ceresio', // Lac de Lugano
        'la Verzasca',
        'castagne', // ch\u00e2taignes — tradition automnale
        'giro al mercato', // march\u00e9 du samedi
        'cassa pensione', // 2e pilier en italien
        'risparmio', // \u00e9pargne
        'piano, piano', // doucement, \u00e9tape par \u00e9tape
      ],
      financialCultureNote:
          'La culture financi\u00e8re tessinoise m\u00eale rigueur suisse '
          'et valeurs familiales italiennes. '
          'L\u2019immobilier est roi \u2014 la casa di famiglia '
          'est un pilier patrimonial autant qu\u2019\u00e9motionnel. '
          'Le travail frontalier avec l\u2019Italie cr\u00e9e des situations '
          'fiscales particuli\u00e8res. '
          'L\u2019\u00e9pargne est une affaire de famille, '
          'transmise de g\u00e9n\u00e9ration en g\u00e9n\u00e9ration.',
      humorStyle:
          'Chaleureux, convivial, jamais cynique. '
          'L\u2019humour tessinois vient de la chaleur humaine '
          'et du contraste entre la dolce vita et la pr\u00e9cision '
          'helv\u00e9tique. Un \u00ab\u00a0piano, piano\u00a0\u00bb '
          'bien plac\u00e9, un clin d\u2019\u0153il au soleil '
          'quand le reste de la Suisse est sous la grisaille. '
          'Ton RSI, pas ton Mediaset.',
      cantonNote: cantonNote,
    );
  }

  static String _italianaCantonNote(String canton) {
    switch (canton) {
      case 'TI':
        return 'Cantone\u00a0: Ticino. Il lato soleggiato della Svizzera. '
            'Lugano, Locarno, la vita sul lago. '
            'Le Tessinois jongle entre identit\u00e9 italophone forte '
            'et fiert\u00e9 suisse. Le frontalier italien fait partie '
            'du paysage \u2014 et de la complexit\u00e9 fiscale locale.';
      case 'GR':
        return 'Cantone\u00a0: Grigioni. Canton trilingue '
            '(allemand, italien, romanche) \u2014 une richesse unique. '
            'La partie italophone (Mesolcina, Poschiavo, Bregaglia) '
            'partage la culture tessinoise avec '
            'une touche alpine en plus.';
      default:
        return '';
    }
  }
}
