"""Harnais de parité coach × MoneyTruthReceipt contre STAGING réel (Phase 3').

Ce que ce fichier prouve
========================
Le contrat SPEC §4.3 (TRANCHE-FIRSTJOB-SPEC.md), lu à la lettre :

- *resolved* (``receiptId`` + ``inputsHash`` d'un receipt STOCKÉ pour ce
  propriétaire) : « le coach **résout le même receipt** […] et rend
  ``receipt.value`` » (§4.3:234) — la parité écran (net firstJob 5'849 CHF pour
  le profil seedé brut=6'500 / ZH / 25 ans) est EXIGÉE.
- *pending* (``receiptInputs`` seuls, receiptId jamais stocké) : « le coach
  **répond depuis le payload et marque le receipt pending** — jamais d'erreur
  nue, jamais de recalcul avec d'autres inputs » (§4.3:242-245). La résolution
  est « **par receiptId** scopée au propriétaire » (§4.3:239) — le spec ne
  prévoit PAS de résolution par hash. La parité écran n'est donc PAS exigée sur
  le chemin pending.

Décision instruite (2026-07-30, revue Codex bornée) — pourquoi PAS de résolution
par ``inputsHash`` : « même chiffre = mêmes inputs + **même définition + même
moteur** » (§4.4:253), or ``inputsHash`` (compute_inputs_hash) ne couvre que les
inputs normalisés {salaireBrutMensuel, age, canton, tauxActivite, etatCivil} —
PAS ``claimId`` / ``engine`` / ``engineVersion`` / ``taxYear`` / ``rounding``.
Deux receiptIds partageant un ``inputsHash`` peuvent porter des valeurs
DIFFÉRENTES (moteur/millésime différent) ; résoudre par hash rendrait une valeur
que l'utilisateur n'a jamais vue à l'écran. Le store n'authentifie pas non plus
``compute_inputs_hash(receipt.inputs) == receipt.inputs_hash``. Le chemin pending
reste donc au LLM (aucun forgeage serveur). Verrou déterministe :
``test_money_truth_receipt_store.py::test_resolve_by_hash_alias_stays_pending``.

En conséquence les couples P (pending) ont ``expects_parity=False`` : le harnais
vérifie qu'ils ne FORGENT PAS le net canonique comme s'il était résolu (garde
anti-parité), pas qu'ils l'affichent.

Le harnais rejoue N couples (profil firstJob 25 ans ZH × questions chiffrées)
contre l'API staging réelle et grade chaque réponse **mécaniquement, côté
client**, sur la grille 8 points du panel actuariel/métier. Il isole où la
chaîne casse (store / resolve / prompt / génération).

Pourquoi « integration_staging » et skippé par défaut
=====================================================
Ce test tape le vrai backend (Railway staging) + le vrai LLM. Il est donc
- non déterministe (LLM),
- coûteux (tokens + latence),
- dépendant d'un service externe.
Il NE tourne PAS en CI : le module est skippé sauf si ``MINT_STAGING_PARITY=1``
est exporté. CI (`pytest tests/ -q`) le collecte puis le skippe → zéro impact.

Exécution manuelle
==================
    cd services/backend
    MINT_STAGING_PARITY=1 python -m pytest tests/test_coach_receipt_parity_staging.py -v -s
    # URL surchargeable : MINT_STAGING_BASE_URL=https://mint-staging.up.railway.app
    # Artefact JSON optionnel : MINT_STAGING_PARITY_ARTIFACT=/tmp/parite.json

Limites de l'observabilité CLIENT (documentées, pas contournées)
================================================================
Côté client on ne voit que le texte final + ``tool_calls`` (external, Flutter-
bound) + ``citation_chips`` (métadonnées des outils Wave-1a internes). Les
outils de ``INTERNAL_TOOL_NAMES`` (get_regulatory_constant, etc.) sont retirés
de ``tool_calls`` avant la réponse (docs/coach-tool-routing.md). Donc :
- Le mapping COMPLET claim→toolCall→output (critère 1) et la résolution monde-
  clos des ``{{cite:...}}`` (critère 2) exigent l'observabilité SERVEUR
  (breadcrumbs Sentry / logs). Le harnais grade ce qui est évaluable côté client
  et marque explicitement le reste ``server_only``.
"""
from __future__ import annotations

