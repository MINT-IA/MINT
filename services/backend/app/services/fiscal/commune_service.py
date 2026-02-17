"""
Service de multiplicateurs communaux suisses.

Fournit les coefficients fiscaux (multiplicateur canton + commune combine)
pour les principales communes suisses. Remplace l'approximation cantonale
unique par des donnees communales precises.

Chaque canton suisse possede son propre systeme de coefficient fiscal
communal (Steuerfuss, centimes additionnels, decimes, moltiplicatore, etc.).
Le multiplicateur total combine la composante cantonale et communale.

Sources:
    - Publications officielles cantonales 2025
    - Administration federale des contributions — Charge fiscale en Suisse 2024
    - LHID art. 1 (harmonisation fiscale)
    - LHID art. 2 al. 1 (autonomie communale en matiere fiscale)

Sprint S20+ — Extension fiscalite communale.
"""

from typing import Dict, List, Optional, Tuple
import unicodedata


# ---------------------------------------------------------------------------
# Compliance constants
# ---------------------------------------------------------------------------

DISCLAIMER = (
    "Coefficients fiscaux approximatifs bases sur les publications cantonales 2025. "
    "Le taux exact depend de la commune, de la confession et de l'annee fiscale. "
    "Pour une estimation precise, consulte le site de ton administration fiscale "
    "communale ou un ou une specialiste fiscal-e. "
    "Outil educatif — ne constitue pas un conseil fiscal (LSFin)."
)

SOURCES = [
    "LHID art. 1 (harmonisation fiscale)",
    "LHID art. 2 al. 1 (autonomie communale en matiere fiscale)",
    "Publications officielles cantonales 2025",
    "Administration federale des contributions — Charge fiscale en Suisse 2024",
]


# ---------------------------------------------------------------------------
# Canton names (French)
# ---------------------------------------------------------------------------

CANTON_NAMES = {
    "ZH": "Zurich",
    "BE": "Berne",
    "LU": "Lucerne",
    "UR": "Uri",
    "SZ": "Schwyz",
    "OW": "Obwald",
    "NW": "Nidwald",
    "GL": "Glaris",
    "ZG": "Zoug",
    "FR": "Fribourg",
    "SO": "Soleure",
    "BS": "Bale-Ville",
    "BL": "Bale-Campagne",
    "SH": "Schaffhouse",
    "AR": "Appenzell RE",
    "AI": "Appenzell RI",
    "SG": "Saint-Gall",
    "GR": "Grisons",
    "AG": "Argovie",
    "TG": "Thurgovie",
    "TI": "Tessin",
    "VD": "Vaud",
    "VS": "Valais",
    "NE": "Neuchatel",
    "GE": "Geneve",
    "JU": "Jura",
}


# ---------------------------------------------------------------------------
# Commune multiplier database
# ---------------------------------------------------------------------------
# Structure per canton:
#   "system": str  — tax system type
#   "base_description": str — description of the system
#   "chef_lieu_multiplier": float — capital city multiplier (fallback)
#   "communes": {
#       "CommuneName": {"npa": [...], "multiplier": float, "steuerfuss": int}
#   }

