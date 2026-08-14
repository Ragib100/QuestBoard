"""Importing every model here keeps SQLAlchemy's registry complete.

`User.quests` and `Quest.user` reference each other by class *name*, which only
resolves if both classes have been imported. Import this package (not the
individual modules) so the mapping never half-loads.
"""

from .quest import Quest
from .user import User

__all__ = [
    "Quest",
    "User",
]
