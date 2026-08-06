// GENERATED — Batch22 R4 (FERMETURE DE LA BOUCLE) runtime catalog for the hidden
// design lab. Mirrors product/mint_next/batch22/r4-six-locale-copy.yaml (semantic
// copy, 6 locales) and product/mint_next/batch22/r4-engine-fixtures.yaml (every
// number engine-derived, 0-trust). Two screens: scenarios_versement (the "et
// maintenant ?" scenario spectrum) and fact_etat_civil (the civil-status
// collection card). The design lab is offline and fixture-bound; it NEVER
// re-implements the fiscal engine (NEVER#3) — it only renders the sealed
// engine-derived fixtures, plus the OPP3 ceiling-DERIVATION rule, which the
// sealed contract explicitly GRAVES (engraves) as a runtime obligation distinct
// from the deferred non-affilié ROUTING decision (scenarios_versement-scope.yaml
// ceiling_derivation_opp3 + deferred_integration.non_affilie_ceiling_routing).
//
// GAP-FILLS (documented, not in the sealed copy, surfaced to the lead for
// reconciliation — same pattern as r3_eclairage_catalog.g.dart):
//   * gloss_dismiss                    : glossary-sheet dismiss label. Reuses
//                                        the batch21/batch20 accepted value
//                                        verbatim (cross-batch precedent).
//   * scenarios_pending_fact_tax_year,
//     scenarios_pending_fact_commune,
//     scenarios_pending_fact_band,
//     scenarios_pending_fact_affiliation : the sealed copy provides
//                                        `scenarios_pending_which: "Information
//                                        manquante : {fact}."` but no localized
//                                        NOUN per critical input to fill
//                                        `{fact}`. These four short, LSFin-safe
//                                        nouns fill that gap deterministically
//                                        (one per critical input in
//                                        scenarios_versement-scope.yaml
//                                        critical_inputs_for_this_screen).
//   * scenarios_excess_note            : scenarios_versement-scope.yaml:440-441
//                                        names this key
//                                        (excess_note_when_scenario_exceeds_room,
//                                        fault_B) but it is ABSENT from the
//                                        sealed r4-six-locale-copy.yaml (a
//                                        contract gap, surfaced to the lead).
//                                        The sentence paraphrases the sealed
//                                        fault_B contract_assertion verbatim
//                                        (no new claim invented): the part of
//                                        a scenario above remaining room adds
//                                        no tax effect.
//   * scenarios_own_amount_save        : `scenarios_own_amount` ("Entrer mon
//                                        propre montant") is the button that
//                                        OPENS the exact_amount_sheet
//                                        (scenarios_block.own_amount_control).
//                                        The sealed copy has no distinct label
//                                        for the sheet's CONFIRM action. This
//                                        gap-fill mirrors the accepted R3
//                                        `eclairage_exact_save` voice
//                                        ("Utiliser ce chiffre" -> "Utiliser ce
//                                        montant") for continuity.
// Do not edit by hand.

const String r4CopySourceRef =
    'product/mint_next/batch22/r4-six-locale-copy.yaml';
const String r4FixturesSourceRef =
    'product/mint_next/batch22/r4-engine-fixtures.yaml';