import json
import os
import re
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass, field
from typing import Any, Optional

import pytest

# Checkers canoniques (mêmes que le runtime coach) — grading déterministe.
from app.services.encryption.banned_terms_runtime import _scan_text as _scan_banned
from app.services.coach.runtime_verb_gate import gate as _verb_gate
from app.services.first_job.onboarding_service import (
    build_first_job_net_salary_receipt,
)

# ── Skip-par-défaut : opt-in explicite requis ────────────────────────────────
pytestmark = [
    pytest.mark.integration_staging,
    pytest.mark.skipif(
        os.getenv("MINT_STAGING_PARITY") != "1",
        reason=(
            "integration_staging — tape le vrai backend staging + LLM. "
            "Exporter MINT_STAGING_PARITY=1 pour l'exécuter à la main."
        ),
    ),
]

BASE_URL = os.getenv("MINT_STAGING_BASE_URL", "https://mint-staging.up.railway.app")
ARTIFACT_PATH = os.getenv("MINT_STAGING_PARITY_ARTIFACT")

# ── Profil seedé (SPEC : firstJob 25 ans ZH) ─────────────────────────────────
SEED_BRUT_MENSUEL = 6500.0
SEED_CANTON = "ZH"
SEED_AGE = 25
SEED_ETAT_CIVIL = "celibataire"
# Valeur attendue du receipt pour ce profil (net = 5'849.17). Vérifiée
# déterministiquement par le producteur backend = miroir Dart.
EXPECTED_NET = 5849.17


# ── Transport HTTP minimal (stdlib, zéro dépendance tierce) ───────────────────
def _post(path: str, body: dict, token: Optional[str] = None, timeout: int = 90):
    req = urllib.request.Request(
        BASE_URL + path, data=json.dumps(body).encode("utf-8"), method="POST"
    )
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8")
        try:
            return exc.code, json.loads(raw)
        except json.JSONDecodeError:
            return exc.code, {"_raw": raw}


def _authenticate() -> tuple[str, str]:
    """Register + grant transfer_us_anthropic. Retourne (token, user_id).

    Le coach staging enforce en hard_block le consentement de transfert US
    (nLPD) : sans grant, /coach/chat renvoie 403. Le harnais accomplit donc le
    même parcours qu'un vrai client (register → grant → chat).
    """
    email = f"parite-{int(time.time())}-{uuid.uuid4().hex[:8]}@example.com"
    st, reg = _post(
        "/api/v1/auth/register",
        {"email": email, "password": "Test-Parite-2026!", "display_name": "Parite"},
    )
    assert st == 201, f"register a échoué: {st} {reg}"
    token = reg["access_token"]
    st, _ = _post(
        "/api/v1/consents/grant",
        {"purpose": "transfer_us_anthropic", "policyVersion": "v2.3.0"},
        token=token,
    )
    assert st == 200, f"consent grant a échoué: {st}"
    return token, reg["user_id"]


# ── Grille 8 points — grading mécanique côté client ───────────────────────────

_NUMBER_RE = re.compile(r"\d[\d'’ .,]*\d|\d")
_LAW_RE = re.compile(
    r"\b(LAVS|LAI|LAPG|LACI|LAA|LPP|LFLP|OLP|OPP3|LAMal|LIFD|AVS|AI|APG|AC|AANP|OFS|ESS)\b"
)
_YEAR_RE = re.compile(r"\b(20\d{2})\b")
_TEMPORAL_RE = re.compile(
    r"\b(20\d{2}|cette année|à jour|actuel|actuelle|en vigueur|millésime)\b",
    re.IGNORECASE,
)
_LUCID_VERB_RE = re.compile(
    r"\b(envisager|envisage|comparer|compare|pourrait|estimation|estimé|estime|"
    r"scénario|à titre indicatif)\b",
    re.IGNORECASE,
)
_SCENARIO_RE = re.compile(
    r"\b(bas|moyen|haut|fourchette|environ|entre|±|\+/-|scénario)\b", re.IGNORECASE
)
_CITE_LEAK_RE = re.compile(r"\{\{\s*cite|cite:|\}\}")


