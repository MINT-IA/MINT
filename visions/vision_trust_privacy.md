# Vision: Trust & Privacy — MINT

## The "No Secrets" Policy
We are transparent about how we use data. Mint is built on trust.

## Data Minimality
- **No Sensitive Free-Text**: We avoid asking for names, IBANs, or detailed transaction descriptions in free-text fields.
- **Aggregated Input**: Financial data is captured via sliders or categories.
- **No Sensitive Logs**: Server logs must not contain user financial profiles or session answers.

## Secure PDF Export
- **Local Generation**: PDFs are generated on the mobile device, reducing server exposure.
- **No Private IDs**: The PDF should contain financial advice and summaries, but no sensitive identifiers (no bank account numbers, no full names if not explicitly needed).

## Progressive Disclosure & Consent
- **Read-only MVP**: Mint does not move money.
- **Open Banking (Reward Flow)**: Connection is a **reward** that unlocks precision, never a barrier. It is opt-in, read-only, and only requested **after** the user has gained value from manual entry (Horizon 2).
- **Consent Dashboard**: A clear UI showing "Who sees what" with a global "Revoke All" button.

## Security Context
- All API traffic is encrypted (HTTPS).
- Minimal persistent storage for MVP (sessions and profiles are effectively ephemeral).
