"""The point economy, which is the part of QuestBoard that cannot be wrong.

The invariant these all defend: **`users.points` always equals the sum of that
user's ledger rows, and points are only ever moved, never minted or burned.**
Every test asserts the balance *and* the ledger, because a bug that updates one
without the other is exactly the failure the ledger exists to prevent.

These were run by hand against the live database through M2–M5; this file is
that suite, committed.
"""

import pytest
from sqlalchemy.orm import Session

from app.models import TARGET_ANSWER, TARGET_QUESTION, PointReason
from app.schemas.answer import AnswerCreate
from app.schemas.question import QuestionCreate
from app.services.admin_service import AdminService
from app.services.answer_service import AnswerService
from app.services.point_service import PointService
from app.services.question_service import QuestionService
from app.services.user_service import UserService
from app.services.vote_service import VoteService

from tests.conftest import ledger_total


def quest_payload(bounty: int = 0) -> QuestionCreate:
    return QuestionCreate(
        title="How do I balance a red-black tree?",
        body="I keep violating the black-height invariant after a deletion.",
        tags=["dsa"],
        bounty_points=bounty,
    )


# --------------------------------------------------------------- PointService


def test_balance_and_ledger_move_together(db: Session, make_user):
    user = make_user(points=100)

    PointService.apply(db, user, -30, PointReason.BOUNTY_POSTED)
    PointService.apply(db, user, 12, PointReason.VOTE_RECEIVED)

    assert user.points == 82
    assert ledger_total(db, user) == -18, "ledger must explain the whole change"


def test_cannot_spend_below_zero(db: Session, make_user):
    user = make_user(points=10)

    with pytest.raises(ValueError, match="Not enough points"):
        PointService.apply(db, user, -11, PointReason.AI_HINT)

    assert user.points == 10
    assert ledger_total(db, user) == 0, "a refused deduction writes nothing"


def test_every_reason_survives_the_check_constraint(db: Session, make_user):
    """The CHECK constraint on `reason` drifted out of sync with `PointReason`
    once and broke two shipped features, so every value gets inserted here."""
    user = make_user(points=1000)
    reasons = [v for k, v in vars(PointReason).items() if k.isupper()]
    assert len(reasons) == 9

    for reason in reasons:
        PointService.apply(db, user, 1, reason)

    db.flush()
    assert ledger_total(db, user) == len(reasons)


# ---------------------------------------------------------------- Quest loop


def test_posting_a_bounty_charges_the_author(db: Session, make_user):
    author = make_user(points=100)

    quest = QuestionService.create(db, author.id, quest_payload(bounty=40))

    db.refresh(author)
    # +10 daily bonus on first activity of the day, -40 bounty.
    assert author.points == 70
    assert ledger_total(db, author) == -30
    assert quest.bounty_points == 40


def test_posting_more_bounty_than_you_have_is_refused(db: Session, make_user):
    author = make_user(points=5)

    with pytest.raises(ValueError, match="Not enough points"):
        QuestionService.create(db, author.id, quest_payload(bounty=100))

    db.refresh(author)
    assert author.points == 5


def test_accepting_an_answer_transfers_the_bounty(db: Session, make_user):
    author = make_user(points=100)
    helper = make_user(points=100)

    quest = QuestionService.create(db, author.id, quest_payload(bounty=40))
    answer = AnswerService.create(
        db, quest.id, helper.id, AnswerCreate(body="Recolour, then rotate.")
    )
    AnswerService.accept(db, answer.id, author.id)

    db.refresh(author)
    db.refresh(helper)
    db.refresh(quest)

    assert quest.is_solved
    assert quest.accepted_answer_id == answer.id
    # The bounty left the author at post time and arrives here; the daily
    # bonus each of them earned is separate and stays.
    assert ledger_total(db, author) == -30
    assert ledger_total(db, helper) == 50
    assert author.points == 70
    assert helper.points == 150


