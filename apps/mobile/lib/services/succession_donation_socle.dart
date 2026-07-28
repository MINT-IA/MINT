// ────────────────────────────────────────────────────────────────────────────
// MINI-SOCLE SUCCESSION/DONATION — miroir Dart du socle backend
// services/backend/app/services/fiscal/succession_donation_socle.py
// (ADR .planning/decisions/2026-07-28-remplacements-succession-donation-immo-lamal.md, P4).
//
// PROVENANCE : constantes LITTÉRALES générées mécaniquement depuis l'archive
// .planning/audit-etat-des-lieux-2026-07/constants-audit/
// succession_donation_2025/socle_extraction.json (ESTV, dossier successions/
// donations, état 1.1.2025, archivé 2026-07-28). Parité verrouillée par
// test/services/succession_donation_socle_test.dart, cellule par cellule.
// NE PAS éditer les valeurs à la main : corriger l'archive, régénérer.
//
// Champs portés côté mobile (mini-socle) : statuts par catégorie, franchises
// CHF, note concubin (condition cantonale de la bascule), plafond de la
// classe au tarif maximal + son caveat. Les notes complètes par catégorie,
// barèmes de base et impôt communal vivent dans le socle backend.
//
// MODÈLE (ADR) : verdict directionnel {statut, plage SEULEMENT si sourcée,
// mécanismes, bascule, source} — plus JAMAIS de « montant × taux plat ».
// Les chaînes de données sourcées ESTV sont en français (comme la source) et
// portent un marqueur lint-ignore : ce sont des constantes de données, pas
// de la copie UI (limitation i18n documentée dans l'unité).
// ────────────────────────────────────────────────────────────────────────────

/// Verdict fiscal directionnel du socle ESTV pour un canton × catégorie.
class SuccessionDonationVerdict {
  /// 'exonere' | 'taxe' | 'taxe_lourd' | 'inconnu'.
  final String statut;

  /// Plafond sourcé de la classe au tarif maximal — null si non sourcé.
  final double? plageMaxPct;

  /// Mécanismes sourcés (franchises, conditions, caveats).
  final List<String> mecanismes;

  /// Variable de bascule (concubins) : mariage/pacte + condition cantonale.
  final String? bascule;

  /// Source primaire citée.
  final String source;

  const SuccessionDonationVerdict({
    required this.statut,
    required this.plageMaxPct,
    required this.mecanismes,
    required this.bascule,
    required this.source,
  });
}

/// Mini-socle succession/donation (ESTV 1.1.2025) — voir en-tête du fichier.
class SuccessionDonationSocle {
  SuccessionDonationSocle._();

  static const String source = 'ESTV Steuermäppchen Erbschafts-/Schenkungssteuer, période 2025, archivé 2026-07-28 (steuermappchen_erbschaft.pdf, 35 p., version 26.11.2025)'; // lint-ignore

  static const List<String> categories = [
    'conjoint',
    'descendant',
    'parent',
    'fratrie',
    'concubin',
    'tiers',
  ];

  static const String _basculeConcubin =
      'Mariage ou partenariat enregistré → exonération ' // lint-ignore
      '(le conjoint est exonéré dans les 26 cantons).'; // lint-ignore

  static const String _luDonationMessage =
      'Lucerne (LU) ne prélève pas d\'impôt sur les donations ; les ' // lint-ignore
      'donations effectuées dans les 5 ans précédant le décès sont ' // lint-ignore
      'toutefois reprises dans la masse successorale imposable ' // lint-ignore
      '(dossier ESTV, état 1.1.2025).'; // lint-ignore

