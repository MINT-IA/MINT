# Paquet régulier AVEC fusion de namespace (pkgutil.extend_path) :
# - régulier => bat tout paquet « tools » parasite en site-packages
#   (incident CI 2026-08-04, shadowing via deps backend) ;
# - extend_path => continue de fusionner les autres répertoires tools/
#   du repo présents sur sys.path (ex. services/backend/tools), que le
#   namespace package fusionnait avant ce fix (régression Backend tests
#   test_eval_narrator_bundle_path corrigée ici).
from pkgutil import extend_path
__path__ = extend_path(__path__, __name__)