COMMUNE_DATA: Dict[str, dict] = {
    "ZH": {
        "system": "steuerfuss_pct",
        "base_description": "Pourcentage de l'impot simple cantonal",
        "chef_lieu_multiplier": 2.38,
        "communes": {
            "Zürich": {"npa": [8000, 8001, 8002, 8003, 8004, 8005, 8006, 8008, 8032, 8037, 8038, 8041, 8044, 8045, 8046, 8047, 8048, 8049, 8050, 8051, 8052, 8053, 8055, 8057, 8063, 8064], "multiplier": 2.38, "steuerfuss": 119},
            "Winterthur": {"npa": [8400, 8401, 8402, 8404, 8405, 8406, 8408, 8409, 8410, 8411], "multiplier": 2.44, "steuerfuss": 122},
            "Uster": {"npa": [8610], "multiplier": 2.22, "steuerfuss": 111},
            "Dübendorf": {"npa": [8600], "multiplier": 2.22, "steuerfuss": 111},
            "Dietikon": {"npa": [8953], "multiplier": 2.24, "steuerfuss": 112},
            "Wädenswil": {"npa": [8820], "multiplier": 2.22, "steuerfuss": 111},
            "Bülach": {"npa": [8180], "multiplier": 2.14, "steuerfuss": 107},
            "Horgen": {"npa": [8810], "multiplier": 1.96, "steuerfuss": 98},
            "Adliswil": {"npa": [8134], "multiplier": 2.06, "steuerfuss": 103},
            "Opfikon": {"npa": [8152], "multiplier": 2.00, "steuerfuss": 100},
            "Wetzikon": {"npa": [8620], "multiplier": 2.28, "steuerfuss": 114},
            "Kloten": {"npa": [8302], "multiplier": 2.14, "steuerfuss": 107},
            "Illnau-Effretikon": {"npa": [8307], "multiplier": 2.24, "steuerfuss": 112},
            "Volketswil": {"npa": [8604], "multiplier": 2.00, "steuerfuss": 100},
            "Küsnacht": {"npa": [8700], "multiplier": 1.76, "steuerfuss": 88},
            "Zollikon": {"npa": [8702], "multiplier": 1.60, "steuerfuss": 80},
            "Rüschlikon": {"npa": [8803], "multiplier": 1.48, "steuerfuss": 74},
            "Kilchberg": {"npa": [8802], "multiplier": 1.72, "steuerfuss": 86},
            "Thalwil": {"npa": [8800], "multiplier": 1.76, "steuerfuss": 88},
            "Meilen": {"npa": [8706], "multiplier": 1.80, "steuerfuss": 90},
            "Erlenbach": {"npa": [8703], "multiplier": 1.56, "steuerfuss": 78},
        },
    },
    "BE": {
        "system": "dezime",
        "base_description": "Decimes cantonales sur l'impot de base",
        "chef_lieu_multiplier": 3.06,
        "communes": {
            "Bern": {"npa": [3000, 3001, 3004, 3005, 3006, 3007, 3008, 3010, 3011, 3012, 3013, 3014, 3015, 3018, 3019, 3020, 3027], "multiplier": 3.06, "steuerfuss": 153},
            "Biel/Bienne": {"npa": [2500, 2501, 2502, 2503, 2504, 2505], "multiplier": 3.10, "steuerfuss": 155},
            "Thun": {"npa": [3600, 3602, 3603, 3604, 3607, 3608, 3609], "multiplier": 3.10, "steuerfuss": 155},
            "Köniz": {"npa": [3098, 3097, 3095, 3084], "multiplier": 2.96, "steuerfuss": 148},
            "Burgdorf": {"npa": [3400, 3401, 3402], "multiplier": 3.06, "steuerfuss": 153},
            "Steffisburg": {"npa": [3612, 3613], "multiplier": 2.84, "steuerfuss": 142},
            "Spiez": {"npa": [3700], "multiplier": 2.96, "steuerfuss": 148},
            "Langenthal": {"npa": [4900, 4901], "multiplier": 3.20, "steuerfuss": 160},
            "Muri bei Bern": {"npa": [3074], "multiplier": 2.82, "steuerfuss": 141},
            "Ostermundigen": {"npa": [3072], "multiplier": 3.16, "steuerfuss": 158},
            "Ittigen": {"npa": [3063], "multiplier": 2.86, "steuerfuss": 143},
        },
    },
    "LU": {
        "system": "einheiten",
        "base_description": "Unites d'impot communal",
        "chef_lieu_multiplier": 3.35,
        "communes": {
            "Luzern": {"npa": [6000, 6002, 6003, 6004, 6005, 6006, 6009, 6010, 6012, 6014, 6015], "multiplier": 3.35, "steuerfuss": 175},
            "Emmen": {"npa": [6020, 6032], "multiplier": 3.55, "steuerfuss": 185},
            "Kriens": {"npa": [6010, 6011], "multiplier": 3.45, "steuerfuss": 180},
            "Horw": {"npa": [6048], "multiplier": 3.25, "steuerfuss": 170},
            "Ebikon": {"npa": [6030, 6031], "multiplier": 3.15, "steuerfuss": 165},
            "Sursee": {"npa": [6210], "multiplier": 3.35, "steuerfuss": 175},
            "Meggen": {"npa": [6045], "multiplier": 2.75, "steuerfuss": 145},
        },
    },
    "UR": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en % de l'impot cantonal",
        "chef_lieu_multiplier": 2.05,
        "communes": {
            "Altdorf": {"npa": [6460, 6467], "multiplier": 2.05, "steuerfuss": 105},
        },
    },
    "SZ": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 1.50,
        "communes": {
            "Schwyz": {"npa": [6430, 6431, 6432, 6433, 6434, 6436, 6438], "multiplier": 1.50, "steuerfuss": 150},
            "Freienbach": {"npa": [8807, 8808], "multiplier": 1.30, "steuerfuss": 130},
            "Wollerau": {"npa": [8832], "multiplier": 1.10, "steuerfuss": 110},
            "Küssnacht": {"npa": [6403], "multiplier": 1.40, "steuerfuss": 140},
            "Einsiedeln": {"npa": [8840, 8841], "multiplier": 1.60, "steuerfuss": 160},
            "Lachen": {"npa": [8853], "multiplier": 1.40, "steuerfuss": 140},
            "Arth": {"npa": [6414, 6415], "multiplier": 1.35, "steuerfuss": 135},
            "Feusisberg": {"npa": [8835], "multiplier": 1.15, "steuerfuss": 115},
        },
    },
    "OW": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.30,
        "communes": {
            "Sarnen": {"npa": [6060, 6061, 6062, 6063, 6064], "multiplier": 2.30, "steuerfuss": 115},
        },
    },
    "NW": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 1.60,
        "communes": {
            "Stans": {"npa": [6370, 6371], "multiplier": 1.60, "steuerfuss": 160},
            "Hergiswil": {"npa": [6052], "multiplier": 1.54, "steuerfuss": 154},
            "Buochs": {"npa": [6374], "multiplier": 1.48, "steuerfuss": 148},
        },
    },
    "GL": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.10,
        "communes": {
            "Glarus": {"npa": [8750], "multiplier": 2.10, "steuerfuss": 105},
        },
    },
    "ZG": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en % (tres bas)",
        "chef_lieu_multiplier": 1.15,
        "communes": {
            "Zug": {"npa": [6300, 6301, 6302, 6303, 6304, 6312, 6313, 6314, 6315, 6316, 6317, 6318, 6319], "multiplier": 1.15, "steuerfuss": 60},
            "Baar": {"npa": [6340, 6341], "multiplier": 1.15, "steuerfuss": 60},
            "Cham": {"npa": [6330, 6331, 6332], "multiplier": 1.22, "steuerfuss": 64},
            "Risch": {"npa": [6343], "multiplier": 1.10, "steuerfuss": 56},
            "Steinhausen": {"npa": [6312], "multiplier": 1.15, "steuerfuss": 60},
            "Hünenberg": {"npa": [6331], "multiplier": 1.18, "steuerfuss": 62},
            "Walchwil": {"npa": [6318], "multiplier": 1.12, "steuerfuss": 58},
        },
    },
    "FR": {
        "system": "coefficient",
        "base_description": "Coefficient communal",
        "chef_lieu_multiplier": 2.80,
        "communes": {
            "Fribourg": {"npa": [1700, 1701, 1702, 1703, 1704, 1705, 1708, 1709], "multiplier": 2.80, "steuerfuss": 100},
            "Bulle": {"npa": [1630], "multiplier": 2.60, "steuerfuss": 90},
            "Villars-sur-Glâne": {"npa": [1752], "multiplier": 2.60, "steuerfuss": 90},
            "Marly": {"npa": [1723], "multiplier": 2.70, "steuerfuss": 95},
            "Düdingen": {"npa": [3186], "multiplier": 2.50, "steuerfuss": 85},
            "Murten/Morat": {"npa": [3280], "multiplier": 2.60, "steuerfuss": 90},
        },
    },
    "SO": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.60,
        "communes": {
            "Solothurn": {"npa": [4500, 4502], "multiplier": 2.60, "steuerfuss": 130},
            "Olten": {"npa": [4600, 4601], "multiplier": 2.70, "steuerfuss": 135},
            "Grenchen": {"npa": [2540], "multiplier": 2.80, "steuerfuss": 140},
            "Zuchwil": {"npa": [4528], "multiplier": 2.60, "steuerfuss": 130},
            "Biberist": {"npa": [4562], "multiplier": 2.40, "steuerfuss": 120},
        },
    },
    "BS": {
        "system": "integrated",
        "base_description": "Impot integre (pas de multiplicateur communal separe)",
        "chef_lieu_multiplier": 1.00,
        "communes": {
            "Basel": {"npa": [4000, 4001, 4002, 4003, 4004, 4005, 4007, 4008, 4009, 4010, 4018, 4019, 4020, 4024, 4025, 4030, 4031, 4051, 4052, 4053, 4054, 4055, 4056, 4057, 4058, 4059], "multiplier": 1.00, "steuerfuss": 100},
            "Riehen": {"npa": [4125], "multiplier": 1.00, "steuerfuss": 100},
            "Bettingen": {"npa": [4126], "multiplier": 1.00, "steuerfuss": 100},
        },
    },
    "BL": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.85,
        "communes": {
            "Liestal": {"npa": [4410, 4411, 4412], "multiplier": 2.85, "steuerfuss": 143},
            "Allschwil": {"npa": [4123], "multiplier": 2.70, "steuerfuss": 135},
            "Reinach": {"npa": [4153], "multiplier": 2.60, "steuerfuss": 130},
            "Muttenz": {"npa": [4132], "multiplier": 2.65, "steuerfuss": 133},
            "Binningen": {"npa": [4102], "multiplier": 2.70, "steuerfuss": 135},
            "Pratteln": {"npa": [4133], "multiplier": 2.75, "steuerfuss": 138},
            "Oberwil": {"npa": [4104], "multiplier": 2.50, "steuerfuss": 125},
            "Birsfelden": {"npa": [4127], "multiplier": 3.10, "steuerfuss": 155},
        },
    },
    "SH": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.20,
        "communes": {
            "Schaffhausen": {"npa": [8200, 8201, 8202, 8203, 8204, 8207, 8208], "multiplier": 2.20, "steuerfuss": 110},
            "Neuhausen am Rheinfall": {"npa": [8212], "multiplier": 2.30, "steuerfuss": 115},
        },
    },
    "AR": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.50,
        "communes": {
            "Herisau": {"npa": [9100, 9101, 9102], "multiplier": 2.50, "steuerfuss": 125},
            "Teufen": {"npa": [9053], "multiplier": 2.30, "steuerfuss": 115},
            "Speicher": {"npa": [9042], "multiplier": 2.20, "steuerfuss": 110},
        },
    },
    "AI": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 1.80,
        "communes": {
            "Appenzell": {"npa": [9050, 9051], "multiplier": 1.80, "steuerfuss": 90},
        },
    },
    "SG": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.65,
        "communes": {
            "St. Gallen": {"npa": [9000, 9001, 9004, 9006, 9007, 9008, 9010, 9011, 9012, 9013, 9014, 9015, 9016], "multiplier": 2.65, "steuerfuss": 133},
            "Rapperswil-Jona": {"npa": [8640, 8645], "multiplier": 2.40, "steuerfuss": 120},
            "Wil": {"npa": [9500, 9501], "multiplier": 2.65, "steuerfuss": 133},
            "Gossau": {"npa": [9200], "multiplier": 2.80, "steuerfuss": 140},
            "Rorschach": {"npa": [9400], "multiplier": 2.90, "steuerfuss": 145},
            "Buchs": {"npa": [9470, 9471], "multiplier": 2.60, "steuerfuss": 130},
        },
    },
    "GR": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.10,
        "communes": {
            "Chur": {"npa": [7000, 7001, 7002, 7004, 7006, 7007], "multiplier": 2.10, "steuerfuss": 105},
            "Davos": {"npa": [7260, 7265, 7270], "multiplier": 2.00, "steuerfuss": 100},
            "St. Moritz": {"npa": [7500], "multiplier": 1.90, "steuerfuss": 95},
            "Ilanz": {"npa": [7130], "multiplier": 2.20, "steuerfuss": 110},
            "Landquart": {"npa": [7302], "multiplier": 2.05, "steuerfuss": 103},
        },
    },
    "AG": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.30,
        "communes": {
            "Aarau": {"npa": [5000, 5001, 5004], "multiplier": 2.30, "steuerfuss": 115},
            "Baden": {"npa": [5400, 5401, 5404, 5405, 5406], "multiplier": 2.00, "steuerfuss": 100},
            "Wettingen": {"npa": [5430], "multiplier": 2.10, "steuerfuss": 105},
            "Brugg": {"npa": [5200], "multiplier": 2.30, "steuerfuss": 115},
            "Wohlen": {"npa": [5610], "multiplier": 2.30, "steuerfuss": 115},
            "Rheinfelden": {"npa": [4310], "multiplier": 2.20, "steuerfuss": 110},
            "Lenzburg": {"npa": [5600], "multiplier": 2.10, "steuerfuss": 105},
            "Oftringen": {"npa": [4665], "multiplier": 2.20, "steuerfuss": 110},
            "Zofingen": {"npa": [4800], "multiplier": 2.20, "steuerfuss": 110},
            "Spreitenbach": {"npa": [8957], "multiplier": 1.90, "steuerfuss": 95},
        },
    },
    "TG": {
        "system": "steuerfuss_pct",
        "base_description": "Steuerfuss en %",
        "chef_lieu_multiplier": 2.50,
        "communes": {
            "Frauenfeld": {"npa": [8500, 8501, 8502, 8503, 8504, 8505, 8506, 8507, 8508, 8509, 8510], "multiplier": 2.50, "steuerfuss": 125},
            "Kreuzlingen": {"npa": [8280], "multiplier": 2.60, "steuerfuss": 130},
            "Arbon": {"npa": [9320], "multiplier": 2.70, "steuerfuss": 135},
            "Amriswil": {"npa": [8580], "multiplier": 2.40, "steuerfuss": 120},
            "Weinfelden": {"npa": [8570], "multiplier": 2.30, "steuerfuss": 115},
        },
    },
    "TI": {
        "system": "moltiplicatore",
        "base_description": "Moltiplicatore d'imposta comunale (%)",
        "chef_lieu_multiplier": 2.20,
        "communes": {
            "Lugano": {"npa": [6900, 6901, 6902, 6903, 6904, 6906, 6907, 6908, 6912, 6913, 6914, 6915, 6916, 6917, 6918, 6919, 6924, 6925, 6926, 6928, 6929, 6930, 6932, 6933, 6934, 6935, 6936, 6942, 6943, 6944, 6945, 6948, 6949, 6950, 6951, 6952, 6953, 6954, 6955, 6956, 6959, 6960, 6962, 6963, 6964, 6965, 6966, 6967, 6968, 6974, 6976, 6977, 6978, 6979], "multiplier": 2.25, "steuerfuss": 75},
            "Bellinzona": {"npa": [6500, 6501, 6503, 6512, 6513, 6514, 6515, 6517, 6518], "multiplier": 2.40, "steuerfuss": 80},
            "Locarno": {"npa": [6600, 6601, 6604, 6605], "multiplier": 2.55, "steuerfuss": 85},
            "Mendrisio": {"npa": [6850], "multiplier": 2.40, "steuerfuss": 80},
            "Chiasso": {"npa": [6830], "multiplier": 2.70, "steuerfuss": 90},
            "Paradiso": {"npa": [6900], "multiplier": 1.80, "steuerfuss": 60},
            "Collina d'Oro": {"npa": [6926], "multiplier": 1.65, "steuerfuss": 55},
        },
    },
    "VD": {
        "system": "coefficient",
        "base_description": "Coefficient communal (centimes additionnels)",
        "chef_lieu_multiplier": 2.45,
        "communes": {
            "Lausanne": {"npa": [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1010, 1011, 1012, 1018], "multiplier": 2.45, "steuerfuss": 79},
            "Yverdon-les-Bains": {"npa": [1400, 1401], "multiplier": 2.60, "steuerfuss": 84},
            "Montreux": {"npa": [1820, 1822, 1823, 1824], "multiplier": 2.50, "steuerfuss": 81},
            "Renens": {"npa": [1020], "multiplier": 2.55, "steuerfuss": 82},
            "Nyon": {"npa": [1260], "multiplier": 2.40, "steuerfuss": 77},
            "Vevey": {"npa": [1800], "multiplier": 2.55, "steuerfuss": 82},
            "Morges": {"npa": [1110], "multiplier": 2.40, "steuerfuss": 77},
            "Prilly": {"npa": [1008], "multiplier": 2.45, "steuerfuss": 79},
            "Pully": {"npa": [1009], "multiplier": 2.30, "steuerfuss": 74},
            "Ecublens": {"npa": [1024], "multiplier": 2.30, "steuerfuss": 74},
            "La Tour-de-Peilz": {"npa": [1814], "multiplier": 2.35, "steuerfuss": 76},
            "Gland": {"npa": [1196], "multiplier": 2.35, "steuerfuss": 76},
            "Bussigny": {"npa": [1030], "multiplier": 2.35, "steuerfuss": 76},
            "Aigle": {"npa": [1860], "multiplier": 2.55, "steuerfuss": 82},
            "Rolle": {"npa": [1180], "multiplier": 2.25, "steuerfuss": 72},
        },
    },
    "VS": {
        "system": "coefficient",
        "base_description": "Coefficient communal",
        "chef_lieu_multiplier": 2.35,
        "communes": {
            "Sion": {"npa": [1950, 1951], "multiplier": 2.35, "steuerfuss": 100},
            "Sierre": {"npa": [3960], "multiplier": 2.55, "steuerfuss": 110},
            "Martigny": {"npa": [1920], "multiplier": 2.45, "steuerfuss": 105},
            "Monthey": {"npa": [1870], "multiplier": 2.65, "steuerfuss": 115},
            "Visp": {"npa": [3930], "multiplier": 2.45, "steuerfuss": 105},
            "Brig-Glis": {"npa": [3900, 3901], "multiplier": 2.55, "steuerfuss": 110},
            "Naters": {"npa": [3904], "multiplier": 2.50, "steuerfuss": 108},
            "Bagnes/Verbier": {"npa": [1936], "multiplier": 2.20, "steuerfuss": 95},
            "Crans-Montana": {"npa": [3963], "multiplier": 2.10, "steuerfuss": 90},
            "Zermatt": {"npa": [3920], "multiplier": 1.90, "steuerfuss": 80},
        },
    },
    "NE": {
        "system": "centimes_additionnels",
        "base_description": "Centimes additionnels",
        "chef_lieu_multiplier": 3.00,
        "communes": {
            "Neuchâtel": {"npa": [2000, 2001, 2002, 2006, 2007, 2008, 2009, 2012], "multiplier": 3.00, "steuerfuss": 100},
            "La Chaux-de-Fonds": {"npa": [2300, 2301, 2302, 2303, 2304], "multiplier": 3.30, "steuerfuss": 110},
            "Le Locle": {"npa": [2400], "multiplier": 3.20, "steuerfuss": 107},
            "Val-de-Travers": {"npa": [2105, 2106, 2108, 2112, 2113, 2114, 2115, 2116, 2117], "multiplier": 3.15, "steuerfuss": 105},
            "Milvignes": {"npa": [2013, 2014, 2016], "multiplier": 2.80, "steuerfuss": 93},
        },
    },
    "GE": {
        "system": "centimes_additionnels",
        "base_description": "Centimes additionnels communaux",
        "chef_lieu_multiplier": 2.40,
        "communes": {
            "Genève": {"npa": [1200, 1201, 1202, 1203, 1204, 1205, 1206, 1207, 1208, 1209, 1210, 1211, 1212, 1213, 1214, 1215, 1216, 1217, 1218, 1219, 1220, 1222, 1223, 1224, 1225, 1226, 1227, 1228], "multiplier": 2.40, "steuerfuss": 45},
            "Vernier": {"npa": [1214, 1220], "multiplier": 2.50, "steuerfuss": 48},
            "Lancy": {"npa": [1212], "multiplier": 2.45, "steuerfuss": 46},
            "Meyrin": {"npa": [1217], "multiplier": 2.55, "steuerfuss": 49},
            "Carouge": {"npa": [1227], "multiplier": 2.50, "steuerfuss": 48},
            "Onex": {"npa": [1213], "multiplier": 2.55, "steuerfuss": 49},
            "Thônex": {"npa": [1226], "multiplier": 2.45, "steuerfuss": 46},
            "Plan-les-Ouates": {"npa": [1228], "multiplier": 2.35, "steuerfuss": 44},
            "Bernex": {"npa": [1233], "multiplier": 2.50, "steuerfuss": 48},
            "Chêne-Bougeries": {"npa": [1224], "multiplier": 2.30, "steuerfuss": 43},
            "Grand-Saconnex": {"npa": [1218], "multiplier": 2.30, "steuerfuss": 43},
            "Cologny": {"npa": [1223], "multiplier": 2.10, "steuerfuss": 39},
            "Collonge-Bellerive": {"npa": [1245], "multiplier": 2.15, "steuerfuss": 40},
            "Vandoeuvres": {"npa": [1253], "multiplier": 2.05, "steuerfuss": 38},
            "Genthod": {"npa": [1294], "multiplier": 2.00, "steuerfuss": 37},
        },
    },
    "JU": {
        "system": "centimes_additionnels",
        "base_description": "Centimes additionnels",
        "chef_lieu_multiplier": 3.10,
        "communes": {
            "Delémont": {"npa": [2800, 2802, 2803], "multiplier": 3.10, "steuerfuss": 100},
            "Porrentruy": {"npa": [2900, 2902, 2903], "multiplier": 3.10, "steuerfuss": 100},
            "Moutier": {"npa": [2740], "multiplier": 3.30, "steuerfuss": 107},
        },
    },
}


