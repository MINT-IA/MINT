"""
Auth admin services: observability and cleanup.
"""

from __future__ import annotations

from datetime import datetime, timedelta, date
import json
from typing import Any
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.analytics_event import AnalyticsEvent
from app.models.auth_security import (
    LoginSecurityStateModel,
    PasswordResetTokenModel,
    EmailVerificationTokenModel,
)
from app.models.billing import SubscriptionModel
from app.models.billing import BillingWebhookEventModel
from app.models.audit_event import AuditEventModel


def _now() -> datetime:
    return datetime.utcnow()


def build_auth_observability_snapshot(db: Session, *, purge_days: int) -> dict[str, Any]:
    now = _now()
    cutoff = now - timedelta(days=max(1, purge_days))

    users_total = db.query(func.count(User.id)).scalar() or 0
    users_verified = (
        db.query(func.count(User.id)).filter(User.email_verified.is_(True)).scalar() or 0
    )
    users_unverified = users_total - users_verified
    users_unverified_older_than_ttl = (
        db.query(func.count(User.id))
        .filter(User.email_verified.is_(False), User.created_at <= cutoff)
        .scalar()
        or 0
    )

    login_states_tracked = db.query(func.count(LoginSecurityStateModel.id)).scalar() or 0
    login_states_locked_now = (
        db.query(func.count(LoginSecurityStateModel.id))
        .filter(LoginSecurityStateModel.lockout_until.is_not(None))
        .filter(LoginSecurityStateModel.lockout_until > now)
        .scalar()
        or 0
    )

    password_reset_tokens_active = (
        db.query(func.count(PasswordResetTokenModel.id))
        .filter(
            PasswordResetTokenModel.used_at.is_(None),
            PasswordResetTokenModel.expires_at >= now,
        )
        .scalar()
        or 0
    )
    email_verification_tokens_active = (
        db.query(func.count(EmailVerificationTokenModel.id))
        .filter(
            EmailVerificationTokenModel.used_at.is_(None),
            EmailVerificationTokenModel.expires_at >= now,
        )
        .scalar()
        or 0
    )

    subscriptions_total = db.query(func.count(SubscriptionModel.id)).scalar() or 0
    subscriptions_active_like = (
        db.query(func.count(SubscriptionModel.id))
        .filter(SubscriptionModel.status.in_(["active", "trialing", "past_due"]))
        .scalar()
        or 0
    )

    return {
        "users_total": int(users_total),
        "users_verified": int(users_verified),
        "users_unverified": int(users_unverified),
        "users_unverified_older_than_ttl": int(users_unverified_older_than_ttl),
        "login_states_tracked": int(login_states_tracked),
        "login_states_locked_now": int(login_states_locked_now),
        "password_reset_tokens_active": int(password_reset_tokens_active),
        "email_verification_tokens_active": int(email_verification_tokens_active),
        "subscriptions_total": int(subscriptions_total),
        "subscriptions_active_like": int(subscriptions_active_like),
    }


def purge_unverified_users(
    db: Session,
    *,
    older_than_days: int,
    dry_run: bool,
) -> dict[str, int | bool]:
    days = max(0, int(older_than_days))
    cutoff = _now() - timedelta(days=days)

    query = db.query(User).filter(User.email_verified.is_(False))
    if days > 0:
        query = query.filter(User.created_at <= cutoff)
    users = query.all()
    user_ids = [u.id for u in users]
    candidates = len(user_ids)
    anonymized_analytics_events = 0
    deleted_users = 0

    if not dry_run and user_ids:
        anonymized_analytics_events = (
            db.query(AnalyticsEvent)
            .filter(AnalyticsEvent.user_id.in_(user_ids))
            .update({AnalyticsEvent.user_id: None}, synchronize_session=False)
        )
        (
            db.query(LoginSecurityStateModel)
            .filter(LoginSecurityStateModel.email.in_([u.email for u in users]))
            .delete(synchronize_session=False)
        )
        (
            db.query(PasswordResetTokenModel)
            .filter(PasswordResetTokenModel.user_id.in_(user_ids))
            .delete(synchronize_session=False)
        )
        (
            db.query(EmailVerificationTokenModel)
            .filter(EmailVerificationTokenModel.user_id.in_(user_ids))
            .delete(synchronize_session=False)
        )
        for user in users:
            db.delete(user)
        deleted_users = candidates
        db.commit()

    return {
        "dry_run": dry_run,
        "older_than_days": days,
        "candidates": candidates,
        "deleted_users": deleted_users,
        "anonymized_analytics_events": int(anonymized_analytics_events),
    }