  static const Map<String, Map<String, Object?>> cantons = {
    'ZH': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'parent': 200000, 'fratrie': 15000, 'concubin': 50000},
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': null, // lint-ignore
        'parent': 'franchise 200000 par Elternteil', // lint-ignore
        'fratrie': null, // lint-ignore
        'concubin': 'non listé dans les multiplicateurs -> übrige x6 ; franchise 50000 si >=5 ans de ménage commun avec le défunt/donateur', // lint-ignore
        'tiers': null, // lint-ignore
      },
      'maxEffectifTiersPct': 42,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'BE': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'y compris Stief- und Pflegekinder (Pflegekinder si prise en charge >=2 ans)', // lint-ignore
        'parent': 'déduction générale 12000 (une fois par 5 ans pour le même donateur) ; cumul des libéralités sur 5 ans pour le taux', // lint-ignore
        'fratrie': 'y compris Halbgeschwister', // lint-ignore
        'concubin': '>=10 ans de ménage commun avec même domicile fiscal : x6 ; sinon tiers x16', // lint-ignore
        'tiers': 'neveux/nièces, beaux-enfants/beaux-parents, oncles/tantes : x11', // lint-ignore
      },
      'maxEffectifTiersPct': 40,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'LU': {
      'succession': true,
      'donation': false,
      'concubinExonerationConditionnelle': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'exonere',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'exonérés au niveau CANTONAL ; les Einwohnergemeinden peuvent prélever une Erbanfallsteuer sur les dévolutions aux descendants (taux de base max 1 % + surcharge comme le canton, exonération si <100000) — assimilés : adoptés, enfants naturels sans droit successoral, Stiefkinder, Pflegekinder >=2 ans', // lint-ignore
        'parent': 'taux de base 6 % + surcharge progressive (jusqu\'à +100 % au-delà de 500000) -> max 12 %', // lint-ignore
        'fratrie': 'taux de base 6 % (comme parents, neveux et nièces) + surcharge -> max 12 %', // lint-ignore
        'concubin': 'exonéré si >=2 ans de relation de type conjugal (eheähnlich) avec le défunt ; déduction 2000 pour Lebenspartner ; sinon übrige 20 %', // lint-ignore
        'tiers': 'taux de base 20 % + surcharge jusqu\'à +100 % ; grands-parents/oncles/tantes/cousins 15 % ; domestiques et employés du défunt 6 % (déduction 2000)', // lint-ignore
      },
      'maxEffectifTiersPct': 40,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'UR': {
      'succession': true,
      'donation': true,
      'concubinExonerationConditionnelle': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'exonere',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'Kinder, Adoptiv- und Stiefkinder', // lint-ignore
        'parent': 'Eltern expressément exonérés', // lint-ignore
        'fratrie': '8 % (y compris Stiefgeschwister)', // lint-ignore
        'concubin': 'exonéré si enfants mineurs communs OU >=5 ans de ménage commun avec même domicile fiscal ; sinon tiers 24 %', // lint-ignore
        'tiers': '24 % (übrige erbberechtigte + non-parents) ; oncles/tantes/descendants de fratrie 12 %', // lint-ignore
      },
      'maxEffectifTiersPct': 24,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'SZ': {
      'succession': false,
      'donation': false,
      'statuts': null,
      'franchises': null,
      'notes': null,
      'maxEffectifTiersPct': 0,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'OW': {
      'succession': false,
      'donation': false,
      'statuts': null,
      'franchises': null,
      'notes': null,
      'maxEffectifTiersPct': 0,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'NW': {
      'succession': true,
      'donation': true,
      'concubinExonerationConditionnelle': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'exonere',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'enfants, petits-enfants, arrière-petits-enfants, Stief- und Pflegekinder', // lint-ignore
        'parent': 'Eltern, Stief-/Pflegeeltern et Schwiegereltern exonérés', // lint-ignore
        'fratrie': '5 % (Geschwister et leurs descendants, grands-parents, arrière-grands-parents)', // lint-ignore
        'concubin': 'exonéré si >=5 ans de communauté d\'habitation durable au même domicile ; sinon tiers 15 %', // lint-ignore
        'tiers': '15 % (übrige) ; oncles/tantes et leurs descendants 10 %', // lint-ignore
      },
      'maxEffectifTiersPct': 15,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'GL': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'parent': 50000, 'fratrie': 10000, 'concubin': 10000, 'tiers': 10000},
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'descendants directs et Adoptivkinder exonérés ; Stief- und Pflegekinder TAXÉS à 6 % avec franchise 100000', // lint-ignore
        'parent': '2.5 % (Eltern, Adoptiveltern, Grosseltern) + surcharge selon montant ; franchise 50000 par Elternteil', // lint-ignore
        'fratrie': '4 % + surcharge ; Halbgeschwister 5 %', // lint-ignore
        'concubin': '4 % (assimilé fratrie) si >=5 ans de ménage commun de type conjugal avant la libéralité ; sinon übrige 10 %', // lint-ignore
        'tiers': '10 % + surcharge', // lint-ignore
      },
      'maxEffectifTiersPct': 25,
      'maxEffectifTiersNote': '10 % x 2.5 (surcharge +150 %) = 25 % ; jusqu\'à 30 % si Bausteuerzuschlag de 20 % appliqué', // lint-ignore
    },
    'ZG': {
      'succession': true,
      'donation': true,
      'concubinExonerationConditionnelle': false,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'exonere',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'y compris Stiefkinder', // lint-ignore
        'parent': 'Eltern und Stiefeltern exonérés', // lint-ignore
        'fratrie': 'Geschwister, Stiefgeschwister', // lint-ignore
        'concubin': '« Lebenspartner » exonérés — aucune condition de durée précisée dans la source', // lint-ignore
        'tiers': 'beaux-enfants/beaux-parents 20 % ; grands-parents/oncles/tantes/enfants de fratrie 60 % ; petits-enfants de fratrie/enfants d\'oncles-tantes 80 %', // lint-ignore
      },
      'maxEffectifTiersPct': 20,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'FR': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': '« parents en ligne directe » exonérés ; enfants du conjoint/partenaire, enfants placés ou recueillis et leurs descendants : taxés 7.75 %', // lint-ignore
        'parent': 'ligne directe (ascendants) exonérée', // lint-ignore
        'fratrie': '5.25 %', // lint-ignore
        'concubin': '8.25 % si ménage commun >=10 ans avec même domicile fiscal ; sinon 22 %', // lint-ignore
        'tiers': '22 % ; neveux/oncles 8.25 %, petits-neveux 10.50 %, cousins 12.75 %, descendants de cousins 17.25 %', // lint-ignore
      },
      'maxEffectifTiersPct': 22,
      'maxEffectifTiersNote': 'hors centimes additionnels communaux ; avec centimes (max 70 % selon complément) : jusqu\'à 37.4 %', // lint-ignore
    },
    'SO': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'Nachkommen, Adoptivkinder et leurs descendants', // lint-ignore
        'parent': 'Eltern und Adoptiveltern exonérés', // lint-ignore
        'fratrie': 'barème progressif 4-12 % (marginal max 12 % sur la tranche 76000-167183, puis 10 %)', // lint-ignore
        'concubin': '>=5 ans de ménage commun ininterrompu avec même domicile fiscal au moment de la naissance de la créance fiscale : Klasse 3 (6-18 %) ; sinon Klasse 5', // lint-ignore
        'tiers': '12-36 % ; oncles/tantes/neveux/nièces Klasse 4 (9-27 %)', // lint-ignore
      },
      'maxEffectifTiersPct': 36,
      'maxEffectifTiersNote': 'marginal max Klasse 5 AVANT multiple annuel (non chiffré dans la source) et hors Nachlasstaxe (max 17 pour mille)', // lint-ignore
    },
    'BS': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'Nachkommen, Adoptivnachkommen et Pflegekinder', // lint-ignore
        'parent': '4 % de base (Eltern, Adoptiveltern) + surcharge selon montant -> max 11 %', // lint-ignore
        'fratrie': '6 % de base (avec grands-parents, Halbgeschwister, beaux-enfants/beaux-parents) -> max 16.5 %', // lint-ignore
        'concubin': '6 % de base (« Personen in nichtehelichen Zusammenlebensformen ») — aucune condition de durée précisée dans la source', // lint-ignore
        'tiers': '18 % de base ; neveux/nièces 8 %, oncles/tantes/beaux-frères 10 %, autres parents avec droit successoral 14 %', // lint-ignore
      },
      'maxEffectifTiersPct': 49.5,
      'maxEffectifTiersNote': '18 % x 2.75 (surcharge +175 % au-delà de 3000000)', // lint-ignore
    },
    'BL': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'fratrie': 30000, 'concubin': 30000, 'tiers': 10000},
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'descendants directs ; assimilés : Stief- und Pflegekinder si >=10 ans de ménage commun avant leurs 25 ans (sinon taxés 7.5 % avec franchise 50000)', // lint-ignore
        'parent': 'Eltern expressément exonérés', // lint-ignore
        'fratrie': '15 % (avec grands-parents, arrière-grands-parents, beaux-parents, beaux-enfants, Stiefeltern, Stiefgrosskinder)', // lint-ignore
        'concubin': '15 % si >=5 ans de ménage commun ininterrompu ; sinon übrige 30 % (franchise 10000)', // lint-ignore
        'tiers': '30 % ; oncles/tantes/neveux/cousins etc. 22.5 % (franchise 20000)', // lint-ignore
      },
      'maxEffectifTiersPct': 30,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'SH': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe_lourd',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'parent': 30000, 'fratrie': 10000, 'concubin': 10000, 'tiers': 10000},
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'Nachkommen, Adoptiv- und Stiefkinder ; Pflegekinder assimilés si prise en charge >=2 ans', // lint-ignore
        'parent': 'Eltern, Adoptiv- und Stiefeltern', // lint-ignore
        'fratrie': 'avec grands-parents (voll- und halbbürtige Geschwister)', // lint-ignore
        'concubin': 'aucune disposition spécifique dans la source -> übrige x5', // lint-ignore
        'tiers': 'autres parents souche parentale x3, souche grand-parentale x4', // lint-ignore
      },
      'maxEffectifTiersPct': 50,
      'maxEffectifTiersNote': '10 % x 5 (marginal) ; au-delà de 700000 : 8 % x 5 = 40 % sur la totalité', // lint-ignore
    },
    'AR': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'fratrie': 5000, 'concubin': 10000, 'tiers': 5000},
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'Nachkommen ainsi que Stief- und Pflegekinder', // lint-ignore
        'parent': 'Eltern expressément exonérés', // lint-ignore
        'fratrie': '22 % (avec grands-parents, Stiefeltern, beaux-parents, beaux-enfants)', // lint-ignore
        'concubin': '12 % (« nicht verheiratete Lebenspartner ») — aucune condition de durée précisée dans la source ; déduction 10000 par dévolution', // lint-ignore
        'tiers': '32 %', // lint-ignore
      },
      'maxEffectifTiersPct': 32,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'AI': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'taxe',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe_lourd',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'descendant': 300000, 'parent': 20000, 'fratrie': 5000, 'concubin': 5000, 'tiers': 5000},
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'TAXÉS 1 % (Nachkommen und Stiefkinder) ; franchise 300000 par descendant/Stiefkind/Pflegekind (>=2 ans)', // lint-ignore
        'parent': '4 % (Eltern und Grosseltern) ; franchise 20000 par Elternteil', // lint-ignore
        'fratrie': '6 % (Geschwister und Adoptivgeschwister)', // lint-ignore
        'concubin': 'non mentionné dans la source -> übrige 20 %', // lint-ignore
        'tiers': '20 % ; nièces/neveux 9 %, tantes/oncles/Pflegekinder/Stiefeltern 12 %', // lint-ignore
      },
      'maxEffectifTiersPct': 20,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'SG': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'parent': 25000, 'fratrie': 10000, 'concubin': 25000, 'tiers': 10000},
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'Nachkommen ainsi que Stief- und Pflegekinder', // lint-ignore
        'parent': '10 % (Eltern, Stief-/Pflegeeltern)', // lint-ignore
        'fratrie': '20 % (avec beaux-parents, gendre/bru, grands-parents)', // lint-ignore
        'concubin': '10 % (Konkubinatspartner) — aucune condition de durée précisée dans la source', // lint-ignore
        'tiers': '30 %', // lint-ignore
      },
      'maxEffectifTiersPct': 30,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'GR': {
      'succession': true,
      'donation': true,
      'concubinExonerationConditionnelle': false,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'exonere',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'Nachkommen, Stief-/Pflegekinder, descendants non communs du conjoint/concubin et leurs descendants', // lint-ignore
        'parent': 'Eltern, Stief-/Pflegeeltern exonérés', // lint-ignore
        'fratrie': '5 % (bénéficiaires de la souche parentale / elterlicher Stamm)', // lint-ignore
        'concubin': 'Konkubinatspartner exonérés — aucune condition de durée précisée dans la source', // lint-ignore
        'tiers': '15 % (übrige)', // lint-ignore
      },
      'maxEffectifTiersPct': 15,
      'maxEffectifTiersNote': 'cantonal seul ; impôt communal FACULTATIF en sus (ex. Chur : 20 % pour les tiers -> jusqu\'à 35 % cumulé ; complément dossier FR : communal max 25 % pour les autres bénéficiaires)', // lint-ignore
    },
    'AG': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'Nachkommen, Stiefkinder, Pflegekinder (>=2 ans de prise en charge)', // lint-ignore
        'parent': 'Eltern, Stiefeltern, Pflegeeltern exonérés', // lint-ignore
        'fratrie': 'barème progressif 6-23 % (avec grands-parents)', // lint-ignore
        'concubin': '>=5 ans de ménage commun (même domicile) : Klasse 1, 4-9 % ; sinon Klasse 3', // lint-ignore
        'tiers': 'barème progressif 12-32 %', // lint-ignore
      },
      'maxEffectifTiersPct': 32,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'TG': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe_lourd',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'parent': 20000},
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'Nachkommen exonérés ; Stiefkinder TAXÉS 4 % de base (comme grands-parents/fratrie)', // lint-ignore
        'parent': '2 % de base + surcharge -> max 7 % ; franchise 20000 par Elternteil', // lint-ignore
        'fratrie': '4 % de base (avec grands-parents, Stiefkinder, beaux-enfants, Pflegekinder >=2 ans) -> max 14 %', // lint-ignore
        'concubin': 'non mentionné dans la source -> übrige 8 % de base -> max 28 %', // lint-ignore
        'tiers': '8 % de base ; oncles/tantes/descendants de fratrie 6 % (max 21 %)', // lint-ignore
      },
      'maxEffectifTiersPct': 28,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'TI': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'taxe_lourd',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'non listé explicitement dans la page Steuermäppchen (le tableau des multiples commence aux frères) ; exonération confirmée par le complément dossier_erbschaft_fr (tableau §6, déc. 2024)', // lint-ignore
        'descendant': 'même réserve : confirmé exonéré par le complément dossier_erbschaft_fr (tableau §6)', // lint-ignore
        'parent': 'même réserve : confirmé exonéré par le complément dossier_erbschaft_fr (tableau §6)', // lint-ignore
        'fratrie': 'frères et enfants d\'un autre lit ; taux maximum plafonné à 15.5 %', // lint-ignore
        'concubin': 'non mentionné dans la source -> non-parents x3.0, taux max 35 %', // lint-ignore
        'tiers': 'neveux/oncles/beaux-parents x1.3 (max 18.5 %) ; petits-neveux/cousins/beaux-fils x1.8 (max 27 %)', // lint-ignore
      },
      'maxEffectifTiersPct': 35,
      'maxEffectifTiersNote': 'plafond EXPLICITE « Taux maximum en % » de la source pour la classe x3.0 (sans plafond, 17.85 x 3 = 53.55)', // lint-ignore
    },
    'VD': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'taxe',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe_lourd',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'conjoint survivant et partenaire enregistré', // lint-ignore
        'descendant': 'ligne directe TAXÉE : 1.350 % (part 20000) à 2.859 % (part 500000, extrait du barème) ; déduction 1000000 par souche héréditaire (réduite de 1/100e par tranche de 1000 dès 1001000) ; donations <=300000/an par enfant en ligne directe descendante exonérées', // lint-ignore
        'parent': 'père/mère, grands-parents, arrière-grands-parents, descendants d\'un précédent mariage du conjoint : 2.970-6.289 % (extrait)', // lint-ignore
        'fratrie': 'frères/sœurs, gendres et brus : 5.940-12.500 % (extrait)', // lint-ignore
        'concubin': 'non mentionné dans la source -> autres collatéraux et personnes non apparentées : 17.820-25.000 %', // lint-ignore
        'tiers': '17.820 % (part 20000) à 25.000 % (part 500000, extrait) ; oncles/tantes/neveux 8.910-16.500 % ; grands-oncles/cousins 13.860-20.000 %', // lint-ignore
      },
      'maxEffectifTiersPct': 25,
      'maxEffectifTiersNote': 'valeur au palier 500000 de l\'extrait de barème publié (barème complet non reproduit dans la source) ; hors centimes communaux : avec centimes max (100 % de l\'impôt cantonal), jusqu\'à 50 %', // lint-ignore
    },
    'VS': {
      'succession': true,
      'donation': true,
      'concubinExonerationConditionnelle': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'exonere',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': null, // lint-ignore
        'descendant': 'descendants en ligne directe et enfants adoptifs', // lint-ignore
        'parent': 'ascendants en ligne directe exonérés', // lint-ignore
        'fratrie': '10 % (parentèle des pères et mères)', // lint-ignore
        'concubin': 'exonéré si concubinage éprouvé >=5 ans OU enfant en commun ; sinon autres attributions 25 %', // lint-ignore
        'tiers': '25 % ; parentèle des grands-parents 15 %, des arrière-grands-parents 20 %', // lint-ignore
      },
      'maxEffectifTiersPct': 25,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'NE': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'taxe',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': {'descendant': 50000, 'parent': 50000},
      'notes': <String, String?>{
        'conjoint': 'conjoint exonéré ; partenaire enregistré exonéré seulement si le partenariat a duré au moins 2 ans', // lint-ignore
        'descendant': 'TAXÉS 3 % (héritiers 1ère parentèle = enfants) ; déduction personnelle 50000 pour les enfants (et 50000 pour les descendants d\'un enfant prédécédé)', // lint-ignore
        'parent': '3 % (pères et mères, grands-parents) ; déduction 50000 pour les parents', // lint-ignore
        'fratrie': '15 %', // lint-ignore
        'concubin': '20 % si ménage commun >=5 ans avec le défunt/donateur ; sinon 45 % (sans degré de parenté)', // lint-ignore
        'tiers': '45 % (bénéficiaires sans degré de parenté) ; neveux 18 %, oncles/tantes 20 %, petits-neveux 21 %, cousins 23 %, alliés 2e parentèle 31 %', // lint-ignore
      },
      'maxEffectifTiersPct': 45,
      'maxEffectifTiersNote': null, // lint-ignore
    },
    'GE': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'exonere',
        'fratrie': 'taxe',
        'concubin': 'taxe_lourd',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'EXCEPTION : pas d\'exonération si le défunt/donateur était imposé d\'après la dépense (forfait) lors de l\'une des 3 dernières taxations définitives -> barème 1ère catégorie 0-6 % (succession et donation)', // lint-ignore
        'descendant': 'même exception forfait-dépense : enfants 0-6 %, petits-enfants 2.4-7.2 % (succession) / 3.6-7.2 % (donation), autres descendants 2.6-7.8 % / 3.9-7.8 %', // lint-ignore
        'parent': 'ascendants exonérés, même exception forfait-dépense (père/mère 0-6 %)', // lint-ignore
        'fratrie': 'succession : 6-11 % (>200000) ; donation : 9-12 % (>300000) ; + centimes additionnels cantonaux', // lint-ignore
        'concubin': 'non mentionné dans la source -> autres bénéficiaires', // lint-ignore
        'tiers': 'succession : 20-26 % (>100000) ; donation : 24-26 % ; oncles/tantes/neveux : 8-13 % (succession) / 10.5-14 % (donation) ; + centimes additionnels cantonaux', // lint-ignore
      },
      'maxEffectifTiersPct': 26,
      'maxEffectifTiersNote': 'hors CENTIMES ADDITIONNELS CANTONAUX : fixés chaque année par le Grand Conseil, taux NON CHIFFRÉ dans les deux sources ; aucun centime sur la 1ère catégorie (ligne directe, conjoint, alliés). La charge effective tiers est donc supérieure à 26 % sans que la source permette de la chiffrer', // lint-ignore
    },
    'JU': {
      'succession': true,
      'donation': true,
      'statuts': {
        'conjoint': 'exonere',
        'descendant': 'exonere',
        'parent': 'taxe',
        'fratrie': 'taxe',
        'concubin': 'taxe',
        'tiers': 'taxe_lourd',
      },
      'franchises': null,
      'notes': <String, String?>{
        'conjoint': 'y compris partenaire enregistré', // lint-ignore
        'descendant': 'descendants exonérés ; enfants du conjoint/ex-conjoint/partenaire/ex-partenaire et leurs descendants, enfants placés ou confiés : taxés 7 %', // lint-ignore
        'parent': 'TAXÉS 7 % (les ascendants)', // lint-ignore
        'fratrie': '14 % (avec le conjoint des ascendants)', // lint-ignore
        'concubin': '14 % si ménage commun >10 ans avec le défunt/donateur (idem ses descendants et ceux de l\'ex-concubin >10 ans) ; sinon 35 %', // lint-ignore
        'tiers': '35 % (autres parents, parents par alliance, sans parenté) ; oncles/tantes/neveux/cousins/beaux-frères 21 %', // lint-ignore
      },
      'maxEffectifTiersPct': 35,
      'maxEffectifTiersNote': null, // lint-ignore
    },
  };

  /// Verdict directionnel — miroir de `verdict()` du socle backend.
  static SuccessionDonationVerdict verdict({
    required String canton,
    required String categorie,
    String typeTransmission = 'succession',
  }) {
    if (!categories.contains(categorie)) {
      throw ArgumentError.value(categorie, 'categorie');
    }
    if (typeTransmission != 'succession' && typeTransmission != 'donation') {
      throw ArgumentError.value(typeTransmission, 'typeTransmission');
    }

    final code = canton.trim().toUpperCase();
    final data = cantons[code];

    if (data == null) {
      return const SuccessionDonationVerdict(
        statut: 'inconnu',
        plageMaxPct: null,
        mecanismes: [
          'Canton non couvert par le socle ESTV 2025 — consulter ' // lint-ignore
              'l\'administration fiscale cantonale pour les règles ' // lint-ignore
              'applicables.',
        ],
        bascule: null,
        source: source,
      );
    }

    // Canton sans cet impôt (SZ/OW toujours ; LU côté donation).
    final leveCetImpot = data[typeTransmission] == true;
    if (!leveCetImpot) {
      return SuccessionDonationVerdict(
        statut: 'exonere',
        plageMaxPct: null,
        mecanismes: [
          if (code == 'LU' && typeTransmission == 'donation')
            _luDonationMessage,
        ],
        bascule: null,
        source: source,
      );
    }

    final statuts = data['statuts'] as Map<String, String>;
    final statut = statuts[categorie]!;

    double? plageMaxPct;
    final mecanismes = <String>[];
    if (statut == 'taxe_lourd') {
      final maxPct = data['maxEffectifTiersPct'] as num?;
      if (maxPct != null && maxPct > 0) {
        plageMaxPct = maxPct.toDouble();
        final maxNote = data['maxEffectifTiersNote'] as String?;
        if (maxNote != null) mecanismes.add(maxNote);
      }
    }

    final franchises = data['franchises'] as Map<String, num>?;
    final franchise = franchises?[categorie];
    if (franchise != null) {
      mecanismes.insert(0, 'Franchise ${_fmtChf(franchise)} CHF');
    }

    final notes = data['notes'] as Map<String, String?>?;
    final note = notes?[categorie];
    if (note != null) mecanismes.add(note);

    // Pas de bascule pour une exonération inconditionnelle (GR/ZG) : la
    // source ne documente aucune condition, on n'en suggère pas une.
    String? bascule;
    final exoConditionnelle =
        data['concubinExonerationConditionnelle'] as bool?;
    if (categorie == 'concubin' &&
        (statut != 'exonere' || exoConditionnelle == true)) {
      bascule = note == null
          ? _basculeConcubin
          : '$_basculeConcubin Condition cantonale actuelle pour ' // lint-ignore
              'concubin·e : $note'; // lint-ignore
    }

    return SuccessionDonationVerdict(
      statut: statut,
      plageMaxPct: plageMaxPct,
      mecanismes: mecanismes,
      bascule: bascule,
      source: source,
    );
  }

  static String _fmtChf(num montant) {
    final raw = montant.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write("'");
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }
}
