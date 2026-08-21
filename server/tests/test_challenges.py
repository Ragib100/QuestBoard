"""The challenge archive, the age decay, and code submissions.

Same invariant as `test_economy.py`: **`users.points` always equals the sum of
that user's ledger rows.** The decay makes that easier to get wrong, not
harder — the amount paid is now computed at claim time and stored separately,
so these check that the three numbers (award, balance, ledger) agree.

Codeforces is stubbed. Every test that claims a challenge would otherwise hit
the public API, which is rate limited, occasionally down, and not the thing
under test.
"""

from datetime import date, timedelta, timezone

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core import clock
from app.models import DECAY_FLOOR, PointReason, award_for
from app.schemas.answer import AnswerCreate
from app.schemas.challenge import SolveRequest
from app.schemas.code import CodeSubmission
from app.services import codeforces_service as cf
from app.services.challenge_service import ChallengeService
from app.services.user_service import UserService

from tests.conftest import ledger_total


@pytest.fixture
def verified(make_user, db: Session):
    """A user who has proved they own a Codeforces handle."""

    def _make(points: int = 100):
        user = make_user(points=points)
        user.codeforces_handle = "tourist"
        user.codeforces_verified = True
        db.commit()
        return user

    return _make


@pytest.fixture
def solved_on_codeforces(monkeypatch):
    """Stubs the Codeforces verdict check.

    Also stubs `last_attempt_at`, which the service calls only to phrase the
    refusal; leaving it live would put a real HTTP request in every test that
    checks an unsolved claim.
    """

    def _set(value: bool, stale_at=None):
        monkeypatch.setattr(cf, "has_solved", lambda handle, problem, since: value)
        monkeypatch.setattr(cf, "last_attempt_at", lambda handle, problem: stale_at)

    return _set


# ------------------------------------------------------------------- decay ---


def test_the_decay_matches_the_published_table():
    """docs/api.md promises these exact numbers for a 50-point challenge."""
    today = date(2026, 8, 20)
    awards = [award_for(50, today - timedelta(days=age), on=today) for age in range(9)]

    assert awards == [50, 45, 40, 35, 30, 25, 20, 15, 10]


def test_the_decay_stops_at_the_floor():
    today = date(2026, 8, 20)
    floor = round(50 * DECAY_FLOOR)

    for age in (8, 30, 365, 10_000):
        assert award_for(50, today - timedelta(days=age), on=today) == floor


def test_a_future_dated_challenge_is_worth_full_price():
    """Clock skew between the server and the row must not pay a bonus."""
    today = date(2026, 8, 20)
    assert award_for(50, today + timedelta(days=3), on=today) == 50


def test_the_decay_never_reaches_zero_for_a_real_bounty():
    today = date(2026, 8, 20)
    for bonus in range(1, 200):
        award = award_for(bonus, today - timedelta(days=9999), on=today)
        assert award >= 1, f"{bonus} decayed to nothing"


# ------------------------------------------------------------- claiming it ---


