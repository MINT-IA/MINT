// GENERATED — Batch21 R3 (ÉCLAIRAGE arc) runtime catalog for the hidden design
// lab. Mirrors product/mint_next/batch21/r3-six-locale-copy.yaml (semantic copy,
// 6 locales) and product/mint_next/batch21/r3-engine-fixtures.yaml (every number
// engine-derived, 0-trust). Two screens: fact_revenu (taxable-income band) and
// eclairage_impot_3a (the payoff range). The design lab is offline and
// fixture-bound; it NEVER re-implements the fiscal engine (NEVER#3), it only
// renders the sealed engine-derived fixtures.
//
// GAP-FILLS (documented, not in the sealed copy): three keys the sealed copy
// does not provide but the sheets/badges require —
//   * gloss_dismiss    : the glossary-sheet dismiss label. Reuses batch20's
//                        accepted fact_lieu catalog values verbatim.
//   * provenance_exact : the "exact" provenance badge on a refined revenu row
//                        (precision_refined state, cf. mockup eclairage_5_refined).
//   * eclairage_amount_open : open-topped rendering for the gt150 band whose
//                        fixture upper edge is null (saving_high: null).
// These are surfaced to the lead for reconciliation with the sealed copy.
//
// Do not edit by hand.

const String r3CopySourceRef =
    'product/mint_next/batch21/r3-six-locale-copy.yaml';
const String r3FixturesSourceRef =
    'product/mint_next/batch21/r3-engine-fixtures.yaml';

