# Voir tools/__init__.py — même logique (régulier + extend_path).
from pkgutil import extend_path
__path__ = extend_path(__path__, __name__)