# ---------------------------------------------------------------------------
# NPA reverse-lookup index (built once at module load)
# ---------------------------------------------------------------------------

_NPA_INDEX: Dict[int, Tuple[str, str]] = {}  # npa -> (canton, commune_name)

for _canton_code, _canton_data in COMMUNE_DATA.items():
    for _commune_name, _commune_info in _canton_data["communes"].items():
        for _npa in _commune_info["npa"]:
            # First match wins (some NPAs may overlap across communes)
            if _npa not in _NPA_INDEX:
                _NPA_INDEX[_npa] = (_canton_code, _commune_name)


# ---------------------------------------------------------------------------
# Helper: normalize string for search (strip accents, lowercase)
# ---------------------------------------------------------------------------

def _normalize(text: str) -> str:
    """Remove accents and lowercase for fuzzy matching."""
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c)).lower()


# ---------------------------------------------------------------------------
# Public API functions
# ---------------------------------------------------------------------------

def search_communes(
    query: str,
    canton: Optional[str] = None,
) -> List[dict]:
    """Search communes by name or NPA (postal code).

    Args:
        query: Search string (commune name or NPA number).
        canton: Optional canton filter (2-letter code, e.g. "ZH").

    Returns:
        List of matching commune dicts with canton, name, multiplier,
        npa, steuerfuss, system, disclaimer, sources.
    """
    if not query or not query.strip():
        return []

    query = query.strip()
    results = []

    # Check if query is a numeric NPA
    if query.isdigit():
        npa = int(query)
        result = get_commune_by_npa(npa)
        if result and result.get("commune"):
            # Apply canton filter if specified
            if canton and result["canton"] != canton.upper():
                return []
            return [result]
        return []

    # Text search: normalize query
    normalized_query = _normalize(query)

    cantons_to_search = (
        {canton.upper(): COMMUNE_DATA[canton.upper()]}
        if canton and canton.upper() in COMMUNE_DATA
        else COMMUNE_DATA
    )

    for canton_code, canton_data in cantons_to_search.items():
        for commune_name, commune_info in canton_data["communes"].items():
            normalized_name = _normalize(commune_name)
            if normalized_query in normalized_name:
                results.append(_build_commune_dict(
                    canton_code, commune_name, commune_info, canton_data
                ))

    # Sort by relevance: exact match first, then alphabetical
    results.sort(key=lambda r: (
        0 if _normalize(r["commune"]) == normalized_query else 1,
        r["commune"],
    ))

    return results


