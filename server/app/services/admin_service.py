from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.models import (
    TARGET_ANSWER,
    TARGET_QUESTION,
    Answer,
    PointReason,
    Question,
    User,
    Vote,
)
from app.services.point_service import PointService


class AdminService:
    """Moderation. Every method here deliberately bypasses the ownership checks
    the normal services enforce — the router is what keeps it behind
    `require_admin`."""

    @staticmethod
    def stats(db: Session) -> dict:
        return {
            "total_users": int(db.scalar(select(func.count(User.id))) or 0),
            "suspended_users": int(
                db.scalar(
                    select(func.count(User.id)).where(User.is_suspended.is_(True))
                )
                or 0
            ),
            "total_quests": int(db.scalar(select(func.count(Question.id))) or 0),
            "open_quests": int(
                db.scalar(
                    select(func.count(Question.id)).where(Question.is_solved.is_(False))
                )
                or 0
            ),
            "total_answers": int(db.scalar(select(func.count(Answer.id))) or 0),
            # The sum of balances, not of the ledger: the two agree by
            # construction (docs/decisions.md D15) and this is one table.
            "points_in_circulation": int(
                db.scalar(select(func.coalesce(func.sum(User.points), 0))) or 0
            ),
        }

    @staticmethod
    def list_users(
        db: Session, page: int = 1, limit: int = 20, search: str | None = None
    ) -> tuple[list[User], int]:
        stmt = select(User)

        if search:
            term = f"%{search.strip()}%"
            # Email lives in auth.users and is never copied here
            # (docs/data-model.md), so username and name are all we can match.
            stmt = stmt.where(
                or_(
                    User.username.ilike(term),
                    User.first_name.ilike(term),
                    User.last_name.ilike(term),
                )
            )

        total = int(db.scalar(select(func.count()).select_from(stmt.subquery())) or 0)

        rows = db.scalars(
            stmt.order_by(User.created_at.desc())
            .offset((page - 1) * limit)
            .limit(limit)
        ).all()

        return list(rows), total

    @staticmethod
    def set_suspended(
        db: Session, target_id: UUID, admin_id: UUID, suspended: bool
    ) -> User:
        user = db.get(User, target_id)
        if user is None:
            raise LookupError("No such user.")

        # Locking yourself out would leave the board with one fewer admin and
        # no way back in without a SQL console.
        if user.id == admin_id:
            raise PermissionError("You cannot suspend your own account.")
        if user.is_admin and suspended:
            raise PermissionError("Remove admin rights before suspending an admin.")

        user.is_suspended = suspended
        try:
            db.commit()
            db.refresh(user)
        except Exception:
            db.rollback()
            raise

        return user

    @staticmethod
    def delete_quest(db: Session, question_id: UUID) -> None:
        """Force-delete, answers and all.

        The author's own DELETE refuses once a quest has answers; moderation
        cannot afford that rule. Points still have to balance, so an unsolved
        quest refunds its bounty exactly as a self-delete would — but a solved
        one does not, because that bounty has already been paid to the helper
        and refunding it would mint points out of nothing.
        """
        question = db.scalar(
            select(Question)
            .options(selectinload(Question.answers))
            .where(Question.id == question_id)
        )
        if question is None:
            raise LookupError("That quest does not exist.")

        answer_ids = [a.id for a in question.answers]

        try:
            if question.bounty_points and not question.is_solved:
                author = db.get(User, question.author_id)
                if author is not None:
                    PointService.apply(
                        db,
                        author,
                        question.bounty_points,
                        PointReason.BOUNTY_REFUNDED,
                        reference_id=question.id,
                    )

            # Votes are polymorphic and have no foreign key, so the cascade
            # that removes the answers will not remove their votes.
            targets = [(TARGET_QUESTION, question.id)] + [
                (TARGET_ANSWER, aid) for aid in answer_ids
            ]
            for target_type, target_id in targets:
                db.execute(
                    Vote.__table__.delete().where(
                        Vote.target_type == target_type,
                        Vote.target_id == target_id,
                    )
                )

            # Breaks questions.accepted_answer_id before the answers go, so the
            # self-referencing FK cannot block the delete.
            question.accepted_answer_id = None
            db.flush()

            db.delete(question)
            db.commit()
        except Exception:
            db.rollback()
            raise
