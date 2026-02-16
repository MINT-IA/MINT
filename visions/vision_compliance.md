# Vision: Compliance — MINT

## Posture: Educational Mentor
Mint is an **aide à la décision** (decision support tool) and an educational mentor. It does NOT provide regulated investment advice, legal advice, or medical advice.

## Alignment with LSFin/OSFin
Mint adopts the spirit of Swiss rules of conduct (LSFin) and clarifications from FINMA:
1. **Transparency on Interests**: All partnership-based recommendations must explicitly disclose that Mint may receive compensation (referral fees).
2. **Conflict Management**: We provide non-partner alternatives for every partnered recommendation to ensure user benefit over commission bias.
3. **No Product Specificity**: We recommend **asset classes** or **strategies** (e.g., "Invest in low-cost 3a Equities fund"), never specific instruments, ISINs, or Tickers.
4. **Assumption Disclosure**: All calculations must clearly state the simplified assumptions (e.g., "Rendement 4%", "Taux marginal 25%").


## Marketing & hooks (Fiscal Mirror / Voisin)
- **Règle d'Or**: Les hooks doivent rester compatibles avec une communication non trompeuse.
- **Interdictions**: Pas d’affirmations absolues ("Gain de 2000CHF"), <!-- compliance:allow -->pas de "garanti", "sans risque", "profit garanti".<!-- compliance:end --> Utilisez des “ordres de grandeur” ("Des profils comme le tien économisent souvent...").
- **H1 (Acquisition)**: Toute estimation fiscale en H1 est **éducative**: elle déclenche une action de compréhension dans MINT, pas un calcul officiel ni une projection de rendement.
- **Transparence**: Chaque hook visuel (pub / social) doit inclure une micro-ligne "estimation basée sur hypothèses".

## Règle "Stress ≠ santé" (Qualité & Ethique)
- **Posture**: Le stress financier est une **charge mentale** ou un **bruit cognitif**, jamais une pathologie.
- **Wording Proscrit**: Diagnostic, traitement, dépression, thérapie, guérir, soigner, patient.
- **Injonctions**: Formulations impératives interdites (ex: injonctions directes). On utilise "Le conseil MINT", "Si... alors...", ou "Il est recommandé de...".
- **Limites**: Toujours rappeler que MINT est un outil pédagogique et ne remplace pas un professionnel de santé.

## Key UX Obligations
- **Disclaimers**: Present on the Report Screen, PDF Export, and any Simulator.
- **Letter Models**: Any generated letter must bear a footer stating: "Template only. Not legal advice. User responsibility."
- **Implementation Intentions**: Use "IF... THEN..." (SI... ALORS...) to empower the user while maintaining a coaching distance.
- **Reporting**: The final report must be durable (PDF available) and contain all mandatory disclosures.

## Data Privacy (LPD)
- No storage of sensitive free-text identifiers (IBAN, etc.).
- Minimal logs (no sensitive financial snapshots in server logs).
- Progressive consent for any data enrichment (e.g., Phase 2 Open Banking).
