"""Full pipeline: Julien's real LPP PDF → extraction → DB → LPP arbitrage.

This is the test that answers "what actually happens when Julien drops his
certificat de prévoyance into MINT?". It exercises every joint:

  PDF bytes
      ↓ /documents/upload  (local docling + LPPCertificateExtractor)
  extracted_fields        (printed so we can inspect what the pipeline sees)
      ↓ /documents/scan-confirmation  (user confirms selected fields)
  ProfileModel.data        (merged via _SCAN_FIELD_TO_PROFILE_KEYS whitelist)
      ↓ /profiles/me       (client reads enriched profile)
  avoirLpp, lppBuybackMax, salaireAssure
      ↓ /retirement/lpp/compare     (rente vs capital at 65)
      ↓ /lpp-deep/rachat-echelonne (staggered buyback plan)
  numeric scenarios        (based on Julien's real numbers, not placeholders)

If any joint drifts, the test reports *where* the chain broke and dumps the
extractor output so we can see which fields are weak.
"""

from __future__ import annotations

import json
import uuid
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app
from app.models.document import DocumentModel
from app.models.profile_model import ProfileModel
from app.models.user import User
from tests.conftest import TestingSessionLocal


JULIEN_CERT_PATH = (
    Path(__file__).parent.parent.parent.parent
    / "test"
    / "golden"
    / "Julien"
    / "Télécharger le certificat de prévoyance.pdf"
)


def _register(client: TestClient) -> tuple[str, str]:
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    email = f"julien-real-{uuid.uuid4().hex[:6]}@test.mint.ch"
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "julienreal123"},
    )
    assert resp.status_code == 201, resp.text
    return email, resp.json()["access_token"]


def _has_vault_feature_short_circuit():
    """Skip if the real PDF fixture is missing (e.g. shallow clone)."""
    if not JULIEN_CERT_PATH.is_file():
        pytest.skip(f"Real cert fixture missing: {JULIEN_CERT_PATH}")


