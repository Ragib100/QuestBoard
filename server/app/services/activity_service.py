from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models import PointReason, User
from app.services.point_service import PointService

DAILY_BONUS = 10


class ActivityService:
    """Streak tracking and the once-a-day login bonus.

    Called at the start of every action that counts as participating — posting
    a quest, answering, accepting, voting. Anything that only reads does not
    count, otherwise opening the app would be enough to keep a streak alive.

    Does not commit: it joins the caller's transaction so the bonus and the
    action that earned it either both land or neither does.
    """

    @staticmethod
    def _as_date(value: datetime | None) -> date | None:
        if value is None:
            return None
        # last_active is stored without a timezone on some rows; normalise so
        # the comparison below never raises on a naive/aware mismatch.
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).date()

    @classmethod
    def record(cls, db: Session, user: User) -> bool:
        """Updates the streak and grants the daily bonus.

        Returns True when this was the user's first activity today.
        """
        now = datetime.now(timezone.utc)
        today = now.date()
        last = cls._as_date(user.last_active)

        if last == today:
            return False

        if last == today - timedelta(days=1):
            user.streak_days += 1
        else:
            # First ever activity, or the chain broke.
            user.streak_days = 1

        user.last_active = now

        PointService.apply(
            db,
            user,
            DAILY_BONUS,
            PointReason.DAILY_BONUS,
        )
        return True