def get_commune_multiplier(
    canton: str,
    commune: str,
) -> float:
    """Get the tax multiplier for a specific commune.

    Falls back to chef-lieu multiplier if commune is not found.

    Args:
        canton: Canton code (2 letters).
        commune: Commune name.

    Returns:
        Tax multiplier (float).

    Raises:
        ValueError: If canton code is unknown.
    """
    canton = canton.upper()
    if canton not in COMMUNE_DATA:
        raise ValueError(
            f"Canton inconnu: '{canton}'. "
            f"Codes valides: {', '.join(sorted(COMMUNE_DATA.keys()))}"
        )

    canton_data = COMMUNE_DATA[canton]

    # Exact match
    if commune in canton_data["communes"]:
        return canton_data["communes"][commune]["multiplier"]

    # Normalized search for fuzzy match
    normalized_commune = _normalize(commune)
    for name, info in canton_data["communes"].items():
        if _normalize(name) == normalized_commune:
            return info["multiplier"]

    # Fallback: chef-lieu multiplier
    return canton_data["chef_lieu_multiplier"]


def get_commune_by_npa(npa: int) -> dict:
    """Lookup a commune by its postal code (NPA).

    Args:
        npa: Swiss postal code (e.g. 8000 for Zurich).

    Returns:
        Dict with commune info, or dict with empty commune if not found.
        Always includes disclaimer and sources.
    """
    if npa in _NPA_INDEX:
        canton_code, commune_name = _NPA_INDEX[npa]
        canton_data = COMMUNE_DATA[canton_code]
        commune_info = canton_data["communes"][commune_name]
        return _build_commune_dict(canton_code, commune_name, commune_info, canton_data)

    # Not found
    return {
        "canton": "",
        "canton_nom": "",
        "commune": "",
        "npa": [npa],
        "multiplier": 0.0,
        "steuerfuss": 0,
        "system": "",
        "disclaimer": DISCLAIMER,
        "sources": list(SOURCES),
    }