def test_the_economy_is_closed(db: Session, make_user):
    """Nothing in a full quest cycle creates or destroys points beyond the
    daily bonus, which is the one deliberate source."""
    author = make_user(points=100)
    helper = make_user(points=100)
    before = author.points + helper.points

    quest = QuestionService.create(db, author.id, quest_payload(bounty=25))
    answer = AnswerService.create(
        db, quest.id, helper.id, AnswerCreate(body="Recolour the uncle, then rotate.")
    )
    AnswerService.accept(db, answer.id, author.id)

    db.refresh(author)
    db.refresh(helper)
    minted = ledger_total(db, author) + ledger_total(db, helper)
    bonuses = 10 * 2  # one daily bonus each

    assert author.points + helper.points == before + minted
    assert minted == bonuses, "the bounty moved sideways; only bonuses are new"


def test_deleting_an_unanswered_quest_refunds_the_bounty(db: Session, make_user):
    author = make_user(points=100)
    quest = QuestionService.create(db, author.id, quest_payload(bounty=40))
    db.refresh(author)
    charged = author.points

    QuestionService.delete(db, quest.id, author.id)

    db.refresh(author)
    assert author.points == charged + 40
    assert ledger_total(db, author) == 10, "back to just the daily bonus"


def test_a_quest_with_answers_cannot_be_self_deleted(db: Session, make_user):
    author = make_user(points=100)
    helper = make_user(points=100)
    quest = QuestionService.create(db, author.id, quest_payload(bounty=40))
    AnswerService.create(db, quest.id, helper.id, AnswerCreate(body="Try rotating."))

    with pytest.raises(ValueError, match="already has answers"):
        QuestionService.delete(db, quest.id, author.id)


# --------------------------------------------------------------------- Votes


def test_votes_move_the_author_balance_by_the_delta(db: Session, make_user):
    author = make_user(points=100)
    voter = make_user(points=100)
    quest = QuestionService.create(db, author.id, quest_payload())
    db.refresh(author)
    start = author.points

    VoteService.cast(db, voter.id, TARGET_QUESTION, quest.id, 1)
    db.refresh(author)
    assert author.points == start + 1

    # Flipping to a downvote is a delta of -2, not a second -1.
    VoteService.cast(db, voter.id, TARGET_QUESTION, quest.id, -1)
    db.refresh(author)
    assert author.points == start - 1

    # The same value again clears the vote, returning the point.
    count, mine = VoteService.cast(db, voter.id, TARGET_QUESTION, quest.id, -1)
    db.refresh(author)
    assert (count, mine) == (0, 0)
    assert author.points == start


def test_a_downvote_still_lands_on_an_author_with_no_points(
    db: Session, make_user, make_quest
):
    """The bug this guards: the debit went through the same affordability check
    as a purchase, so downvoting a broke author raised "Not enough points" —
    failing *the voter's* request and quoting them someone else's balance."""
    author = make_user(points=0)
    voter = make_user(points=100)
    quest = make_quest(author, bounty=0)

    count, mine = VoteService.cast(db, voter.id, TARGET_QUESTION, quest.id, -1)
    db.commit()
    db.refresh(author)

    assert (count, mine) == (-1, -1)
    assert author.points == -1, "the debit is recorded, not silently dropped"
    assert ledger_total(db, author) == -1, "balance and ledger stay in step"


def test_flipping_a_vote_on_a_broke_author_cannot_mint_points(
    db: Session, make_user, make_quest
):
    """Clamping the debit at zero instead of letting the balance go negative
    would hand the author a free point on the flip back up."""
    author = make_user(points=0)
    voter = make_user(points=100)
    quest = make_quest(author, bounty=0)

    VoteService.cast(db, voter.id, TARGET_QUESTION, quest.id, -1)
    VoteService.cast(db, voter.id, TARGET_QUESTION, quest.id, 1)
    db.commit()
    db.refresh(author)

    assert author.points == 1, "down then up is a net +1, not +2"
    assert ledger_total(db, author) == 1


def test_a_zero_movement_writes_nothing(db: Session, make_user):
    """A challenge worth 0 points used to write a 0-amount ledger row — noise
    in a point history that is meant to explain a balance."""
    user = make_user(points=100)

    entry = PointService.apply(db, user, 0, PointReason.CHALLENGE_SOLVED)

    assert entry is None
    assert user.points == 100
    assert ledger_total(db, user) == 0