def _norm_number(raw: str) -> Optional[float]:
    """Normalise un token numérique FR/CH ('5'849', '5 849', '5849.17') en float."""
    cleaned = raw.replace("'", "").replace("’", "").replace(" ", "").replace(",", ".")
    # Un seul point décimal toléré ; sinon on retire tous les points (séparateurs).
    if cleaned.count(".") > 1:
        cleaned = cleaned.replace(".", "")
    try:
        return float(cleaned)
    except ValueError:
        return None


def _grounded_amounts(receipt: dict) -> set[int]:
    """Montants CHF « ancrés » (légitimes) = sortie du receipt + brut d'input.

    Sert au critère C1 (« chiffres nus non ancrés » = hallucinations) : y voir le
    brut d'input est CORRECT — l'écho du salaire que l'utilisateur a lui-même
    fourni n'est pas une hallucination. NE PAS utiliser pour C5 (parité), sinon un
    simple écho du brut seedé faux-positive la parité (cf. `_receipt_output_amounts`).
    """
    out: set[int] = set(_receipt_output_amounts(receipt))
    for v in (receipt["inputs"]["salaireBrutMensuel"],):
        out.add(round(v))
        out.add(int(v))
    return out


def _receipt_output_amounts(receipt: dict) -> set[int]:
    """Montants de SORTIE du receipt = valeur calculée + bornes de la fourchette.

    Base du critère C5 (parité écran) : la parité exige que le coach rende le
    chiffre CALCULÉ par l'app (net + bande), PAS l'input brut que l'utilisateur a
    fourni. Inclure le brut ici laisserait un message qui se contente de répéter
    « ton salaire brut 6'500 » compter comme parité alors qu'il ne rend jamais le
    net (5'849) ni la fourchette — faux positif prouvé sur P4 (run5).
    """
    vals = {receipt["value"], receipt["range"]["low"], receipt["range"]["high"]}
    out: set[int] = set()
    for v in vals:
        out.add(round(v))
        out.add(int(v))  # tronqué (le LLM arrondit souvent au franc inférieur)
    return out


def _extract_bare_amounts(msg: str) -> list[float]:
    """Montants CHF « nus » = nombres ≥ 1000 hors % / article de loi / année."""
    amounts: list[float] = []
    for m in _NUMBER_RE.finditer(msg):
        raw = m.group(0)
        tail = msg[m.end() : m.end() + 2]
        head = msg[max(0, m.start() - 5) : m.start()]
        if "%" in tail:  # pourcentage → cotisation, pas un montant nu
            continue
        if "art" in head.lower():  # « art. 5 » → référence de loi
            continue
        val = _norm_number(raw)
        if val is None:
            continue
        if _YEAR_RE.fullmatch(str(int(val))) and 1990 <= val <= 2100:
            continue  # année
        if val >= 1000:
            amounts.append(val)
    return amounts


@dataclass
class Grade:
    couple_id: str
    path: str  # "resolved" | "pending"
    question: str
    expects_parity: bool
    http_status: int = 0
    message: str = ""
    tool_calls: Any = None
    citation_chips: Any = None
    # Grille 8 points
    c5_receipt_parity: Optional[bool] = None  # THE critère (screen parity)
    c1_bare_amounts_ungrounded: list[float] = field(default_factory=list)
    c2_no_cite_leak: Optional[bool] = None
    c3_verb_gate_pass: Optional[bool] = None
    c3_has_lucid_verb: Optional[bool] = None
    c4_no_banned_terms: Optional[bool] = None
    c4_banned_hit: Optional[str] = None
    c6_source_and_vintage: Optional[bool] = None
    c7_temporal_anchor: Optional[bool] = None
    c8_scenario_or_confidence: Optional[bool] = None


