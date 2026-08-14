from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models import (
    TARGET_ANSWER,
    Answer,
    NotificationType,
    PointReason,
    Question,
    User,
    Vote,
)
from app.schemas.answer import AnswerCreate, AnswerUpdate
from app.services.activity_service import ActivityService
from app.services.badge_service import BadgeService
from app.services.notification_service import NotificationService
from app.services.point_service import PointService


class AnswerService:
    @staticmethod
    def _get(db: Session, answer_id: UUID) -> Answer:
        answer = db.scalar(
            select(Answer)
            .options(selectinload(Answer.author))
            .where(Answer.id == answer_id)
        )
        if answer is None:
            raise LookupError("That answer does not exist.")
        return answer

    @classmethod
    def create(
        cls, db: Session, question_id: UUID, user_id: UUID, data: AnswerCreate
    ) -> Answer:
        question = db.get(Question, question_id)
        if question is None:
            raise LookupError("That quest does not exist.")

        if question.is_solved:
            raise ValueError("This quest is already solved.")

        if question.author_id == user_id:
            raise PermissionError("You cannot answer your own quest.")

        author = db.get(User, user_id)
        if author is None:
            raise ValueError("Complete your profile first.")

        answer = Answer(
            question_id=question_id,
            author_id=user_id,
            body=data.body.strip(),
            image_url=data.image_url,
        )

        try:
            db.add(answer)
            db.flush()

            ActivityService.record(db, author)
            BadgeService.sync(db, author)

            NotificationService.create(
                db,
                user_id=question.author_id,
                notification_type=NotificationType.ANSWER_RECEIVED,
                message=f"{author.username} answered your quest "
                f'"{question.title}".',
                reference_id=question.id,
            )

            db.commit()
            db.refresh(answer)
        except Exception:
            db.rollback()
            raise

        return answer

    @classmethod
    def update(
        cls, db: Session, answer_id: UUID, user_id: UUID, data: AnswerUpdate
    ) -> Answer:
        answer = cls._get(db, answer_id)

        if answer.author_id != user_id:
            raise PermissionError("You can only edit your own answer.")

        if answer.is_accepted:
            raise ValueError("An accepted answer can no longer be edited.")

        answer.body = data.body.strip()
        if data.image_url is not None:
            answer.image_url = data.image_url

        try:
            db.commit()
            db.refresh(answer)
        except Exception:
            db.rollback()
            raise

        return answer

    @classmethod
    def delete(cls, db: Session, answer_id: UUID, user_id: UUID) -> None:
        answer = cls._get(db, answer_id)

        if answer.author_id != user_id:
            raise PermissionError("You can only delete your own answer.")

        if answer.is_accepted:
            raise ValueError("An accepted answer can no longer be deleted.")

        try:
            db.execute(
                Vote.__table__.delete().where(
                    Vote.target_type == TARGET_ANSWER,
                    Vote.target_id == answer.id,
                )
            )
            db.delete(answer)
            db.commit()
        except Exception:
            db.rollback()
            raise

    @classmethod
    def accept(cls, db: Session, answer_id: UUID, user_id: UUID) -> Answer:
        """Award the bounty to the helper.

        This is the core of the economy, so it is one transaction: mark the
        answer accepted, close the quest, credit the helper, and log the
        movement. A partial apply here would create or destroy points.
        """
        answer = cls._get(db, answer_id)
        question = db.get(Question, answer.question_id)

        if question is None:
            raise LookupError("That quest does not exist.")

        if question.author_id != user_id:
            raise PermissionError("Only the quest author can accept an answer.")

        if question.is_solved:
            raise ValueError("This quest already has an accepted answer.")

        helper = db.get(User, answer.author_id)
        if helper is None:
            raise ValueError("That answer's author no longer exists.")

        asker = db.get(User, user_id)

        try:
            answer.is_accepted = True
            question.is_solved = True
            question.accepted_answer_id = answer.id

            # The points were already debited from the author at post time,
            # so accepting only credits the helper.
            if question.bounty_points:
                PointService.apply(
                    db,
                    helper,
                    question.bounty_points,
                    PointReason.BOUNTY_AWARDED,
                    reference_id=question.id,
                )
                NotificationService.create(
                    db,
                    user_id=helper.id,
                    notification_type=NotificationType.BOUNTY_AWARDED,
                    message=f"You won {question.bounty_points} points for "
                    f'answering "{question.title}".',
                    reference_id=question.id,
                )

            NotificationService.create(
                db,
                user_id=helper.id,
                notification_type=NotificationType.ANSWER_ACCEPTED,
                message=f'Your answer to "{question.title}" was accepted.',
                reference_id=question.id,
            )

            if asker is not None:
                ActivityService.record(db, asker)

            # Winning a bounty can unlock first_bounty or bounty_hunter.
            BadgeService.sync(db, helper)

            db.commit()
            db.refresh(answer)
        except Exception:
            db.rollback()
            raise

        return answer