// ---------------------------------------------------------------------------
// COPY — 6 locales, keyed exactly by the sealed copy keys (plus the three
// documented gap-fills). Accents are locale-correct and byte-faithful to the
// sealed source.
// ---------------------------------------------------------------------------
const Map<String, Map<String, String>> r3Copy = <String, Map<String, String>>{
  'fr': <String, String>{
    // fact_revenu
    'fact_revenu_eyebrow': 'Simulation 3a · {taxYear}',
    'fact_revenu_question': 'Ton revenu imposable, c’est combien à peu près ?',
    'fact_revenu_band_lt30': 'Moins de 30 000',
    'fact_revenu_band_30_50': '30 000 – 50 000',
    'fact_revenu_band_50_70': '50 000 – 70 000',
    'fact_revenu_band_70_100': '70 000 – 100 000',
    'fact_revenu_band_100_150': '100 000 – 150 000',
    'fact_revenu_band_gt150': 'Plus de 150 000',
    'fact_revenu_unit_hint': 'en francs par an',
    'fact_revenu_help_link': 'Où trouver mon revenu imposable ?',
    'fact_revenu_selection_label': 'Ton choix',
    'fact_revenu_selection_none': 'Tu n’as pas encore choisi de tranche.',
    'fact_revenu_selection_selected': '{band} CHF',
    'fact_revenu_change': 'Modifier',
    'fact_revenu_continue': 'Continuer',
    'fact_revenu_back': 'Retour',
    'fact_revenu_error_no_selection': 'Choisis une tranche pour continuer.',
    'fact_revenu_gloss_imposable_term': 'revenu imposable',
    'fact_revenu_gloss_imposable_def':
        'C’est le montant qui reste après les déductions et sur lequel ton impôt est calculé. Tu le trouves sur ta dernière taxation.',
    'fact_revenu_gloss_imposable_metaphor':
        'Le fisc ne taxe pas directement ton salaire : il part de ton revenu imposable.',
    'fact_revenu_gloss_brut_term': 'brut',
    'fact_revenu_gloss_brut_def':
        'Ton salaire brut, c’est avant les cotisations et l’impôt. Ton revenu imposable est plus bas : pars plutôt de ta taxation.',
    // eclairage
    'eclairage_eyebrow': 'Simulation 3a · {taxYear}',
    'eclairage_mechanism':
        'Un versement 3a se déduit de ton revenu imposable. Ton impôt de l’année peut alors baisser.',
    'eclairage_amount': '{low} à {high} CHF',
    'eclairage_amount_caption':
        'd’impôt en moins cette année, d’après notre estimation.',
    'eclairage_hyp_label': 'Cette estimation part de :',
    'eclairage_hyp_revenu': 'Revenu imposable · {band} CHF',
    'eclairage_hyp_versement': 'Versement 3a · {versement} CHF',
    'eclairage_hyp_situation': 'Situation · célibataire',
    'eclairage_refine_situation': 'Préciser mon état civil',
    'eclairage_hyp_lieu': 'Impôts · {commune} ({canton})',
    'eclairage_hyp_edit_hint': 'Tu peux modifier chaque ligne.',
    'eclairage_assumptions':
        'On suppose aussi : sans enfant, hors impôt d’Église, imposé ordinairement.',
    'eclairage_disclaimer':
        'C’est une estimation, pas un conseil fiscal. Le montant exact figure sur ta taxation.',
    'eclairage_continue': 'Continuer',
    'eclairage_back': 'Retour',
    'eclairage_pending_title': 'Il manque ton revenu imposable.',
    'eclairage_pending_revenu': 'Choisis d’abord ta tranche de revenu.',
    'eclairage_pending_action': 'Choisir ma tranche',
    'eclairage_zero_income':
        'Sous 30 000 CHF, l’effet fiscal d’un versement 3a est souvent faible cette année.',
    'eclairage_gloss_deduction_term': 'déduction',
    'eclairage_gloss_deduction_def':
        'Un montant qu’on retire de ton revenu imposable. Moins de revenu imposable, moins d’impôt.',
    'eclairage_gloss_deduction_metaphor':
        'Ce que tu verses sur ton 3a, l’impôt ne le compte plus.',
    'eclairage_gloss_3a_term': '3a',
    'eclairage_gloss_3a_def':
        'Le pilier 3a est une épargne liée. Tes versements peuvent être déduits de ton revenu imposable, jusqu’à la limite annuelle.',
    'eclairage_gloss_versement_term': 'versement 3a',
    'eclairage_gloss_versement_def':
        'C’est ce que tu as versé sur ton 3a cette année. Ici, le calcul part de la limite annuelle. Touche la ligne pour changer le montant.',
    'eclairage_gloss_ordinaire_term': 'imposé ordinairement',
    'eclairage_gloss_ordinaire_def':
        'Ton impôt est calculé sur ta déclaration. Si tu es imposé à la source — souvent avec un permis B ou comme frontalier — la déduction 3a peut fonctionner autrement. Vérifie ce qui vaut pour toi.',
    'eclairage_na_title': 'On ne peut pas estimer ton économie ici.',
    'eclairage_na_body':
        'Imposé à la source, tu ne peux en général pas déduire ton 3a de la même façon. Une taxation ordinaire est parfois possible — vérifie ta situation.',
    'eclairage_na_action': 'Pourquoi ?',
    'eclairage_situation_celibataire': 'Célibataire',
    'eclairage_situation_marie': 'Marié·e ou pacsé·e',
    'eclairage_situation_concubinage': 'En couple, non marié·e',
    'eclairage_refine_hint': 'Un chiffre exact resserre l’estimation.',
    'eclairage_amount_caption_refined':
        'd’impôt en moins cette année, d’après ton chiffre.',
    'eclairage_exact_revenu_title': 'Ton revenu imposable exact',
    'eclairage_exact_revenu_placeholder': 'p. ex. 85 000',
    'eclairage_exact_revenu_note':
        'Pas besoin d’un chiffre exact. Si tu l’as, il resserre l’estimation.',
    'eclairage_exact_save': 'Utiliser ce chiffre',
    // gap-fills
    'gloss_dismiss': 'Compris',
    'provenance_exact': 'exact',
    'eclairage_amount_open': '{low} CHF et plus',
  },
  'en': <String, String>{
    'fact_revenu_eyebrow': '3a simulation · {taxYear}',
    'fact_revenu_question': 'Your taxable income — roughly how much?',
    'fact_revenu_band_lt30': 'Under 30 000',
    'fact_revenu_band_30_50': '30 000 – 50 000',
    'fact_revenu_band_50_70': '50 000 – 70 000',
    'fact_revenu_band_70_100': '70 000 – 100 000',
    'fact_revenu_band_100_150': '100 000 – 150 000',
    'fact_revenu_band_gt150': 'More than 150 000',
    'fact_revenu_unit_hint': 'in francs per year',
    'fact_revenu_help_link': 'Where do I find my taxable income?',
    'fact_revenu_selection_label': 'Your choice',
    'fact_revenu_selection_none': 'You haven’t picked a range yet.',
    'fact_revenu_selection_selected': '{band} CHF',
    'fact_revenu_change': 'Change',
    'fact_revenu_continue': 'Continue',
    'fact_revenu_back': 'Back',
    'fact_revenu_error_no_selection': 'Pick a range to continue.',
    'fact_revenu_gloss_imposable_term': 'taxable income',
    'fact_revenu_gloss_imposable_def':
        'It’s the amount left after deductions, on which your tax is worked out. You’ll find it on your latest tax assessment.',
    'fact_revenu_gloss_imposable_metaphor':
        'The tax office doesn’t tax your salary directly: it starts from your taxable income.',
    'fact_revenu_gloss_brut_term': 'gross',
    'fact_revenu_gloss_brut_def':
        'Your gross salary is before contributions and tax. Your taxable income is lower: start from your assessment instead.',
    'eclairage_eyebrow': '3a simulation · {taxYear}',
    'eclairage_mechanism':
        'A 3a contribution is deducted from your taxable income. Your tax for the year can then go down.',
    'eclairage_amount': '{low} to {high} CHF',
    'eclairage_amount_caption': 'less tax this year, by our estimate.',
    'eclairage_hyp_label': 'This estimate starts from:',
    'eclairage_hyp_revenu': 'Taxable income · {band} CHF',
    'eclairage_hyp_versement': '3a contribution · {versement} CHF',
    'eclairage_hyp_situation': 'Situation · single',
    'eclairage_refine_situation': 'Refine my civil status',
    'eclairage_hyp_lieu': 'Tax · {commune} ({canton})',
    'eclairage_hyp_edit_hint': 'You can change any line.',
    'eclairage_assumptions':
        'We also assume: no children, church tax not counted, taxed at the ordinary rate.',
    'eclairage_disclaimer':
        'This is an estimate, not tax advice. The exact amount is on your tax assessment.',
    'eclairage_continue': 'Continue',
    'eclairage_back': 'Back',
    'eclairage_pending_title': 'Your taxable income is missing.',
    'eclairage_pending_revenu': 'Pick your income range first.',
    'eclairage_pending_action': 'Pick my range',
    'eclairage_zero_income':
        'Under 30 000 CHF, a 3a contribution often has little tax effect this year.',
    'eclairage_gloss_deduction_term': 'deduction',
    'eclairage_gloss_deduction_def':
        'An amount taken off your taxable income. Less taxable income, less tax.',
    'eclairage_gloss_deduction_metaphor':
        'What you pay into your 3a, tax no longer counts.',
    'eclairage_gloss_3a_term': '3a',
    'eclairage_gloss_3a_def':
        'Pillar 3a is tied savings. Your contributions can be deducted from your taxable income, up to the yearly limit.',
    'eclairage_gloss_versement_term': '3a contribution',
    'eclairage_gloss_versement_def':
        'It’s what you paid into your 3a this year. Here the calculation starts from the yearly limit. Tap the line to change the amount.',
    'eclairage_gloss_ordinaire_term': 'taxed at the ordinary rate',
    'eclairage_gloss_ordinaire_def':
        'Your tax is worked out from your tax return. If you’re taxed at source — often on a B permit or as a cross-border worker — the 3a deduction may work differently. Check what applies to you.',
    'eclairage_na_title': 'We can’t estimate your saving here.',
    'eclairage_na_body':
        'Taxed at source, you usually can’t deduct your 3a the same way. An ordinary assessment is sometimes possible — check your situation.',
    'eclairage_na_action': 'Why?',
    'eclairage_situation_celibataire': 'Single',
    'eclairage_situation_marie': 'Married or in a registered partnership',
    'eclairage_situation_concubinage': 'Living together, not married',
    'eclairage_refine_hint': 'An exact figure narrows the estimate.',
    'eclairage_amount_caption_refined': 'less tax this year, based on your figure.',
    'eclairage_exact_revenu_title': 'Your exact taxable income',
    'eclairage_exact_revenu_placeholder': 'e.g. 85 000',
    'eclairage_exact_revenu_note':
        'No need for an exact figure. If you have it, it narrows the estimate.',
    'eclairage_exact_save': 'Use this figure',
    'gloss_dismiss': 'Got it',
    'provenance_exact': 'exact',
    'eclairage_amount_open': '{low} CHF and above',
  },
  'de': <String, String>{
    'fact_revenu_eyebrow': '3a-Simulation · {taxYear}',
    'fact_revenu_question': 'Dein steuerbares Einkommen — ungefähr wie viel?',
    'fact_revenu_band_lt30': 'Weniger als 30 000',
    'fact_revenu_band_30_50': '30 000 – 50 000',
    'fact_revenu_band_50_70': '50 000 – 70 000',
    'fact_revenu_band_70_100': '70 000 – 100 000',
    'fact_revenu_band_100_150': '100 000 – 150 000',
    'fact_revenu_band_gt150': 'Mehr als 150 000',
    'fact_revenu_unit_hint': 'in Franken pro Jahr',
    'fact_revenu_help_link': 'Wo finde ich mein steuerbares Einkommen?',
    'fact_revenu_selection_label': 'Deine Wahl',
    'fact_revenu_selection_none': 'Du hast noch keine Spanne gewählt.',
    'fact_revenu_selection_selected': '{band} CHF',
    'fact_revenu_change': 'Ändern',
    'fact_revenu_continue': 'Weiter',
    'fact_revenu_back': 'Zurück',
    'fact_revenu_error_no_selection': 'Wähle eine Spanne, um fortzufahren.',
    'fact_revenu_gloss_imposable_term': 'steuerbares Einkommen',
    'fact_revenu_gloss_imposable_def':
        'Das ist der Betrag, der nach den Abzügen bleibt und auf dem deine Steuer berechnet wird. Du findest ihn auf deiner letzten Veranlagung.',
    'fact_revenu_gloss_imposable_metaphor':
        'Das Steueramt besteuert nicht direkt deinen Lohn: Es geht von deinem steuerbaren Einkommen aus.',
    'fact_revenu_gloss_brut_term': 'brutto',
    'fact_revenu_gloss_brut_def':
        'Dein Bruttolohn ist vor Beiträgen und Steuer. Dein steuerbares Einkommen ist tiefer: geh lieber von deiner Veranlagung aus.',
    'eclairage_eyebrow': '3a-Simulation · {taxYear}',
    'eclairage_mechanism':
        'Ein 3a-Beitrag wird von deinem steuerbaren Einkommen abgezogen. Deine Steuer für das Jahr kann dann sinken.',
    'eclairage_amount': '{low} bis {high} CHF',
    'eclairage_amount_caption': 'weniger Steuer dieses Jahr, nach unserer Schätzung.',
    'eclairage_hyp_label': 'Diese Schätzung geht aus von:',
    'eclairage_hyp_revenu': 'Steuerbares Einkommen · {band} CHF',
    'eclairage_hyp_versement': '3a-Beitrag · {versement} CHF',
    'eclairage_hyp_situation': 'Situation · ledig',
    'eclairage_refine_situation': 'Zivilstand präzisieren',
    'eclairage_hyp_lieu': 'Steuern · {commune} ({canton})',
    'eclairage_hyp_edit_hint': 'Du kannst jede Zeile ändern.',
    'eclairage_assumptions':
        'Wir nehmen ausserdem an: keine Kinder, ohne Kirchensteuer, ordentlich besteuert.',
    'eclairage_disclaimer':
        'Das ist eine Schätzung, keine Steuerberatung. Der genaue Betrag steht auf deiner Veranlagung.',
    'eclairage_continue': 'Weiter',
    'eclairage_back': 'Zurück',
    'eclairage_pending_title': 'Dein steuerbares Einkommen fehlt.',
    'eclairage_pending_revenu': 'Wähle zuerst deine Einkommensspanne.',
    'eclairage_pending_action': 'Meine Spanne wählen',
    'eclairage_zero_income':
        'Unter 30 000 CHF hat ein 3a-Beitrag dieses Jahr oft wenig steuerliche Wirkung.',
    'eclairage_gloss_deduction_term': 'Abzug',
    'eclairage_gloss_deduction_def':
        'Ein Betrag, der von deinem steuerbaren Einkommen abgezogen wird. Weniger steuerbares Einkommen, weniger Steuer.',
    'eclairage_gloss_deduction_metaphor':
        'Was du in deine 3a einzahlst, zählt die Steuer nicht mehr.',
    'eclairage_gloss_3a_term': '3a',
    'eclairage_gloss_3a_def':
        'Die Säule 3a ist gebundenes Sparen. Deine Beiträge können von deinem steuerbaren Einkommen abgezogen werden, bis zur jährlichen Grenze.',
    'eclairage_gloss_versement_term': '3a-Beitrag',
    'eclairage_gloss_versement_def':
        'Das ist, was du dieses Jahr in deine 3a eingezahlt hast. Hier geht die Berechnung von der jährlichen Grenze aus. Tippe die Zeile an, um den Betrag zu ändern.',
    'eclairage_gloss_ordinaire_term': 'ordentlich besteuert',
    'eclairage_gloss_ordinaire_def':
        'Deine Steuer wird aus deiner Steuererklärung berechnet. Wenn du an der Quelle besteuert wirst — oft mit einem B-Ausweis oder als Grenzgänger —, kann der 3a-Abzug anders funktionieren. Prüfe, was für dich gilt.',
    'eclairage_na_title': 'Wir können deine Ersparnis hier nicht schätzen.',
    'eclairage_na_body':
        'An der Quelle besteuert, kannst du deine 3a in der Regel nicht auf dieselbe Weise abziehen. Eine ordentliche Veranlagung ist manchmal möglich — prüfe deine Situation.',
    'eclairage_na_action': 'Warum?',
    'eclairage_situation_celibataire': 'Ledig',
    'eclairage_situation_marie': 'Verheiratet oder in eingetragener Partnerschaft',
    'eclairage_situation_concubinage': 'Zusammenlebend, nicht verheiratet',
    'eclairage_refine_hint': 'Eine genaue Zahl verengt die Schätzung.',
    'eclairage_amount_caption_refined': 'weniger Steuer dieses Jahr, nach deiner Zahl.',
    'eclairage_exact_revenu_title': 'Dein genaues steuerbares Einkommen',
    'eclairage_exact_revenu_placeholder': 'z. B. 85 000',
    'eclairage_exact_revenu_note':
        'Eine genaue Zahl ist nicht nötig. Wenn du sie hast, verengt sie die Schätzung.',
    'eclairage_exact_save': 'Diese Zahl verwenden',
    'gloss_dismiss': 'Verstanden',
    'provenance_exact': 'genau',
    'eclairage_amount_open': '{low} CHF und mehr',
  },
  'it': <String, String>{
    'fact_revenu_eyebrow': 'Simulazione 3a · {taxYear}',
    'fact_revenu_question': 'Il tuo reddito imponibile, più o meno quanto?',
    'fact_revenu_band_lt30': 'Meno di 30 000',
    'fact_revenu_band_30_50': '30 000 – 50 000',
    'fact_revenu_band_50_70': '50 000 – 70 000',
    'fact_revenu_band_70_100': '70 000 – 100 000',
    'fact_revenu_band_100_150': '100 000 – 150 000',
    'fact_revenu_band_gt150': 'Più di 150 000',
    'fact_revenu_unit_hint': 'in franchi all’anno',
    'fact_revenu_help_link': 'Dove trovo il mio reddito imponibile?',
    'fact_revenu_selection_label': 'La tua scelta',
    'fact_revenu_selection_none': 'Non hai ancora scelto una fascia.',
    'fact_revenu_selection_selected': '{band} CHF',
    'fact_revenu_change': 'Modifica',
    'fact_revenu_continue': 'Continua',
    'fact_revenu_back': 'Indietro',
    'fact_revenu_error_no_selection': 'Scegli una fascia per continuare.',
    'fact_revenu_gloss_imposable_term': 'reddito imponibile',
    'fact_revenu_gloss_imposable_def':
        'È l’importo che resta dopo le deduzioni e su cui viene calcolata la tua imposta. Lo trovi sulla tua ultima tassazione.',
    'fact_revenu_gloss_imposable_metaphor':
        'Il fisco non tassa direttamente il tuo salario: parte dal tuo reddito imponibile.',
    'fact_revenu_gloss_brut_term': 'lordo',
    'fact_revenu_gloss_brut_def':
        'Il tuo salario lordo è prima dei contributi e dell’imposta. Il tuo reddito imponibile è più basso: parti piuttosto dalla tua tassazione.',
    'eclairage_eyebrow': 'Simulazione 3a · {taxYear}',
    'eclairage_mechanism':
        'Un versamento 3a si deduce dal tuo reddito imponibile. La tua imposta dell’anno può così diminuire.',
    'eclairage_amount': 'da {low} a {high} CHF',
    'eclairage_amount_caption':
        'di imposta in meno quest’anno, secondo la nostra stima.',
    'eclairage_hyp_label': 'Questa stima parte da:',
    'eclairage_hyp_revenu': 'Reddito imponibile · {band} CHF',
    'eclairage_hyp_versement': 'Versamento 3a · {versement} CHF',
    'eclairage_hyp_situation': 'Situazione · celibe/nubile',
    'eclairage_refine_situation': 'Precisa il mio stato civile',
    'eclairage_hyp_lieu': 'Imposte · {commune} ({canton})',
    'eclairage_hyp_edit_hint': 'Puoi modificare ogni riga.',
    'eclairage_assumptions':
        'Supponiamo anche: senza figli, senza imposta di culto, tassazione ordinaria.',
    'eclairage_disclaimer':
        'È una stima, non una consulenza fiscale. L’importo esatto è sulla tua tassazione.',
    'eclairage_continue': 'Continua',
    'eclairage_back': 'Indietro',
    'eclairage_pending_title': 'Manca il tuo reddito imponibile.',
    'eclairage_pending_revenu': 'Scegli prima la tua fascia di reddito.',
    'eclairage_pending_action': 'Scegliere la mia fascia',
    'eclairage_zero_income':
        'Sotto i 30 000 CHF, un versamento 3a ha spesso un effetto fiscale ridotto quest’anno.',
    'eclairage_gloss_deduction_term': 'deduzione',
    'eclairage_gloss_deduction_def':
        'Un importo che si toglie dal tuo reddito imponibile. Meno reddito imponibile, meno imposta.',
    'eclairage_gloss_deduction_metaphor':
        'Quello che versi sulla tua 3a, l’imposta non lo conta più.',
    'eclairage_gloss_3a_term': '3a',
    'eclairage_gloss_3a_def':
        'Il pilastro 3a è un risparmio vincolato. I tuoi versamenti possono essere dedotti dal tuo reddito imponibile, fino al limite annuo.',
    'eclairage_gloss_versement_term': 'versamento 3a',
    'eclairage_gloss_versement_def':
        'È quello che hai versato sulla tua 3a quest’anno. Qui il calcolo parte dal limite annuo. Tocca la riga per cambiare l’importo.',
    'eclairage_gloss_ordinaire_term': 'tassazione ordinaria',
    'eclairage_gloss_ordinaire_def':
        'La tua imposta è calcolata dalla tua dichiarazione. Se sei tassato alla fonte — spesso con un permesso B o come frontaliere — la deduzione 3a può funzionare diversamente. Verifica cosa vale per te.',
    'eclairage_na_title': 'Qui non possiamo stimare il tuo risparmio.',
    'eclairage_na_body':
        'Tassato alla fonte, di solito non puoi dedurre la tua 3a nello stesso modo. Una tassazione ordinaria è a volte possibile — verifica la tua situazione.',
    'eclairage_na_action': 'Perché?',
    'eclairage_situation_celibataire': 'Celibe/nubile',
    'eclairage_situation_marie': 'Sposato/a o in unione domestica registrata',
    'eclairage_situation_concubinage': 'In coppia, non sposato/a',
    'eclairage_refine_hint': 'Una cifra esatta restringe la stima.',
    'eclairage_amount_caption_refined':
        'di imposta in meno quest’anno, in base alla tua cifra.',
    'eclairage_exact_revenu_title': 'Il tuo reddito imponibile esatto',
    'eclairage_exact_revenu_placeholder': 'es. 85 000',
    'eclairage_exact_revenu_note':
        'Non serve una cifra esatta. Se ce l’hai, restringe la stima.',
    'eclairage_exact_save': 'Usare questa cifra',
    'gloss_dismiss': 'Ho capito',
    'provenance_exact': 'esatto',
    'eclairage_amount_open': '{low} CHF e più',
  },
  'es': <String, String>{
    'fact_revenu_eyebrow': 'Simulación 3a · {taxYear}',
    'fact_revenu_question': 'Tu ingreso imponible, ¿más o menos cuánto?',
    'fact_revenu_band_lt30': 'Menos de 30 000',
    'fact_revenu_band_30_50': '30 000 – 50 000',
    'fact_revenu_band_50_70': '50 000 – 70 000',
    'fact_revenu_band_70_100': '70 000 – 100 000',
    'fact_revenu_band_100_150': '100 000 – 150 000',
    'fact_revenu_band_gt150': 'Más de 150 000',
    'fact_revenu_unit_hint': 'en francos al año',
    'fact_revenu_help_link': '¿Dónde encuentro mi ingreso imponible?',
    'fact_revenu_selection_label': 'Tu elección',
    'fact_revenu_selection_none': 'Aún no has elegido un tramo.',
    'fact_revenu_selection_selected': '{band} CHF',
    'fact_revenu_change': 'Cambiar',
    'fact_revenu_continue': 'Continuar',
    'fact_revenu_back': 'Atrás',
    'fact_revenu_error_no_selection': 'Elige un tramo para continuar.',
    'fact_revenu_gloss_imposable_term': 'ingreso imponible',
    'fact_revenu_gloss_imposable_def':
        'Es el importe que queda tras las deducciones y sobre el que se calcula tu impuesto. Lo encuentras en tu última liquidación.',
    'fact_revenu_gloss_imposable_metaphor':
        'Hacienda no grava directamente tu salario: parte de tu ingreso imponible.',
    'fact_revenu_gloss_brut_term': 'bruto',
    'fact_revenu_gloss_brut_def':
        'Tu salario bruto es antes de las cotizaciones y el impuesto. Tu ingreso imponible es más bajo: parte más bien de tu liquidación.',
    'eclairage_eyebrow': 'Simulación 3a · {taxYear}',
    'eclairage_mechanism':
        'Una aportación 3a se deduce de tu ingreso imponible. Tu impuesto del año puede así bajar.',
    'eclairage_amount': '{low} a {high} CHF',
    'eclairage_amount_caption': 'de impuesto menos este año, según nuestra estimación.',
    'eclairage_hyp_label': 'Esta estimación parte de:',
    'eclairage_hyp_revenu': 'Ingreso imponible · {band} CHF',
    'eclairage_hyp_versement': 'Aportación 3a · {versement} CHF',
    'eclairage_hyp_situation': 'Situación · soltero/a',
    'eclairage_refine_situation': 'Precisar mi estado civil',
    'eclairage_hyp_lieu': 'Impuestos · {commune} ({canton})',
    'eclairage_hyp_edit_hint': 'Puedes modificar cada línea.',
    'eclairage_assumptions':
        'También suponemos: sin hijos, sin impuesto eclesiástico, tributación ordinaria.',
    'eclairage_disclaimer':
        'Es una estimación, no un asesoramiento fiscal. El importe exacto está en tu liquidación.',
    'eclairage_continue': 'Continuar',
    'eclairage_back': 'Atrás',
    'eclairage_pending_title': 'Falta tu ingreso imponible.',
    'eclairage_pending_revenu': 'Elige primero tu tramo de ingreso.',
    'eclairage_pending_action': 'Elegir mi tramo',
    'eclairage_zero_income':
        'Por debajo de 30 000 CHF, una aportación 3a suele tener poco efecto fiscal este año.',
    'eclairage_gloss_deduction_term': 'deducción',
    'eclairage_gloss_deduction_def':
        'Un importe que se resta de tu ingreso imponible. Menos ingreso imponible, menos impuesto.',
    'eclairage_gloss_deduction_metaphor':
        'Lo que aportas a tu 3a, el impuesto ya no lo cuenta.',
    'eclairage_gloss_3a_term': '3a',
    'eclairage_gloss_3a_def':
        'El pilar 3a es un ahorro vinculado. Tus aportaciones pueden deducirse de tu ingreso imponible, hasta el límite anual.',
    'eclairage_gloss_versement_term': 'aportación 3a',
    'eclairage_gloss_versement_def':
        'Es lo que has aportado a tu 3a este año. Aquí el cálculo parte del límite anual. Toca la línea para cambiar el importe.',
    'eclairage_gloss_ordinaire_term': 'tributación ordinaria',
    'eclairage_gloss_ordinaire_def':
        'Tu impuesto se calcula a partir de tu declaración. Si tributas en la fuente — a menudo con un permiso B o como fronterizo — la deducción 3a puede funcionar de otra manera. Comprueba lo que se aplica a ti.',
    'eclairage_na_title': 'Aquí no podemos estimar tu ahorro.',
    'eclairage_na_body':
        'Si tributas en la fuente, en general no puedes deducir tu 3a de la misma forma. A veces es posible una tributación ordinaria — comprueba tu situación.',
    'eclairage_na_action': '¿Por qué?',
    'eclairage_situation_celibataire': 'Soltero/a',
    'eclairage_situation_marie': 'Casado/a o en unión registrada',
    'eclairage_situation_concubinage': 'En pareja, no casado/a',
    'eclairage_refine_hint': 'Una cifra exacta estrecha la estimación.',
    'eclairage_amount_caption_refined':
        'de impuesto menos este año, según tu cifra.',
    'eclairage_exact_revenu_title': 'Tu ingreso imponible exacto',
    'eclairage_exact_revenu_placeholder': 'p. ej. 85 000',
    'eclairage_exact_revenu_note':
        'No hace falta una cifra exacta. Si la tienes, estrecha la estimación.',
    'eclairage_exact_save': 'Usar esta cifra',
    'gloss_dismiss': 'Entendido',
    'provenance_exact': 'exacto',
    'eclairage_amount_open': '{low} CHF y más',
  },
  'pt': <String, String>{
    'fact_revenu_eyebrow': 'Simulação 3a · {taxYear}',
    'fact_revenu_question': 'O teu rendimento tributável, mais ou menos quanto?',
    'fact_revenu_band_lt30': 'Menos de 30 000',
    'fact_revenu_band_30_50': '30 000 – 50 000',
    'fact_revenu_band_50_70': '50 000 – 70 000',
    'fact_revenu_band_70_100': '70 000 – 100 000',
    'fact_revenu_band_100_150': '100 000 – 150 000',
    'fact_revenu_band_gt150': 'Mais de 150 000',
    'fact_revenu_unit_hint': 'em francos por ano',
    'fact_revenu_help_link': 'Onde encontro o meu rendimento tributável?',
    'fact_revenu_selection_label': 'A tua escolha',
    'fact_revenu_selection_none': 'Ainda não escolheste um escalão.',
    'fact_revenu_selection_selected': '{band} CHF',
    'fact_revenu_change': 'Alterar',
    'fact_revenu_continue': 'Continuar',
    'fact_revenu_back': 'Voltar',
    'fact_revenu_error_no_selection': 'Escolhe um escalão para continuar.',
    'fact_revenu_gloss_imposable_term': 'rendimento tributável',
    'fact_revenu_gloss_imposable_def':
        'É o montante que resta depois das deduções e sobre o qual o teu imposto é calculado. Encontra-lo na tua última tributação.',
    'fact_revenu_gloss_imposable_metaphor':
        'O fisco não tributa diretamente o teu salário: parte do teu rendimento tributável.',
    'fact_revenu_gloss_brut_term': 'bruto',
    'fact_revenu_gloss_brut_def':
        'O teu salário bruto é antes das contribuições e do imposto. O teu rendimento tributável é mais baixo: parte antes da tua tributação.',
    'eclairage_eyebrow': 'Simulação 3a · {taxYear}',
    'eclairage_mechanism':
        'Um depósito 3a deduz-se do teu rendimento tributável. O teu imposto do ano pode então baixar.',
    'eclairage_amount': '{low} a {high} CHF',
    'eclairage_amount_caption': 'de imposto a menos este ano, segundo a nossa estimativa.',
    'eclairage_hyp_label': 'Esta estimativa parte de:',
    'eclairage_hyp_revenu': 'Rendimento tributável · {band} CHF',
    'eclairage_hyp_versement': 'Depósito 3a · {versement} CHF',
    'eclairage_hyp_situation': 'Situação · solteiro/a',
    'eclairage_refine_situation': 'Precisar o meu estado civil',
    'eclairage_hyp_lieu': 'Impostos · {commune} ({canton})',
    'eclairage_hyp_edit_hint': 'Podes alterar cada linha.',
    'eclairage_assumptions':
        'Supomos também: sem filhos, sem imposto eclesiástico, tributado normalmente.',
    'eclairage_disclaimer':
        'É uma estimativa, não um aconselhamento fiscal. O montante exato está na tua tributação.',
    'eclairage_continue': 'Continuar',
    'eclairage_back': 'Voltar',
    'eclairage_pending_title': 'Falta o teu rendimento tributável.',
    'eclairage_pending_revenu': 'Escolhe primeiro o teu escalão de rendimento.',
    'eclairage_pending_action': 'Escolher o meu escalão',
    'eclairage_zero_income':
        'Abaixo de 30 000 CHF, um depósito 3a tem muitas vezes pouco efeito fiscal este ano.',
    'eclairage_gloss_deduction_term': 'dedução',
    'eclairage_gloss_deduction_def':
        'Um montante que se retira do teu rendimento tributável. Menos rendimento tributável, menos imposto.',
    'eclairage_gloss_deduction_metaphor':
        'O que depositas na tua 3a, o imposto já não conta.',
    'eclairage_gloss_3a_term': '3a',
    'eclairage_gloss_3a_def':
        'O pilar 3a é uma poupança vinculada. Os teus depósitos podem ser deduzidos do teu rendimento tributável, até ao limite anual.',
    'eclairage_gloss_versement_term': 'depósito 3a',
    'eclairage_gloss_versement_def':
        'É o que depositaste na tua 3a este ano. Aqui o cálculo parte do limite anual. Toca na linha para mudar o montante.',
    'eclairage_gloss_ordinaire_term': 'tributado normalmente',
    'eclairage_gloss_ordinaire_def':
        'O teu imposto é calculado a partir da tua declaração. Se és tributado na fonte — muitas vezes com uma autorização B ou como trabalhador transfronteiriço — a dedução 3a pode funcionar de outra forma. Verifica o que se aplica a ti.',
    'eclairage_na_title': 'Aqui não podemos estimar a tua poupança.',
    'eclairage_na_body':
        'Tributado na fonte, em geral não podes deduzir a tua 3a da mesma forma. Uma tributação normal é por vezes possível — verifica a tua situação.',
    'eclairage_na_action': 'Porquê?',
    'eclairage_situation_celibataire': 'Solteiro/a',
    'eclairage_situation_marie': 'Casado/a ou em parceria registada',
    'eclairage_situation_concubinage': 'Em casal, não casado/a',
    'eclairage_refine_hint': 'Um número exato estreita a estimativa.',
    'eclairage_amount_caption_refined':
        'de imposto a menos este ano, com base no teu número.',
    'eclairage_exact_revenu_title': 'O teu rendimento tributável exato',
    'eclairage_exact_revenu_placeholder': 'p. ex. 85 000',
    'eclairage_exact_revenu_note':
        'Não precisas de um número exato. Se o tens, estreita a estimativa.',
    'eclairage_exact_save': 'Usar este número',
    'gloss_dismiss': 'Percebi',
    'provenance_exact': 'exato',
    'eclairage_amount_open': '{low} CHF e mais',
  },
};

