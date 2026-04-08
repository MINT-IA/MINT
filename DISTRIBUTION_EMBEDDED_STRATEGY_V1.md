# MINT Distribution & Embedded Strategy V1
> Distribution is MINT's real moat. This document answers: "Go where users already are."
>
> **Meta**: Product roadmap (Système Vivant v2.0) builds feature logic. THIS document builds the distribution channels that make those features relevant.
>
> Created: 2026-04-06 | Owner: Founder + Embedded Finance Strategist

---

## THESIS

MINT's competitive advantage is NOT standalone features — it's **financial intelligence at the moment of decision**. WeChat Pay didn't compete on transaction speed; it embedded payments into messaging and became inseparable from social. Grab didn't create ride-hailing; it embedded finance into the ride. Revolut didn't invent cards; it embedded them into accounts + travel.

**MINT's moat**: Swiss-specific document intelligence (LPP certs, cantonal deductions, AVS extracts) delivered at 5 critical moments:

1. **When income changes** (salary cert uploaded)
2. **When a life event happens** (marriage, housing, job loss)
3. **When a financial deadline looms** (3a Dec 31, tax filing)
4. **When looking at a financial product** (insurance doc, mortgage offer, pension statement)
5. **When applying for credit** (mortgage pre-approval, employer reference)

Today: MINT waits for users to open the app.
v2.0 + Distribution: MINT appears in context, **uninvited but essential**.

---

## CORE INSIGHT: The Swiss Financial Passport

Every Swiss financial decision requires the same documents:
- Salary certificate(s)
- LPP statement + pension extract
- Tax return (last 2 years)
- Debt declarations (mortgages, credit)
- Income stability (employment contract, tax history)

Currently: scattered across bank portals, employer HR systems, pension fund websites, cantonal tax offices, bureau à louer listings.

**MINT's killer use case**: Be the single verified dossier that users can share with banks, landlords, employers, insurance brokers. Not "let's build a portfolio tracker" — "let's be the passport that unlocks Swiss financial life."

This is worth distribution investment because:
1. **Immediate utility** — solves real friction (5-10 different portals to collect docs)
2. **High frequency** — mortgage (every 7-10 years), job change (every 3-4 years), housing (every 5 years), insurance (annual)
3. **Network effects** — landlords + HR departments incentivized to ask for "MINT passport"
4. **Compliance moat** — competitors can't match Swiss-specific extraction quality in 2-3 years

---

## DISTRIBUTION LAYER 1: OS-Level Integration (Months 1-3)

### iOS Share Sheet Extension

**Why**: Screenshots are the #1 financial doc type in MINT's context. User receives salary cert PDF via email → taps Share → "Add to MINT" → MINT processes in background → notification: "Salary confirmed at 92k. Confidence +12 pts."

**Implementation**:
```swift
// WidgetKit + Share Sheet Extension
- Appear in iOS share menu under "Add to MINT"
- Accept: images, PDFs, screenshots from ANY app
- Process in background (ExtensionKit)
- Push notification: "Document processed"
- User taps notification → opens MINT at document detail screen
  (not full app launch — contextual deep link)
```

**User journey**:
1. User gets email with salary cert PDF
2. Long-press PDF → Share → "Add to MINT"
3. Background processing (< 2s if cached, < 5s if new extraction)
4. Notification: "Certificat 92k CHF confirmé. Confiance +12 pts."
5. User taps → opens MINT at new document card (not home screen)
6. FinancialBiography updated (local only)

**Competitive moat**: No competitor in Switzerland has built iOS share sheet + Swiss financial document pipeline. WeChat took 2 years to build receipts extraction. MINT would ship this in Q2 2026.

**Cost**: 1 iOS dev (4 weeks) + backend endpoint validation

---

### Android Share Intent

**Parallel implementation**:
- Same Share menu integration
- Background processing via WorkManager
- Notification routing via firebase push
- Same UX parity as iOS

---

## DISTRIBUTION LAYER 2: Bank & Pension Fund Integrations (Months 2-4, v3.0 foundation)

### The B2B2C Play: "MINT Inside"

**Why**: Banks don't want to build document intelligence. Pension funds don't want to coach users. Both have user friction points.

**Model**: MINT offers an API that banks/pension funds embed. User never leaves their app.

#### Use Case 1: Raiffeisen Members

**Problem Raiffeisen solves**: Members see pension dashboard + raw LPP statement. They don't understand implications.

