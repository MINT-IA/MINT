"""B-EXP-F-1 regression tests — archetype-aware annual refresh.

Audit finding 2026-05-08 (PR #533) : the yearly refresh cron asked
« Ton salaire annuel brut a-t-il change ? » to retirees. Reframed to
« Tes sources de revenus (rentes, retraits, autres) ont-elles change ? »
when employment_status == 'retraite'.

Refs:
- Perimeter STUB
  .planning/decisions/2026-05-09-perimeter-p1-cron-archetype-aware/STUB.md
"""

from __future__ import annotations

from app.services.scenario.annual_refresh_service import AnnualRefreshService


def test_legacy_no_employment_status_keeps_salary_label():
    """Backward-compat: callers that don't pass employment_status get the
    pre-fix salary-framed labels.
    """
    service = AnnualRefreshService()
    result = service.generate_refresh_questions(
        current_salary=120000,
        current_lpp=350000,
        current_3a=22000,
    )
    salary_q = next(q for q in result.questions if q.key == "salary_changed")
    assert "salaire" in salary_q.label.lower()
    assert "rentes" not in salary_q.label.lower()


def test_employment_status_salarie_keeps_salary_label():
    """Active salaried users get the standard salary-framed labels."""
    service = AnnualRefreshService()
    result = service.generate_refresh_questions(
        current_salary=120000,
        current_lpp=350000,
        current_3a=22000,
        employment_status="salarie",
    )
    salary_q = next(q for q in result.questions if q.key == "salary_changed")
    assert "salaire" in salary_q.label.lower()


def test_employment_status_retraite_reframes_salary_to_revenue_sources():
    """Retirees get reframed labels — « sources de revenus » instead of
    « salaire annuel brut ».

    This is the device-friendly fix that prevents the yearly cron from
    asking a retiree about a salary they don't have.
    """
    service = AnnualRefreshService()
    result = service.generate_refresh_questions(
        current_salary=0,
        current_lpp=350000,
        current_3a=22000,
        employment_status="retraite",
    )
    salary_q = next(q for q in result.questions if q.key == "salary_changed")
    assert "salaire" not in salary_q.label.lower(), (
        f"Retiree should not see 'salaire' in cron prompt — got "
        f"{salary_q.label!r}"
    )
    assert "rentes" in salary_q.label.lower() or "revenus" in salary_q.label.lower()


def test_employment_status_retraite_reframes_job_change_too():
    """The companion 'job_changed' question is also archetype-aware so
    a retiree isn't asked « As-tu change d'emploi ».
    """
    service = AnnualRefreshService()
    result = service.generate_refresh_questions(
        employment_status="retraite",
    )
    job_q = next(q for q in result.questions if q.key == "job_changed")
    label = job_q.label.lower()
    # Should reference retiree-relevant change events, not job change.
    assert "emploi" not in label or "rente" in label, (
        f"Retiree job-change prompt should reference rente / activite "
        f"reduite, got {job_q.label!r}"
    )


def test_question_count_unchanged_at_seven():
    """All 7 questions still present regardless of employment_status —
    only the labels are reframed, not the structure.
    """
    service = AnnualRefreshService()
    for status in (None, "salarie", "retraite", "independant", "student"):
        result = service.generate_refresh_questions(
            employment_status=status,
        )
        assert len(result.questions) == 7, (
            f"Expected 7 questions for employment_status={status!r}, "
            f"got {len(result.questions)}"
        )


def test_lpp_3a_questions_unchanged_across_archetypes():
    """LPP and 3a questions are universal (don't depend on archetype)."""
    service = AnnualRefreshService()
    legacy = service.generate_refresh_questions(employment_status=None)
    retired = service.generate_refresh_questions(employment_status="retraite")

    legacy_lpp = next(q for q in legacy.questions if q.key == "lpp_balance")
    retired_lpp = next(q for q in retired.questions if q.key == "lpp_balance")
    assert legacy_lpp.label == retired_lpp.label

    legacy_3a = next(q for q in legacy.questions if q.key == "three_a_balance")
    retired_3a = next(q for q in retired.questions if q.key == "three_a_balance")
    assert legacy_3a.label == retired_3a.label
