"""
Constantes centralisees pour MINT backend.

Toutes les constantes liees aux assurances sociales suisses (LPP, AVS, AC, 3a)
sont definies ici comme source unique de verite. Les services importent depuis
ce module au lieu de dupliquer les valeurs.

Mise a jour annuelle: quand l'OFAS publie les nouvelles valeurs, modifier
UNIQUEMENT ce fichier. Les tests et services s'adaptent automatiquement.

Source officielle: https://finpension.ch/fr/connaissances/salaire-minimum-et-maximum-lpp/
"""

from app.constants.social_insurance import *  # noqa: F401, F403