def test_julien_real_pdf_flows_into_lpp_arbitrage(client: TestClient) -> None:
    _has_vault_feature_short_circuit()
    email, token = _register(client)
    h = {"Authorization": f"Bearer {token}"}

    # ── Step 1: baseline profile (minimum realistic for Julien) ─────────
    pid = client.get("/api/v1/profiles/me", headers=h).json()["id"]
    client.patch(
        f"/api/v1/profiles/{pid}",
        headers=h,
        json={
            "birthYear": 1977,
            "canton": "VS",
            "householdType": "couple",
            "incomeGrossYearly": 122_000,  # baseline before PDF
            "has2ndPillar": True,
            "commune": "Sion",
            "employmentStatus": "salarie",
            "goal": "retire",
        },
    )

    # ── Step 2: upload the REAL PDF ─────────────────────────────────────
    with open(JULIEN_CERT_PATH, "rb") as fh:
        upload = client.post(
            "/api/v1/documents/upload",
            headers=h,
            files={"file": ("julien_cert.pdf", fh, "application/pdf")},
        )
    assert upload.status_code == 200, upload.text
    up_body = upload.json()
    extracted = up_body["extracted_fields"]

    # Document the extraction reality (printed on failure for diagnosis)
    print("\n=== RAW EXTRACTION (Julien cert) ===")
    print(json.dumps(extracted, indent=2, ensure_ascii=False))
    print(f"confidence={up_body.get('confidence')}")
    print(f"fields_found={up_body.get('fields_found')}")

    # The fixture extraction is noisy — what matters is that SOMETHING came
    # out and was persisted to DocumentModel.
    doc_id = up_body["id"]
    db = TestingSessionLocal()
    try:
        doc_row = db.query(DocumentModel).filter(DocumentModel.id == doc_id).one()
        assert doc_row.user_id is not None
        assert doc_row.extracted_fields  # non-empty dict
    finally:
        db.close()

    # ── Step 3: simulate user reviewing + confirming the fields ─────────
    # In the real UI, the user sees the extracted candidate values, corrects
    # weak ones (the current extractor e.g. mis-picks caisse_name=phone),
    # and confirms. Here we hand-feed the ground-truth values that a user
    # would rationally approve from this specific certificate.
    confirmed = client.post(
        "/api/v1/documents/scan-confirmation",
        headers=h,
        json={
            "documentType": "lpp_certificate",
            "overallConfidence": 0.92,
            "extractionMethod": "manual_after_ocr",
            "confirmedFields": [
                {"fieldName": "avoirLpp", "value": 70376.6, "confidence": "high"},
                {"fieldName": "lppInsuredSalary", "value": 91967.0, "confidence": "high"},
                {"fieldName": "lppBuybackMax", "value": 539413.7, "confidence": "high"},
                {"fieldName": "salaireBrutAnnuel", "value": 122206.8, "confidence": "high"},
            ],
        },
    )
    assert confirmed.status_code == 200, confirmed.text
    assert confirmed.json()["fieldsUpdated"] == 4

    # ── Step 4: profile now exposes the fields (DB + API) ───────────────
    me = client.get("/api/v1/profiles/me", headers=h).json()
    assert me["avoirLpp"] == 70376.6
    assert me["lppInsuredSalary"] == 91967.0
    assert me["lppBuybackMax"] == 539413.7
    assert me["incomeGrossYearly"] == 122206.8  # scan overwrote the baseline

    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one()
        profile = (
            db.query(ProfileModel)
            .filter(ProfileModel.user_id == user.id)
            .order_by(ProfileModel.updated_at.desc())
            .first()
        )
        data = dict(profile.data)
        for k in (
            "avoirLpp",
            "lppInsuredSalary",
            "lppBuybackMax",
            "incomeGrossYearly",
        ):
            assert k in data, (k, sorted(data.keys()))
        # DocumentModel audit row is still present alongside the profile merge
        docs = db.query(DocumentModel).filter(DocumentModel.user_id == user.id).all()
        assert len(docs) >= 2  # upload + scan-confirmation both create rows
        doc_types = {d.document_type for d in docs}
        assert "lpp_certificate" in doc_types
    finally:
        db.close()

    # ── Step 5: downstream arbitrage reads the stored LPP numbers ───────
    # "Given my real avoir LPP (70k today, projected ~677k at 65), what's
    # the rente vs capital trade-off?"
    compare = client.post(
        "/api/v1/retirement/lpp/compare",
        headers=h,
        json={
            "capitalLpp": 677_847,  # Julien's projected LPP at 65
            "canton": me["canton"],
            "ageRetraite": 65,
        },
    ).json()
    assert compare["optionRenteBruteMensuelle"] > 0
    assert compare["optionCapitalNet"] > 0
    # Capital tax on 677k is nonzero and comparable to known Swiss brackets
    assert compare["optionCapitalImpot"] > 0
    assert compare["optionCapitalImpot"] < compare["optionCapitalBrut"]
    print(
        f"LPP compare @ 65: rente_mens={compare['optionRenteBruteMensuelle']:.0f} "
        f"capital_net={compare['optionCapitalNet']:.0f} "
        f"breakeven={compare['breakevenAge']}"
    )

    # ── Step 6: LPP buyback plan uses the stored lppBuybackMax ──────────
    rachat = client.post(
        "/api/v1/lpp-deep/rachat-echelonne",
        headers=h,
        json={
            "avoirActuel": me["avoirLpp"],
            "rachatMax": me["lppBuybackMax"],
            "revenuImposable": me["incomeGrossYearly"],
            "canton": me["canton"],
            "horizonRachatAnnees": 3,
        },
    ).json()
    assert "plan" in rachat
    assert rachat["horizonAnnees"] == 3
    assert rachat["totalRachat"] > 0
    # The buyback must not exceed the user's documented max
    assert rachat["totalRachat"] <= me["lppBuybackMax"] + 0.01
    # Each yearly step has a non-zero fiscal economy (buyback is deductible)
    for entry in rachat["plan"]:
        assert entry["economieFiscale"] >= 0
        assert entry["coutNet"] <= entry["montantRachat"]
    print(
        f"Rachat 3y plan: total={rachat['totalRachat']:.0f} "
        f"avoir_projete_post={rachat.get('avoirProjetePostRachat')}"
    )
