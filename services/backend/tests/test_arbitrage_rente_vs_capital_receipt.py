def test_rente_vs_capital_success_includes_receipt(client):
    resp = client.post(
        "/api/v1/arbitrage/rente-vs-capital",
        json={"capital_lpp_total": 500000, "capital_obligatoire": 300000,
              "capital_surobligatoire": 200000,
              "rente_annuelle_proposee": 30000, "canton": "ZH"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["calculationVersion"] == "backend-l2-rente-vs-capital-v1"
    assert body["missingFields"] == []
    assert "Origine du calcul : comparaison backend L2" in body["receiptLines"]
    assert "Champs manquants : aucun" in body["receiptLines"]
