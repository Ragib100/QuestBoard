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

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.database import engine
from app.models import Question, User

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