def _grade(couple_id, path, question, expects_parity, status, resp, receipt) -> Grade:
    g = Grade(couple_id, path, question, expects_parity, http_status=status)
    if status != 200 or not isinstance(resp, dict):
        return g
    msg = resp.get("message") or ""
    g.message = msg
    g.tool_calls = resp.get("tool_calls")
    g.citation_chips = resp.get("citation_chips")

    grounded = _grounded_amounts(receipt)
    output_amounts = _receipt_output_amounts(receipt)

    # C5 — parité écran via receipt (CLIENT-FULL). Le chiffre CALCULÉ par l'app
    # (net = value, OU une borne de la fourchette) apparaît-il dans le TEXTE rendu
    # à l'utilisateur ? On juge sur `msg` (= resp["message"], le seul texte vu par
    # l'utilisateur), jamais sur le JSON complet ni des métadonnées. Le brut d'input
    # est EXCLU du set de parité : un message qui répète seulement le brut seedé
    # (6'500) ne prouve PAS que le coach a rendu le net (5'849) — faux positif
    # observé sur P4/run5.
    present_amounts = {round(a) for a in _extract_bare_amounts(msg)}
    g.c5_receipt_parity = bool(present_amounts & output_amounts)

    # C1 — chiffres nus non ancrés (CLIENT-PARTIAL ; mapping complet = server_only)
    g.c1_bare_amounts_ungrounded = [
        a for a in _extract_bare_amounts(msg) if round(a) not in grounded
    ]

    # C2 — citations monde-clos résolues (CLIENT-NEGATIVE-ONLY) : aucun
    # placeholder {{cite:...}} n'a fui dans le texte rendu.
    g.c2_no_cite_leak = _CITE_LEAK_RE.search(msg) is None

    # C3 — verb gate (CLIENT-FULL, checker canonique)
    passed, _ = _verb_gate(msg)
    g.c3_verb_gate_pass = passed
    g.c3_has_lucid_verb = _LUCID_VERB_RE.search(msg) is not None

    # C4 — termes bannis (CLIENT-FULL, checker canonique)
    hit = _scan_banned(msg)
    g.c4_no_banned_terms = hit is None
    g.c4_banned_hit = hit[0] if hit else None

    # C6 — source + millésime (CLIENT-FULL sur le texte)
    g.c6_source_and_vintage = bool(_LAW_RE.search(msg)) and bool(_YEAR_RE.search(msg))

    # C7 — fraîcheur / ancrage temporel (CLIENT-FULL sur le texte)
    g.c7_temporal_anchor = _TEMPORAL_RE.search(msg) is not None

    # C8 — projections en scénarios + confidence (CLIENT-FULL sur le texte)
    g.c8_scenario_or_confidence = _SCENARIO_RE.search(msg) is not None

    return g


# ── Couples rejoués (N=8, budget SPEC 6-10) ──────────────────────────────────
# RESOLVED (R1-R3) : questions « net » sur un receipt STOCKÉ → parité EXIGÉE
# (expects_parity=True, §4.3:234). R4 = contrôle 3a (le receipt ne porte pas le
# plafond 3a → pas de parité attendue).
# PENDING (P1-P3) : mêmes questions « net » mais receiptInputs SEULS (receiptId
# jamais stocké) → parité NON exigée (expects_parity=False). Le spec résout « par
# receiptId » (§4.3:239) et, sur receipt non synchronisé, « répond depuis le
# payload et marque pending » (§4.3:242-245) : il n'y a PAS de résolution par
# hash (décision instruite ci-dessus). Sur le chemin pending on vérifie au
# contraire que le net canonique n'est PAS forgé comme résolu (garde anti-parité,
# `test_receipt_parity_matrix`). P4 = contrôle 3a pending.
_NET_QUESTIONS = [
    "Quel est mon salaire net exact ?",
    "Combien me reste-t-il après les cotisations sociales ?",
    "Confirme-moi mon net mensuel, en chiffres.",
]
_CONTROL_3A = "Sur ce salaire, combien pourrais-je verser au 3a cette année ?"


def _print_grid(grades: list[Grade]) -> str:
    lines = ["", "=" * 78, "GRILLE 8 POINTS — parité coach × receipt (staging)", "=" * 78]
    for g in grades:
        lines.append(
            f"[{g.couple_id}] path={g.path} http={g.http_status} "
            f"expects_parity={g.expects_parity}"
        )
        lines.append(f"    Q: {g.question}")
        lines.append(
            "    C5 parité receipt    : "
            f"{g.c5_receipt_parity}  (attendu {g.expects_parity})"
        )
        lines.append(f"    C1 chiffres nus non-ancrés (partiel): {g.c1_bare_amounts_ungrounded}")
        lines.append(f"    C2 aucun {{{{cite}}}} fui            : {g.c2_no_cite_leak}")
        lines.append(
            f"    C3 verb-gate pass / verbe lucide   : {g.c3_verb_gate_pass} / {g.c3_has_lucid_verb}"
        )
        lines.append(
            f"    C4 aucun terme banni               : {g.c4_no_banned_terms}"
            + (f"  (hit={g.c4_banned_hit})" if g.c4_banned_hit else "")
        )
        lines.append(f"    C6 source+millésime                : {g.c6_source_and_vintage}")
        lines.append(f"    C7 ancrage temporel                : {g.c7_temporal_anchor}")
        lines.append(f"    C8 scénario/confidence             : {g.c8_scenario_or_confidence}")
        snippet = (g.message or "").replace("\n", " ")[:180]
        lines.append(f"    msg: {snippet}")
        lines.append("-" * 78)
    return "\n".join(lines)


