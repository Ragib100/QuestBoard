"""Seed a demo board: five students, eight quests, answers, votes, badges.

    python seed_demo.py          # create
    python seed_demo.py --undo   # remove everything it created

Run it against a *demo* project, not a database with real users. Everything it
writes goes through the normal services, so the point ledger balances exactly as
it would if five people had used the app — nothing is inserted straight into
`users.points`, and no number on any screen will be a number nobody earned.

Demo accounts are real Supabase accounts (`demo1@questboard.test` … password
`questboard-demo`), so you can sign in as one during a presentation.
"""

import argparse
import json
import sys
import uuid

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.database import SessionLocal, engine
from app.models import TARGET_ANSWER, TARGET_QUESTION, User
from app.schemas.answer import AnswerCreate
from app.schemas.question import QuestionCreate
from app.services.answer_service import AnswerService
from app.services.question_service import QuestionService
from app.services.vote_service import VoteService

AUTH_INSTANCE = "00000000-0000-0000-0000-000000000000"
DEMO_PASSWORD = "questboard-demo"
DEMO_DOMAIN = "questboard.test"

PEOPLE = [
    ("nadia", "Nadia", "Rahman"),
    ("tanvir", "Tanvir", "Ahmed"),
    ("priya", "Priya", "Das"),
    ("shakib", "Shakib", "Hossain"),
    ("mim", "Mim", "Akter"),
]

# (author index, title, body, tags, bounty)
QUESTS = [
    (
        0,
        "Why does my binary search loop forever on the last element?",
        "I am using `while (low < high)` with `mid = (low + high) / 2`. It works "
        "for everything except when the answer is the final element, where it "
        "spins. I think the midpoint rounds down but I cannot see why that "
        "matters here.",
        ["dsa", "algorithms"],
        25,
    ),
    (
        1,
        "How do I know when to use DP instead of greedy?",
        "Both feel like they apply to the coin change problem, but greedy gives "
        "the wrong answer for coins like {1, 3, 4} and amount 6. Is there a test "
        "I can apply before writing the whole solution?",
        ["dynamic-programming", "algorithms"],
        40,
    ),
    (
        2,
        "Proving that the sum of the first n odd numbers is n squared",
        "I can see the pattern holds for n up to 10 by hand, and induction feels "
        "like the right tool, but I get stuck setting up the inductive step. "
        "Where does the (n+1) squared term come from?",
        ["math", "number-theory"],
        15,
    ),
    (
        3,
        "Dijkstra with a negative edge — what actually goes wrong?",
        "Everyone says Dijkstra fails with negative weights, but on my small "
        "graph it produced the right answer anyway. I would like a concrete "
        "example where it is wrong, not just the rule.",
        ["graph-theory", "algorithms"],
        30,
    ),
    (
        4,
        "Why is my recursive Fibonacci so much slower than the loop?",
        "The recursive version takes several seconds at n=40 and the loop is "
        "instant. I understand they compute the same thing, so where is all the "
        "time going?",
        ["dsa", "dynamic-programming"],
        10,
    ),
    (
        0,
        "Understanding the difference between O(n log n) and O(n) in practice",
        "For n around a million, is the log factor actually noticeable, or is it "
        "the kind of thing that only matters in a textbook? I am deciding "
        "between sorting and a hash-based approach.",
        ["algorithms", "data-structures"],
        20,
    ),
    (
        1,
        "How do I compute the variance of a sum of dependent variables?",
        "I know Var(X + Y) = Var(X) + Var(Y) when they are independent, but my "
        "two variables are correlated and I do not know where the covariance "
        "term comes from.",
        ["probability", "statistics"],
        35,
    ),
    (
        2,
        "Is a hash map always better than a sorted array for lookups?",
        "Constant time sounds strictly better than logarithmic, so I am not sure "
        "why anyone would binary search a sorted array instead. What am I "
        "missing about the trade-off?",
        ["data-structures", "dsa"],
        0,
    ),
]