def list_communes_by_canton(canton: str) -> List[dict]:
    """List all communes for a given canton, sorted by multiplier ascending.

    Args:
        canton: Canton code (2 letters).

    Returns:
        List of commune dicts sorted by multiplier (cheapest first).

    Raises:
        ValueError: If canton code is unknown.
    """
    canton = canton.upper()
    if canton not in COMMUNE_DATA:
        raise ValueError(
            f"Canton inconnu: '{canton}'. "
            f"Codes valides: {', '.join(sorted(COMMUNE_DATA.keys()))}"
        )

    canton_data = COMMUNE_DATA[canton]
    results = []

    for commune_name, commune_info in canton_data["communes"].items():
        results.append(_build_commune_dict(
            canton, commune_name, commune_info, canton_data
        ))

    # Sort by multiplier ascending
    results.sort(key=lambda r: r["multiplier"])
    return results


def get_cheapest_communes(
    canton: Optional[str] = None,
    limit: int = 10,
) -> List[dict]:
    """Get the cheapest communes by tax multiplier.

    Args:
        canton: Optional canton filter. If None, searches all cantons.
        limit: Maximum number of results (default 10).

    Returns:
        List of commune dicts sorted by multiplier ascending.
    """
    if limit <= 0:
        limit = 10

    results = []

    if canton:
        canton = canton.upper()
        if canton not in COMMUNE_DATA:
            return []
        cantons_to_search = {canton: COMMUNE_DATA[canton]}
    else:
        cantons_to_search = COMMUNE_DATA

    for canton_code, canton_data in cantons_to_search.items():
        for commune_name, commune_info in canton_data["communes"].items():
            results.append(_build_commune_dict(
                canton_code, commune_name, commune_info, canton_data
            ))

    # Sort by multiplier ascending
    results.sort(key=lambda r: r["multiplier"])
    return results[:limit]


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def _build_commune_dict(
    canton_code: str,
    commune_name: str,
    commune_info: dict,
    canton_data: dict,
) -> dict:
    """Build a standardized commune result dict."""
    return {
        "canton": canton_code,
        "canton_nom": CANTON_NAMES.get(canton_code, canton_code),
        "commune": commune_name,
        "npa": commune_info["npa"],
        "multiplier": commune_info["multiplier"],
        "steuerfuss": commune_info["steuerfuss"],
        "system": canton_data["system"],
        "disclaimer": DISCLAIMER,
        "sources": list(SOURCES),
    }