**MINT solution**:
```
Raiffeisen Banking App
  └─ "Your Pension" tab
       └─ [Raw pension data from RIF caisse]
       └─ [MINT insight card: "Your LPP conversion at 65 yields CHF X/month. This assumes Y returns. Your coverage gap for Z is estimated at Q."]
       └─ User taps insight → deep dive in MINT (if installed) OR Raiffeisen-hosted MINT lightweight interface
```

**API contract**:
```
POST /partner/v1/insight
{
  "source": "pension_fund",
  "lppCapital": 450000,
  "conversionRate": 0.068,
  "retirementAge": 65,
  "archetype": "swiss_native",
  "partnerBrandColors": {...}
}
→ RESPONSE {
  "insightCard": {
    "title": "Rente LPP à 65",
    "body": "CHF 30.6k/an estimé (avec 2% rendement)",
    "cta": "Voir plus",
    "deepLink": "mint://pension-deep?lpp_capital=450000"
  },
  "disclaimer": "Outil éducatif LSFin",
  "confidence": 0.87
}
```

**Why banks adopt**:
1. Solves member confusion (liability reduction)
2. Differentiates UX at zero build cost
3. Increases app engagement (users stay in Raiffeisen)
4. MINT co-brands but doesn't disrupt bank's brand

**Why MINT wins**:
1. Access to Raiffeisen's 1M+ members instantly
2. Real data (pension capital, age, canton) feeds FinancialBiography
3. Bank branding in card → members discover MINT naturally ("What is this feature?")
4. Permission to store data (bank's customer consents to Raiffeisen, who consents to MINT)

**Scope for v2.0**: Design API contract + build 1 mock integration (Raiffeisen sandbox). Production requires legal + tech partnerships = v3.0+.

---

#### Use Case 2: HR Portals (BVG/LPP Employee Dashboards)

**Problem**: Employees see pension balance but don't understand rachat opportunities, 3a strategy, or tax optimization.

**MINT solution**: HR department enables "MINT insights" toggle in their existing pension portal. Employee sees contextual insights without leaving their HR portal.

```
Employer HR Portal (e.g., HR One, HCM system)
  └─ "My Pension" section
       └─ [Raw LPP capital shown by HCM]
       └─ [MINT card: "Rachat possible: max CHF 123k (spreads tax over 3 years). Deadline for 2026: Dec 31."]
       └─ "Learn more" → opens lightweight MINT coach (iframe, not native app)
```

**Why HR departments adopt**:
1. Reduces pension-related HR support tickets (30%+ of HR time in CH is "what's my pension worth?")
2. Employees happier (fewer complaints about pension confusion)
3. Zero cost to HR (MINT delivers via API)
4. Branding: HR can customize card with company colors

**Why MINT wins**:
1. Reach: 5000+ Swiss companies × avg 200 employees = 1M+ captive users
2. Trust transfer: if HR portal trusts MINT, users trust MINT
3. Data rich: actual LPP capitals, salaries (via proxy), life events (maternity, job change)
4. Engagement: annual HR platform engagement = annual MINT touchpoint

**Timeline**: v2.0 = design API. v3.0+ = production partnerships (requires employment law compliance per canton).

---

## DISTRIBUTION LAYER 3: Apple/Google Platform Hooks (Months 3-6, v3.0)

### "Financial Health" in Apple Health Analogy

**Insight**: Apple Health centralizes biometric data. iOS apps read from it with explicit permission. Google Fit does same for Android.

**MINT as "Financial Health" ecosystem partner**:

1. **Data source**: MINT writes anonymized financial health metrics to Apple Health (if user opts in)
   - Annual savings rate (%)
   - Retirement readiness score (0-100)
   - Debt-to-income ratio
   - Insurance coverage adequacy

2. **Data consumer**: Other Swiss fintech apps (insurance, mortgage, tax software) READ from MINT's "Financial Health" layer
   - Insurance app: reads coverage adequacy → suggests gaps
   - Mortgage app: reads debt-to-income → pre-fills affordability check
   - Tax app: reads retirement assets → estimates tax liability

**Why this matters**: Creates network effects. MINT becomes the **data hub** that other apps depend on, not a standalone app.

**Contract with Apple/Google**: Requires partnership discussions (2-3 months). Likely requires v2.1+ (post-launch data richness).

---

## DISTRIBUTION LAYER 4: Landlord/Mortgage Integration (Months 4-6, v3.0)

### The "Financial Passport" Payment Moment

**Why**: When applying for apartments or mortgages, users must submit salary certs, LPP extracts, tax returns, debt declarations. Currently = 4-6 different document requests, weeks of back-and-forth.

**MINT solution**: Generate a verified "Financial Passport" — encrypted JSON dossier signed by MINT + user's consent signature.

```
User in MINT app:
  [Dossier section] → [Generate Financial Passport]
    → Aggregates: salary cert (extracted + verified)
                  LPP statement (extracted + verified)
                  Tax return (imported)
                  Debt declarations (auto-filled from profile)
    → Generates: time-bound token (30 days)
               signed JSON passport
               shareable link (optional)
    → User copies link
    → Shares with landlord/mortgage broker

Landlord/broker receives:
  "https://passport.mint.ch/verify/abc123?expires=2026-05-06"
  → Can view summary (salary, LPP, debts, confidence score)
  → Can request source documents (user grants per-document access)
  → MINT tracks what was shared (audit log)
  → User can revoke at any time
```

**Why users adopt**: Eliminates document scatter. "Here's my MINT passport" beats "wait, I need to download, email, re-email" flow.

**Why landlords/brokers adopt**:
1. Instant verification (doc extraction confidence score included)
2. Audit trail (can prove they validated user's financial info)
3. Reduces fraud (MINT's extraction confidence > user self-report)

**Compliance considerations**:
- nLPD: passport contains no more data than user already disclosed
- LSFin: MINT isn't advising on mortgage suitability, just sharing verified data
- Banking secrecy: user explicitly consents to data sharing (token gating)

**Implementation**:
- v2.0: Design API contract
- v3.0: Production passport API + user consent manager + audit log

---

## DISTRIBUTION LAYER 5: Content Marketing & Earned Media (Ongoing, Months 1-3)

### "Swiss Financial Health Report" (Annual)

**Model**: Aggregate anonymized MINT user data + third-party sources → annual report on Swiss financial health.

```
"Swiss Financial Health Report 2026"
- Median savings rate by canton (VD vs ZH vs TI)
- Most common financial regrets (by life event)
- Pension readiness: % of Swiss on track
- Tax optimization blind spots: top 5 by region
- 3a adoption rates by age + income
```

**Why this works**:
1. **Press coverage**: "Swiss app reveals shocking pension gap" → RTS/NZZ interest
2. **Distribution**: Report sits on MINT.ch, gets shared, drives SEO
3. **Trust building**: MINT becomes thought leader (not just app)
4. **User curiosity**: "Where do I compare to other Swiss?" → installs app to check benchmark

**Cost**: 1 data scientist + 2 weeks (q4 2026). ROI: ~5-10% of CAC.

---

### Strategic Partnerships (Months 2-6)

| Partner | Value Exchange | Timeline |
|---------|---|---|
| **SRG (RTS/SRF)** | Segment on "Your Money Your Decision" → MINT link | Q2 2026 |
| **Digitale Gesellschaft (Advocacy group)** | White paper on "Financial health equity in Switzerland" | Q2 2026 |
| **Tax software (SteuererklarApp, Kontrol)** | Link in "Further reading" section | Q2 2026 |
| **Mortgage brokers (Immodo, Comparis)** | Integration with passport API (future) | Q3 2026 |
| **Universities (USI, UniBe)** | Case study: "FinTech for financial literacy" | Q3 2026 |

---

## DISTRIBUTION LAYER 6: WhatsApp/Telegram Chat Interface (v3.0, Months 7+)

### "MINT in Messages"

**Why**: 80% of Swiss under 40 prefer messaging to native apps for lightweight interactions. Why build a home screen when users live in WhatsApp?

**Implementation**:
```
User messages MINT bot on WhatsApp:
  → "I got a new salary offer"
  → MINT: "Send me the offer letter 📎"
  → User: [screenshot or PDF]
  → MINT: "Offer: 110k vs your current 92k.
             Impact: +30% gross, +25% net, +10pts tax bracket.
             Before deciding: ask about benefits package + LPP.
             Use our calculator? https://mint.ch/compare-offers"

MINT responds in 2-3 minutes, no app install needed.
User can save conversation as reference.
If interested: "Want the full analysis? [Download MINT app]"
```

**Why this is distribution gold**:
1. **Zero friction**: No app download, no auth, just message
2. **Network effect**: User shares MINT's response with friends → more messages to bot → more viral growth
3. **Messaging = permission**: User opted into notifications by messaging MINT first
4. **Multi-turn**: WhatsApp's 24-hour window = natural coaching flow

**Limitations**: WhatsApp Business API has strict compliance rules. Requires FINMA pre-approval + clear "educational" framing.

**v2.0 scope**: NOT included. v3.0 foundation: design coach responses for SMS/Telegram. v4.0 production.

---

## DISTRIBUTION LAYER 7: Corporate Perks (HR Tech B2B) (v2.5, Months 6+)

### "MINT as Employee Benefit"

**Why**: Companies pay for Spotify, Gym passes, health apps. Why not financial health?

**Model**:
- Employee gets MINT Premium free (company pays ~CHF 5/month per employee)
- Company gets dashboard: "60% of our employees have reviewed their 3a, 40% updated their pension expectations"
- MINT gets: CAC of ~CHF 2 (employee acquisition cost = company bulk discount)

**Players**: BensoFlex, Reward Gateway, Gust

**Timeline**: v2.5 (post-launch) — requires proof of engagement + testimonials first.

---

## DISTRIBUTION LAYER 8: Insurance Broker Integrations (v3.0)

### "MINT Inside Insurance Apps"

**Why**: Insurance brokers (Comparis, Moneyland, Finpension) already have 500k+ users. MINT's risk assessment (debt, assets, income) feeds insurance recommendations naturally.

**Example**:
```
Comparis life insurance selector:
  → User inputs: age 35, salary 85k, mortgage 280k
  → Comparis: "Recommended coverage: CHF 400k"
  → [MINT card appears]: "Based on your mortgage + family obligations,
       MINT suggests: CHF 380-450k. This covers your debt + 5 years income replacement."
  → User can toggle MINT insights on/off
  → Comparis still ranks insurance products (MINT doesn't recommend products)
```

**Why brokers adopt**:
- Differentiates their UX
- Reduces support friction ("why do I need this much insurance?")
- Increases conversion (users feel confident in recommendation)

**Why MINT wins**:
- Real users at decision moment (high intent)
- Insurance underwriting data improves FinancialBiography

---

## GROWTH LOOP: "Invite Your Advisor" (Months 3-6, v2.0+)

### Reverse Network Effect: Professionals Share MINT With Clients

**Why**: Tax advisors, insurance brokers, mortgage brokers, HR departments all see value in MINT. They become unofficial "MINT ambassadors."

**Mechanism**:
1. Advisor (e.g., tax consultant) recommends MINT to client during annual review
2. Advisor provides client a referral link: `https://mint.ch/ref/tax-advisor-bern-01`
3. Client installs + completes first journey
4. Advisor sees: "Your referral (23 clients) has saved them 120k CHF in tax optimization" (anonymized aggregate)
5. Advisor offers "I recommend MINT" badge in their LinkedIn profile

**Why this works**:
- Advisors want tools that improve their client outcomes (MINT is force multiplier)
- MINT gets ~20% of new user CAC from advisors' networks
- Advisors feel invested in MINT's success

**Onboarding for advisors**:
- 1-pager: "How to recommend MINT to your clients"
- Referral link + tracking (free)
- Monthly aggregate report: "Your referred clients are on average X% more confident about their finances"

**CAC impact**: ~CHF 8-12 per referred client (free marketing via trusted intermediary).

---

## GROWTH LOOP: "Share Your Plan" (Months 3-6, v2.0+)

### Viral Coefficient: Plan Sharing

**Why**: "I just realized my pension is worth less than I thought" is a conversation starter.

**Mechanism**:
1. User creates a projection (e.g., retirement plan)
2. User taps "Share with spouse/advisor/friend"
3. Generates secure link: `https://plan.mint.ch/share/abc123?expires=30d`
4. Recipient views projection (no account needed, read-only)
5. Recipient sees: "Want your own analysis? Download MINT"

**Why this matters**:
- Couples share plans → spouse installs → 2x households
- Advisors share client plans with underwriters → underwriters discover MINT
- Friend shares mortgage plan → other friends see mortgage implications → install

**Network effect metric**: Viral coefficient of 0.3-0.5 is typical (each user brings 0.3-0.5 new users through sharing).

---

## CAC Breakdown: First 10,000 Users (v2.0-v2.5)

| Channel | Timeline | Users | CAC | Cumulative |
|---------|----------|-------|-----|-----------|
| **Organic (word of mouth + App Store)** | Months 1-3 | 500 | CHF 0 | CHF 0 |
| **Share Sheet (iOS/Android)** | Months 1-3 | 1,500 | CHF 2-5 | CHF 5-7k |
| **Advisor referrals** | Months 2-6 | 2,000 | CHF 8-12 | CHF 21-31k |
| **Plan sharing (viral)** | Months 2-6 | 2,000 | CHF 0 (inherent) | CHF 31k |
| **Content marketing (reports)** | Months 3-6 | 1,500 | CHF 5-8 | CHF 39-43k |
| **HR partnerships (pilots)** | Months 4-6 | 1,000 | CHF 3-5 (company pays) | CHF 42-48k |
| **App Store featuring** (SG) | Months 4-6 | 500 | CHF 0 (editorial) | CHF 42-48k |
| **Paid acquisition (SG/Facebook)** | Months 4-6 | 500 | CHF 20-30 | CHF 52-63k |
| | | **10,000** | **~CHF 5.2-6.3 avg** | |

**Target**: CAC < CHF 10 by v2.5. Breakeven when LTV (lifetime value) = 3x CAC.

---

## DISTRIBUTION ROADMAP: Timeline

```
Phase 1: "Get to Distribution-Ready" (v2.0, Months 1-3)
├─ Perfect Léa's journey (Phase 1 milestone)
├─ Build share sheet extension (iOS + Android)
├─ Design bank/pension APIs (NOT production)
└─ Document "Financial Passport" spec (NOT production)

Phase 2: "Activate All Channels" (v2.1-v2.2, Months 3-6)
├─ Launch share sheet publicly
├─ Onboard first 5 advisors (tax/mortgage brokers in Zurich)
├─ Release Swiss Financial Health Report 2026
├─ Activate plan sharing
├─ Pilot HR partnerships (3 companies)
└─ First 10,000 users target

Phase 3: "B2B2C Pilot" (v2.5-v3.0, Months 6-12)
├─ Raiffeisen API pilot (sandbox)
├─ Comparis integration pilot
├─ HR perks program launch (Benefits platforms)
├─ WhatsApp bot MVP (compliance pre-approval)
└─ Scale to 50,000 users

Phase 4: "Platform Ecosystem" (v3.0+, Months 12+)
├─ Financial Passport production launch
├─ 5+ active B2B partnerships (banks, brokers, HR tech)
├─ Apple Health integration (if approved)
├─ WhatsApp/Telegram bot production
└─ Target: 200k+ users, CHF 5M ARR (premium tier)
```

---

## Why This Beats "Build Features" Strategy

| Approach | Users at 12 Months | CAC | Notes |
|----------|---|---|---|
| **Feature-first** (current roadmap) | ~5-10k | CHF 15-25 | Build and hope users find it |
| **Distribution-first** (this plan) | ~50-100k | CHF 5-10 | Use existing distribution channels to reach ready users |

**Key insight**: Raiffeisen's 1M members are 100x more likely to install MINT than a random iOS user. A tax advisor's 50 clients are 20x more likely to adopt. An HR platform's 5,000 employees are 15x more likely to engage.

**Competitive lock-in**: By Month 9 (v2.5), MINT is embedded in:
- 500+ advisors' workflows
- 3-5 major companies' HR platforms
- 2-3 major banks' apps
- 50+ HR tech platforms (via perks program)

When competitors launch (Revolut, Kreos, Neon expand to Switzerland), MINT isn't a standalone app — MINT is a layer that's already woven into Swiss financial infrastructure.

---

## Architecture Decisions Needed for Distribution

### Backend Changes (to support v2.0 distribution)

1. **PartnerAPIService** (FastAPI)
   - Endpoint: `POST /partner/v1/insight` (bank/pension fund requests)
   - Input: anonymized user data (no names, no identifiers)
   - Output: insight card + deep link
   - Auth: partner API key + per-institution consent signatures
   - Rate limit: 1000 req/sec per partner (SLA negotiation)

2. **PassportService** (for Financial Passport, v3.0)
   - Endpoint: `POST /user/passport/generate` (create shareable dossier)
   - Output: time-bound JWT + encrypted JSON
   - Verification: `GET /verify/passport/{token}` (public, read-only)
   - Audit: track all view + share events

3. **ShareService** (for plan sharing)
   - Endpoint: `POST /plan/{plan_id}/share` (create shareable link)
   - Output: time-bound URL + expiry
   - Verification: `GET /share/{token}` (read-only, no auth required)
   - Track: referral source (if recipient installs)

4. **AnalyticsService** enhancements
   - Track: share sheet activation, referral source, attribution
   - Privacy: anonymized to "source=share_sheet" (no device ID)

### Flutter Changes (to support distribution)

1. **ShareSheetManager** (ios/ + android/)
   - Listen to incoming share events (photos, PDFs)
   - Route to DocumentAdapter pipeline (Phase 2 logic)
   - Push notification when processing complete
   - Deep link to document detail screen

2. **PlanShareWidget** (new widget)
   - Copy link button
   - Expiry timer UI
   - Share via WhatsApp/iMessage/Mail
   - Revoke link button

3. **PassportGenerator** (new screen, v3.0)
   - Review collected documents
   - Select subset to include in passport
   - Generate + copy link
   - Audit log viewer

4. **ReferralBadge** (new component)
   - Shows "Invited by [Advisor Name]" in onboarding
   - Tracks attribution source
   - Surfaces later as advisor engagement stat

---

## Compliance Considerations

### LSFin Art. 8 (Personalized Recommendations)

**Not violated by**:
- Sharing user's own data with their chosen recipients (user-initiated)
- Surfacing educational content + simulators (no specific product recommended)
- Bank/pension fund partners showing factual data extractions (bank's responsibility to verify)

**Requires careful guardrails**:
- Partner API outputs NEVER include "you should buy X insurance" — only facts
- Share links are read-only (no modification)
- Referral programs clarify MINT isn't paying advisors for recommendations

### nLPD (Data Minimization)

- Partner API receives anonymized data only (no names, no identifiers)
- Passport generation includes user consent screen ("You're about to share: salary, LPP capital, debt")
- Audit trail retained for 2 years (nLPD art. 14 obligation)
- Users can revoke all shared accesses anytime

### Banking Secrecy / Privacy

- bLink integration requires explicit SFTI / per-bank contracts
- Raiffeisen partnership requires their legal team to validate data handling
- All agreements include: data minimization, user revocation, audit logging, incident reporting

---

## Success Metrics (v2.0 → v2.5)

| Metric | v2.0 Target | v2.5 Target | Rationale |
|--------|---|---|---|
| **Active users** | 2,000 | 50,000 | Distribution scaling |
| **CAC** | < CHF 12 | < CHF 8 | Channel optimization |
| **LTV:CAC ratio** | 2:1 | 3:1 | Sustainable growth |
| **Share sheet activation rate** | 8% | 25% | Existing users share documents |
| **Referral coefficient** | 0.15 | 0.35 | Plan sharing + advisor referrals |
| **Partner integrations** | 2 pilot | 5 production | B2B2C traction |
| **Advisor network** | 10 | 200+ | Bottom-up growth loop |
| **Viral sharing** (plan shares) | 100/day | 2,000/day | Network effect |

---

## Open Questions for Team Discussion

1. **Share Sheet Timing**: Can we ship iOS/Android share sheet in Q2 (parallel to Phase 1)? Or does it require Phase 2 document pipeline stability first?

2. **API Prioritization**: Which partner integration comes first — Raiffeisen, Comparis, or an HR platform? Each has different legal complexity.

3. **Passport**: Should Financial Passport be a v2.0 feature (design only) or v2.5 (production)? Impact on v2.0 scope.

4. **WhatsApp vs. Native**: Do we invest in WhatsApp bot (v3.0) or focus on native app + web first?

5. **Monetization Lock**: Does distributing through partners commit us to "free" model (no premium)? Or can premium tier (advanced simulations, export) coexist?

6. **Compliance Pre-Work**: Should we start FINMA pre-approval conversations for bLink now (6-month cycle) or wait until v2.0 ships?

---

## Conclusion

**MINT v2.0 builds the features. Distribution v1.0 builds the channels.**

By Months 9-12 (v2.5), MINT isn't a standalone app — it's a layer woven into:
- iOS share sheet (every user, every financial document)
- Bank apps (Raiffeisen, others)
- HR portals (5,000+ companies)
- Advisor workflows (500+ tax/mortgage/insurance advisors)
- Plan sharing (viral coefficient 0.3-0.5)

This compounds to 50-100k users with CAC of CHF 5-10, instead of the traditional "build, market, acquire" path that requires CHF 15-25 CAC to reach same scale.

**The moat**: Swiss-specific document intelligence is valuable only if it reaches users at their moments of decision. Distribution is the distribution of the moat.