// ---------------------------------------------------------------------------
// COPY — 6 locales, keyed exactly by the sealed copy keys (plus the
// documented gap-fills above). Accents are locale-correct and byte-faithful
// to the sealed source.
// ---------------------------------------------------------------------------
const Map<String, Map<String, String>> r4Copy = <String, Map<String, String>>{
  'fr': <String, String>{
    // scenarios_versement
    'scenarios_eyebrow': 'Simulation 3a · {taxYear}',
    'scenarios_choose_line':
        'À toi de choisir le montant. Voici l’effet estimé pour chacun.',
    'scenarios_remaining': 'Tu peux encore verser jusqu’à {room} CHF cette année.',
    'scenarios_amount': '{amount} CHF',
    'scenarios_amount_max_suffix': ' · le maximum cette année',
    'scenarios_effect': 'environ {low} à {high} CHF d’impôt en moins',
    'scenarios_already': 'Tu as déjà versé {contributed} CHF cette année.',
    'scenarios_amount_more': '+{amount} CHF',
    'scenarios_amount_rest_suffix': ' · encore possible cette année',
    'scenarios_liquidity':
        'L’argent versé sur un 3a reste bloqué jusqu’à la retraite, sauf dans les cas prévus par la loi.',
    'scenarios_commune_caveat':
        'L’estimation part du chef-lieu du canton ; selon ta commune, le montant peut changer.',
    'scenarios_disclaimer': 'Ce sont des estimations, pas un conseil.',
    'scenarios_own_amount': 'Entrer mon propre montant',
    'scenarios_keep_reference': 'Garder cette estimation',
    'scenarios_reference_kept': 'Estimation gardée.',
    'scenarios_continue': 'Continuer',
    'scenarios_back': 'Retour',
    'scenarios_plafond20_line':
        'Sans caisse de pension, ton plafond 3a dépend de ton revenu (20 %).',
    'scenarios_plafond20_amount': 'Ton plafond est de {ceiling} CHF cette année.',
    'scenarios_plafond20_effect_note':
        'À ce revenu, l’effet sur l’impôt reste modeste et dépend beaucoup de ta commune.',
    'scenarios_plafond20_income_hyp': 'Estimation basée sur ton revenu d’activité.',
    'scenarios_over_line':
        'Tu as déjà versé {contributed} CHF, au-dessus du plafond de {cap} CHF cette année.',
    'scenarios_over_excess':
        'Tu as versé {excess} CHF de plus que le plafond annuel ordinaire. Selon ta situation, ce surplus ne réduit pas toujours l’impôt. Vérifie avec ton prestataire 3a ce qui s’applique.',
    'scenarios_over_action': 'Voir ce qui est à vérifier',
    'scenarios_pending_title': 'Il manque une information pour calculer les scénarios.',
    'scenarios_pending_which': 'Information manquante : {fact}.',
    'scenarios_pending_action': 'Ajouter l’information',
    'scenarios_gloss_plafond_term': 'plafond',
    'scenarios_gloss_plafond_def':
        'Le plafond est le total que tu peux verser sur tes 3a cette année. Avec une caisse de pension : {affiliatedCap} CHF. Sans caisse : 20 % de ton revenu, jusqu’à un maximum fixé par la loi.',
    'scenarios_gloss_marge_term': 'marge restante',
    'scenarios_gloss_marge_def':
        'Ce qu’il te reste à verser cette année : le plafond, moins ce que tu as déjà mis.',
    'scenarios_gloss_bloque_term': 'bloqué',
    'scenarios_gloss_bloque_def':
        'L’argent du 3a ne peut pas être retiré librement. Un retrait anticipé est notamment possible pour acheter ton logement, te mettre à ton compte ou quitter définitivement la Suisse. Sinon, il reste bloqué jusqu’à la retraite.',
    // fact_etat_civil
    'etat_civil_eyebrow': 'Simulation 3a · {taxYear}',
    'etat_civil_question': 'Quelle est ta situation de famille ?',
    'etat_civil_determining_hint': 'On regarde ta situation au 31 décembre {taxYear}.',
    'etat_civil_card_celibataire': 'Célibataire',
    'etat_civil_card_marie_pacse': 'Marié·e ou en partenariat enregistré',
    'etat_civil_card_concubinage': 'En couple, non marié·e',
    'etat_civil_help_link': 'Pourquoi ça change l’impôt ?',
    'etat_civil_recompute_hint': 'Ton choix précise l’hypothèse « Situation ». Pour un ménage marié, l’économie dépend du revenu du couple.',
    'etat_civil_selection_label': 'Ton choix',
    'etat_civil_selection_none': 'Tu n’as pas encore choisi.',
    'etat_civil_selection_selected': '{status}',
    'etat_civil_change': 'Modifier',
    'etat_civil_continue': 'Continuer',
    'etat_civil_back': 'Retour',
    'etat_civil_error_no_selection': 'Choisis ta situation pour continuer.',
    'etat_civil_gloss_marie_term': 'marié·e ou en partenariat enregistré',
    'etat_civil_gloss_marie_def':
        'Marié·e ou en partenariat enregistré et vivant en ménage commun, tu es imposé·e avec ton ou ta partenaire : vos revenus entrent dans un calcul commun. Séparé·e durablement, tu es imposé·e comme une personne seule.',
    'etat_civil_gloss_concubinage_term': 'en couple, non marié·e',
    'etat_civil_gloss_concubinage_def':
        'Sans mariage ni partenariat enregistré, chacun est imposé séparément, comme une personne célibataire.',
    'etat_civil_gloss_celibataire_term': 'célibataire',
    'etat_civil_gloss_celibataire_def':
        'Après une séparation durable, un divorce ou un veuvage, l’impôt te considère aussi comme célibataire.',
    // gap-fills
    'gloss_dismiss': 'Compris',
    'scenarios_pending_fact_tax_year': 'l’année fiscale',
    'scenarios_pending_fact_commune': 'ta commune',
    'scenarios_pending_fact_band': 'ta tranche de revenu imposable',
    'scenarios_pending_fact_affiliation': 'ton affiliation à une caisse de pension',
    'scenarios_excess_note':
        'Au-dessus de ta marge restante, la part en trop ne réduit pas ton impôt.',
    'scenarios_own_amount_save': 'Utiliser ce montant',
  },
  'en': <String, String>{
    'scenarios_eyebrow': '3a simulation · {taxYear}',
    'scenarios_choose_line': 'You choose the amount. Here’s the estimated effect for each one.',
    'scenarios_remaining': 'You can still pay in up to {room} CHF this year.',
    'scenarios_amount': '{amount} CHF',
    'scenarios_amount_max_suffix': ' · the most this year',
    'scenarios_effect': 'around {low} to {high} CHF less tax',
    'scenarios_already': 'You’ve already paid in {contributed} CHF this year.',
    'scenarios_amount_more': '+{amount} CHF',
    'scenarios_amount_rest_suffix': ' · still possible this year',
    'scenarios_liquidity':
        'Money paid into a 3a stays locked until retirement, except in the cases allowed by law.',
    'scenarios_commune_caveat':
        'The estimate starts from the canton’s main town; depending on your municipality, the amount can change.',
    'scenarios_disclaimer': 'These are estimates, not advice.',
    'scenarios_own_amount': 'Enter my own amount',
    'scenarios_keep_reference': 'Keep this estimate',
    'scenarios_reference_kept': 'Estimate kept.',
    'scenarios_continue': 'Continue',
    'scenarios_back': 'Back',
    'scenarios_plafond20_line': 'Without a pension fund, your 3a limit depends on your income (20%).',
    'scenarios_plafond20_amount': 'Your limit is {ceiling} CHF this year.',
    'scenarios_plafond20_effect_note':
        'At this income, the effect on tax stays modest and depends a lot on your municipality.',
    'scenarios_plafond20_income_hyp': 'Based on your earned income.',
    'scenarios_over_line':
        'You’ve already paid in {contributed} CHF, above the {cap} CHF limit for this year.',
    'scenarios_over_excess':
        'You’ve paid {excess} CHF more than the ordinary annual limit. Depending on your situation, this surplus doesn’t always reduce your tax. Check with your 3a provider what applies.',
    'scenarios_over_action': 'See what to check',
    'scenarios_pending_title': 'Some information is missing to work out the scenarios.',
    'scenarios_pending_which': 'Missing information: {fact}.',
    'scenarios_pending_action': 'Add the information',
    'scenarios_gloss_plafond_term': 'limit',
    'scenarios_gloss_plafond_def':
        'The limit is the total you can pay into your 3a this year. With a pension fund: {affiliatedCap} CHF. Without one: 20% of your income, up to a maximum set by law.',
    'scenarios_gloss_marge_term': 'remaining room',
    'scenarios_gloss_marge_def':
        'What you’ve still got left to pay in this year: the limit, minus what you’ve already put in.',
    'scenarios_gloss_bloque_term': 'locked',
    'scenarios_gloss_bloque_def':
        'Money in a 3a can’t be withdrawn freely. An early withdrawal is possible in particular to buy your home, become self-employed or leave Switzerland for good. Otherwise it stays locked until retirement.',
    'etat_civil_eyebrow': '3a simulation · {taxYear}',
    'etat_civil_question': 'What’s your family situation?',
    'etat_civil_determining_hint': 'We look at your situation on 31 December {taxYear}.',
    'etat_civil_card_celibataire': 'Single',
    'etat_civil_card_marie_pacse': 'Married or in a registered partnership',
    'etat_civil_card_concubinage': 'Living together, not married',
    'etat_civil_help_link': 'Why does this change the tax?',
    'etat_civil_recompute_hint': 'Your choice refines the “Situation” assumption. For a married household, the saving depends on the couple’s income.',
    'etat_civil_selection_label': 'Your choice',
    'etat_civil_selection_none': 'You haven’t chosen yet.',
    'etat_civil_selection_selected': '{status}',
    'etat_civil_change': 'Change',
    'etat_civil_continue': 'Continue',
    'etat_civil_back': 'Back',
    'etat_civil_error_no_selection': 'Choose your situation to continue.',
    'etat_civil_gloss_marie_term': 'married or in a registered partnership',
    'etat_civil_gloss_marie_def':
        'Married or in a registered partnership and living in the same household, you’re taxed together with your partner: your incomes go into one joint calculation. If you’re lastingly separated, you’re taxed as a single person.',
    'etat_civil_gloss_concubinage_term': 'living together, not married',
    'etat_civil_gloss_concubinage_def':
        'Without marriage or a registered partnership, each person is taxed separately, like a single person.',
    'etat_civil_gloss_celibataire_term': 'single',
    'etat_civil_gloss_celibataire_def':
        'After a lasting separation, a divorce or being widowed, tax also treats you as single.',
    'gloss_dismiss': 'Got it',
    'scenarios_pending_fact_tax_year': 'the tax year',
    'scenarios_pending_fact_commune': 'your municipality',
    'scenarios_pending_fact_band': 'your income range',
    'scenarios_pending_fact_affiliation': 'your pension fund affiliation',
    'scenarios_excess_note':
        'Above your remaining room, the extra part doesn’t reduce your tax.',
    'scenarios_own_amount_save': 'Use this amount',
  },
  'de': <String, String>{
    'scenarios_eyebrow': '3a-Simulation · {taxYear}',
    'scenarios_choose_line': 'Du wählst den Betrag. Hier ist die geschätzte Wirkung für jeden.',
    'scenarios_remaining': 'Du kannst dieses Jahr noch bis zu {room} CHF einzahlen.',
    'scenarios_amount': '{amount} CHF',
    'scenarios_amount_max_suffix': ' · das Maximum dieses Jahr',
    'scenarios_effect': 'rund {low} bis {high} CHF weniger Steuer',
    'scenarios_already': 'Du hast dieses Jahr schon {contributed} CHF eingezahlt.',
    'scenarios_amount_more': '+{amount} CHF',
    'scenarios_amount_rest_suffix': ' · dieses Jahr noch möglich',
    'scenarios_liquidity':
        'Geld in einer 3a bleibt bis zur Pensionierung gebunden, ausser in den vom Gesetz vorgesehenen Fällen.',
    'scenarios_commune_caveat':
        'Die Schätzung geht vom Kantonshauptort aus; je nach deiner Gemeinde kann der Betrag anders ausfallen.',
    'scenarios_disclaimer': 'Das sind Schätzungen, keine Beratung.',
    'scenarios_own_amount': 'Eigenen Betrag eingeben',
    'scenarios_keep_reference': 'Diese Schätzung behalten',
    'scenarios_reference_kept': 'Schätzung behalten.',
    'scenarios_continue': 'Weiter',
    'scenarios_back': 'Zurück',
    'scenarios_plafond20_line': 'Ohne Pensionskasse hängt deine 3a-Grenze von deinem Einkommen ab (20 %).',
    'scenarios_plafond20_amount': 'Deine Grenze liegt dieses Jahr bei {ceiling} CHF.',
    'scenarios_plafond20_effect_note':
        'Bei diesem Einkommen bleibt die Wirkung auf die Steuer gering und hängt stark von deiner Gemeinde ab.',
    'scenarios_plafond20_income_hyp': 'Auf Basis deines Erwerbseinkommens.',
    'scenarios_over_line':
        'Du hast schon {contributed} CHF eingezahlt, über der Grenze von {cap} CHF für dieses Jahr.',
    'scenarios_over_excess':
        'Du hast {excess} CHF mehr als die ordentliche Jahresgrenze eingezahlt. Je nach Situation senkt dieser Überschuss die Steuer nicht immer. Kläre mit deinem 3a-Anbieter, was für dich gilt.',
    'scenarios_over_action': 'Sehen, was zu prüfen ist',
    'scenarios_pending_title': 'Für die Szenarien fehlt eine Angabe.',
    'scenarios_pending_which': 'Fehlende Angabe: {fact}.',
    'scenarios_pending_action': 'Angabe ergänzen',
    'scenarios_gloss_plafond_term': 'Höchstbetrag',
    'scenarios_gloss_plafond_def':
        'Der Höchstbetrag ist das Total, das du dieses Jahr in deine 3a einzahlen kannst. Mit Pensionskasse: {affiliatedCap} CHF. Ohne: 20 % deines Einkommens, bis zu einem gesetzlich festgelegten Maximum.',
    'scenarios_gloss_marge_term': 'verbleibender Spielraum',
    'scenarios_gloss_marge_def':
        'Was du dieses Jahr noch einzahlen kannst: der Höchstbetrag, minus das, was du schon eingezahlt hast.',
    'scenarios_gloss_bloque_term': 'gebunden',
    'scenarios_gloss_bloque_def':
        'Geld in der 3a kann nicht frei bezogen werden. Ein Vorbezug ist namentlich möglich, um Wohneigentum zu kaufen, sich selbständig zu machen oder die Schweiz endgültig zu verlassen. Sonst bleibt es bis zur Pensionierung gebunden.',
    'etat_civil_eyebrow': '3a-Simulation · {taxYear}',
    'etat_civil_question': 'Wie ist deine familiäre Situation?',
    'etat_civil_determining_hint': 'Massgebend ist deine Situation am 31. Dezember {taxYear}.',
    'etat_civil_card_celibataire': 'Ledig',
    'etat_civil_card_marie_pacse': 'Verheiratet oder in eingetragener Partnerschaft',
    'etat_civil_card_concubinage': 'Zusammenlebend, nicht verheiratet',
    'etat_civil_help_link': 'Warum ändert das die Steuer?',
    'etat_civil_recompute_hint': 'Deine Wahl präzisiert die Annahme „Situation“. Bei einem verheirateten Haushalt hängt die Ersparnis vom Einkommen des Paares ab.',
    'etat_civil_selection_label': 'Deine Wahl',
    'etat_civil_selection_none': 'Du hast noch nicht gewählt.',
    'etat_civil_selection_selected': '{status}',
    'etat_civil_change': 'Ändern',
    'etat_civil_continue': 'Weiter',
    'etat_civil_back': 'Zurück',
    'etat_civil_error_no_selection': 'Wähle deine Situation, um fortzufahren.',
    'etat_civil_gloss_marie_term': 'verheiratet oder in eingetragener Partnerschaft',
    'etat_civil_gloss_marie_def':
        'Verheiratet oder in eingetragener Partnerschaft und im gemeinsamen Haushalt lebend, wirst du zusammen mit deiner Partnerin oder deinem Partner besteuert: eure Einkommen kommen in eine gemeinsame Berechnung. Dauerhaft getrennt, wirst du wie eine ledige Person besteuert.',
    'etat_civil_gloss_concubinage_term': 'zusammenlebend, nicht verheiratet',
    'etat_civil_gloss_concubinage_def':
        'Ohne Heirat oder eingetragene Partnerschaft wird jede Person einzeln besteuert, wie eine ledige Person.',
    'etat_civil_gloss_celibataire_term': 'ledig',
    'etat_civil_gloss_celibataire_def':
        'Nach einer dauerhaften Trennung, einer Scheidung oder einer Verwitwung behandelt dich die Steuer ebenfalls als ledig.',
    'gloss_dismiss': 'Verstanden',
    'scenarios_pending_fact_tax_year': 'das Steuerjahr',
    'scenarios_pending_fact_commune': 'deine Gemeinde',
    'scenarios_pending_fact_band': 'deine Einkommensspanne',
    'scenarios_pending_fact_affiliation': 'deine Pensionskassen-Zugehörigkeit',
    'scenarios_excess_note':
        'Über deinem verbleibenden Spielraum verringert der zusätzliche Teil deine Steuer nicht.',
    'scenarios_own_amount_save': 'Diesen Betrag verwenden',
  },
  'it': <String, String>{
    'scenarios_eyebrow': 'Simulazione 3a · {taxYear}',
    'scenarios_choose_line': 'Scegli tu l’importo. Ecco l’effetto stimato per ciascuno.',
    'scenarios_remaining': 'Quest’anno puoi ancora versare fino a {room} CHF.',
    'scenarios_amount': '{amount} CHF',
    'scenarios_amount_max_suffix': ' · il massimo quest’anno',
    'scenarios_effect': 'circa da {low} a {high} CHF di imposta in meno',
    'scenarios_already': 'Quest’anno hai già versato {contributed} CHF.',
    'scenarios_amount_more': '+{amount} CHF',
    'scenarios_amount_rest_suffix': ' · ancora possibile quest’anno',
    'scenarios_liquidity':
        'Il denaro versato su una 3a resta vincolato fino alla pensione, salvo nei casi previsti dalla legge.',
    'scenarios_commune_caveat':
        'La stima parte dal capoluogo del cantone; a seconda del tuo comune, l’importo può cambiare.',
    'scenarios_disclaimer': 'Sono stime, non una consulenza.',
    'scenarios_own_amount': 'Inserire il mio importo',
    'scenarios_keep_reference': 'Conservare questa stima',
    'scenarios_reference_kept': 'Stima conservata.',
    'scenarios_continue': 'Continua',
    'scenarios_back': 'Indietro',
    'scenarios_plafond20_line': 'Senza cassa pensioni, il tuo limite 3a dipende dal tuo reddito (20%).',
    'scenarios_plafond20_amount': 'Il tuo limite è di {ceiling} CHF quest’anno.',
    'scenarios_plafond20_effect_note':
        'Con questo reddito, l’effetto sull’imposta resta modesto e dipende molto dal tuo comune.',
    'scenarios_plafond20_income_hyp': 'In base al tuo reddito da attività.',
    'scenarios_over_line': 'Hai già versato {contributed} CHF, oltre il limite di {cap} CHF per quest’anno.',
    'scenarios_over_excess':
        'Hai versato {excess} CHF in più del limite annuo ordinario. A seconda della tua situazione, questo surplus non riduce sempre l’imposta. Verifica con il tuo istituto 3a cosa vale per te.',
    'scenarios_over_action': 'Vedere cosa verificare',
    'scenarios_pending_title': 'Manca un’informazione per calcolare gli scenari.',
    'scenarios_pending_which': 'Informazione mancante: {fact}.',
    'scenarios_pending_action': 'Aggiungere l’informazione',
    'scenarios_gloss_plafond_term': 'limite',
    'scenarios_gloss_plafond_def':
        'Il limite è il totale che puoi versare sulle tue 3a quest’anno. Con una cassa pensioni: {affiliatedCap} CHF. Senza: il 20% del tuo reddito, fino a un massimo fissato dalla legge.',
    'scenarios_gloss_marge_term': 'margine restante',
    'scenarios_gloss_marge_def':
        'Quello che ti resta da versare quest’anno: il limite, meno quello che hai già messo.',
    'scenarios_gloss_bloque_term': 'vincolato',
    'scenarios_gloss_bloque_def':
        'Il denaro della 3a non può essere ritirato liberamente. Un prelievo anticipato è possibile in particolare per comprare la tua abitazione, metterti in proprio o lasciare definitivamente la Svizzera. Altrimenti resta vincolato fino alla pensione.',
    'etat_civil_eyebrow': 'Simulazione 3a · {taxYear}',
    'etat_civil_question': 'Qual è la tua situazione familiare?',
    'etat_civil_determining_hint': 'Conta la tua situazione al 31 dicembre {taxYear}.',
    'etat_civil_card_celibataire': 'Celibe/nubile',
    'etat_civil_card_marie_pacse': 'Sposato/a o in unione domestica registrata',
    'etat_civil_card_concubinage': 'In coppia, non sposato/a',
    'etat_civil_help_link': 'Perché cambia l’imposta?',
    'etat_civil_recompute_hint': 'La tua scelta precisa l’ipotesi «Situazione». Per una coppia sposata, il risparmio dipende dal reddito dei coniugi.',
    'etat_civil_selection_label': 'La tua scelta',
    'etat_civil_selection_none': 'Non hai ancora scelto.',
    'etat_civil_selection_selected': '{status}',
    'etat_civil_change': 'Modifica',
    'etat_civil_continue': 'Continua',
    'etat_civil_back': 'Indietro',
    'etat_civil_error_no_selection': 'Scegli la tua situazione per continuare.',
    'etat_civil_gloss_marie_term': 'sposato/a o in unione domestica registrata',
    'etat_civil_gloss_marie_def':
        'Sposato/a o in unione domestica registrata e convivente, sei tassato/a insieme al tuo o alla tua partner: i vostri redditi entrano in un calcolo comune. Se sei separato/a in modo duraturo, sei tassato/a come una persona sola.',
    'etat_civil_gloss_concubinage_term': 'in coppia, non sposato/a',
    'etat_civil_gloss_concubinage_def':
        'Senza matrimonio né unione domestica registrata, ciascuno è tassato separatamente, come una persona sola.',
    'etat_civil_gloss_celibataire_term': 'celibe/nubile',
    'etat_civil_gloss_celibataire_def':
        'Dopo una separazione duratura, un divorzio o una vedovanza, l’imposta ti considera come una persona sola.',
    'gloss_dismiss': 'Ho capito',
    'scenarios_pending_fact_tax_year': 'l’anno fiscale',
    'scenarios_pending_fact_commune': 'il tuo comune',
    'scenarios_pending_fact_band': 'la tua fascia di reddito',
    'scenarios_pending_fact_affiliation': 'la tua affiliazione a una cassa pensioni',
    'scenarios_excess_note':
        'Oltre il tuo margine restante, la parte in più non riduce la tua imposta.',
    'scenarios_own_amount_save': 'Usare questo importo',
  },
  'es': <String, String>{
    'scenarios_eyebrow': 'Simulación 3a · {taxYear}',
    'scenarios_choose_line': 'Tú eliges el importe. Aquí tienes el efecto estimado de cada uno.',
    'scenarios_remaining': 'Este año aún puedes aportar hasta {room} CHF.',
    'scenarios_amount': '{amount} CHF',
    'scenarios_amount_max_suffix': ' · el máximo este año',
    'scenarios_effect': 'alrededor de {low} a {high} CHF de impuesto menos',
    'scenarios_already': 'Este año ya has aportado {contributed} CHF.',
    'scenarios_amount_more': '+{amount} CHF',
    'scenarios_amount_rest_suffix': ' · aún posible este año',
    'scenarios_liquidity':
        'El dinero aportado a un 3a queda bloqueado hasta la jubilación, salvo en los casos previstos por la ley.',
    'scenarios_commune_caveat':
        'La estimación parte de la capital del cantón; según tu municipio, el importe puede cambiar.',
    'scenarios_disclaimer': 'Son estimaciones, no un asesoramiento.',
    'scenarios_own_amount': 'Introducir mi propio importe',
    'scenarios_keep_reference': 'Guardar esta estimación',
    'scenarios_reference_kept': 'Estimación guardada.',
    'scenarios_continue': 'Continuar',
    'scenarios_back': 'Atrás',
    'scenarios_plafond20_line': 'Sin caja de pensiones, tu límite 3a depende de tu ingreso (20 %).',
    'scenarios_plafond20_amount': 'Tu límite es de {ceiling} CHF este año.',
    'scenarios_plafond20_effect_note':
        'Con este ingreso, el efecto sobre el impuesto es modesto y depende mucho de tu municipio.',
    'scenarios_plafond20_income_hyp': 'Según tu ingreso por actividad.',
    'scenarios_over_line': 'Ya has aportado {contributed} CHF, por encima del límite de {cap} CHF de este año.',
    'scenarios_over_excess':
        'Has aportado {excess} CHF más que el límite anual ordinario. Según tu situación, este excedente no siempre reduce el impuesto. Consulta con tu proveedor 3a qué se aplica.',
    'scenarios_over_action': 'Ver qué comprobar',
    'scenarios_pending_title': 'Falta un dato para calcular los escenarios.',
    'scenarios_pending_which': 'Falta este dato: {fact}.',
    'scenarios_pending_action': 'Añadir el dato',
    'scenarios_gloss_plafond_term': 'límite',
    'scenarios_gloss_plafond_def':
        'El límite es el total que puedes aportar a tus 3a este año. Con una caja de pensiones: {affiliatedCap} CHF. Sin ella: el 20 % de tu ingreso, hasta un máximo fijado por la ley.',
    'scenarios_gloss_marge_term': 'margen restante',
    'scenarios_gloss_marge_def':
        'Lo que te queda por aportar este año: el límite, menos lo que ya has puesto.',
    'scenarios_gloss_bloque_term': 'bloqueado',
    'scenarios_gloss_bloque_def':
        'El dinero del 3a no se puede retirar libremente. Un retiro anticipado es posible en particular para comprar tu vivienda, establecerte por tu cuenta o dejar Suiza de forma definitiva. Si no, queda bloqueado hasta la jubilación.',
    'etat_civil_eyebrow': 'Simulación 3a · {taxYear}',
    'etat_civil_question': '¿Cuál es tu situación familiar?',
    'etat_civil_determining_hint': 'Cuenta tu situación a 31 de diciembre de {taxYear}.',
    'etat_civil_card_celibataire': 'Soltero/a',
    'etat_civil_card_marie_pacse': 'Casado/a o en unión registrada',
    'etat_civil_card_concubinage': 'En pareja, no casado/a',
    'etat_civil_help_link': '¿Por qué cambia el impuesto?',
    'etat_civil_recompute_hint': 'Tu elección precisa el supuesto «Situación». En una pareja casada, el ahorro depende de los ingresos de ambos.',
    'etat_civil_selection_label': 'Tu elección',
    'etat_civil_selection_none': 'Todavía no has elegido.',
    'etat_civil_selection_selected': '{status}',
    'etat_civil_change': 'Cambiar',
    'etat_civil_continue': 'Continuar',
    'etat_civil_back': 'Atrás',
    'etat_civil_error_no_selection': 'Elige tu situación para continuar.',
    'etat_civil_gloss_marie_term': 'casado/a o en unión registrada',
    'etat_civil_gloss_marie_def':
        'Casado/a o en unión registrada y viviendo en el mismo hogar, tributas junto con tu pareja: vuestros ingresos entran en un cálculo común. Si estás separado/a de forma duradera, tributas como una persona sola.',
    'etat_civil_gloss_concubinage_term': 'en pareja, no casado/a',
    'etat_civil_gloss_concubinage_def':
        'Sin matrimonio ni unión registrada, cada uno tributa por separado, como una persona soltera.',
    'etat_civil_gloss_celibataire_term': 'soltero/a',
    'etat_civil_gloss_celibataire_def':
        'Tras una separación duradera, un divorcio o una viudedad, el impuesto también te considera soltero/a.',
    'gloss_dismiss': 'Entendido',
    'scenarios_pending_fact_tax_year': 'el año fiscal',
    'scenarios_pending_fact_commune': 'tu municipio',
    'scenarios_pending_fact_band': 'tu tramo de ingreso',
    'scenarios_pending_fact_affiliation': 'tu afiliación a una caja de pensiones',
    'scenarios_excess_note':
        'Por encima de tu margen restante, la parte de más no reduce tu impuesto.',
    'scenarios_own_amount_save': 'Usar este importe',
  },
  'pt': <String, String>{
    'scenarios_eyebrow': 'Simulação 3a · {taxYear}',
    'scenarios_choose_line': 'És tu que escolhes o montante. Eis o efeito estimado de cada um.',
    'scenarios_remaining': 'Este ano ainda podes depositar até {room} CHF.',
    'scenarios_amount': '{amount} CHF',
    'scenarios_amount_max_suffix': ' · o máximo este ano',
    'scenarios_effect': 'cerca de {low} a {high} CHF de imposto a menos',
    'scenarios_already': 'Este ano já depositaste {contributed} CHF.',
    'scenarios_amount_more': '+{amount} CHF',
    'scenarios_amount_rest_suffix': ' · ainda possível este ano',
    'scenarios_liquidity':
        'O dinheiro depositado num 3a fica bloqueado até à reforma, salvo nos casos previstos na lei.',
    'scenarios_commune_caveat':
        'A estimativa parte da capital do cantão; consoante o teu município, o montante pode mudar.',
    'scenarios_disclaimer': 'São estimativas, não um aconselhamento.',
    'scenarios_own_amount': 'Inserir o meu próprio montante',
    'scenarios_keep_reference': 'Guardar esta estimativa',
    'scenarios_reference_kept': 'Estimativa guardada.',
    'scenarios_continue': 'Continuar',
    'scenarios_back': 'Voltar',
    'scenarios_plafond20_line': 'Sem caixa de pensões, o teu limite 3a depende do teu rendimento (20%).',
    'scenarios_plafond20_amount': 'O teu limite é de {ceiling} CHF este ano.',
    'scenarios_plafond20_effect_note':
        'Com este rendimento, o efeito no imposto é modesto e depende muito do teu município.',
    'scenarios_plafond20_income_hyp': 'Com base no teu rendimento de atividade.',
    'scenarios_over_line': 'Já depositaste {contributed} CHF, acima do limite de {cap} CHF deste ano.',
    'scenarios_over_excess':
        'Depositaste {excess} CHF a mais do que o limite anual ordinário. Consoante a tua situação, este excedente nem sempre reduz o imposto. Confirma com o teu fornecedor 3a o que se aplica.',
    'scenarios_over_action': 'Ver o que verificar',
    'scenarios_pending_title': 'Falta uma informação para calcular os cenários.',
    'scenarios_pending_which': 'Informação em falta: {fact}.',
    'scenarios_pending_action': 'Adicionar a informação',
    'scenarios_gloss_plafond_term': 'limite',
    'scenarios_gloss_plafond_def':
        'O limite é o total que podes depositar nas tuas 3a este ano. Com uma caixa de pensões: {affiliatedCap} CHF. Sem ela: 20% do teu rendimento, até um máximo fixado pela lei.',
    'scenarios_gloss_marge_term': 'margem restante',
    'scenarios_gloss_marge_def':
        'O que te falta depositar este ano: o limite, menos o que já puseste.',
    'scenarios_gloss_bloque_term': 'bloqueado',
    'scenarios_gloss_bloque_def':
        'O dinheiro do 3a não pode ser levantado livremente. Um levantamento antecipado é possível, em particular, para comprar a tua habitação, começar a trabalhar por conta própria ou deixar definitivamente a Suíça. Caso contrário, fica bloqueado até à reforma.',
    'etat_civil_eyebrow': 'Simulação 3a · {taxYear}',
    'etat_civil_question': 'Qual é a tua situação familiar?',
    'etat_civil_determining_hint': 'Conta a tua situação a 31 de dezembro de {taxYear}.',
    'etat_civil_card_celibataire': 'Solteiro/a',
    'etat_civil_card_marie_pacse': 'Casado/a ou em parceria registada',
    'etat_civil_card_concubinage': 'Em casal, não casado/a',
    'etat_civil_help_link': 'Porque é que isto muda o imposto?',
    'etat_civil_recompute_hint': 'A tua escolha detalha a hipótese «Situação». Num casal casado, a poupança depende dos rendimentos de ambos.',
    'etat_civil_selection_label': 'A tua escolha',
    'etat_civil_selection_none': 'Ainda não escolheste.',
    'etat_civil_selection_selected': '{status}',
    'etat_civil_change': 'Alterar',
    'etat_civil_continue': 'Continuar',
    'etat_civil_back': 'Voltar',
    'etat_civil_error_no_selection': 'Escolhe a tua situação para continuar.',
    'etat_civil_gloss_marie_term': 'casado/a ou em parceria registada',
    'etat_civil_gloss_marie_def':
        'Casado/a ou em parceria registada e a viver em economia comum, és tributado/a em conjunto com o teu ou a tua parceira: os vossos rendimentos entram num cálculo comum. Se estás separado/a de forma duradoura, és tributado/a como uma pessoa sozinha.',
    'etat_civil_gloss_concubinage_term': 'em casal, não casado/a',
    'etat_civil_gloss_concubinage_def':
        'Sem casamento nem parceria registada, cada um é tributado separadamente, como uma pessoa solteira.',
    'etat_civil_gloss_celibataire_term': 'solteiro/a',
    'etat_civil_gloss_celibataire_def':
        'Após uma separação duradoura, um divórcio ou uma viuvez, o imposto também te considera solteiro/a.',
    'gloss_dismiss': 'Percebi',
    'scenarios_pending_fact_tax_year': 'o ano fiscal',
    'scenarios_pending_fact_commune': 'o teu município',
    'scenarios_pending_fact_band': 'o teu escalão de rendimento',
    'scenarios_pending_fact_affiliation': 'a tua afiliação a uma caixa de pensões',
    'scenarios_excess_note':
        'Acima da tua margem restante, a parte a mais não reduz o teu imposto.',
    'scenarios_own_amount_save': 'Usar este montante',
  },
};