# (quest index, answerer index, body, accept?)
ANSWERS = [
    (
        0,
        1,
        "Check what happens when low and high are adjacent: mid rounds down "
        "to low, and if your update is `high = mid` you never move. Try tracing "
        "low=3, high=4 on paper and watch the values.",
        True,
    ),
    (
        0,
        2,
        "Adding an assert that the interval shrinks every iteration is a good "
        "habit — it turns an infinite loop into a failure at the exact step "
        "where the invariant breaks.",
        False,
    ),
    (
        1,
        3,
        "Greedy is safe when the problem has the greedy-choice property: a "
        "locally best pick is part of some optimal solution. For coins {1,3,4} "
        "and 6, greedy takes 4 then two 1s; the optimum is 3+3, so it fails.",
        True,
    ),
    (
        2,
        0,
        "Write the (n+1) case as [sum of first n odds] + (2n+1). Substitute "
        "the inductive hypothesis for the bracket and you have n² + 2n + 1 — "
        "which factors into exactly what you wanted.",
        True,
    ),
    (
        3,
        4,
        "Try a triangle: A→B costs 1, A→C costs 5, B→C costs -10. Dijkstra "
        "finalises C at 5 before ever relaxing the negative edge, so it misses "
        "the true distance of -9.",
        True,
    ),
    (
        3,
        0,
        "The underlying reason is that Dijkstra assumes distances only grow "
        "as you extend a path, which is what lets it commit to a node forever.",
        False,
    ),
    (
        4,
        3,
        "Count the calls: fib(n) recomputes fib(n-2) twice, fib(n-3) three "
        "times, and so on — the call tree is exponential. Memoising it collapses "
        "back to linear.",
        True,
    ),
    (
        5,
        4,
        "At a million elements the log factor is about 20x on comparisons, "
        "but constant factors and cache behaviour often matter more. Measure "
        "both on your actual data before committing.",
        False,
    ),
    (
        6,
        0,
        "Expand Var(X+Y) = E[(X+Y)²] − (E[X+Y])² and the cross terms give you "
        "2·Cov(X,Y). Independence is what makes that covariance zero.",
        True,
    ),
]

# (target kind, index, voter indices)
VOTES = [
    ("question", 0, [1, 2, 3]),
    ("question", 1, [0, 2, 4]),
    ("question", 3, [0, 1]),
    ("question", 6, [2, 3, 4]),
    ("answer", 0, [2, 3, 4]),
    ("answer", 2, [0, 2]),
    ("answer", 3, [1, 3, 4]),
    ("answer", 4, [0, 1, 2]),
    ("answer", 6, [0, 1]),
]


def demo_email(handle: str) -> str:
    return f"{handle}@{DEMO_DOMAIN}"


def existing_demo_ids(db: Session) -> list[uuid.UUID]:
    rows = db.execute(
        text("select id from auth.users where email like :pattern"),
        {"pattern": f"%@{DEMO_DOMAIN}"},
    ).scalars()
    return list(rows)


def undo(db: Session) -> None:
    ids = existing_demo_ids(db)
    if not ids:
        print("Nothing to undo — no demo accounts found.")
        return

    # Deleting the auth row cascades to public.users, and from there to quests,
    # answers and the ledger. Votes are polymorphic with no foreign key, so they
    # go explicitly first.
    db.execute(text("delete from public.votes where user_id = any(:ids)"), {"ids": ids})
    db.execute(text("delete from auth.users where id = any(:ids)"), {"ids": ids})
    db.commit()
    print(f"Removed {len(ids)} demo accounts and everything they created.")


