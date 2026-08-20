"""Importing every model here keeps SQLAlchemy's registry complete.

Relationships reference each other by class *name*, which only resolves once
every class has been imported. Import this package, never the modules directly.
"""

from .ai_hint import HINT_COST, AiHint
from .answer import Answer
from .badge import Badge, BadgeCode, UserBadge
from .challenge import (
    CHALLENGE_BONUS,
    DECAY_FLOOR,
    DECAY_PER_DAY,
    ChallengeAttempt,
    DailyChallenge,
    Difficulty,
    award_for,
)
from .notification import Notification, NotificationType
from .point_transaction import PointReason, PointTransaction
from .question import Question, Tag, question_tags
from .user import SIGNUP_BONUS, User
from .vote import TARGET_ANSWER, TARGET_QUESTION, Vote

__all__ = [
    "AiHint",
    "Answer",
    "Badge",
    "BadgeCode",
    "CHALLENGE_BONUS",
    "ChallengeAttempt",
    "DECAY_FLOOR",
    "DECAY_PER_DAY",
    "DailyChallenge",
    "Difficulty",
    "HINT_COST",
    "Notification",
    "NotificationType",
    "PointReason",
    "PointTransaction",
    "Question",
    "SIGNUP_BONUS",
    "Tag",
    "TARGET_ANSWER",
    "TARGET_QUESTION",
    "User",
    "UserBadge",
    "Vote",
    "award_for",
    "question_tags",
]