def test_claiming_today_pays_the_full_bonus(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    solved_on_codeforces(True)
    user = verified(points=100)
    challenge = make_challenge(age_days=0, bonus=50)

    attempt = ChallengeService.claim(db, challenge.id, user.id)
    db.refresh(user)

    assert attempt.awarded_points == 50
    # 50 for the challenge plus the 10 daily bonus the claim also triggers.
    assert user.points == 160
    assert ledger_total(db, user) == 60, "ledger must explain the whole change"


def test_claiming_an_old_challenge_pays_the_decayed_award(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    """The bug this guards: paying `bonus_points` for a month-old problem."""
    solved_on_codeforces(True)
    user = verified(points=100)
    challenge = make_challenge(age_days=4, bonus=50)

    attempt = ChallengeService.claim(db, challenge.id, user.id)
    db.refresh(user)

    assert attempt.awarded_points == 30, "4 days old: 50 - 4x5"
    assert user.points == 140, "30 for the challenge, 10 for the daily bonus"
    assert ledger_total(db, user) == 40


def test_the_stored_award_matches_the_ledger_row(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    """`awarded_points` is what the leaderboard shows; the ledger is what was
    paid. They are written in one transaction and must never disagree."""
    solved_on_codeforces(True)
    user = verified(points=0)
    challenge = make_challenge(age_days=6, bonus=50)

    attempt = ChallengeService.claim(db, challenge.id, user.id)

    rows = list(
        db.execute(
            text(
                "select amount from point_transactions "
                "where user_id = :u and reason = :r"
            ),
            {"u": user.id, "r": PointReason.CHALLENGE_SOLVED},
        ).scalars()
    )

    assert rows == [attempt.awarded_points]


def test_submitting_code_needs_no_codeforces_verdict(
    db: Session, verified, make_challenge
):
    """The regression this guards: "there is no submit button".

    `claim` was the only writer of a submission, and it refuses unless
    Codeforces already shows an accepted verdict — so code written before
    solving upstream could not be saved at all. Note there is no Codeforces
    stub here on purpose: this path must never call out.
    """
    user = verified(points=0)
    challenge = make_challenge(age_days=0, bonus=50)

    attempt = ChallengeService.save_submission(
        db,
        challenge.id,
        user.id,
        CodeSubmission(code_body="print(1)", code_language="python"),
    )

    assert attempt.code_body == "print(1)"
    assert attempt.code_language == "python"
    assert attempt.is_solved is False
    assert attempt.awarded_points == 0
    db.refresh(user)
    assert user.points == 0, "saving code must never pay"
    assert ledger_total(db, user) == 0


def test_submitting_code_does_not_need_a_verified_handle(
    db: Session, make_user, make_challenge
):
    """Keeping a record of your work is not the same act as claiming a bonus."""
    user = make_user(points=0)
    challenge = make_challenge(age_days=0, bonus=50)

    attempt = ChallengeService.save_submission(
        db, challenge.id, user.id, CodeSubmission(code_body="x = 1")
    )

    assert attempt.code_body == "x = 1"
    assert attempt.code_language == "text", "unlabelled code still gets a label"


def test_submitting_code_twice_replaces_it(db: Session, verified, make_challenge):
    user = verified(points=0)
    challenge = make_challenge(age_days=0, bonus=50)

    ChallengeService.save_submission(
        db, challenge.id, user.id, CodeSubmission(code_body="first")
    )
    attempt = ChallengeService.save_submission(
        db, challenge.id, user.id, CodeSubmission(code_body="second")
    )

    rows = db.execute(
        text(
            "select count(*) from challenge_attempts "
            "where challenge_id = :c and user_id = :u"
        ),
        {"c": challenge.id, "u": user.id},
    ).scalar()

    assert attempt.code_body == "second"
    assert rows == 1, "the second submit must update, not insert a second row"


def test_submitting_code_survives_a_later_claim(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    """Submitting first and claiming afterwards is the intended order."""
    solved_on_codeforces(True)
    user = verified(points=0)
    challenge = make_challenge(age_days=0, bonus=50)

    ChallengeService.save_submission(
        db, challenge.id, user.id, CodeSubmission(code_body="solution()")
    )
    attempt = ChallengeService.claim(db, challenge.id, user.id)

    assert attempt.code_body == "solution()", "claiming must not wipe the code"
    assert attempt.is_solved is True
    assert attempt.awarded_points == 50


def test_submitting_code_after_solving_is_still_allowed(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    """Claiming twice is refused; tidying up your saved solution is not."""
    solved_on_codeforces(True)
    user = verified(points=0)
    challenge = make_challenge(age_days=0, bonus=50)

    ChallengeService.claim(db, challenge.id, user.id)
    before = ledger_total(db, user)

    attempt = ChallengeService.save_submission(
        db, challenge.id, user.id, CodeSubmission(code_body="tidied()")
    )

    assert attempt.code_body == "tidied()"
    assert attempt.is_solved is True
    assert ledger_total(db, user) == before, "editing code must not pay again"


def test_submitting_to_a_missing_challenge_is_a_lookup_error(db: Session, verified):
    from uuid import uuid4

    user = verified(points=0)

    with pytest.raises(LookupError):
        ChallengeService.save_submission(
            db, uuid4(), user.id, CodeSubmission(code_body="x")
        )


def test_claiming_twice_is_refused(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    solved_on_codeforces(True)
    user = verified(points=100)
    challenge = make_challenge(age_days=1, bonus=50)

    ChallengeService.claim(db, challenge.id, user.id)
    db.refresh(user)
    after_first = user.points

    with pytest.raises(ValueError, match="already claimed"):
        ChallengeService.claim(db, challenge.id, user.id)

    db.refresh(user)
    assert user.points == after_first, "a refused second claim pays nothing"
    assert ledger_total(db, user) == after_first - 100


def test_an_unverified_handle_cannot_claim(
    db: Session, make_user, make_challenge, solved_on_codeforces
):
    solved_on_codeforces(True)
    user = make_user(points=100)
    challenge = make_challenge(age_days=0)

    with pytest.raises(PermissionError, match="Verify your Codeforces handle"):
        ChallengeService.claim(db, challenge.id, user.id)

    db.refresh(user)
    assert user.points == 100
    assert ledger_total(db, user) == 0


def test_an_unaccepted_solve_pays_nothing(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    solved_on_codeforces(False)
    user = verified(points=100)
    challenge = make_challenge(age_days=0)

    with pytest.raises(ValueError, match="no accepted submission"):
        ChallengeService.claim(db, challenge.id, user.id)

    db.refresh(user)
    assert user.points == 100
    assert ledger_total(db, user) == 0

    attempt = ChallengeService.attempt_of(db, challenge.id, user.id)
    assert (
        attempt is not None and not attempt.is_solved
    ), "the failed attempt is still recorded"


# -------------------------------------------------------------- submissions ---


def test_a_claim_stores_the_submitted_code(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    solved_on_codeforces(True)
    user = verified(points=100)
    challenge = make_challenge(age_days=2)

    attempt = ChallengeService.claim(
        db,
        challenge.id,
        user.id,
        SolveRequest(
            code_body="int main(){return 0;}",
            code_language="cpp",
            attachment_url="https://example.test/sol.cpp",
            attachment_name="sol.cpp",
        ),
    )

    assert attempt.code_body == "int main(){return 0;}"
    assert attempt.code_language == "cpp"
    assert attempt.attachment_name == "sol.cpp"


def test_a_premature_claim_keeps_the_code(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    """Claiming a minute before the verdict lands must not discard the work."""
    solved_on_codeforces(False)
    user = verified(points=100)
    challenge = make_challenge(age_days=0)

    with pytest.raises(ValueError):
        ChallengeService.claim(
            db,
            challenge.id,
            user.id,
            SolveRequest(code_body="print('wip')", code_language="python"),
        )

    attempt = ChallengeService.attempt_of(db, challenge.id, user.id)
    assert attempt is not None
    assert attempt.code_body == "print('wip')"
    assert not attempt.is_solved


def test_code_with_no_language_is_labelled_rather_than_left_blank(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    solved_on_codeforces(True)
    user = verified(points=100)
    challenge = make_challenge(age_days=0)

    attempt = ChallengeService.claim(
        db, challenge.id, user.id, SolveRequest(code_body="x = 1")
    )

    assert attempt.code_language == "text"


def test_leading_indentation_survives_the_round_trip():
    """Stripping a Python solution's indentation would break the code."""
    data = SolveRequest(code_body="    if x:\n        return 1\n\n")

    assert data.code_body == "    if x:\n        return 1"


def test_an_unknown_language_is_refused():
    with pytest.raises(ValueError, match="not a language"):
        SolveRequest(code_body="x", code_language="brainfuck")


def test_an_answer_may_be_code_with_almost_no_prose():
    """The ten-character minimum does not apply to a working solution."""
    answer = AnswerCreate(body="here", code_body="int main(){}", code_language="cpp")

    assert answer.code_body == "int main(){}"


def test_an_answer_with_neither_prose_nor_code_is_refused():
    with pytest.raises(ValueError, match="Write an answer"):
        AnswerCreate(body="   ")


# ----------------------------------------------------------------- archive ---


def test_the_archive_excludes_today_by_default(db: Session, make_challenge):
    make_challenge(age_days=0)
    old = make_challenge(age_days=3)

    rows, _ = ChallengeService.archive_page(db, limit=50)
    ids = [row["challenge"].id for row in rows]

    assert old.id in ids
    assert all(
        row["challenge"].challenge_date < date.today() for row in rows
    ), "today's challenge belongs on the daily screen, not in the archive"


def test_the_archive_reports_the_viewers_own_attempt(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    solved_on_codeforces(True)
    user = verified(points=100)
    challenge = make_challenge(age_days=2)
    ChallengeService.claim(db, challenge.id, user.id)

    rows, _ = ChallengeService.archive_page(db, limit=50, viewer_id=user.id)
    mine = next(r for r in rows if r["challenge"].id == challenge.id)

    assert mine["attempt"] is not None and mine["attempt"].is_solved
    assert mine["solver_count"] == 1


# --------------------------------------------------- the signup bonus gap ---


def test_a_new_profile_ledgers_its_signup_bonus(db: Session, auth_identity):
    """The bug this guards: `users.points` defaulted to 100 with no transaction
    behind it, so every account's balance was 100 points the ledger could not
    explain."""
    from app.schemas.user import UserCreate

    user_id = auth_identity()
    user = UserService.create_user(
        db,
        user_id,
        UserCreate(
            username=f"pytest_{user_id.hex[:12]}",
            first_name="Ada",
            last_name="Lovelace",
            image_url="",
            codeforces_handle="",
        ),
    )

    assert user.points == 100
    assert ledger_total(db, user) == 100, "the balance must be explained"


# --------------------------------------------- the solve has to be recent ---


def test_an_old_accepted_submission_does_not_pay(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    """The bug this guards: the verdict check looked at a handle's whole
    history, so anyone who had solved the problem years ago could claim a
    challenge without opening it."""
    user = verified()
    challenge = make_challenge(age_days=0)

    two_years_ago = clock.now() - timedelta(days=730)
    solved_on_codeforces(False, stale_at=two_years_ago)

    before, ledger_before = user.points, ledger_total(db, user)
    with pytest.raises(ValueError, match="before this challenge opened"):
        ChallengeService.claim(db, challenge.id, user.id)

    db.refresh(user)
    assert user.points == before
    assert ledger_total(db, user) == ledger_before, "a refused claim pays nothing"


def test_the_refusal_says_which_problem_it_is_when_nothing_was_submitted(
    db: Session, verified, make_challenge, solved_on_codeforces
):
    user = verified()
    challenge = make_challenge(age_days=0)
    solved_on_codeforces(False, stale_at=None)

    with pytest.raises(ValueError, match="no accepted submission"):
        ChallengeService.claim(db, challenge.id, user.id)


def test_the_recency_bound_is_the_challenges_own_dhaka_midnight(
    db: Session, verified, make_challenge, monkeypatch
):
    """A challenge from three days ago accepts a solve from any of those days —
    the bound is when the challenge opened, not the last 24 hours."""
    user = verified()
    challenge = make_challenge(age_days=3)

    seen: list = []

    def _record(handle, problem, since):
        seen.append(since)
        return True

    monkeypatch.setattr(cf, "has_solved", _record)
    ChallengeService.claim(db, challenge.id, user.id)

    assert len(seen) == 1
    since = seen[0]
    assert since.date() == challenge.challenge_date
    assert since.hour == 0 and since.minute == 0
    assert since.utcoffset() == timedelta(hours=6), "midnight in Dhaka, not UTC"


def test_solved_at_stops_paging_once_it_is_past_the_bound(monkeypatch):
    """Codeforces returns submissions newest first, so the scan must stop
    rather than walking a decade of history for every claim."""
    now = clock.utc_now()
    since = now - timedelta(hours=6)

    pages: list[int] = []

    def _fake(handle, count, start=1):
        pages.append(start)
        # One page, all of it older than `since`.
        return [
            {
                "creationTimeSeconds": int((now - timedelta(days=400)).timestamp()),
                "problem": {"contestId": 1, "index": "A"},
                "verdict": "OK",
            }
        ] * cf.PAGE_SIZE

    monkeypatch.setattr(cf, "_submissions", _fake)

    assert cf.solved_at("tourist", "1/A", since) is None
    assert pages == [1], "it should not have asked for a second page"


def test_solved_at_credits_the_earliest_qualifying_submission(monkeypatch):
    now = clock.utc_now()
    since = now - timedelta(hours=12)
    first = now - timedelta(hours=5)
    second = now - timedelta(hours=1)

    def _fake(handle, count, start=1):
        if start > 1:
            return []
        return [
            {
                "creationTimeSeconds": int(second.timestamp()),
                "problem": {"contestId": 1, "index": "A"},
                "verdict": "OK",
            },
            {
                "creationTimeSeconds": int(first.timestamp()),
                "problem": {"contestId": 1, "index": "A"},
                "verdict": "OK",
            },
        ]

    monkeypatch.setattr(cf, "_submissions", _fake)

    found = cf.solved_at("tourist", "1/A", since)
    assert found is not None
    assert int(found.timestamp()) == int(first.timestamp())


# ------------------------------------------------------- the Dhaka clock ---


def test_the_day_rolls_over_at_midnight_dhaka_not_utc():
    """18:30 UTC is 00:30 the next day in Dhaka. The challenge, the streak and
    the decay all have to agree it is already tomorrow."""
    from datetime import datetime, timezone

    instant = datetime(2026, 8, 20, 18, 30, tzinfo=timezone.utc)

    assert instant.astimezone(clock.DHAKA).date() == date(2026, 8, 21)
    assert instant.date() == date(2026, 8, 20)


def test_start_of_day_is_dhaka_midnight():
    start = clock.start_of_day(date(2026, 8, 20))
    assert start.utcoffset() == timedelta(hours=6)
    # 00:00 Dhaka is 18:00 the previous day in UTC.
    assert start.astimezone(timezone.utc).hour == 18


# ------------------------------------------------- no minimum, real limit ---


def test_a_one_word_quest_is_allowed(db: Session, make_user):
    """The old floors were 10 characters of title and 20 of body. "Why?" is a
    real question and padding it to twenty characters helped nobody."""
    from app.schemas.question import QuestionCreate

    data = QuestionCreate(title="Why?", body="No idea")
    assert data.title == "Why?"
    assert data.body == "No idea"


def test_a_blank_quest_is_still_refused():
    from app.schemas.question import QuestionCreate

    with pytest.raises(ValueError, match="title cannot be empty"):
        QuestionCreate(title="   ", body="Something")

    with pytest.raises(ValueError, match="description cannot be empty"):
        QuestionCreate(title="Something", body="\n\n")


def test_a_quest_body_has_a_ceiling():
    """Not a style rule — a bound on what one request can write into the row."""
    from app.schemas.question import MAX_BODY_CHARS, QuestionCreate

    QuestionCreate(title="Fine", body="x" * MAX_BODY_CHARS)

    with pytest.raises(ValueError):
        QuestionCreate(title="Fine", body="x" * (MAX_BODY_CHARS + 1))


def test_a_two_character_answer_is_allowed():
    answer = AnswerCreate(body="No")
    assert answer.body == "No"
