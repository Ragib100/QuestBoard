from uuid import UUID

from sqlalchemy.orm import Session

from app.models import PointTransaction, User


class PointService:
    """The only place `users.points` is ever written.

    Every movement writes a ledger row and updates the cached balance in the
    same unit of work, so the two can never drift. Nothing here commits — the
    caller owns the transaction, which is what lets a bounty transfer debit one
    user and credit another atomically.
    """

    @staticmethod
    def balance_of(db: Session, user: User) -> int:
        return user.points

    @staticmethod
    def apply(
        db: Session,
        user: User,
        amount: int,
        reason: str,
        reference_id: UUID | None = None,
    ) -> PointTransaction:
        """Move `amount` points (negative to deduct) and log why.

        Raises ValueError if the user cannot afford a deduction, so the caller
        can turn it into a 402 before anything else has happened.
        """
        if amount < 0 and user.points + amount < 0:
            raise ValueError(
                f"Not enough points. This costs {abs(amount)} but you have "
                f"{user.points}."
            )

        user.points += amount

        entry = PointTransaction(
            user_id=user.id,
            amount=amount,
            reason=reason,
            reference_id=reference_id,
        )
        db.add(entry)
        return entry
