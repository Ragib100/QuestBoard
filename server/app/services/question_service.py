from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session, selectinload

from app.models import (
    TARGET_ANSWER,
    TARGET_QUESTION,
    Answer,
    PointReason,
    Question,
    Tag,
    User,
    Vote,
)
from app.schemas.question import QuestionCreate, QuestionUpdate
from app.services.activity_service import ActivityService
from app.services.point_service import PointService
from app.services.user_service import UserService
from app.services.vote_service import VoteService

SORTS = ("latest", "bounty", "votes")


class QuestionService:
    @staticmethod
    def _resolve_tags(db: Session, names: list[str]) -> list[Tag]:
        """Tags are a fixed catalogue — unknown names are rejected rather than
        created, so the feed filter cannot fill up with typos."""
        if not names:
            return []

        wanted = {n.strip().lower() for n in names if n.strip()}
        found = db.scalars(select(Tag).where(Tag.name.in_(wanted))).all()

        missing = wanted - {t.name for t in found}
        if missing:
            raise ValueError(f"Unknown tag(s): {', '.join(sorted(missing))}.")

        return list(found)

    @staticmethod
    def _require_author(db: Session, user_id: UUID) -> User:
        return UserService.require_active(db, user_id)

    @classmethod
    def create(cls, db: Session, user_id: UUID, data: QuestionCreate) -> Question:
        author = cls._require_author(db, user_id)
        tags = cls._resolve_tags(db, data.tags)

        question = Question(
            author_id=user_id,
            title=data.title.strip(),
            body=data.body.strip(),
            image_url=data.image_url,
            bounty_points=data.bounty_points,
        )
        question.tags = tags

        try:
            db.add(question)
            db.flush()

            # Credit the daily bonus before charging the bounty: a user whose
            # streak payment would cover the cost should not be refused.
            ActivityService.record(db, author)

            # The bounty leaves the author's balance the moment the quest is
            # posted, so points cannot be promised twice.
            if data.bounty_points:
                PointService.apply(
                    db,
                    author,
                    -data.bounty_points,
                    PointReason.BOUNTY_POSTED,
                    reference_id=question.id,
                )

            db.commit()
            db.refresh(question)
        except Exception:
            db.rollback()
            raise

        return question

    @staticmethod
    def _vote_count_subq():
        return (
            select(func.coalesce(func.sum(Vote.value), 0))
            .where(
                Vote.target_type == TARGET_QUESTION,
                Vote.target_id == Question.id,
            )
            .correlate(Question)
            .scalar_subquery()
        )

    @staticmethod
    def _answer_count_subq():
        return (
            select(func.count(Answer.id))
            .where(Answer.question_id == Question.id)
            .correlate(Question)
            .scalar_subquery()
        )

    @classmethod
    def list_page(
        cls,
        db: Session,
        page: int = 1,
        limit: int = 20,
        tag: str | None = None,
        sort: str = "latest",
        search: str | None = None,
    ) -> tuple[list[dict], int]:
        if sort not in SORTS:
            raise ValueError(f"sort must be one of: {', '.join(SORTS)}.")

        votes = cls._vote_count_subq().label("vote_count")
        answers = cls._answer_count_subq().label("answer_count")

        stmt = select(Question, votes, answers).options(
            selectinload(Question.author), selectinload(Question.tags)
        )

        if tag:
            stmt = stmt.where(Question.tags.any(Tag.name == tag.strip().lower()))

        # Ranks a title hit above a body-only hit. Ordinary `ILIKE '%term%'`
        # cannot use a B-tree, which is why schema.sql creates GIN trigram
        # indexes over both columns — they are what keeps this a index scan.
        title_hit = None
        if search:
            term = f"%{search.strip()}%"
            stmt = stmt.where(Question.title.ilike(term) | Question.body.ilike(term))
            title_hit = case((Question.title.ilike(term), 0), else_=1)

        count_stmt = select(func.count()).select_from(stmt.subquery())
        total = int(db.scalar(count_stmt) or 0)

        if title_hit is not None and sort == "latest":
            # A search has its own idea of "best first"; an explicit sort by
            # bounty or votes is the user overriding that, so it still wins.
            stmt = stmt.order_by(title_hit, Question.created_at.desc())
        elif sort == "bounty":
            stmt = stmt.order_by(
                Question.bounty_points.desc(), Question.created_at.desc()
            )
        elif sort == "votes":
            stmt = stmt.order_by(votes.desc(), Question.created_at.desc())
        else:
            stmt = stmt.order_by(Question.created_at.desc())

        rows = db.execute(stmt.offset((page - 1) * limit).limit(limit)).all()

        items = [
            {"question": q, "vote_count": int(v or 0), "answer_count": int(a or 0)}
            for q, v, a in rows
        ]
        return items, total

    @staticmethod
    def get(db: Session, question_id: UUID, *, count_view: bool = False) -> Question:
        question = db.scalar(
            select(Question)
            .options(
                selectinload(Question.author),
                selectinload(Question.tags),
                selectinload(Question.answers).selectinload(Answer.author),
            )
            .where(Question.id == question_id)
        )
        if question is None:
            raise LookupError("That quest does not exist.")

        if count_view:
            question.view_count += 1
            db.commit()
            db.refresh(question)

        return question

    @classmethod
    def update(
        cls, db: Session, question_id: UUID, user_id: UUID, data: QuestionUpdate
    ) -> Question:
        question = cls.get(db, question_id)

        if question.author_id != user_id:
            raise PermissionError("You can only edit your own quest.")

        if data.title is not None:
            question.title = data.title.strip()
        if data.body is not None:
            question.body = data.body.strip()
        if data.image_url is not None:
            question.image_url = data.image_url
        if data.tags is not None:
            question.tags = cls._resolve_tags(db, data.tags)

        try:
            db.commit()
            db.refresh(question)
        except Exception:
            db.rollback()
            raise

        return question

    @classmethod
    def delete(cls, db: Session, question_id: UUID, user_id: UUID) -> None:
        question = cls.get(db, question_id)

        if question.author_id != user_id:
            raise PermissionError("You can only delete your own quest.")

        if question.answers:
            raise ValueError(
                "This quest already has answers — it can no longer be deleted."
            )

        try:
            # Refund the locked bounty; deleting must not burn the points.
            if question.bounty_points:
                author = db.get(User, question.author_id)
                if author is not None:
                    PointService.apply(
                        db,
                        author,
                        question.bounty_points,
                        PointReason.BOUNTY_REFUNDED,
                        reference_id=question.id,
                    )

            db.execute(
                Vote.__table__.delete().where(
                    Vote.target_type == TARGET_QUESTION,
                    Vote.target_id == question.id,
                )
            )
            db.delete(question)
            db.commit()
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def enrich(db: Session, question: Question, viewer_id: UUID | None) -> dict:
        """Adds the counts and the viewer's own votes that the ORM cannot."""
        answers = []
        for a in question.answers:
            answers.append(
                {
                    "answer": a,
                    "vote_count": VoteService.count_for(db, TARGET_ANSWER, a.id),
                    "my_vote": (
                        VoteService.my_vote(db, viewer_id, TARGET_ANSWER, a.id)
                        if viewer_id
                        else 0
                    ),
                }
            )

        answers.sort(key=lambda x: (not x["answer"].is_accepted, -x["vote_count"]))

        return {
            "question": question,
            "vote_count": VoteService.count_for(db, TARGET_QUESTION, question.id),
            "my_vote": (
                VoteService.my_vote(db, viewer_id, TARGET_QUESTION, question.id)
                if viewer_id
                else 0
            ),
            "answers": answers,
        }
