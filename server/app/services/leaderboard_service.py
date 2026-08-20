from datetime import timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core import clock
from app.models import PointTransaction, User

WEEKLY = "weekly"
ALL_TIME = "all_time"
PERIODS = (WEEKLY, ALL_TIME)


class LeaderboardService:
    """Rankings.

    All-time reads `users.points` directly. Weekly sums the ledger over the last
    seven days instead of snapshotting scores on a schedule — the ledger is
    already an append-only history, so the number can always be recomputed and
    there is no cron job to forget, no snapshot table to drift, and no Monday
    morning where the reset did not run.
    """

    @staticmethod
    def _weekly_scores():
        # Naive UTC, matching the column: `point_transactions.created_at` is
        # `timestamp without time zone`, and handing Postgres an aware value
        # made the comparison depend on the session timezone.
        since = clock.naive_utc_now() - timedelta(days=7)
        return (
            select(
                PointTransaction.user_id.label("user_id"),
                func.sum(PointTransaction.amount).label("score"),
            )
            .where(PointTransaction.created_at >= since)
            .group_by(PointTransaction.user_id)
            .subquery()
        )

    @classmethod
    def top(cls, db: Session, period: str = ALL_TIME, limit: int = 20) -> list[dict]:
        if period not in PERIODS:
            raise ValueError(f"period must be one of: {', '.join(PERIODS)}.")

        if period == ALL_TIME:
            rows = db.execute(
                select(User, User.points.label("score"))
                .order_by(User.points.desc(), User.created_at)
                .limit(limit)
            ).all()
        else:
            scores = cls._weekly_scores()
            rows = db.execute(
                select(User, scores.c.score)
                .join(scores, scores.c.user_id == User.id)
                .order_by(scores.c.score.desc(), User.created_at)
                .limit(limit)
            ).all()

        return [
            {"rank": i + 1, "user": user, "score": int(score or 0)}
            for i, (user, score) in enumerate(rows)
        ]

    @classmethod
    def rank_of(cls, db: Session, user_id: UUID, period: str = ALL_TIME) -> dict | None:
        """The caller's own standing, so they can see it even outside the top 20."""
        user = db.get(User, user_id)
        if user is None:
            return None

        if period == ALL_TIME:
            ahead = db.scalar(
                select(func.count(User.id)).where(User.points > user.points)
            )
            return {"rank": int(ahead or 0) + 1, "user": user, "score": user.points}

        scores = cls._weekly_scores()
        mine = db.scalar(select(scores.c.score).where(scores.c.user_id == user_id))

        if mine is None:
            return {"rank": None, "user": user, "score": 0}

        ahead = db.scalar(
            select(func.count()).select_from(scores).where(scores.c.score > mine)
        )
        return {"rank": int(ahead or 0) + 1, "user": user, "score": int(mine)}