def _aggregate_count_by_day(
    db: Session,
    *,
    day_expr,
    table,
    filters: list[Any],
) -> dict[str, int]:
    query = db.query(day_expr.label("day"), func.count().label("count")).select_from(table)
    if filters:
        query = query.filter(*filters)
    rows = query.group_by("day").all()
    out: dict[str, int] = {}
    for day_value, count_value in rows:
        if day_value is None:
            continue
        out[str(day_value)] = int(count_value or 0)
    return out


def build_auth_billing_cohort_rows(
    db: Session,
    *,
    start_date: date,
    end_date: date,
) -> list[dict[str, int | str]]:
    """
    Build day-level auth/billing cohort metrics rows.
    """
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt_exclusive = datetime.combine(end_date + timedelta(days=1), datetime.min.time())

    user_day = func.date(User.created_at)
    audit_day = func.date(AuditEventModel.created_at)
    sub_day = func.date(SubscriptionModel.created_at)
    webhook_day = func.date(BillingWebhookEventModel.created_at)

    users_registered = _aggregate_count_by_day(
        db,
        day_expr=user_day,
        table=User,
        filters=[User.created_at >= start_dt, User.created_at < end_dt_exclusive],
    )
    users_verified = _aggregate_count_by_day(
        db,
        day_expr=func.date(User.updated_at),
        table=User,
        filters=[
            User.email_verified.is_(True),
            User.updated_at >= start_dt,
            User.updated_at < end_dt_exclusive,
        ],
    )
    login_success = _aggregate_count_by_day(
        db,
        day_expr=audit_day,
        table=AuditEventModel,
        filters=[
            AuditEventModel.event_type == "auth.login",
            AuditEventModel.status == "success",
            AuditEventModel.created_at >= start_dt,
            AuditEventModel.created_at < end_dt_exclusive,
        ],
    )
    login_failed = _aggregate_count_by_day(
        db,
        day_expr=audit_day,
        table=AuditEventModel,
        filters=[
            AuditEventModel.event_type == "auth.login",
            AuditEventModel.status == "failed",
            AuditEventModel.created_at >= start_dt,
            AuditEventModel.created_at < end_dt_exclusive,
        ],
    )
    login_blocked = _aggregate_count_by_day(
        db,
        day_expr=audit_day,
        table=AuditEventModel,
        filters=[
            AuditEventModel.event_type == "auth.login",
            AuditEventModel.status.in_(["blocked", "blocked_unverified_email"]),
            AuditEventModel.created_at >= start_dt,
            AuditEventModel.created_at < end_dt_exclusive,
        ],
    )
    password_reset_requests = _aggregate_count_by_day(
        db,
        day_expr=audit_day,
        table=AuditEventModel,
        filters=[
            AuditEventModel.event_type == "auth.password_reset_request",
            AuditEventModel.status == "success",
            AuditEventModel.created_at >= start_dt,
            AuditEventModel.created_at < end_dt_exclusive,
        ],
    )
    email_verification_requests = _aggregate_count_by_day(
        db,
        day_expr=audit_day,
        table=AuditEventModel,
        filters=[
            AuditEventModel.event_type == "auth.email_verification_request",
            AuditEventModel.status == "success",
            AuditEventModel.created_at >= start_dt,
            AuditEventModel.created_at < end_dt_exclusive,
        ],
    )
    subscriptions_started = _aggregate_count_by_day(
        db,
        day_expr=sub_day,
        table=SubscriptionModel,
        filters=[
            SubscriptionModel.tier == "coach",
            SubscriptionModel.created_at >= start_dt,
            SubscriptionModel.created_at < end_dt_exclusive,
        ],
    )
    billing_webhooks = _aggregate_count_by_day(
        db,
        day_expr=webhook_day,
        table=BillingWebhookEventModel,
        filters=[
            BillingWebhookEventModel.created_at >= start_dt,
            BillingWebhookEventModel.created_at < end_dt_exclusive,
        ],
    )

    rows: list[dict[str, int | str]] = []
    cursor = start_date
    while cursor <= end_date:
        day_key = cursor.isoformat()
        rows.append(
            {
                "date": day_key,
                "users_registered": users_registered.get(day_key, 0),
                "users_verified": users_verified.get(day_key, 0),
                "login_success": login_success.get(day_key, 0),
                "login_failed": login_failed.get(day_key, 0),
                "login_blocked": login_blocked.get(day_key, 0),
                "password_reset_requests": password_reset_requests.get(day_key, 0),
                "email_verification_requests": email_verification_requests.get(day_key, 0),
                "subscriptions_started": subscriptions_started.get(day_key, 0),
                "billing_webhooks_received": billing_webhooks.get(day_key, 0),
            }
        )
        cursor += timedelta(days=1)
    return rows


