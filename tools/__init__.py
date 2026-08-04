# Paquet régulier : garantit que tools/ du repo bat tout paquet « tools »
# installé en site-packages (règle Python : un paquet régulier court-circuite
# les namespace packages, quel que soit l ordre de sys.path). Incident CI
# 2026-08-04 : un paquet top-level « tools » tiré par les deps backend masquait
# le namespace du repo et tuait journey_os_check à l import.
