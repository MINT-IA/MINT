/// Rich educational content for each topic in the "J'y comprends rien" hub.
/// Each topic has a chiffre choc, explanation, key facts, quiz, fun fact,
/// legal sources, and a compliance disclaimer.
class EducationTopicContent {
  final String chiffreChoc;
  final String chiffreChocUnit;
  final String chiffreChocLabel;
  final String intro;
  final List<String> keyFacts;
  final QuizQuestion quiz;
  final String funFact;
  final List<String> sources;

  const EducationTopicContent({
    required this.chiffreChoc,
    required this.chiffreChocUnit,
    required this.chiffreChocLabel,
    required this.intro,
    required this.keyFacts,
    required this.quiz,
    required this.funFact,
    required this.sources,
  });

  static const String disclaimer =
      'Contenu a visee pedagogique. Ne constitue pas un conseil financier, '
      'fiscal ou juridique (LSFin). Consulte un\u00b7e specialiste pour ta situation.';
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class EducationContentData {
  static EducationTopicContent? getContent(String themeId) {
    return _content[themeId];
  }

  static const Map<String, EducationTopicContent> _content = {
    // ─── 3a : Le 3e pilier ───
    '3a': EducationTopicContent(
      chiffreChoc: "7'258",
      chiffreChocUnit: 'CHF/an',
      chiffreChocLabel: 'Plafond annuel 3a pour un\u00b7e salarie\u00b7e affilie\u00b7e LPP',
      intro:
          'Le 3e pilier (3a) est un compte epargne retraite qui te permet de '
          'reduire tes impots chaque annee. Chaque franc verse est deduit de '
          'ton revenu imposable. C\'est le reflexe financier n\u00b01 en Suisse.',
      keyFacts: [
        'Compte bloque jusqu\'a la retraite (sauf achat immobilier, depart de Suisse, ou activite independante)',
        'Chaque franc verse reduit directement ton revenu imposable',
        'Economie fiscale typique : 1\'000 a 2\'500 CHF/an selon ton canton et ton revenu',
        'Independant\u00b7e sans LPP : plafond majore a 36\'288 CHF/an (20% du revenu net)',
        'Ouvrir plusieurs comptes 3a permet d\'echelonner les retraits et reduire l\'impot au retrait',
      ],
      quiz: QuizQuestion(
        question:
            'Quel est le plafond annuel 3a pour un\u00b7e salarie\u00b7e affilie\u00b7e LPP ?',
        options: ['5\'000 CHF', '7\'258 CHF', '10\'000 CHF', '36\'288 CHF'],
        correctIndex: 1,
        explanation:
            'Le plafond 2025 est de 7\'258 CHF/an pour les salarie\u00b7es '
            'affilie\u00b7es a une caisse de pension (LPP). Le montant de '
            '36\'288 CHF concerne les independant\u00b7es sans LPP (OPP3 art. 7).',
      ),
      funFact:
          'Si tu verses 7\'258 CHF/an des 25 ans avec un rendement moyen de '
          '3%, tu accumuleras environ 550\'000 CHF a 65 ans. Sans rien faire '
          'de plus que ce virement annuel.',
      sources: [
        'OPP3 art. 7 (Plafond annuel 3a)',
        'LIFD art. 33 al. 1 let. e (Deduction fiscale 3a)',
        'OPP3 art. 3 (Conditions de retrait)',
        'LIFD art. 38 (Imposition des prestations en capital)',
      ],
    ),

    // ─── LPP : La caisse de pension ───
    'lpp': EducationTopicContent(
      chiffreChoc: '50%',
      chiffreChocUnit: 'minimum',
      chiffreChocLabel:
          'Part payee par ton employeur sur tes cotisations LPP',
      intro:
          'La caisse de pension (LPP, 2e pilier) est ta retraite '
          'professionnelle. Ton employeur paie au minimum la moitie de tes '
          'cotisations — c\'est de l\'argent qui s\'accumule pour toi sans '
          'effort.',
      keyFacts: [
        'Obligatoire des 22\'680 CHF/an de salaire (LPP art. 7)',
        'Ton employeur cotise au minimum 50% — c\'est un complement de salaire invisible',
        'Taux de conversion minimum : 6.8% (100\'000 CHF de capital = 6\'800 CHF de rente/an)',
        'Tu peux racheter des annees manquantes et deduire chaque franc de tes impots',
        'Ton avoir LPP peut servir d\'apport pour un achat immobilier (EPL, LPP art. 30c)',
      ],
      quiz: QuizQuestion(
        question: 'Qui paie tes cotisations LPP ?',
        options: [
          'Toi seul\u00b7e',
          'Ton employeur seul',
          'Toi et ton employeur (min 50/50)',
          'L\'Etat',
        ],
        correctIndex: 2,
        explanation:
            'Les cotisations LPP sont partagees : ton employeur paie au '
            'minimum 50%, souvent plus. Certains employeurs genereux couvrent '
            'jusqu\'a 60-70% des cotisations. Verifie ton certificat de '
            'prevoyance.',
      ),
      funFact:
          'La deduction de coordination (26\'460 CHF) fait que si tu gagnes '
          'moins de 22\'680 CHF/an, tu n\'es pas assure\u00b7e LPP. '
          'C\'est le "trou" du 2e pilier qui touche les temps partiels.',
      sources: [
        'LPP art. 7 (Seuil d\'acces)',
        'LPP art. 8 (Deduction de coordination)',
        'LPP art. 14 (Taux de conversion minimum 6.8%)',
        'LPP art. 79b (Rachat de prestations)',
        'LPP art. 30c (Encouragement a la propriete, EPL)',
      ],
    ),

    // ─── AVS : Les lacunes ───
    'avs': EducationTopicContent(
      chiffreChoc: '2.3%',
      chiffreChocUnit: 'de rente en moins',
      chiffreChocLabel:
          'Reduction de ta rente AVS pour chaque annee de cotisation manquante',
      intro:
          'L\'AVS (1er pilier) est la base de ta retraite. Chaque annee ou '
          'tu n\'as pas cotise cree une lacune qui reduit ta rente — a vie. '
          'Bonne nouvelle : tu peux verifier et rattraper certaines lacunes.',
      keyFacts: [
        'Cotisation obligatoire des 18 ans (des le premier emploi)',
        'Rente maximale individuelle : 30\'240 CHF/an (pour 44 annees completes)',
        'Annees a l\'etranger = lacunes potentielles (sauf accords bilateraux UE/AELE)',
        'Tu peux racheter les 5 dernieres annees manquantes aupres de ta caisse de compensation',
        'Commander ton extrait de compte AVS : gratuit sur ahv-iv.ch',
      ],
      quiz: QuizQuestion(
        question:
            'Combien d\'annees de cotisation faut-il pour la rente AVS maximale ?',
        options: ['30 ans', '40 ans', '44 ans', '50 ans'],
        correctIndex: 2,
        explanation:
            '44 annees completes de cotisation sont necessaires pour la rente '
            'maximale (LAVS art. 29). De 21 a 65 ans = 44 ans. Une seule '
            'annee manquante = rente reduite a vie.',
      ),
      funFact:
          '44 annees de cotisation completes sont necessaires pour la rente '
          'maximale. Une seule annee manquante la reduit definitivement. '
          'Verifie ton extrait — ca prend 5 minutes en ligne.',
      sources: [
        'LAVS art. 29 (Duree de cotisation)',
        'LAVS art. 30 (Calcul de la rente)',
        'LAVS art. 3 (Personnes assujetties)',
        'RAVS art. 52b (Extrait de compte individuel)',
      ],
    ),

    // ─── Emergency : Le fonds d'urgence ───
    'emergency': EducationTopicContent(
      chiffreChoc: '3 a 6',
      chiffreChocUnit: 'mois',
      chiffreChocLabel:
          'D\'epargne de securite recommandee (charges mensuelles)',
      intro:
          'Le fonds d\'urgence, c\'est ton filet de securite. Si tu perds ton '
          'emploi, si ta voiture lache, si une facture imprevue tombe : tu as '
          'de quoi tenir sans stress. C\'est la base avant tout investissement.',
      keyFacts: [
        'Calcul : charges mensuelles x 3 (minimum) a 6 (confort)',
        'Sur un compte separe, accessible en 24-48h (pas investi, pas bloque)',
        'L\'assurance chomage ne couvre que 70-80% du salaire, avec un delai de carence',
        'Independant\u00b7e ? Vise plutot 6 a 9 mois (pas de chomage, pas d\'IJM)',
        'Astuce : automatise un virement le 1er du mois, meme 100 CHF',
      ],
      quiz: QuizQuestion(
        question:
            'Pourquoi ne faut-il PAS investir son fonds d\'urgence ?',
        options: [
          'Parce que c\'est interdit',
          'Parce qu\'il doit etre disponible immediatement',
          'Parce que les rendements sont trop bas',
          'Parce que les banques refusent',
        ],
        correctIndex: 1,
        explanation:
            'Le fonds d\'urgence doit etre liquide, c\'est-a-dire '
            'accessible en 24-48h. Un investissement (actions, fonds, crypto) '
            'peut perdre de la valeur au moment ou tu en as besoin. '
            'Garde-le en compte epargne classique.',
      ),
      funFact:
          '43% des menages suisses ne pourraient pas couvrir une depense '
          'imprevue de 2\'500 CHF sans emprunter (OFS 2022). '
          'Constituer ton fonds d\'urgence te place dans la majorite qui dort tranquille.',
      sources: [
        'OFS Enquete sur le budget des menages 2022',
        'LACI art. 8 (Droit aux indemnites de chomage)',
        'Recommandations Budget-conseil Suisse',
      ],
    ),

    // ─── Debt : Les dettes ───
    'debt': EducationTopicContent(
      chiffreChoc: '9.9%',
      chiffreChocUnit: 'taux moyen',
      chiffreChocLabel:
          'Taux d\'interet moyen d\'un credit a la consommation en Suisse',
      intro:
          'Les dettes a la consommation (credit, leasing) sont les ennemies '
          'silencieuses de ton patrimoine. A 9.9% d\'interet, elles '
          'grossissent vite pendant que tu les oublies. Regle d\'or : '
          'rembourser avant d\'investir.',
      keyFacts: [
        'Un leasing auto de 30\'000 CHF coute environ 4\'500 CHF d\'interets sur 4 ans',
        'Regle d\'or : toujours rembourser les dettes a taux eleve AVANT d\'investir',
        'Les "petits credits" a 0% ont souvent des frais de dossier ou assurances obligatoires',
        'Le surendettement touche 18% des menages suisses (OFS)',
        'Des aides gratuites existent : Caritas, centres de desendettement cantonaux',
      ],
      quiz: QuizQuestion(
        question:
            'Que faut-il faire en priorite : rembourser une dette a 9% ou investir a 5% ?',
        options: [
          'Investir a 5%',
          'Rembourser la dette a 9%',
          'Faire les deux a parts egales',
          'Attendre que les taux baissent',
        ],
        correctIndex: 1,
        explanation:
            'Rembourser une dette a 9% equivaut a un rendement effectif de '
            '9% sans alea. Tres peu d\'investissements battent ca de facon fiable. '
            'Priorite absolue : eliminer les dettes couteuses, puis investir.',
      ),
      funFact:
          'A 9.9% d\'interet compose, une dette de 10\'000 CHF double en '
          'environ 7 ans si tu ne rembourses que le minimum. '
          '10\'000 CHF deviennent 20\'000 CHF — sans rien acheter de plus.',
      sources: [
        'LCC art. 14 (Taux d\'interet maximum, credit a la consommation)',
        'CO art. 312ss (Contrat de pret)',
        'OFS Statistique du surendettement en Suisse',
        'LCC art. 28-31 (Droit de revocation)',
      ],
    ),

    // ─── Mortgage : L'hypotheque ───
    'mortgage': EducationTopicContent(
      chiffreChoc: '5%',
      chiffreChocUnit: 'taux theorique',
      chiffreChocLabel:
          'Utilise par les banques pour calculer ta capacite d\'emprunt',
      intro:
          'En Suisse, les banques ne regardent pas le taux reel de ton '
          'hypotheque (1-2%) mais un taux theorique de 5%. C\'est ce "stress '
          'test" qui determine combien tu peux emprunter — et il est '
          'beaucoup plus strict que ce que tu imagines.',
      keyFacts: [
        'Apport minimum : 20% du prix (max 10% depuis le 2e pilier)',
        'Charges totales (interets + amortissement + frais) \u2264 1/3 du revenu brut',
        'SARON : taux variable (suit le marche), actuellement autour de 1.5%',
        'Taux fixe : verrouille sur 5-10 ans, plus cher mais previsible',
        'Valeur locative : tu es impose\u00b7e sur un loyer "fictif" de ton propre logement',
      ],
      quiz: QuizQuestion(
        question:
            'Quel pourcentage du revenu brut les charges hypothecaires ne doivent pas depasser ?',
        options: ['25%', '33% (1/3)', '40%', '50%'],
        correctIndex: 1,
        explanation:
            'La regle du tiers (33%) est la norme bancaire suisse (ASB). '
            'Les charges comprennent : interets au taux theorique de 5%, '
            '1% d\'amortissement, et 1% de frais accessoires. Tout cela '
            'calcule sur le revenu brut du menage.',
      ),
      funFact:
          'Avec le taux theorique de 5%, un couple gagnant 150\'000 CHF '
          'brut/an ne peut acheter qu\'un bien a environ 700\'000 CHF — '
          'alors qu\'avec le taux reel de 1.5%, il pourrait largement se le '
          'permettre. C\'est le paradoxe suisse.',
      sources: [
        'FINMA circ. 2017/7 (Normes minimales hypothecaires)',
        'ASB Directives relatives aux financements hypothecaires',
        'LPP art. 30c (EPL — retrait pour propriete)',
        'LIFD art. 21 al. 1 let. b (Valeur locative)',
      ],
    ),

    // ─── Budget : Le reste a vivre ───
    'budget': EducationTopicContent(
      chiffreChoc: '50/30/20',
      chiffreChocUnit: 'regle d\'or',
      chiffreChocLabel:
          '50% charges fixes, 30% envies, 20% epargne',
      intro:
          'Le reste a vivre, c\'est ce qui te reste apres les charges fixes '
          '(loyer, assurances, impots). Connaitre ce chiffre, c\'est '
          'reprendre le controle. La regle 50/30/20 est un repere simple '
          'pour structurer ton budget.',
      keyFacts: [
        'Reste a vivre = revenu net \u2212 charges fixes (loyer, LAMal, impots, transports)',
        'En Suisse, le loyer represente en moyenne 33% du budget d\'un menage',
        'Les impots ne sont pas preleves a la source pour les citoyen\u00b7nes et permis C',
        'Astuce : automatise un virement epargne le 1er du mois — paie-toi en premier',
        'L\'OFS estime les charges fixes moyennes d\'un menage suisse a 5\'200 CHF/mois',
      ],
      quiz: QuizQuestion(
        question:
            'Quel est le premier poste de depenses d\'un menage suisse ?',
        options: [
          'L\'alimentation',
          'Le logement',
          'Les impots',
          'Les assurances',
        ],
        correctIndex: 1,
        explanation:
            'Le logement (loyer ou charges hypothecaires) represente en '
            'moyenne 33% du budget d\'un menage suisse, soit le premier '
            'poste de depenses. Les impots arrivent en 2e position dans '
            'la plupart des cantons.',
      ),
      funFact:
          'Un cafe par jour a 5.50 CHF = 2\'007 CHF/an. Investi a 5% '
          'pendant 30 ans, ca ferait environ 140\'000 CHF. On ne te dit '
          'pas d\'arreter le cafe — juste de connaitre le vrai cout.',
      sources: [
        'OFS Enquete sur le budget des menages 2022',
        'LIFD art. 25-33 (Deductions generales)',
        'Budget-conseil Suisse (recommandations budgetaires)',
      ],
    ),

    // ─── LAMal : Les subsides ───
    // ─── Fiscal : La fiscalité suisse ───
    'fiscal': EducationTopicContent(
      chiffreChoc: '~35%',
      chiffreChocUnit: 'du revenu',
      chiffreChocLabel:
          'Pression fiscale moyenne en Suisse (federal + cantonal + communal)',
      intro:
          'En Suisse, tu payes des impots a 3 niveaux : federal, cantonal et '
          'communal. Le taux varie enormement selon ton canton, ta commune et '
          'ta situation familiale. Bonne nouvelle : il existe de nombreuses '
          'deductions legales pour reduire ta facture fiscale.',
      keyFacts: [
        'L\'impot federal est le meme partout (max ~11.5%), mais cantonal et communal varient enormement',
        'Le versement 3a est la deduction la plus rentable : jusqu\'a 7\'258 CHF deductibles (2025)',
        'Le rachat LPP est 100% deductible du revenu imposable (LPP art. 79b)',
        'Les frais effectifs (trajets, repas, formation) peuvent depasser le forfait',
        'Un demenagement dans un canton fiscalement avantageux peut faire economiser des milliers de CHF/an',
      ],
      quiz: QuizQuestion(
        question:
            'Combien peux-tu deduire de tes impots avec un versement 3a en 2025 ?',
        options: [
          '5\'000 CHF',
          '6\'883 CHF',
          '7\'258 CHF',
          '10\'000 CHF',
        ],
        correctIndex: 2,
        explanation:
            'Le plafond 3a pour un salarie avec LPP est de 7\'258 CHF en 2025 '
            '(OPP3 art. 7). C\'est la deduction fiscale la plus simple et la '
            'plus efficace a mettre en place.',
      ),
      funFact:
          'Un couple avec deux revenus a Zoug paie environ 4 fois moins d\'impots '
          'qu\'un couple identique a Geneve. La concurrence fiscale entre cantons '
          'est unique au monde.',
      sources: [
        'LIFD art. 33 (Deductions generales)',
        'LIFD art. 82 (Deduction 3a)',
        'LPP art. 79b (Rachat LPP)',
        'LHID art. 9 (Harmonisation des deductions cantonales)',
        'OPP3 art. 7 (Plafond 3a)',
      ],
    ),

    'lamal': EducationTopicContent(
      chiffreChoc: '~350',
      chiffreChocUnit: 'CHF/mois',
      chiffreChocLabel:
          'Prime moyenne LAMal en Suisse pour un adulte (franchise 300)',
      intro:
          'L\'assurance maladie (LAMal) est obligatoire en Suisse, mais les '
          'primes varient du simple au double selon le canton et la caisse. '
          'Choisir la bonne franchise et verifier ton droit aux subsides '
          'peut te faire economiser des centaines de francs par an.',
      keyFacts: [
        'Les primes varient enormement selon le canton (GE et BS sont les plus chers)',
        'Franchise 300 vs 2\'500 : economie de prime d\'environ 1\'500 CHF/an, mais risque accru',
        'Subsides disponibles dans tous les cantons — criteres de revenu variables',
        'Delai pour changer de caisse : 30 novembre de chaque annee',
        'Les modeles alternatifs (medecin de famille, HMO, telmed) offrent 10-20% de reduction',
      ],
      quiz: QuizQuestion(
        question:
            'A quelle date limite peux-tu changer de caisse maladie pour l\'annee suivante ?',
        options: [
          '31 octobre',
          '30 novembre',
          '31 decembre',
          '1er janvier',
        ],
        correctIndex: 1,
        explanation:
            'La date limite est le 30 novembre. Ta nouvelle caisse doit '
            'avoir recu ta demande avant cette date. Astuce : les primes '
            'sont annoncees fin septembre — compare des octobre.',
      ),
      funFact:
          'En passant de la franchise 300 a 2\'500, tu economises '
          'environ 1\'500 CHF/an de primes. Mais une seule hospitalisation '
          'peut te couter 2\'200 CHF de plus. Le bon choix depend de ta '
          'sante et de ton epargne disponible.',
      sources: [
        'LAMal art. 61-65 (Primes et subsides)',
        'LAMal art. 62 (Participation aux couts, franchises)',
        'OFS Statistique de l\'assurance-maladie obligatoire',
        'OFSP Primes de reference par canton',
      ],
    ),
  };
}