def build_onboarding_quality_snapshot(
    db: Session,
    *,
    days: int,
) -> dict[str, int | float]:
    """
    Compute onboarding quality metrics from analytics events.
    """
    window_days = max(1, min(int(days), 365))
    since = _now() - timedelta(days=window_days)

    events = (
        db.query(AnalyticsEvent)
        .filter(
            AnalyticsEvent.timestamp >= since,
            AnalyticsEvent.session_id.is_not(None),
            AnalyticsEvent.event_name.in_(
                [
                    "onboarding_started",
                    "onboarding_step_completed",
                    "onboarding_completed",
                    "onboarding_step_duration",
                ]
            ),
        )
        .all()
    )

    started_sessions: set[str] = set()
    completed_sessions: set[str] = set()
    step_sessions: dict[int, set[str]] = {1: set(), 2: set(), 3: set(), 4: set()}
    completion_seconds: list[float] = []
    step_duration_seconds: list[float] = []

    for event in events:
        sid = event.session_id
        if not sid:
            continue

        if event.event_name == "onboarding_started":
            started_sessions.add(sid)
            continue
        if event.event_name == "onboarding_completed":
            completed_sessions.add(sid)
        data = {}
        if event.event_data:
            try:
                data = json.loads(event.event_data)
            except Exception:
                data = {}
        if event.event_name == "onboarding_completed":
            t = data.get("time_spent_seconds")
            if isinstance(t, (int, float)) and t > 0:
                completion_seconds.append(float(t))
        elif event.event_name == "onboarding_step_completed":
            step = data.get("step")
            if isinstance(step, int) and step in step_sessions:
                step_sessions[step].add(sid)
        elif event.event_name == "onboarding_step_duration":
            d = data.get("duration_seconds")
            if isinstance(d, (int, float)) and d > 0:
                step_duration_seconds.append(float(d))

    started = len(started_sessions)
    completed = len(completed_sessions)
    step1 = len(step_sessions[1])
    step2 = len(step_sessions[2])
    step3 = len(step_sessions[3])
    step4 = len(step_sessions[4])

    completion_rate = (completed / started * 100.0) if started > 0 else 0.0
    step1_to_2 = (step2 / step1 * 100.0) if step1 > 0 else 0.0
    step2_to_3 = (step3 / step2 * 100.0) if step2 > 0 else 0.0
    step3_to_4 = (step4 / step3 * 100.0) if step3 > 0 else 0.0

    avg_completion = (
        sum(completion_seconds) / len(completion_seconds)
        if completion_seconds
        else 0.0
    )
    avg_step_duration = (
        sum(step_duration_seconds) / len(step_duration_seconds)
        if step_duration_seconds
        else 0.0
    )

    completion_component = min(max(completion_rate, 0.0), 100.0) * 0.5
    flow_component = (step1_to_2 + step2_to_3 + step3_to_4) / 3.0 * 0.35
    if avg_step_duration <= 0:
        speed_component = 0.0
    elif avg_step_duration <= 20:
        speed_component = 100.0
    elif avg_step_duration >= 90:
        speed_component = 0.0
    else:
        speed_component = (90.0 - avg_step_duration) / 70.0 * 100.0
    quality_score = completion_component + flow_component + (speed_component * 0.15)
    quality_score = max(0.0, min(100.0, quality_score))

    return {
        "days": window_days,
        "sessions_started": started,
        "sessions_completed": completed,
        "completion_rate_pct": round(completion_rate, 2),
        "step1_sessions": step1,
        "step2_sessions": step2,
        "step3_sessions": step3,
        "step4_sessions": step4,
        "step1_to_2_pct": round(step1_to_2, 2),
        "step2_to_3_pct": round(step2_to_3, 2),
        "step3_to_4_pct": round(step3_to_4, 2),
        "avg_completion_seconds": round(avg_completion, 2),
        "avg_step_duration_seconds": round(avg_step_duration, 2),
        "quality_score": round(quality_score, 2),
    }