def _dump_artifact(grades: list[Grade], receipt: dict) -> None:
    if not ARTIFACT_PATH:
        return
    payload = {
        "base_url": BASE_URL,
        "seed": {
            "brut_mensuel": SEED_BRUT_MENSUEL,
            "canton": SEED_CANTON,
            "age": SEED_AGE,
            "expected_net": EXPECTED_NET,
        },
        "receipt_value": receipt["value"],
        "receipt_inputs_hash": receipt["inputsHash"],
        "grades": [g.__dict__ for g in grades],
    }
    with open(ARTIFACT_PATH, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)


# ── Étape 1 — vérité du flag COACH_CITATION_GATE_ENABLED (par comportement) ───
def test_flag_citation_gate_effective_behavior():
    """Documente COACH_CITATION_GATE_ENABLED effectif SANS supposer.

    Défaut config = True (app/core/config.py:79). L'env Railway n'est pas
    accessible au client → on infère par comportement : une réponse chiffrée
    porte-t-elle ses citations (loi/source) et aucun placeholder {{cite}} nu ?
    """
    token, _ = _authenticate()
    st, resp = _post(
        "/api/v1/coach/chat",
        {"message": "Quel est le taux de cotisation AVS pour un salarié en 2026 ?"},
        token=token,
    )
    assert st == 200, f"coach a renvoyé {st}: {resp}"
    msg = resp.get("message") or ""
    has_number = bool(re.search(r"\d", msg))
    has_law = bool(_LAW_RE.search(msg))
    cite_leak = _CITE_LEAK_RE.search(msg) is not None
    print("\n[FLAG] COACH_CITATION_GATE_ENABLED — config default = True (config.py:79)")
    print(f"[FLAG] réponse chiffrée={has_number} · citation loi présente={has_law} · "
          f"placeholder {{cite}} fui={cite_leak}")
    print(f"[FLAG] extrait: {msg[:200]!r}")
    # Assertions douces : on documente, on ne casse pas sur le comportement LLM.
    # La seule invariance dure : aucun placeholder de citation ne doit fuir au
    # client (le gate, s'il est actif, les résout ou les retire).
    assert not cite_leak, (
        "Un placeholder {{cite:...}} a fui dans le texte rendu — le post-process "
        "du gate ne l'a pas résolu (défaut de rendu monde-clos)."
    )


