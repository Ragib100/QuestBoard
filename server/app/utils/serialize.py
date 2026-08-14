"""Turning ORM rows plus their computed counts into response schemas.

Vote and answer counts are aggregates, not columns, so the services return them
alongside the model. These helpers keep that stitching in one place instead of
spreading it across every router.
"""

from app.schemas.question import AnswerResponse, QuestionDetail, QuestionSummary
from app.schemas.user import UserSummary


def answer_payload(row: dict) -> AnswerResponse:
    answer = row["answer"]
    return AnswerResponse(
        id=answer.id,
        question_id=answer.question_id,
        body=answer.body,
        image_url=answer.image_url,
        is_accepted=answer.is_accepted,
        created_at=answer.created_at,
        author=UserSummary.model_validate(answer.author),
        vote_count=row.get("vote_count", 0),
        my_vote=row.get("my_vote", 0),
    )


def _summary_fields(question, vote_count: int, answer_count: int) -> dict:
    return {
        "id": question.id,
        "title": question.title,
        "bounty_points": question.bounty_points,
        "is_solved": question.is_solved,
        "view_count": question.view_count,
        "created_at": question.created_at,
        "author": UserSummary.model_validate(question.author),
        "tags": [t.name for t in question.tags],
        "answer_count": answer_count,
        "vote_count": vote_count,
    }


def question_summary(row: dict) -> QuestionSummary:
    return QuestionSummary(
        **_summary_fields(
            row["question"], row.get("vote_count", 0), row.get("answer_count", 0)
        )
    )


def question_detail(row: dict) -> QuestionDetail:
    question = row["question"]
    answers = row.get("answers", [])
    return QuestionDetail(
        **_summary_fields(question, row.get("vote_count", 0), len(answers)),
        body=question.body,
        image_url=question.image_url,
        accepted_answer_id=question.accepted_answer_id,
        my_vote=row.get("my_vote", 0),
        answers=[answer_payload(a) for a in answers],
    )
