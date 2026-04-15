#!/usr/bin/env bash
# E2E smoke against staging. Fails fast if any step breaks.
# Uses: register → patch profile → upload cert Julien → scan-confirm → chat → assertions.
set -euo pipefail

API="https://mint-staging.up.railway.app/api/v1"
CERT="/Users/julienbattaglia/Desktop/MINT/test/golden/Julien/Télécharger le certificat de prévoyance.pdf"
EMAIL="e2e-$(date +%s)@example.com"
PW="E2E2026!"

echo "## 1. register ($EMAIL)"
REG=$(curl -sfS -m 30 -X POST "$API/auth/register" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"birthYear\":1977,\"canton\":\"VS\",\"householdType\":\"couple\"}")
TOKEN=$(echo "$REG" | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
echo "  → token OK"

echo "## 2. patch profile (Julien)"
PID=$(curl -sfS -m 15 "$API/profiles/me" -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
curl -sfS -m 15 -X PATCH "$API/profiles/$PID" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"birthYear":1977,"canton":"VS","householdType":"couple","incomeNetMonthly":7600,"lppInsuredSalary":91967,"has2ndPillar":true,"pillar3aAnnual":7258,"goal":"retire","commune":"Sion","employmentStatus":"salarie"}' >/dev/null
echo "  → profile patched"

echo "## 3. upload certif Julien (Vision)"
B64=$(base64 -i "$CERT")
cat > /tmp/_req.json <<JSON
{"documentType":"lpp_certificate","imageBase64":"$B64","canton":"VS","languageHint":"fr"}
JSON
VISION=$(curl -sfS -m 180 -X POST "$API/documents/extract-vision" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @/tmp/_req.json)
AVOIR=$(echo "$VISION" | python3 -c "import sys,json;d=json.load(sys.stdin);f=next((x for x in d['extractedFields'] if x['fieldName']=='avoirLppTotal'),None);print(f['value'] if f else 'MISSING')")
echo "  → avoirLppTotal extracted: $AVOIR"
[[ "$AVOIR" == "MISSING" ]] && { echo "FAIL: avoirLppTotal not extracted"; exit 1; }

echo "## 4. scan-confirmation"
CONFIRM=$(curl -sfS -m 30 -X POST "$API/documents/scan-confirmation" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"documentType\":\"lpp_certificate\",\"overallConfidence\":0.84,\"extractionMethod\":\"claude_vision\",\"confirmedFields\":[{\"fieldName\":\"avoirLppTotal\",\"value\":$AVOIR,\"confidence\":\"high\",\"sourceText\":\"Avoir\"}]}")
echo "  → $CONFIRM"

echo "## 5. GET profile (assertion: avoirLpp merged)"
PROF=$(curl -sfS -m 15 "$API/profiles/me" -H "Authorization: Bearer $TOKEN")
AVOIR_IN_PROFILE=$(echo "$PROF" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('avoirLpp') or d.get('lppTotalBalance') or 'ABSENT')")
echo "  → profile.avoirLpp: $AVOIR_IN_PROFILE (expected ~$AVOIR)"
[[ "$AVOIR_IN_PROFILE" == "ABSENT" ]] && echo "❌ BUG #1 CONFIRMED: scan-confirm does not merge to profile"

echo "## 6. coach chat (assertion: cites profile data)"
CHAT=$(curl -sfS -m 60 -X POST "$API/coach/chat" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"message":"Qu'\''est-ce que tu sais de moi? Cite mes chiffres.","language":"fr","cashLevel":3}')
MSG=$(echo "$CHAT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('message',''))")
echo "  → message (first 300 chars): ${MSG:0:300}"
for NUM in "7600" "49" "VS" "1977"; do
  if echo "$MSG" | grep -q "$NUM"; then echo "  ✓ cites $NUM"; else echo "  ✗ MISSING $NUM"; fi
done
WORD_COUNT=$(echo "$MSG" | wc -w | tr -d ' ')
echo "  → word count: $WORD_COUNT (target ≤ 60)"
[[ $WORD_COUNT -gt 100 ]] && echo "❌ BUG #3 CONFIRMED: coach/chat response too long ($WORD_COUNT words)"

echo ""
echo "=== E2E SUMMARY ==="
echo "Register + profile + vision + confirm + chat = completed"