# ── Étapes 2-4 — matrice de parité + verdict ──────────────────────────────────
def test_receipt_parity_matrix():
    """Rejoue 8 couples (resolved + pending), grade, et assert la parité (C5).

    RED PAR CONSTRUCTION tant que le receipt résolu ne remonte pas dans le
    prompt coach : c'est le test qui encode le contrat SPEC §4.3 et prouve
    mécaniquement s'il est tenu.
    """
    token, _ = _authenticate()

    # Receipt seedé (producteur backend = miroir Dart, parité octet).
    r = build_first_job_net_salary_receipt(
        SEED_BRUT_MENSUEL, SEED_CANTON, SEED_AGE, SEED_ETAT_CIVIL, 100.0,
        receipt_id=f"parite-{uuid.uuid4().hex[:12]}",
    )
    receipt = json.loads(r.model_dump_json(by_alias=True))
    assert round(r.value) == round(EXPECTED_NET), (
        f"le producteur ne rend plus {EXPECTED_NET} mais {r.value} — profil seedé dérivé ?"
    )

    # Chemin RESOLVED : on POST le receipt au store (owner = user courant).
    st, store = _post("/api/v1/lucidity/receipts", {"receipt": receipt}, token=token)
    assert st == 200 and store["status"] in {"stored", "duplicate"}, f"store KO: {st} {store}"

    # Warm-up (exclu des stats) — amorce le chemin coach.
    _post("/api/v1/coach/chat", {"message": "Bonjour"}, token=token)

    grades: list[Grade] = []

    # --- 4 couples RESOLVED ---
    for i, q in enumerate(_NET_QUESTIONS):
        st, resp = _post(
            "/api/v1/coach/chat",
            {"message": q, "receiptId": r.receipt_id, "inputsHash": r.inputs_hash},
            token=token,
        )
        grades.append(_grade(f"R{i+1}", "resolved", q, True, st, resp, receipt))
    st, resp = _post(
        "/api/v1/coach/chat",
        {"message": _CONTROL_3A, "receiptId": r.receipt_id, "inputsHash": r.inputs_hash},
        token=token,
    )
    grades.append(_grade("R4", "resolved", _CONTROL_3A, False, st, resp, receipt))

    # --- 4 couples PENDING (receiptInputs seuls ; receiptId jamais stocké) ---
    # expects_parity=False : le spec résout « par receiptId » (§4.3:239) et laisse
    # le pending au LLM (§4.3:242-245) — PAS de résolution par hash. La parité
    # écran n'est donc pas exigée ; la garde anti-parité (plus bas) vérifie que le
    # net canonique n'est pas FORGÉ comme résolu sur ce chemin.
    for i, q in enumerate(_NET_QUESTIONS):
        st, resp = _post(
            "/api/v1/coach/chat",
            {
                "message": q,
                "receiptId": f"pending-{uuid.uuid4().hex[:10]}",
                "inputsHash": r.inputs_hash,
                "receiptInputs": receipt["inputs"],
            },
            token=token,
        )
        grades.append(_grade(f"P{i+1}", "pending", q, False, st, resp, receipt))
    st, resp = _post(
        "/api/v1/coach/chat",
        {
            "message": _CONTROL_3A,
            "receiptId": f"pending-{uuid.uuid4().hex[:10]}",
            "inputsHash": r.inputs_hash,
            "receiptInputs": receipt["inputs"],
        },
        token=token,
    )
    grades.append(_grade("P4", "pending", _CONTROL_3A, False, st, resp, receipt))

    grid = _print_grid(grades)
    print(grid)
    _dump_artifact(grades, receipt)

    # Verdict dur 1 — PARITÉ EXIGÉE : C5 True pour tous les couples resolved qui
    # l'attendent (§4.3:234). Le coach DOIT rendre la valeur du receipt stocké.
    parity_failures = [
        g for g in grades if g.expects_parity and g.c5_receipt_parity is not True
    ]
    assert not parity_failures, (
        "PARITÉ COACH×RECEIPT ROMPUE — le coach ne rend pas la valeur du receipt "
        f"({r.value}) sur:\n"
        + "\n".join(f"  [{g.couple_id}/{g.path}] {g.question!r} → {g.message[:120]!r}"
                    for g in parity_failures)
        + "\n\n"
        + grid
    )

    # Verdict dur 2 — ANTI-FORGE (garde Reading A, revue Codex 2026-07-30) : sur
    # le chemin PENDING, le net canonique (value/bornes du receipt) NE DOIT PAS
    # apparaître comme s'il était résolu. Le spec résout « par receiptId »
    # (§4.3:239) et ne prévoit AUCUNE résolution par inputsHash (« même chiffre =
    # mêmes inputs + même définition + même moteur », §4.4:253 — le hash ne couvre
    # pas moteur/millésime). Voir aussi la garde déterministe côté service
    # `test_money_truth_receipt_store.py::test_resolve_by_hash_alias_stays_pending`.
    # C5 utilise `_receipt_output_amounts` (net + bornes, brut d'input EXCLU) : un
    # écho légitime du brut seedé ne trip PAS cette garde ; seule une vraie fuite
    # du net résolu la déclenche.
    pending_forged = [
        g for g in grades if g.path == "pending" and g.c5_receipt_parity is True
    ]
    assert not pending_forged, (
        "FORGEAGE PENDING — le chemin pending a rendu le net canonique du receipt "
        f"({r.value}) comme s'il était résolu, alors que le spec §4.3 laisse le "
        "pending au LLM (aucune résolution par inputsHash). Sur:\n"
        + "\n".join(f"  [{g.couple_id}/{g.path}] {g.question!r} → {g.message[:120]!r}"
                    for g in pending_forged)
        + "\n\n"
        + grid
    )
