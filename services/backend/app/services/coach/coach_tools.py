"""
Coach Tools — S56.

Defines the tools (function calling) that Claude can use to show
rich inline widgets in the MINT coach chat.

When the user asks a financial question, Claude chooses the right
tool AND writes a narrative response. The Flutter app renders the
tool result as an interactive widget inside the conversation.

Architecture:
  User question → Claude (system prompt + tools) → text + tool_use
  → Backend extracts tool call → returns {reply, widget} to Flutter
  → Flutter renders text bubble + rich widget inline

Profile input tools (ask_user_input, show_onboarding_progress) allow
Claude to collect missing profile data conversationally. The frontend
renders the appropriate inline input (picker, numeric keyboard, etc.)
based on the `field` parameter.
"""

# The tools Claude can call — each maps to a Flutter widget.
COACH_TOOLS = [
    {
        "name": "show_retirement_comparison",
        "description": (
            "Affiche une comparaison visuelle entre le revenu actuel "
            "et le revenu estime a la retraite. Utilise quand l'utilisateur "
            "pose des questions sur sa retraite, sa pension, son taux de "
            "remplacement ou combien il va toucher."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "today_monthly": {
                    "type": "number",
                    "description": "Revenu net mensuel actuel en CHF",
                },
                "retirement_monthly": {
                    "type": "number",
                    "description": "Revenu mensuel estime a la retraite en CHF",
                },
                "replacement_rate": {
                    "type": "number",
                    "description": "Taux de remplacement en pourcentage",
                },
                "narrative": {
                    "type": "string",
                    "description": "Phrase courte interpretant le resultat (max 15 mots)",
                },
            },
            "required": ["today_monthly", "retirement_monthly", "narrative"],
        },
    },
    {
        "name": "show_budget_overview",
        "description": (
            "Affiche une comparaison visuelle entre les revenus et les depenses. "
            "Utilise quand l'utilisateur pose des questions sur son budget, "
            "ses depenses, sa marge ou combien il lui reste."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "income_monthly": {
                    "type": "number",
                    "description": "Revenu net mensuel en CHF",
                },
                "expenses_monthly": {
                    "type": "number",
                    "description": "Depenses mensuelles totales en CHF",
                },
                "narrative": {
                    "type": "string",
                    "description": "Phrase courte sur la marge (max 15 mots)",
                },
            },
            "required": ["income_monthly", "expenses_monthly", "narrative"],
        },
    },
    {
        "name": "show_score_gauge",
        "description": (
            "Affiche une jauge circulaire montrant un score ou pourcentage. "
            "Utilise pour le score fitness financier, le taux de remplacement, "
            "le niveau de confiance des donnees, ou tout pourcentage important."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Titre de la jauge (ex: 'Score fitness')",
                },
                "value": {
                    "type": "number",
                    "description": "Valeur actuelle",
                },
                "max_value": {
                    "type": "number",
                    "description": "Valeur maximale (defaut 100)",
                },
                "label": {
                    "type": "string",
                    "description": "Label affiche au centre (ex: '57/100')",
                },
                "narrative": {
                    "type": "string",
                    "description": "Phrase interpretant le score",
                },
            },
            "required": ["title", "value", "label"],
        },
    },
    {
        "name": "show_fact_card",
        "description": (
            "Affiche un fait financier unique et percutant avec un gros chiffre. "
            "Utilise pour les impots, l'economie 3a, le rachat LPP, "
            "ou tout chiffre-choc a mettre en valeur."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "eyebrow": {
                    "type": "string",
                    "description": "Petit label au-dessus (ex: 'Economie fiscale')",
                },
                "value": {
                    "type": "string",
                    "description": "Le chiffre hero (ex: 'CHF 1'240')",
                },
                "description": {
                    "type": "string",
                    "description": "Explication courte du chiffre",
                },
                "route": {
                    "type": "string",
                    "description": "Route Flutter pour approfondir (ex: '/pilier-3a')",
                },
            },
            "required": ["eyebrow", "value", "description"],
        },
    },
    {
        "name": "show_choice_comparison",
        "description": (
            "Affiche une comparaison entre deux choix financiers cote a cote. "
            "Utilise pour rente vs capital, rembourser vs investir, "
            "demenager ou rester, franchise haute vs basse."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Titre de la comparaison",
                },
                "left_title": {"type": "string"},
                "left_value": {"type": "string"},
                "left_description": {"type": "string"},
                "right_title": {"type": "string"},
                "right_value": {"type": "string"},
                "right_description": {"type": "string"},
                "route": {
                    "type": "string",
                    "description": "Route Flutter pour la comparaison detaillee",
                },
            },
            "required": [
                "title", "left_title", "left_value", "left_description",
                "right_title", "right_value", "right_description",
            ],
        },
    },
    {
        "name": "show_pillar_breakdown",
        "description": (
            "Affiche la decomposition des 3 piliers suisses (AVS, LPP, 3a). "
            "Utilise quand l'utilisateur demande d'ou vient sa retraite, "
            "comment sont repartis ses piliers, ou veut comprendre le systeme."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "avs_monthly": {
                    "type": "number",
                    "description": "Rente AVS mensuelle estimee en CHF",
                },
                "lpp_monthly": {
                    "type": "number",
                    "description": "Rente LPP mensuelle estimee en CHF",
                },
                "pillar_3a_monthly": {
                    "type": "number",
                    "description": "Equivalent mensuel 3a en CHF (capital / 240 mois)",
                },
                "narrative": {
                    "type": "string",
                    "description": "Phrase sur la repartition",
                },
            },
            "required": ["avs_monthly", "lpp_monthly", "narrative"],
        },
    },
    # --- Profile input tools (conversational onboarding) ---
    {
        "name": "ask_user_input",
        "description": (
            "Demande une information specifique a l'utilisateur pour completer "
            "son profil. Utilise quand une donnee manque pour repondre "
            "correctement. Le frontend affichera le bon type d'input inline "
            "dans le chat."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "field": {
                    "type": "string",
                    "enum": [
                        "age", "salary", "canton", "civil_status",
                        "employment_status", "children", "lpp_certificate",
                    ],
                    "description": "Le champ a demander",
                },
                "message": {
                    "type": "string",
                    "description": (
                        "Message contextuel pour accompagner la demande "
                        "(max 20 mots)"
                    ),
                },
            },
            "required": ["field", "message"],
        },
    },
    {
        "name": "show_onboarding_progress",
        "description": (
            "Affiche la progression du profil utilisateur. "
            "Utilise apres que l'utilisateur a fourni une information."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "completed_fields": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Champs deja remplis",
                },
                "missing_fields": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Champs encore manquants",
                },
                "message": {
                    "type": "string",
                    "description": "Message de progression",
                },
            },
            "required": ["completed_fields", "missing_fields"],
        },
    },
]
