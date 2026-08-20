"""Test fixtures.

These run against the **real** database from `DATABASE_URL`, not SQLite: the
schema leans on `gen_random_uuid()`, `uuid` columns, CHECK constraints and a
self-referencing foreign key, and a fake database that accepted all of them
would not be testing the thing that breaks.

Isolation comes from a transaction instead. Each test gets a Session joined to
an outer transaction that is rolled back afterwards, so services can call
`db.commit()` exactly as they do in production while nothing survives the test.
This is what makes it safe to point these at the live project.
"""

import uuid
from datetime import date, timedelta

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.database import engine
from app.models import DailyChallenge, Question, User

AUTH_INSTANCE = "00000000-0000-0000-0000-000000000000"


@pytest.fixture
def db():
    connection = engine.connect()
    outer = connection.begin()
    # `create_savepoint` lets the code under test commit: the commit lands on a
    # savepoint inside our transaction, and the rollback below discards it.
    session = Session(bind=connection, join_transaction_mode="create_savepoint")

    yield session

    session.close()
    outer.rollback()
    connection.close()


@pytest.fixture
def make_user(db: Session):
    """A brand-new user, points and all.

    `public.users.id` is a foreign key onto Supabase's `auth.users`, so a test
    account needs a row in both. Both are rolled back with everything else.
    """

    def _make(points: int = 100, is_admin: bool = False, suspended: bool = False):
        user_id = uuid.uuid4()
        db.execute(
            text(
                """insert into auth.users
                   (id, instance_id, aud, role, email, encrypted_password,
                    email_confirmed_at, created_at, updated_at)
                   values (:id, :inst, 'authenticated', 'authenticated', :email,
                           '', now(), now(), now())"""
            ),
            {"id": user_id, "inst": AUTH_INSTANCE, "email": f"{user_id}@pytest.test"},
        )
        user = User(
            id=user_id,
            username=f"pytest_{user_id.hex[:12]}",
            points=points,
            is_admin=is_admin,
            is_suspended=suspended,
        )
        # Committed, not flushed: services roll back on a domain error, and a
        # rollback discards everything since the session began — the fixture
        # user included. The commit lands on a savepoint inside the outer
        # transaction, so it is still thrown away at the end of the test.
        db.add(user)
        db.commit()
        return user

    return _make


@pytest.fixture
def make_quest(db: Session):
    """A quest written straight to the table — no points move.

    Tests that care about the bounty being charged go through
    `QuestionService.create`; the rest just need a quest to exist.
    """

    def _make(author: User, bounty: int = 0, solved: bool = False):
        quest = Question(
            author_id=author.id,
            title="A pytest quest about balancing trees",
            body="Body long enough to satisfy the schema and then some.",
            bounty_points=bounty,
            is_solved=solved,
        )
        db.add(quest)
        db.commit()
        return quest

    return _make


@pytest.fixture
def auth_identity(db: Session):
    """A row in `auth.users` and nothing else.

    `UserService.create_user` writes the `public.users` row itself, so a test
    of it needs the Supabase side to exist first and the profile side not to.
    """

    def _make():
        user_id = uuid.uuid4()
        db.execute(
            text(
                """insert into auth.users
                   (id, instance_id, aud, role, email, encrypted_password,
                    email_confirmed_at, created_at, updated_at)
                   values (:id, :inst, 'authenticated', 'authenticated', :email,
                           '', now(), now(), now())"""
            ),
            {"id": user_id, "inst": AUTH_INSTANCE, "email": f"{user_id}@pytest.test"},
        )
        db.commit()
        return user_id

    return _make


@pytest.fixture
def make_challenge(db: Session):
    """A daily challenge dated `age_days` ago.

    Written straight to the table: `ChallengeService.today` would call the real
    Codeforces API, and the age is the whole point of these tests.
    """

    def _make(age_days: int = 0, bonus: int = 50):
        challenge_date = date.today() - timedelta(days=age_days)

        # `challenge_date` is unique and the live table already holds real
        # challenges for recent dates. Clearing the day first is safe here for
        # the same reason the whole suite is: this runs inside the outer
        # transaction, which is rolled back, so the real row is never gone.
        db.execute(
            text("delete from daily_challenges where challenge_date = :d"),
            {"d": challenge_date},
        )

        challenge = DailyChallenge(
            codeforces_id="1873/D",
            title="A pytest challenge",
            body="Solve it on Codeforces.",
            cf_rating=1200,
            difficulty="medium",
            bonus_points=bonus,
            challenge_date=challenge_date,
        )
        db.add(challenge)
        db.commit()
        return challenge

    return _make


def ledger_total(db: Session, user: User) -> int:
    """Sum of the user's ledger rows — must always equal `users.points`."""
    return int(
        db.execute(
            text(
                "select coalesce(sum(amount), 0) from point_transactions "
                "where user_id = :u"
            ),
            {"u": user.id},
        ).scalar()
        or 0
    )