/// Resolves the R4 copy map for [languageCode], falling back to fr.
Map<String, String> r4CopyFor(String languageCode) =>
    r4Copy[languageCode] ?? r4Copy['fr']!;

// ---------------------------------------------------------------------------
// FIXTURES — engine-derived (r4-engine-fixtures.yaml). NEVER re-derived here.
// Every saving value is the fixture's rounded raw engine output; the widget
// applies floor_to_100 on both bounds at display time (rounding_rule,
// inherited from batch21 eclairage-scope.yaml:44 — never collapse to a point).
// ---------------------------------------------------------------------------

/// LIFD art. 33 al. 1 let. e — the small-3a ceiling with an LPP affiliation.
/// apps/mobile/lib/constants/social_insurance.dart:398.
const int r4AffiliatedCapChf = 7258;

/// OPP3 art. 7 — the big-3a ceiling without an LPP affiliation:
/// min(0.20 * net earned income, r4NonAffiliatedMaxCapChf).
/// apps/mobile/lib/constants/social_insurance.dart:401,404.
const int r4NonAffiliatedMaxCapChf = 36288;
const double r4NonAffiliatedRate = 0.20;

/// The ceiling_derivation_opp3 rule, GRAVED by the sealed contract (distinct
/// from the DEFERRED non-affilié routing decision): the annual cap derives
/// from affiliation + income, never from employment status, never a flat
/// 7258 for a non-affilié. Matches the 3 mandatory_contract_test_cases exactly
/// (20 000 -> 4 000 ; 250 000 -> 36 288 clamped ; affiliated any income -> 7 258).
int r4DeriveAnnualCapChf({
  required bool affiliated,
  required int nonAffiliatedIncomeChf,
}) {
  if (affiliated) return r4AffiliatedCapChf;
  final derived = (nonAffiliatedIncomeChf * r4NonAffiliatedRate).round();
  return derived > r4NonAffiliatedMaxCapChf ? r4NonAffiliatedMaxCapChf : derived;
}

