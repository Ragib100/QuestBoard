"""Importing every model here keeps SQLAlchemy's registry complete.

Relationships reference each other by class *name*, which only resolves once
every class has been imported. Import this package, never the modules directly.
"""

from .answer import Answer
from .point_transaction import PointReason, PointTransaction
from .question import Question, Tag, question_tags
from .user import User
from .vote import TARGET_ANSWER, TARGET_QUESTION, Vote

__all__ = [
    "Answer",
    "PointReason",
    "PointTransaction",
    "Question",
    "Tag",
    "TARGET_ANSWER",
    "TARGET_QUESTION",
    "User",
    "Vote",
    "question_tags",
]