def test_self_votes_are_refused(db: Session, make_user):
    author = make_user(points=100)
    quest = QuestionService.create(db, author.id, quest_payload())

    with pytest.raises(PermissionError, match="your own"):
        VoteService.cast(db, author.id, TARGET_QUESTION, quest.id, 1)


def test_self_answers_are_refused(db: Session, make_user):
    author = make_user(points=100)
    quest = QuestionService.create(db, author.id, quest_payload())

    with pytest.raises(PermissionError, match="your own"):
        AnswerService.create(
            db, quest.id, author.id, AnswerCreate(body="Answering me.")
        )


def test_only_the_author_accepts_and_only_once(db: Session, make_user):
    author = make_user(points=100)
    helper = make_user(points=100)
    outsider = make_user(points=100)

    quest = QuestionService.create(db, author.id, quest_payload(bounty=10))
    answer = AnswerService.create(
        db, quest.id, helper.id, AnswerCreate(body="Here is the invariant you broke.")
    )

    with pytest.raises(PermissionError):
        AnswerService.accept(db, answer.id, outsider.id)

    AnswerService.accept(db, answer.id, author.id)
    with pytest.raises(ValueError):
        AnswerService.accept(db, answer.id, author.id)

    db.refresh(helper)
    assert ledger_total(db, helper) == 20, "paid once: 10 bounty + 10 bonus"


# ------------------------------------------------------------- Moderation


def test_suspension_blocks_writing_but_not_reading(db: Session, make_user):
    user = make_user(points=100, suspended=True)

    with pytest.raises(PermissionError, match="suspended"):
        UserService.require_active(db, user.id)
    with pytest.raises(PermissionError, match="suspended"):
        QuestionService.create(db, user.id, quest_payload())

    # Reading is untouched — list_page takes no user at all.
    assert QuestionService.list_page(db, limit=1) is not None


def test_admins_cannot_suspend_themselves_or_each_other(db: Session, make_user):
    admin = make_user(is_admin=True)
    other_admin = make_user(is_admin=True)

    with pytest.raises(PermissionError, match="your own"):
        AdminService.set_suspended(db, admin.id, admin.id, True)
    with pytest.raises(PermissionError, match="admin"):
        AdminService.set_suspended(db, other_admin.id, admin.id, True)


def test_suspending_is_reversible(db: Session, make_user):
    admin = make_user(is_admin=True)
    user = make_user()

    assert AdminService.set_suspended(db, user.id, admin.id, True).is_suspended
    assert not AdminService.set_suspended(db, user.id, admin.id, False).is_suspended
    UserService.require_active(db, user.id)  # no longer raises


def test_force_delete_refunds_an_unsolved_quest(db: Session, make_user):
    author = make_user(points=100)
    helper = make_user(points=100)
    quest = QuestionService.create(db, author.id, quest_payload(bounty=30))
    answer = AnswerService.create(
        db, quest.id, helper.id, AnswerCreate(body="Have you tried rotating first?")
    )
    VoteService.cast(db, author.id, TARGET_ANSWER, answer.id, 1)
    db.refresh(author)
    charged = author.points

    AdminService.delete_quest(db, quest.id)

    db.refresh(author)
    assert author.points == charged + 30


def test_force_delete_does_not_refund_a_paid_out_bounty(db: Session, make_user):
    """The helper already has those points. Refunding would mint them twice."""
    author = make_user(points=100)
    helper = make_user(points=100)
    quest = QuestionService.create(db, author.id, quest_payload(bounty=30))
    answer = AnswerService.create(
        db, quest.id, helper.id, AnswerCreate(body="Have you tried rotating first?")
    )
    AnswerService.accept(db, answer.id, author.id)
    db.refresh(author)
    db.refresh(helper)
    author_before, helper_before = author.points, helper.points

    AdminService.delete_quest(db, quest.id)

    db.refresh(author)
    db.refresh(helper)
    assert author.points == author_before
    assert helper.points == helper_before


