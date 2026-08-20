from datetime import timedelta
from uuid import UUID

import httpx
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core import clock
from app.core.config import settings
from app.models import HINT_COST, AiHint, PointReason, Question, User
from app.services.point_service import PointService

# Three an hour. Enough to get unstuck on a hard quest, not enough to walk the
# model through a whole problem set — the point economy is the other brake.
HOURLY_LIMIT = 3

# Generous for a five-sentence hint, because `max_tokens` caps thinking and
# response text together on Claude Opus 5.
MAX_TOKENS = 2000

# Free tiers are slower than paid ones; the client allows 60s for this call.
TIMEOUT = 45.0

SYSTEM_PROMPT = """You are a Socratic tutor for STEM students on QuestBoard.

A student is stuck on the question below and has spent points to ask you for a
hint. Give them the smallest push that gets them moving again.

Rules:
- Never give the answer, the final result, or complete working code. If the
  question asks "what is X", do not state X.
- Name the concept or theorem that applies, or ask the question that exposes
  the student's wrong assumption.
- Point at the specific step where their reasoning breaks down when you can
  see it.
- Four sentences at most. Plain text, no markdown headings.
- If the question is too vague to hint at, say what detail is missing instead
  of guessing."""


class AiHintError(RuntimeError):
    """The model could not be reached, or is not configured."""


class AiService:
    """AI hints on a quest, paid for in points.

    The deduction happens before the model call and the whole thing runs in
    one transaction, so a failed call rolls the points back rather than
    charging for nothing.
    """

    @staticmethod
    def is_configured() -> bool:
        return bool(settings.AI_API_KEY or settings.ANTHROPIC_API_KEY)

    @staticmethod
    def _used_this_hour(db: Session, user_id: UUID) -> int:
        cutoff = clock.naive_utc_now() - timedelta(hours=1)
        return int(
            db.scalar(
                select(func.count(AiHint.id)).where(
                    AiHint.user_id == user_id,
                    AiHint.created_at >= cutoff,
                )
            )
            or 0
        )

    @staticmethod
    def _prompt(question: Question) -> str:
        return f"Title: {question.title}\n\nWhat the student wrote:\n{question.body}"

    @classmethod
    def _ask(cls, question: Question) -> str:
        """Whichever backend is configured. The OpenAI-compatible one wins.

        Both return plain text or raise AiHintError; the caller does not care
        which model produced the hint.
        """
        if settings.AI_API_KEY:
            return cls._ask_openai_compatible(question)
        return cls._ask_anthropic(question)

    @classmethod
    def _ask_openai_compatible(cls, question: Question) -> str:
        """Any `/chat/completions` endpoint — Gemini, Groq, OpenRouter, …

        One shape covers all of them, which is the whole point: swapping
        providers when a free tier runs out is three lines of `.env`, not a
        code change.
        """
        base = settings.AI_BASE_URL.rstrip("/")
        if not base or not settings.AI_MODEL:
            raise AiHintError(
                "AI hints are half-configured: AI_API_KEY is set but "
                "AI_BASE_URL or AI_MODEL is missing."
            )

        response = httpx.post(
            f"{base}/chat/completions",
            timeout=TIMEOUT,
            headers={"Authorization": f"Bearer {settings.AI_API_KEY}"},
            json={
                "model": settings.AI_MODEL,
                "max_tokens": MAX_TOKENS,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": cls._prompt(question)},
                ],
            },
        )

        if response.status_code == 429:
            raise AiHintError(
                "The AI provider's free quota is used up for now. "
                "Try again later — you were not charged."
            )
        if response.status_code >= 400:
            # Surface the provider's own message: a bad key or a retired model
            # name is the usual cause, and "unavailable" would hide it.
            raise AiHintError(
                f"The hint service rejected the request ({response.status_code}). "
                "You were not charged."
            )

        choices = response.json().get("choices") or []
        text = (choices[0]["message"].get("content") or "").strip() if choices else ""
        if not text:
            raise AiHintError("The model returned an empty hint. Try again.")
        return text

    @classmethod
    def _ask_anthropic(cls, question: Question) -> str:
        # Imported here so the `anthropic` package is only needed by servers
        # that actually use it — a free-tier deploy installs nothing extra.
        import anthropic

        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        response = client.messages.create(
            model=settings.ANTHROPIC_MODEL,
            max_tokens=MAX_TOKENS,
            system=SYSTEM_PROMPT,
            output_config={"effort": "low"},
            messages=[{"role": "user", "content": cls._prompt(question)}],
        )

        if response.stop_reason == "refusal":
            raise AiHintError(
                "The model declined to answer this one. Try rephrasing your quest."
            )

        text = "\n".join(
            block.text for block in response.content if block.type == "text"
        ).strip()
        if not text:
            raise AiHintError("The model returned an empty hint. Try again.")
        return text

    @classmethod
    def hint(cls, db: Session, question_id: UUID, user_id: UUID) -> tuple[str, int]:
        """Returns (hint_text, points_remaining).

        Raises LookupError (unknown quest or profile), ValueError (not enough
        points), PermissionError (hourly cap) or AiHintError (model failure).
        """
        if not cls.is_configured():
            raise AiHintError("AI hints are not configured on this server yet.")

        question = db.get(Question, question_id)
        if question is None:
            raise LookupError("That quest does not exist.")

        user = db.get(User, user_id)
        if user is None:
            raise LookupError("Finish setting up your profile first.")

        used = cls._used_this_hour(db, user_id)
        if used >= HOURLY_LIMIT:
            raise PermissionError(
                f"You have used all {HOURLY_LIMIT} hints for this hour. "
                "Try again later."
            )

        # Deduct up front so an expensive model call cannot be started by
        # someone who cannot pay for it.
        try:
            PointService.apply(
                db, user, -HINT_COST, PointReason.AI_HINT, reference_id=question_id
            )
        except ValueError:
            db.rollback()
            raise

        try:
            text = cls._ask(question)
        except AiHintError:
            # The refund: nothing in this transaction has been committed, so
            # dropping it puts the points back exactly where they were.
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            raise AiHintError(
                "The hint service is unavailable right now. You were not charged."
            ) from e

        db.add(
            AiHint(
                question_id=question_id,
                user_id=user_id,
                hint_text=text,
                points_cost=HINT_COST,
            )
        )
        db.commit()

        return text, user.points

    @staticmethod
    def remaining_today(db: Session, user_id: UUID) -> int:
        return max(0, HOURLY_LIMIT - AiService._used_this_hour(db, user_id))