/// One discrete, engine-grounded scenario anchor (scenarios_versement
/// scenario_row_shape). `savingLowRaw`/`savingHighRaw` are null for the
/// non-affilié overlay's single max scenario, whose effect is stated
/// QUALITATIVELY (scenarios_plafond20_effect_note) — never a fabricated
/// number (communal_residual_rule.display_rule.at_exact_income).
class R4ScenarioAnchor {
  const R4ScenarioAnchor({
    required this.amountChf,
    this.savingLowRaw,
    this.savingHighRaw,
    this.isMax = false,
  });

  final int amountChf;
  final int? savingLowRaw;
  final int? savingHighRaw;

  /// Marks the top anchor ("le maximum cette année" / "encore possible").
  final bool isMax;

  bool get isQualitative => savingLowRaw == null || savingHighRaw == null;
}

/// nominal_scenarios (r4-engine-fixtures.yaml #2): affilié, plafond 7 258,
/// déjà versé 0, tranche FR 70-100k, célibataire. OFFLINE-LAB LIMITATION
/// (documented, as R3 documented its single grounded refine point): the
/// fixtures cover ONLY this band; other bands have no grounded anchors here.
const List<R4ScenarioAnchor> r4NominalScenarios = <R4ScenarioAnchor>[
  R4ScenarioAnchor(amountChf: 2000, savingLowRaw: 505, savingHighRaw: 618),
  R4ScenarioAnchor(amountChf: 4000, savingLowRaw: 1009, savingHighRaw: 1236),
  R4ScenarioAnchor(
    amountChf: 7258,
    savingLowRaw: 1831,
    savingHighRaw: 2242,
    isMax: true,
  ),
];

/// marge_reduite_incremental (r4-engine-fixtures.yaml #3): déjà versé 4 000,
/// plafond 7 258 -> reste 3 258 ; effet ADDITIONNEL (la marge déjà acquise
/// n'est pas recomptée). OFFLINE-LAB LIMITATION: grounded ONLY at
/// alreadyContributed == 4000; no fixture exists for other partial amounts.
const int r4MargeReduiteGroundedContributedChf = 4000;
const List<R4ScenarioAnchor> r4MargeReduiteScenarios = <R4ScenarioAnchor>[
  R4ScenarioAnchor(amountChf: 1000, savingLowRaw: 252, savingHighRaw: 309),
  R4ScenarioAnchor(
    amountChf: 3258,
    savingLowRaw: 822,
    savingHighRaw: 1007,
    isMax: true,
  ),
];

/// plafond_20pct_exact (r4-engine-fixtures.yaml #4): non-affilié, revenu EXACT
/// 20 000 -> plafond dérivé 4 000. At an exact income the only remaining
/// width is the MEASURED communal dispersion (large) — never a tight number
/// (communal_residual_rule). The harness demo income is 20 000.
const int r4Plafond20DemoIncomeChf = 20000;
