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
    def apply(
        db: Session,
        user: User,
        amount: int,
        reason: str,
        reference_id: UUID | None = None,
        allow_negative: bool = False,
    ) -> PointTransaction | None:
        """Move `amount` points (negative to deduct) and log why.

        Raises ValueError if the user cannot afford a deduction, so the caller
        can turn it into a 402 before anything else has happened.

        `allow_negative` lifts that check. It exists for exactly one caller —
        a downvote debiting an author who has already spent everything. That
        movement is not the author's own action to be refused: refusing it
        would fail *the voter's* request, and clamping it at zero would let a
        downvote-then-upvote flip mint the difference. A balance that dips
        below zero is the honest record of what happened.

        Returns None for a zero movement: `users.points` does not change and a
        ledger row saying so is noise in someone's point history.
        """
        if amount == 0:
            return None

        if amount < 0 and user.points + amount < 0 and not allow_negative:
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

        # The session runs with autoflush off, so anything that reads the ledger
        # later in the same transaction — a badge check counting bounties won —
        # would not see this row. Flush, but never commit: the caller still owns
        # the transaction.
        db.flush()
        return entry