def test_force_delete_removes_answers_and_their_votes(db: Session, make_user):
    author = make_user(points=100)
    helper = make_user(points=100)
    quest = QuestionService.create(db, author.id, quest_payload(bounty=10))
    answer = AnswerService.create(
        db, quest.id, helper.id, AnswerCreate(body="Have you tried rotating first?")
    )
    VoteService.cast(db, author.id, TARGET_ANSWER, answer.id, 1)
    VoteService.cast(db, helper.id, TARGET_QUESTION, quest.id, 1)

    AdminService.delete_quest(db, quest.id)

    # Votes are polymorphic with no foreign key, so nothing cascades them.
    assert VoteService.count_for(db, TARGET_ANSWER, answer.id) == 0
    assert VoteService.count_for(db, TARGET_QUESTION, quest.id) == 0
    with pytest.raises(LookupError):
        QuestionService.get(db, quest.id)


def test_admin_stats_count_the_real_rows(db: Session, make_user):
    before = AdminService.stats(db)
    author = make_user(points=100)
    QuestionService.create(db, author.id, quest_payload(bounty=5))

    after = AdminService.stats(db)
    assert after["total_users"] == before["total_users"] + 1
    assert after["total_quests"] == before["total_quests"] + 1


# ------------------------------------------------------- the admin gate ---


def test_require_admin_refuses_an_ordinary_user(db: Session, make_user):
    """`AdminService` deliberately skips every ownership check the normal
    services enforce, so this dependency is the only thing standing between it
    and any signed-in caller. Worth a test of its own."""
    from fastapi import HTTPException

    from app.dependencies.admin import require_admin

    user = make_user()

    with pytest.raises(HTTPException) as raised:
        require_admin(db=db, user_id=user.id)
    assert raised.value.status_code == 403

    admin = make_user(is_admin=True)
    assert require_admin(db=db, user_id=admin.id).id == admin.id


def test_require_admin_refuses_a_token_with_no_profile(db: Session, auth_identity):
    """A valid Supabase token whose `users` row does not exist yet. `db.get`
    returns None and `None.is_admin` would be an AttributeError, not a 403."""
    from fastapi import HTTPException

    from app.dependencies.admin import require_admin

    with pytest.raises(HTTPException) as raised:
        require_admin(db=db, user_id=auth_identity())
    assert raised.value.status_code == 403


def test_admin_user_search_matches_name_and_username(db: Session, make_user):
    user = make_user()
    user.first_name = "Zilpharetta"
    user.last_name = "Quibblesworth"
    db.commit()

    found, total = AdminService.list_users(db, search="Zilpharetta")
    assert total >= 1
    assert user.id in {u.id for u in found}

    # Case-insensitive, and matches the surname too.
    assert AdminService.list_users(db, search="quibblesworth")[1] >= 1

    # Email is never copied out of auth.users, so it cannot be searched.
    assert AdminService.list_users(db, search="Zzz_no_such_user_zzz")[1] == 0


def test_admin_search_paging_totals_ignore_the_page_window(db: Session, make_user):
    """The count has to come from the filtered query, not from the page — a
    total of "20" on every page is the classic version of this bug."""
    for _ in range(3):
        u = make_user()
        u.first_name = "Bartholomewesque"
        db.commit()

    _, total = AdminService.list_users(db, search="Bartholomewesque", limit=1)
    assert total >= 3, "the total counts every match, not the one row returned"

    page, _ = AdminService.list_users(db, search="Bartholomewesque", limit=1)
    assert len(page) == 1


def test_force_deleting_a_quest_leaves_the_ledger_balanced(db: Session, make_user):
    """The refund is a ledger movement like any other, so the invariant that
    `users.points` equals the sum of that user's rows has to survive it."""
    author = make_user(points=100)
    before_points, before_ledger = author.points, ledger_total(db, author)

    quest = QuestionService.create(db, author.id, quest_payload(bounty=25))
    AdminService.delete_quest(db, quest.id)

    db.refresh(author)
    # Posting also pays the once-a-day activity bonus, so the balance does not
    # come back to where it started — but every point of the difference has a
    # row behind it, which is the invariant that matters.
    assert author.points - before_points == ledger_total(db, author) - before_ledger

    # And the bounty specifically went out and came back.
    from sqlalchemy import select

    from app.models import PointTransaction

    amounts = sorted(
        db.scalars(
            select(PointTransaction.amount).where(
                PointTransaction.user_id == author.id,
                PointTransaction.reference_id == quest.id,
            )
        )
    )
    assert amounts == [-25, 25]
