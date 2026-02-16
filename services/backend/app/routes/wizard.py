from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, List
from datetime import datetime, timedelta
from app.models.session import Session
from app.database import get_db
from sqlalchemy.orm import Session as DBSession

router = APIRouter(prefix="/sessions", tags=["wizard"])


class WizardAnswers(BaseModel):
    answers: Dict[str, Any]
    completed_actions: Dict[str, Any] = {}


class TimelineItemCreate(BaseModel):
    date: datetime
    category: str
    label: str
    description: str
    action_url: str | None = None
    priority: str
    completed: bool = False


# Modèle TimelineItem pour la base de données
class TimelineItem:
    def __init__(
        self,
        session_id,
        date,
        category,
        label,
        description,
        action_url=None,
        priority="medium",
        completed=False,
    ):
        self.session_id = session_id
        self.date = date
        self.category = category
        self.label = label
        self.description = description
        self.action_url = action_url
        self.priority = priority
        self.completed = completed


@router.post("/wizard")
async def create_wizard_session(
    data: WizardAnswers,
    db: DBSession = Depends(get_db),
):
    """
    Crée une session wizard et génère le plan initial

    1. Sauvegarde les réponses
    2. Calcule l'indice de précision
    3. Génère les timeline items
    4. Détermine Safe Mode
    5. Retourne le rapport initial
    """
    try:
        # 1. Calculer l'indice de précision
        precision_index = _calculate_precision(data.answers)

        # 2. Déterminer Safe Mode
        safe_mode = _is_safe_mode_active(data.answers)

        # 3. Générer les actions
        actions = _generate_actions(data.answers, safe_mode)

        # 4. Générer les timeline items
        timeline_items = _generate_timeline_items(data.answers)

        # 5. Créer la session
        session = Session(
            user_id=1,  # TODO: Get from auth
            created_at=datetime.utcnow(),
            answers=data.answers,
            precision_index=precision_index,
            safe_mode=safe_mode,
        )

        db.add(session)
        db.commit()
        db.refresh(session)

        # 6. Sauvegarder les timeline items
        for item in timeline_items:
            timeline_item = TimelineItem(
                session_id=session.id,
                **item.dict(),
            )
            db.add(timeline_item)

        db.commit()

        return {
            "session_id": session.id,
            "precision_index": precision_index,
            "safe_mode": safe_mode,
            "actions": actions,
            "timeline_items": timeline_items,
            "next_most_valuable_info": _get_next_info(data.answers, precision_index),
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sessions/{session_id}/timeline")
async def get_timeline(
    session_id: int,
    db: DBSession = Depends(get_db),
):
    """
    Retourne les timeline items pour une session
    """
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    timeline_items = (
        db.query(TimelineItem).filter(TimelineItem.session_id == session_id).all()
    )

    # Séparer en upcoming et overdue
    now = datetime.utcnow()
    upcoming = [
        item for item in timeline_items if item.date > now and not item.completed
    ]
    overdue = [
        item for item in timeline_items if item.date <= now and not item.completed
    ]

    return {
        "upcoming": sorted(upcoming, key=lambda x: x.date),
        "overdue": sorted(overdue, key=lambda x: x.priority, reverse=True),
        "completed": [item for item in timeline_items if item.completed],
    }


@router.post("/sessions/{session_id}/timeline/{item_id}/complete")
async def complete_timeline_item(
    session_id: int,
    item_id: int,
    db: DBSession = Depends(get_db),
):
    """
    Marque un timeline item comme complété
    """
    item = (
        db.query(TimelineItem)
        .filter(
            TimelineItem.id == item_id,
            TimelineItem.session_id == session_id,
        )
        .first()
    )

    if not item:
        raise HTTPException(status_code=404, detail="Timeline item not found")

    item.completed = True
    db.commit()

    return {"status": "completed"}


@router.post("/sessions/{session_id}/life-event")
async def trigger_life_event(
    session_id: int,
    event_type: str,
    event_data: Dict[str, Any],
    db: DBSession = Depends(get_db),
):
    """
    Déclenche un événement de vie et génère les delta questions
    """
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Générer les delta questions selon l'événement
    delta_questions = _get_delta_questions(event_type)

    # Générer les timeline items pour cet événement
    event_timeline_items = _get_event_timeline_items(event_type, event_data)

    # Sauvegarder les timeline items
    for item in event_timeline_items:
        timeline_item = TimelineItem(
            session_id=session_id,
            **item,
        )
        db.add(timeline_item)

    db.commit()

    return {
        "delta_questions": delta_questions,
        "timeline_items": event_timeline_items,
    }


# Helper functions


def _calculate_precision(answers: Dict[str, Any]) -> float:
    """Calcule l'indice de précision (0-100%)"""
    precision = 0.0

    # Profil minimal (20%)
    if all(k in answers for k in ["q_canton", "q_birth_year", "q_household_type"]):
        precision += 20

    # Cashflow (20%)
    if all(k in answers for k in ["q_net_income_monthly", "q_savings_monthly"]):
        precision += 20

    # Dettes (20%)
    if all(k in answers for k in ["q_has_leasing", "q_has_consumer_credit"]):
        precision += 20

    # Prévoyance (20%)
    if "q_has_3a" in answers:
        precision += 10
    if "q_has_lpp_certificate" in answers:
        precision += 10

    # Objectif (20%)
    if "q_primary_goal" in answers:
        precision += 20

    return precision


def _is_safe_mode_active(answers: Dict[str, Any]) -> bool:
    """Détermine si Safe Mode est actif"""
    income = answers.get("q_net_income_monthly", 0)
    if income == 0:
        return False

    total_debt = 0
    if answers.get("q_has_leasing"):
        total_debt += answers.get("q_leasing_monthly", 0)
    if answers.get("q_has_consumer_credit"):
        total_debt += answers.get("q_consumer_credit_monthly", 0)

    debt_ratio = total_debt / income if income > 0 else 0

    has_emergency_fund = answers.get("q_single_emergency_fund") or answers.get(
        "hasEmergencyFund"
    )
    late_payments = answers.get("q_late_payments")
    credit_card_minimum = answers.get("q_credit_card_minimum") == "often"

    return (
        debt_ratio > 0.3
        or not has_emergency_fund
        or late_payments
        or credit_card_minimum
    )


def _generate_actions(answers: Dict[str, Any], safe_mode: bool) -> List[Dict[str, Any]]:
    """Génère les actions selon les réponses"""
    actions = []

    # Action 1 : Fonds d'urgence
    if not answers.get("hasEmergencyFund"):
        actions.append(
            {
                "id": "emergency_fund",
                "label": "Fonds d'urgence",
                "description": "Constituer 3-6 mois de charges",
                "status": "pending",
                "impact_on_precision": 15,
            }
        )
    else:
        actions.append(
            {
                "id": "emergency_fund",
                "label": "Fonds d'urgence",
                "description": "Objectif atteint",
                "status": "ready",
                "impact_on_precision": 0,
            }
        )

    # Action 2 : 3a
    if safe_mode:
        actions.append(
            {
                "id": "3a",
                "label": "3a",
                "description": "Bloqué : priorité au fonds d'urgence",
                "status": "blocked",
                "blocking_reason": "Constitue d'abord ton fonds d'urgence",
                "impact_on_precision": 0,
            }
        )
    elif not answers.get("q_has_3a"):
        actions.append(
            {
                "id": "3a",
                "label": "3a",
                "description": "Ouvrir un compte 3a",
                "status": "pending",
                "impact_on_precision": 10,
            }
        )
    else:
        actions.append(
            {
                "id": "3a",
                "label": "3a",
                "description": "Optimiser versement annuel",
                "status": "ready",
                "impact_on_precision": 5,
            }
        )

    return actions


def _generate_timeline_items(answers: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Génère les timeline items depuis les réponses selon les routes CH"""
    items = []

    # 1. Hypothèque fixe : Fenêtre de renégociation suisse standard [web:473]
    if (
        answers.get("q_housing_status") == "owner"
        and answers.get("q_mortgage_type") == "fixed"
        and "q_mortgage_fixed_end_date" in answers
    ):
        try:
            # On attend une date ISO ou string YYYY-MM
            end_val = answers["q_mortgage_fixed_end_date"]
            if len(end_val) == 7:  # YYYY-MM
                end_date = datetime.strptime(end_val, "%Y-%m")
            else:
                end_date = datetime.fromisoformat(end_val)

            # Rappel 15 mois avant : Préparer
            items.append(
                {
                    "date": end_date - timedelta(days=15 * 30),
                    "category": "housing",
                    "label": "Hypothèque: préparer renouvellement",
                    "description": "Analyse du marché 15 mois avant l'échéance",
                    "priority": "medium",
                }
            )

            # Rappel 6 mois avant : Préavis critique
            items.append(
                {
                    "date": end_date - timedelta(days=6 * 30),
                    "category": "housing",
                    "label": "Hypothèque: préavis contrat",
                    "description": "Vérifier le délai de résiliation (souvent 6 mois)",
                    "priority": "high",
                }
            )
        except Exception:
            pass

    # 2. Versement 3a : Règle décembre obligatoire [web:444]
    if answers.get("q_has_3a") == "yes":
        # Rappel 15 décembre
        dec_date = datetime(datetime.now().year, 12, 15)
        if dec_date < datetime.now():
            dec_date = datetime(datetime.now().year + 1, 12, 15)

        items.append(
            {
                "date": dec_date,
                "category": "pension",
                "label": "Décembre: versement 3a",
                "description": "Délai bancaire pour la déduction fiscale annuelle",
                "priority": "high",
            }
        )

    # 3. Fin de leasing / Crédit
    for field, label in [
        ("q_leasing_end_date", "fin de leasing"),
        ("q_credit_end_date", "fin de crédit"),
    ]:
        if field in answers:
            try:
                end_date = datetime.fromisoformat(answers[field])
                items.append(
                    {
                        "date": end_date - timedelta(days=30),
                        "category": "debt",
                        "label": f"Action: préparer {label}",
                        "description": "Anticiper la libération du budget mensuel",
                        "priority": "medium",
                    }
                )
            except Exception:
                pass

    # Limiter à 6 items max par session pour éviter le bruit
    return items[:6]


def _get_next_info(answers: Dict[str, Any], precision: float) -> str | None:
    """Retourne la prochaine info la plus rentable"""
    if "q_canton" not in answers:
        return "Canton de résidence"
    if "q_birth_year" not in answers:
        return "Année de naissance"
    if "q_household_type" not in answers:
        return "Situation familiale"
    if "q_net_income_monthly" not in answers:
        return "Revenu net mensuel"
    if "q_savings_monthly" not in answers:
        return "Épargne mensuelle"
    if "q_has_3a" not in answers:
        return "Compte 3a"
    if "q_primary_goal" not in answers:
        return "Objectif principal"

    return None


def _get_delta_questions(event_type: str) -> List[str]:
    """Retourne les questions delta pour un événement"""
    delta_map = {
        "new_job": ["q_new_job_date", "q_new_income", "q_lpp_transfer"],
        "birth": ["q_child_age", "q_insurance_review", "q_budget_impact"],
        "mortgage_renewal": ["q_current_rate", "q_desired_rate", "q_bank_offers"],
    }

    return delta_map.get(event_type, [])


def _get_event_timeline_items(
    event_type: str, event_data: Dict[str, Any]
) -> List[Dict[str, Any]]:
    """Génère les timeline items pour un événement"""
    items = []
    now = datetime.utcnow()

    if event_type == "new_job":
        items.append(
            {
                "date": now + timedelta(days=30),
                "category": "pension",
                "label": "Transfert LPP",
                "description": "Transférer ton avoir LPP",
                "action_url": "/advisor/lpp-transfer",
                "priority": "high",
            }
        )

    elif event_type == "birth":
        items.append(
            {
                "date": now + timedelta(days=7),
                "category": "insurance",
                "label": "Revue couverture",
                "description": "Vérifier assurances décès/invalidité",
                "action_url": "/advisor/insurance-review",
                "priority": "critical",
            }
        )

    return items
