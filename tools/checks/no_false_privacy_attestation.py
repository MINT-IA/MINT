#!/usr/bin/env python3
"""GATE: forbid false "document never leaves phone" privacy attestations.

Audit état-des-lieux 2026-07 (T16-F02/F34/F36) found user- and release-facing
docs asserting on-device-only document handling while the canonical privacy
policy discloses a real transfer of the document to Anthropic Vision (US). That
is an internally-contradictory, materially false public/compliance attestation.

This check fails (exit 1) if any scanned attestation doc still carries an
absolute on-device promise WHILE the canonical policy discloses the US transfer.
Wire it into CI/lefthook so the false claim cannot be re-introduced.

Design (anti-façade): it is RED on the current tree by construction — it proves
the defect exists — and stays GREEN only once the docs tell the truth.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# Docs that make user/release-facing privacy attestations.
ATTESTATION_DOCS = [
    "LEGAL_RELEASE_CHECK.md",
    "docs/DATA_ACQUISITION_STRATEGY.md",
    "PRIVACY.md",
    "legal/PRIVACY.md",
    # Étiquettes App Store / Play Store — un « Data Not Collected » y est une
    # déclaration opposable à Apple/Google, pas juste du texte marketing.
    "legal/APP_STORE_PRIVACY_LABELS.md",
    # Référence FR de l'app — les 5 autres locales suivent par parité ARB.
    "apps/mobile/lib/l10n/app_fr.arb",
]

# The canonical honest disclosure of the US transfer (source of truth).
CANONICAL_POLICY = "docs/legal/privacy_policy_v2.3.0.md"
TRANSFER_MARKER = "transfer_us_anthropic"

# Absolute on-device promises that are false once a US transfer exists.
# Each pattern is matched case-insensitively on a per-line basis.
FALSE_PROMISE_PATTERNS = [
    r"document never leaves (the |your |ton )?phone",
    r"on-device ocr by default",
    r"aucun document ne (sera|transite|quitte)",
    r"(traitement|parsing).{0,40}(int[ée]gralement|integralement).{0,20}(sur )?ton appareil",
    r"toutes tes donn[ée]es personnelles restent sur ton appareil",
    # Audit T08-F35 (MINT_nosync-27m) : le coach REÇOIT les montants exacts
    # (salaire, LPP, 3a) via _PROFILE_SAFE_FIELDS -> prompt Anthropic US.
    # Toute attestation « agrégé seulement / jamais le salaire exact » est fausse.
    r"re[çc]oit uniquement des donn[ée]es agr[ée]g[ée]es",
    r"jamais (de donn[ée]es personnelles identifiantes \(salaire|ton salaire exact)",
    r"contexte agr[ée]g[ée] \(pas de pii\)",
    r"salaire exact n['’]est (pas|jamais) (envoy|partag)",
    r'"dataTransparencySalaryDetail":.*[Jj]amais envoy',
    # Beads campagne-A (panel 2026-07-24) : le backend est hébergé hors de
    # Suisse (Railway, cf. legal/PRIVACY.md) — toute string affirmant que le
    # relevé/document part vers un « serveur suisse » est fausse. Motif ancré
    # sur « serveur » : les mentions légitimes (« conçu en Suisse », « le 3a
    # en Suisse », le projet futur « hébergement en Suisse en Phase 2 ») ne
    # matchent pas. Les autres géo-attestations fausses de PRIVACY.md
    # (analytics « restent en Suisse ») relèvent d'un bead PRIVACY.md dédié.
    r"serveur\b.{0,15}\bsuisse",
    # Audit 2026-08-14 (.planning/audit/2026-08-14-affirmations-de-localite-fausses.md)
    # — trouve en OUVRANT l'app, pas en relisant. Les motifs ci-dessus visaient
    # des tournures etroites ; ils rataient la formulation SIMPLE, qui est
    # justement celle employee partout. Un garde qui rassure en manquant
    # l'occurrence la plus visible est pire qu'un garde absent.
    #
    # Le profil part au cloud des la creation d'un compte
    # (auth_provider.dart:1434 -> sync.py:350 « cloud profile »), l'OCR local
    # a ete supprime le 2026-04-17 (document_scan_screen.dart:680) et le
    # modele embarque est un stub (slm_engine.dart:1-15).
    r"(tes|vos|les) donn[ée]es restent( chiffr[ée]es)? sur (ton|votre|l['’])"
    r"\s*(appareil|t[ée]l[ée]phone|device)",
    r"analys[ée]{1,2}s? localement",
    r"l['’]extraction se fait sur ton appareil",
    r"n['’]est jamais (stock[ée]e ni )?envoy[ée]e",
    r"fonctionne 100 ?% sur ton appareil",
    r"tourne sur ton appareil",
    r"aucune donn[ée]e ne quitte ton t[ée]l[ée]phone",
    # Étiquettes App Store / Play Store : le profil financier est persisté côté
    # serveur (Railway) ET transmis au coach Anthropic (US) avec les montants
    # exacts, et les documents uploadés partent chez Claude Vision (US). Ces
    # motifs ciblent les FORMULATIONS FAUSSES précises (« tout reste sur
    # l'appareil / financial info local seulement / aucune donnée partagée »),
    # PAS le libellé de catégorie légitime « Data Not Collected » (vrai
    # per-catégorie pour Location, Contacts, etc. — non matché à dessein).
    r"toutes les donn[ée]es personnelles restent sur l['’]appareil",
    r"donn[ée]es financi[èe]res stock[ée]es localement uniquement",
    r"no data shared with third parties",
]

_COMPILED = [re.compile(p, re.IGNORECASE) for p in FALSE_PROMISE_PATTERNS]

# Self-test (Codex #1018 P2): prove each pattern has teeth and none over-matches
# a legitimate line. Each positive must hit ≥1 pattern; every pattern must be
# hit by ≥1 positive (no dead/broken regex); no negative may hit any pattern.
_SELF_TEST_POSITIVES = [
    "your document never leaves your phone",
    "on-device OCR by default for all uploads",
    "aucun document ne quitte l'appareil",
    "le parsing se fait intégralement sur ton appareil",
    "toutes tes données personnelles restent sur ton appareil",
    "le coach reçoit uniquement des données agrégées",
    "on n'envoie jamais ton salaire exact au coach",
    "contexte agrégé (pas de PII) transmis au modèle",
    "ton salaire exact n'est jamais envoyé à Anthropic",
    '"dataTransparencySalaryDetail": "jamais envoyé au serveur"',
    "ton relevé est traité sur notre serveur suisse",
    "toutes les données personnelles restent sur l'appareil",
    "Financial Info — données financières stockées localement uniquement",
    "No data shared with third parties",
    # Audit 2026-08-14 — les phrases REELLES trouvees dans app_fr.arb, pas des
    # paraphrases : un exemple invente ne prouve pas qu'on attrape le vrai.
    '"authGatePrivacyNote": "Tes donnees restent sur ton appareil et sont chiffrees.",',
    '"vaultPrivacy": "Tes documents sont analyses localement et ne sont jamais partages.",',
    '"docScanPrivacyNote": "L\'image est analysee localement (OCR sur l\'appareil).",',
    '"avsGuidePrivacyNote": "L\'extraction se fait sur ton appareil.",',
    '"avsGuidePrivacyNote2": "L\'image de ton extrait n\'est jamais stockee ni envoyee.",',
    '"slmPrivacyMessage": "Le modele fonctionne 100 % sur ton appareil.",',
    '"settingsSlmSubtitle": "Tourne sur ton appareil, meme hors ligne",',
    '"slmPrivacyMessage2": "Aucune donnee ne quitte ton telephone.",',
]
_SELF_TEST_NEGATIVES = [
    "Location: Data Not Collected",                       # legit per-category
    "Contacts: Data Not Collected",                       # legit per-category
    "Financial Info | Oui | Oui | Non | profil synchronisé serveur",
    "shared with Anthropic (US) — coach IA",
    "MINT est conçu en Suisse",                           # « serveur suisse » non matché
    "hébergement en Suisse prévu en Phase 2",             # projet futur légitime
    "le 3a est un pilier suisse",
    "profil pseudonymisé, montants exacts inclus, transmis au coach",
]


def _line_hits(line: str) -> bool:
    return any(rx.search(line) for rx in _COMPILED)


def _self_test() -> int:
    failures: list[str] = []
    for sample in _SELF_TEST_POSITIVES:
        if not _line_hits(sample):
            failures.append(f"MISS (should flag): {sample!r}")
    for sample in _SELF_TEST_NEGATIVES:
        if _line_hits(sample):
            failures.append(f"FALSE POSITIVE (should be clean): {sample!r}")
    # No dead pattern: every regex must be exercised by ≥1 positive.
    for pat, rx in zip(FALSE_PROMISE_PATTERNS, _COMPILED):
        if not any(rx.search(s) for s in _SELF_TEST_POSITIVES):
            failures.append(f"DEAD PATTERN (no positive covers it): {pat!r}")
    if failures:
        print("no_false_privacy_attestation --self-test FAILED:")
        for f in failures:
            print(f"  ✗ {f}")
        return 1
    print(f"no_false_privacy_attestation --self-test OK "
          f"({len(_SELF_TEST_POSITIVES)} flagged, {len(_SELF_TEST_NEGATIVES)} clean, "
          f"{len(FALSE_PROMISE_PATTERNS)} patterns covered).")
    return 0


BASELINE = REPO_ROOT / "tools/checks/_baseline_false_locality_claims.txt"


def _load_baseline() -> set[str]:
    """Les violations HERITEES, nommees une par une.

    Avant l'audit du 2026-08-14 elles passaient en silence : le garde rendait
    OK. Les nommer ne les excuse pas — ça transforme une dette invisible en
    dette enumeree, que ce garde empeche desormais de grossir.
    """
    if not BASELINE.exists():
        return set()
    return {
        line.strip()
        for line in BASELINE.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }


def _read(rel: str) -> list[str] | None:
    path = REPO_ROOT / rel
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def main() -> int:
    policy = _read(CANONICAL_POLICY)
    us_transfer_disclosed = bool(policy) and any(
        TRANSFER_MARKER in line for line in policy
    )

    hits: list[str] = []
    for rel in ATTESTATION_DOCS:
        lines = _read(rel)
        if lines is None:
            continue
        for i, line in enumerate(lines, start=1):
            for rx in _COMPILED:
                if rx.search(line):
                    hits.append(f"{rel}:{i}: {line.strip()}")
                    break

    # CLIQUET. Une violation nommee dans la base est toleree et VISIBLE ; une
    # nouvelle est refusee. La cle ARB sert d'identite : la ligne bouge quand
    # le fichier grossit, la cle non.
    baseline = _load_baseline()
    def _key_of(hit: str) -> str:
        marker = hit.split(': ', 1)[-1].lstrip()
        return marker.split('"')[1] if marker.startswith('"') else marker[:60]

    if "--update-baseline" in sys.argv:
        _write_baseline({_key_of(h) for h in hits})
        print(f"base regeneree — {len(hits)} affirmation(s) heritee(s).")
        return 0

    fresh = [h for h in hits if _key_of(h) not in baseline]
    healed = baseline - {_key_of(h) for h in hits}
    if healed and not fresh:
        print(
            f"ECHEC — {len(healed)} affirmation(s) de la base ont disparu :\n  "
            + "\n  ".join(sorted(healed))
            + "\n\n  Bonne nouvelle, mais la base doit le refleter, sinon elle"
            "\n  decrit un monde qui n'existe plus. Retirer ces lignes de "
            f"\n  {BASELINE.relative_to(REPO_ROOT)}."
        )
        return 1
    hits = fresh

    if hits and us_transfer_disclosed:
        print(
            "FALSE PRIVACY ATTESTATION — these docs promise on-device-only "
            f"document handling, but {CANONICAL_POLICY} discloses a real US "
            f"transfer ({TRANSFER_MARKER}). Align the attestation with reality:\n"
        )
        for h in hits:
            print(f"  ✗ {h}")
        print(
            "\nFix (documents): state that document OCR runs server-side via "
            "Anthropic Vision (US) with PII masking when possible (see "
            f"{CANONICAL_POLICY} §3.3), or remove the false claim."
        )
        print(
            "Fix (coach): exact profile amounts ARE sent to the Anthropic "
            "coach (_PROFILE_SAFE_FIELDS -> prompt) — state it truthfully "
            "(pseudonymized profile incl. amounts; user messages sent as-is), "
            "never claim aggregated-only / never-exact-salary."
        )
        return 1

    if hits and not us_transfer_disclosed:
        # No disclosed transfer => the on-device promise may be truthful. Warn only.
        print(
            "WARN: on-device promises present but no US-transfer disclosure "
            f"found in {CANONICAL_POLICY}; verify the promise is actually true."
        )
        return 0

    if baseline:
        # Ne PAS rendre un « OK » nu : il y a bien des affirmations fausses,
        # elles sont seulement nommees. Taire le compte reproduirait exactement
        # le defaut que l'audit du 2026-08-14 a trouve — un garde qui rassure.
        print(
            f"OK no_false_privacy_attestation — aucune NOUVELLE affirmation, "
            f"mais {len(baseline)} heritee(s) restent a corriger "
            f"({BASELINE.relative_to(REPO_ROOT)})."
        )
        return 0
    print("OK: no false on-device privacy attestation.")
    return 0


def _write_baseline(keys: set[str]) -> None:
    header = (
        "# Affirmations de localite FAUSSES, heritees d'avant l'audit du\n"
        "# 2026-08-14. Avant lui elles passaient EN SILENCE : le garde rendait\n"
        "# OK parce que ses motifs ne visaient que des tournures etroites.\n"
        "#\n"
        "# Les nommer ne les excuse pas. Ca transforme une dette invisible en\n"
        "# dette enumeree — et ce garde empeche desormais qu'elle grossisse.\n"
        "#\n"
        "# CLIQUET : cette liste ne peut que DECROITRE. Une nouvelle\n"
        "# affirmation est refusee ; une affirmation corrigee doit quitter la\n"
        "# liste dans le meme lot.\n"
        "#\n"
        "# Detail, preuves et contre-arguments :\n"
        "#   .planning/audit/2026-08-14-affirmations-de-localite-fausses.md\n"
        "#\n"
        "# Regenerer apres une correction :\n"
        "#   python3 tools/checks/no_false_privacy_attestation.py --update-baseline\n"
        "\n"
    )
    BASELINE.write_text(header + "\n".join(sorted(keys)) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--self-test", action="store_true",
        help="Verify the false-promise patterns catch known lies and not legitimate lines.",
    )
    parser.add_argument(
        "--update-baseline", action="store_true",
        help="Renomme les affirmations heritees. A n'utiliser QUE pour retirer "
             "de la liste ce qui vient d'etre corrige — le cliquet ne remonte pas.",
    )
    args = parser.parse_args()
    sys.exit(_self_test() if args.self_test else main())