/// Resolves the R3 copy map for [languageCode], falling back to fr.
Map<String, String> r3CopyFor(String languageCode) =>
    r3Copy[languageCode] ?? r3Copy['fr']!;

/// The exact substring of `eclairage_mechanism` to emphasise + turn into the
/// `déduction` glossary anchor (mockup eclairage_1_nominal bolds it). These are
/// verbatim substrings of the sealed mechanism copy above, used only for styling
/// — not new copy. The deduction glossary term itself is a distinct noun form
/// (`eclairage_gloss_deduction_term`), so the anchor is the conjugated verb here.
const Map<String, String> r3MechanismEmphasis = <String, String>{
  'fr': 'déduit',
  'en': 'deducted',
  'de': 'abgezogen',
  'it': 'si deduce',
  'es': 'se deduce',
  'pt': 'deduz-se',
};

// ---------------------------------------------------------------------------
// FIXTURES — engine-derived (r3-engine-fixtures.yaml). NEVER re-derived here.
// ---------------------------------------------------------------------------

/// The 3a contribution assumed by the fixtures: the LPP-affiliated cap
/// (pilier3aPlafondAvecLpp — apps/mobile/lib/constants/social_insurance.dart:397).
/// R3 slice precondition is lpp_affiliation_yes, so the cap is 7258.
const int r3VersementChf = 7258;