def create_account(db: Session, handle: str, first: str, last: str) -> User:
    user_id = uuid.uuid4()
    db.execute(
        text(
            # The empty strings are not decoration: GoTrue reads these columns
            # as strings and returns a 500 on login if any of them is NULL, so
            # an account seeded without them exists but can never sign in.
            """insert into auth.users
               (id, instance_id, aud, role, email, encrypted_password,
                email_confirmed_at, created_at, updated_at,
                raw_app_meta_data, raw_user_meta_data,
                confirmation_token, recovery_token,
                email_change, email_change_token_new)
               values (:id, :inst, 'authenticated', 'authenticated', :email,
                       crypt(:password, gen_salt('bf')), now(), now(), now(),
                       '{"provider":"email","providers":["email"]}'::jsonb,
                       cast(:metadata as jsonb),
                       '', '', '', '')"""
        ),
        {
            "id": user_id,
            "inst": AUTH_INSTANCE,
            "email": demo_email(handle),
            "password": DEMO_PASSWORD,
            "metadata": json.dumps({"sub": str(user_id), "email": demo_email(handle)}),
        },
    )
    user = User(id=user_id, username=handle, first_name=first, last_name=last)
    db.add(user)
    db.commit()
    return user


def seed(db: Session) -> None:
    if existing_demo_ids(db):
        print("Demo data is already present. Run with --undo first.")
        sys.exit(1)

    users = [create_account(db, *person) for person in PEOPLE]
    print(f"Created {len(users)} demo accounts (password: {DEMO_PASSWORD})")

    quests = []
    for author_i, title, body, tags, bounty in QUESTS:
        quests.append(
            QuestionService.create(
                db,
                users[author_i].id,
                QuestionCreate(title=title, body=body, tags=tags, bounty_points=bounty),
            )
        )
    print(f"Posted {len(quests)} quests")

    # Every answer is written before any is accepted: accepting closes the
    # quest, and a closed quest refuses further answers — as it should.
    answers = []
    for quest_i, author_i, body, _ in ANSWERS:
        answers.append(
            AnswerService.create(
                db, quests[quest_i].id, users[author_i].id, AnswerCreate(body=body)
            )
        )

    accepted = 0
    for answer, (quest_i, _, _, accept) in zip(answers, ANSWERS):
        if accept:
            AnswerService.accept(db, answer.id, quests[quest_i].author_id)
            accepted += 1
    print(f"Wrote {len(answers)} answers, {accepted} accepted")

    cast = 0
    for kind, index, voters in VOTES:
        target = quests[index] if kind == "question" else answers[index]
        target_type = TARGET_QUESTION if kind == "question" else TARGET_ANSWER
        for voter_i in voters:
            if users[voter_i].id == target.author_id:
                continue  # self-votes are refused, and rightly so
            VoteService.cast(db, users[voter_i].id, target_type, target.id, 1)
            cast += 1

    # VoteService flushes but never commits — the router owns the transaction
    # in production (docs/decisions.md D20), and here that owner is us. Without
    # this the votes and the points they moved vanish at db.close().
    db.commit()
    print(f"Cast {cast} votes")

    print("\nBalances (all earned through the ledger, none set directly):")
    for user in users:
        db.refresh(user)
        ledger = db.execute(
            text(
                "select coalesce(sum(amount),0) from point_transactions "
                "where user_id = :u"
            ),
            {"u": user.id},
        ).scalar()
        flag = "OK" if user.points == 100 + ledger else "MISMATCH"
        print(f"  {user.username:<8} {user.points:>5} pts  (ledger {ledger:+}) {flag}")

    print(f"\nSign in as {demo_email(PEOPLE[0][0])} / {DEMO_PASSWORD}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--undo", action="store_true", help="delete the demo accounts and their data"
    )
    args = parser.parse_args()

    with engine.begin() as conn:
        # crypt()/gen_salt() hash the demo passwords the way Supabase Auth does.
        conn.execute(text("create extension if not exists pgcrypto"))

    db = SessionLocal()
    try:
        undo(db) if args.undo else seed(db)
    finally:
        db.close()


if __name__ == "__main__":
    main()
