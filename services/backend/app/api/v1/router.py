from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    auth,
    profiles,
    scenarios,
    recommendations,
    partners,
    sessions,
    analytics,
    rag,
    documents,
    job_comparison,
    life_events,
    coaching,
    segments,
    assurances,
    open_banking,
    lpp_deep,
    pillar_3a_deep,
    debt_prevention,
    mortgage,
    independants,
    unemployment,
    first_job,
    fiscal,
    wealth_tax,
    retirement,
    family,
    expat,
    disability_gap,
    next_steps,
    educational_content,
    communes,
    privacy,
    sync,
    billing,
    onboarding,
    arbitrage,
    snapshots,
    coach,
    coach_chat,
    notifications,
    scenario_narration,
    fri,
    reengagement,
    precision,
    document_parser,
    confidence,
    household,
    config,
    knowledge,
    regulatory,
    bank_import,
    budget,
    admin,
)

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(profiles.router, prefix="/profiles", tags=["profiles"])
api_router.include_router(scenarios.router, prefix="/scenarios", tags=["scenarios"])
api_router.include_router(
    recommendations.router, prefix="/recommendations", tags=["recommendations"]
)
api_router.include_router(partners.router, prefix="/partners", tags=["partners"])
api_router.include_router(sessions.router, prefix="/sessions", tags=["sessions"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(rag.router, prefix="/rag", tags=["rag"])
api_router.include_router(documents.router, prefix="/documents", tags=["documents"])
api_router.include_router(
    job_comparison.router, prefix="/job-comparison", tags=["job-comparison"]
)
api_router.include_router(
    life_events.router, prefix="/life-events", tags=["life-events"]
)
api_router.include_router(
    coaching.router, prefix="/coaching", tags=["coaching"]
)
api_router.include_router(
    segments.router, prefix="/segments", tags=["segments"]
)
api_router.include_router(
    assurances.router, prefix="/assurances", tags=["assurances"]
)
api_router.include_router(
    open_banking.router, prefix="/open-banking", tags=["open-banking"]
)
api_router.include_router(
    lpp_deep.router, prefix="/lpp-deep", tags=["lpp-deep"]
)
api_router.include_router(
    pillar_3a_deep.router, prefix="/3a-deep", tags=["3a-deep"]
)
api_router.include_router(
    debt_prevention.router, prefix="/debt", tags=["debt-prevention"]
)
api_router.include_router(
    mortgage.router, prefix="/mortgage", tags=["mortgage"]
)
api_router.include_router(
    independants.router, prefix="/independants", tags=["independants"]
)
api_router.include_router(
    unemployment.router, prefix="/unemployment", tags=["unemployment"]
)
api_router.include_router(
    first_job.router, prefix="/first-job", tags=["first-job"]
)
api_router.include_router(
    fiscal.router, prefix="/fiscal", tags=["fiscal"]
)
api_router.include_router(
    wealth_tax.router, prefix="/fiscal/wealth-tax", tags=["wealth-tax"]
)
api_router.include_router(
    retirement.router, prefix="/retirement", tags=["retirement"]
)
api_router.include_router(
    family.router, prefix="/family", tags=["family"]
)
api_router.include_router(
    expat.router, prefix="/expat", tags=["expat"]
)
api_router.include_router(
    disability_gap.router, prefix="/disability-gap", tags=["disability-gap"]
)
api_router.include_router(
    next_steps.router, prefix="/next-steps", tags=["next-steps"]
)
api_router.include_router(
    educational_content.router, prefix="/educational-content", tags=["educational-content"]
)
api_router.include_router(
    communes.router, prefix="/communes", tags=["communes"]
)
api_router.include_router(
    privacy.router, prefix="/privacy", tags=["privacy"]
)
api_router.include_router(
    sync.router, prefix="/sync", tags=["sync"]
)
api_router.include_router(
    billing.router, prefix="/billing", tags=["billing"]
)
api_router.include_router(
    onboarding.router, prefix="/onboarding", tags=["Onboarding S31"]
)
api_router.include_router(
    arbitrage.router, prefix="/arbitrage", tags=["Arbitrage S32-S33"]
)
api_router.include_router(
    snapshots.router, prefix="/snapshots", tags=["Snapshots S33"]
)
api_router.include_router(
    coach.router, prefix="/coach", tags=["Coach Narrative S35"]
)
api_router.include_router(
    coach_chat.router, prefix="/coach", tags=["Coach Chat S56"]
)
api_router.include_router(
    notifications.router, prefix="/notifications", tags=["Notifications S36"]
)
api_router.include_router(
    scenario_narration.router, prefix="/scenario", tags=["Scenario Narration S37"]
)
api_router.include_router(
    fri.router, prefix="/fri", tags=["fri"]
)
api_router.include_router(
    reengagement.router, prefix="/reengagement", tags=["Reengagement S40"]
)
api_router.include_router(
    precision.router, prefix="/precision", tags=["precision"]
)
api_router.include_router(
    document_parser.router, prefix="/document-parser", tags=["Document Parser S42-S43"]
)
api_router.include_router(
    confidence.router, prefix="/confidence", tags=["Confidence S46"]
)
api_router.include_router(
    household.router, prefix="/household", tags=["Household P6"]
)
api_router.include_router(
    config.router, prefix="/config", tags=["Config"]
)
api_router.include_router(knowledge.router, tags=["Knowledge S67"])
api_router.include_router(regulatory.router, tags=["Regulatory Core"])
api_router.include_router(
    bank_import.router, prefix="/bank-import", tags=["Bank Import"]
)
api_router.include_router(
    budget.router, prefix="/budget", tags=["Budget Anomaly Detection"]
)
api_router.include_router(
    admin.router, prefix="/admin", tags=["Admin"]
)