/// The example canton/commune the fixtures were executed against: FR (Fribourg),
/// chef-lieu, célibataire (cantonal_comparator.py:99-101 calibration profile).
const String r3ExampleCommune = 'Fribourg';
const String r3ExampleCanton = 'Fribourg';

/// A reviewed taxable-income band. `savingHigh` is null for the open-topped
/// gt150 band (fixtures saving_high: null). `renderState` is the sealed
/// render_contract state this band lands on.
class R3Band {
  const R3Band({
    required this.key,
    required this.labelKey,
    required this.lowEdge,
    required this.highEdge,
    required this.savingLow,
    required this.savingHigh,
    required this.renderState,
  });

  final String key; // band_enum
  final String labelKey; // copy key for the human label
  final int lowEdge; // income lower edge (chf/year)
  final int? highEdge; // income upper edge (null = open-topped)
  final int savingLow; // engine-derived saving at the lower edge
  final int? savingHigh; // engine-derived saving at the upper edge (null gt150)
  final String renderState; // nominal | low_income_floor
}

/// Bands in stable low->high order (committed-key order = band_enum order).
/// Every saving value is reproduced verbatim from r3-engine-fixtures.yaml
/// `saving_fourchette.bands` (executed live 2026-08-05, canton FR).
const List<R3Band> r3Bands = <R3Band>[
  R3Band(
    key: 'lt30',
    labelKey: 'fact_revenu_band_lt30',
    lowEdge: 0,
    highEdge: 30000,
    savingLow: 0,
    savingHigh: 1243,
    renderState: 'low_income_floor',
  ),
  R3Band(
    key: 'b30_50',
    labelKey: 'fact_revenu_band_30_50',
    lowEdge: 30000,
    highEdge: 50000,
    savingLow: 1243,
    savingHigh: 1794,
    renderState: 'nominal',
  ),
  R3Band(
    key: 'b50_70',
    labelKey: 'fact_revenu_band_50_70',
    lowEdge: 50000,
    highEdge: 70000,
    savingLow: 1794,
    savingHigh: 1831,
    renderState: 'nominal',
  ),
  R3Band(
    key: 'b70_100',
    labelKey: 'fact_revenu_band_70_100',
    lowEdge: 70000,
    highEdge: 100000,
    savingLow: 1831,
    savingHigh: 2242, // maquette « ≈ 1 800 à 2 200 CHF »
    renderState: 'nominal',
  ),
  R3Band(
    key: 'b100_150',
    labelKey: 'fact_revenu_band_100_150',
    lowEdge: 100000,
    highEdge: 150000,
    savingLow: 2242,
    savingHigh: 2776,
    renderState: 'nominal',
  ),
  R3Band(
    key: 'gt150',
    labelKey: 'fact_revenu_band_gt150',
    lowEdge: 150000,
    highEdge: null,
    savingLow: 2776,
    savingHigh: null, // open-topped
    renderState: 'nominal',
  ),
];

/// The single engine-derived precision_refined point (fixtures
/// precision_refined_point): exact taxable income 85 000 CHF, canton FR,
/// célibataire, versement 7258 -> saving 2213 (never displayed as a point).
/// The refined range is that point floored to the nearest 100 (2200) widened by
/// the residual band (±100), keeping a WIDE range that never collapses (P3/P4).
const int r3RefinedExactIncomeChf = 85000;
const int r3RefinedSavingChf = 2213;
const int r3RefinedRangeLow = 2100;
const int r3RefinedRangeHigh = 2300;