def _quality_score_from_rates(*, completion_rate: float, avg_step_duration: float) -> float:
    completion_component = min(max(completion_rate, 0.0), 100.0) * 0.85
    if avg_step_duration <= 0:
        speed_component = 0.0
    elif avg_step_duration <= 20:
        speed_component = 100.0
    elif avg_step_duration >= 90:
        speed_component = 0.0
    else:
        speed_component = (90.0 - avg_step_duration) / 70.0 * 100.0
    score = completion_component + (speed_component * 0.15)
    return max(0.0, min(100.0, score))


def build_onboarding_quality_cohorts(
    db: Session,
    *,
    days: int,
) -> dict[str, Any]:
    """
    Compute onboarding quality by cohort (variant + platform).
    """
    window_days = max(1, min(int(days), 365))
    since = _now() - timedelta(days=window_days)

    events = (
        db.query(AnalyticsEvent)
        .filter(
            AnalyticsEvent.timestamp >= since,
            AnalyticsEvent.session_id.is_not(None),
            AnalyticsEvent.event_name.in_(
                [
                    "onboarding_started",
                    "onboarding_completed",
                    "onboarding_step_duration",
                ]
            ),
        )
        .all()
    )

    session_variant: dict[str, str] = {}
    session_platform: dict[str, str] = {}
    cohorts: dict[str, dict[str, Any]] = {}

    def ensure_row(variant: str, platform: str) -> dict[str, Any]:
        key = f"variant:{variant}|platform:{platform}"
        if key not in cohorts:
            cohorts[key] = {
                "cohort_key": key,
                "variant": variant,
                "platform": platform,
                "started_sessions": set(),
                "completed_sessions": set(),
                "completion_times": [],
                "step_durations": [],
            }
        return cohorts[key]

    for event in events:
        sid = event.session_id
        if not sid:
            continue
        data = {}
        if event.event_data:
            try:
                data = json.loads(event.event_data)
            except Exception:
                data = {}
        variant = str(data.get("variant") or session_variant.get(sid) or "unknown")
        platform = str(event.platform or session_platform.get(sid) or "unknown")
        session_variant[sid] = variant
        session_platform[sid] = platform
        row = ensure_row(variant, platform)

        if event.event_name == "onboarding_started":
            row["started_sessions"].add(sid)
        elif event.event_name == "onboarding_completed":
            row["completed_sessions"].add(sid)
            t = data.get("time_spent_seconds")
            if isinstance(t, (int, float)) and t > 0:
                row["completion_times"].append(float(t))
        elif event.event_name == "onboarding_step_duration":
            d = data.get("duration_seconds")
            if isinstance(d, (int, float)) and d > 0:
                row["step_durations"].append(float(d))

    result_rows: list[dict[str, Any]] = []
    total_started = 0
    for row in cohorts.values():
        started = len(row["started_sessions"])
        completed = len(row["completed_sessions"])
        total_started += started
        completion_rate = (completed / started * 100.0) if started > 0 else 0.0
        avg_completion = (
            sum(row["completion_times"]) / len(row["completion_times"])
            if row["completion_times"]
            else 0.0
        )
        avg_step_duration = (
            sum(row["step_durations"]) / len(row["step_durations"])
            if row["step_durations"]
            else 0.0
        )
        result_rows.append(
            {
                "cohort_key": row["cohort_key"],
                "variant": row["variant"],
                "platform": row["platform"],
                "sessions_started": started,
                "sessions_completed": completed,
                "completion_rate_pct": round(completion_rate, 2),
                "avg_completion_seconds": round(avg_completion, 2),
                "avg_step_duration_seconds": round(avg_step_duration, 2),
                "quality_score": round(
                    _quality_score_from_rates(
                        completion_rate=completion_rate,
                        avg_step_duration=avg_step_duration,
                    ),
                    2,
                ),
            }
        )
    result_rows.sort(key=lambda x: x["sessions_started"], reverse=True)
    return {
        "days": window_days,
        "total_sessions_started": total_started,
        "cohorts": result_rows,
    }
