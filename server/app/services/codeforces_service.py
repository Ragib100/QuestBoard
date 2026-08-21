"""Thin client for the public Codeforces API.

Everything here talks to codeforces.com and nothing here touches the database,
so a Codeforces outage degrades one feature instead of breaking a request that
also had points to move. Failures raise `CodeforcesError`, which the callers
turn into a 502/503 with an honest message.
"""

import hashlib
from datetime import datetime, timedelta, timezone

import httpx

from app.core import clock

BASE_URL = "https://codeforces.com/api"

# Codeforces is rate limited to one call per two seconds per IP and is
# occasionally slow; anything longer than this and the client has already
# given up on us.
TIMEOUT = 8.0

# The band we pull daily challenges from. Below 800 there is nothing, and
# above 1600 a first-year student has no realistic shot before midnight.
MIN_RATING = 800
MAX_RATING = 1600

# How long a handle-verification submission stays acceptable.
VERIFICATION_WINDOW = timedelta(minutes=30)

# How far back we will page through a handle's submissions looking for the
# solve. Codeforces returns them newest first, so we stop as soon as we are
# older than the window we care about and this is only the hard stop for a
# handle that submits hundreds of times a day.
MAX_SUBMISSIONS_SCANNED = 1000
PAGE_SIZE = 100


class CodeforcesError(RuntimeError):
    """Codeforces was unreachable or answered with an error."""


def _get(path: str, params: dict | None = None) -> dict | list:
    try:
        response = httpx.get(f"{BASE_URL}/{path}", params=params, timeout=TIMEOUT)
        payload = response.json()
    except Exception as e:
        raise CodeforcesError("Could not reach Codeforces. Try again shortly.") from e

    if payload.get("status") != "OK":
        # `comment` is Codeforces' own message, e.g. "handle: User not found".
        raise CodeforcesError(
            payload.get("comment") or "Codeforces rejected the request."
        )

    return payload["result"]


def _problem_id(problem: dict) -> str:
    return f"{problem['contestId']}/{problem['index']}"


def problem_url(codeforces_id: str) -> str:
    contest_id, index = codeforces_id.split("/", 1)
    return f"https://codeforces.com/problemset/problem/{contest_id}/{index}"


def submit_url(codeforces_id: str) -> str:
    """The page with Codeforces' own submit form for this problem.

    There is no API for this. Codeforces' public API is read-only — it has no
    submit method and does not expose statements either — so the only way to
    submit without asking a user for their Codeforces password is to send them
    to Codeforces' own form. The client hosts this page in an in-app WebView so
    that still happens without leaving QuestBoard (decisions.md D43).
    """
    contest_id, index = codeforces_id.split("/", 1)
    return f"https://codeforces.com/problemset/submit/{contest_id}/{index}"


def difficulty_for(rating: int | None) -> str:
    """Maps a Codeforces rating onto our three-level scale."""
    from app.models import Difficulty

    if rating is None or rating <= 1000:
        return Difficulty.EASY
    if rating <= 1300:
        return Difficulty.MEDIUM
    return Difficulty.HARD


def pick_problem(seed: str) -> dict:
    """Chooses one rated problem, deterministically for a given `seed`.

    The seed is the date, so every caller on the same day picks the same
    problem even if two of them race to create the row.
    """
    result = _get("problemset.problems")
    problems = [
        p
        for p in result["problems"]
        if p.get("contestId")
        and p.get("index")
        and MIN_RATING <= p.get("rating", 0) <= MAX_RATING
    ]
    if not problems:
        raise CodeforcesError("Codeforces returned no problems in our rating range.")

    problems.sort(key=_problem_id)
    digest = hashlib.sha256(seed.encode()).digest()
    index = int.from_bytes(digest[:8], "big") % len(problems)
    return problems[index]


def _submissions(handle: str, count: int, start: int = 1) -> list[dict]:
    result = _get("user.status", {"handle": handle, "from": start, "count": count})
    return list(result)


def _submitted_at(submission: dict) -> datetime:
    return datetime.fromtimestamp(
        submission.get("creationTimeSeconds", 0), tz=timezone.utc
    )


def solved_at(handle: str, codeforces_id: str, since: datetime) -> datetime | None:
    """When the handle first got an accepted verdict on the problem, at or
    after `since` — or None if there is no such submission.

    The `since` bound is the whole point. Codeforces keeps a submission history
    forever, so without it anyone who happened to solve the problem two years
    ago could claim a challenge without opening it. The bound is the challenge's
    own day, so the solve has to have been made *for* the challenge.

    Returns the *earliest* qualifying accepted submission rather than the first
    one it finds, so a solver who submitted twice is credited with the attempt
    that actually earned it.

    Submissions come back newest first, which is what lets this stop paging as
    soon as it is past `since` instead of walking a decade of history.
    """
    found: datetime | None = None
    start = 1

    while start <= MAX_SUBMISSIONS_SCANNED:
        page = _submissions(handle, PAGE_SIZE, start=start)
        if not page:
            break

        for submission in page:
            created = _submitted_at(submission)
            if created < since:
                # Newest-first, so everything from here on is older still.
                return found

            problem = submission.get("problem") or {}
            if not problem.get("contestId"):
                continue
            if _problem_id(problem) != codeforces_id:
                continue
            if submission.get("verdict") == "OK":
                found = created

        if len(page) < PAGE_SIZE:
            break
        start += PAGE_SIZE

    return found


def has_solved(handle: str, codeforces_id: str, since: datetime) -> bool:
    """True when the handle solved the problem at or after `since`."""
    return solved_at(handle, codeforces_id, since) is not None


def last_attempt_at(handle: str, codeforces_id: str) -> datetime | None:
    """When the handle last submitted anything at all for this problem.

    Only used to write a better error message: "you solved this in 2023, submit
    it again" is a different problem from "we cannot see any submission", and a
    user who has just spent an hour on a problem deserves to be told which.
    """
    for submission in _submissions(handle, 200):
        problem = submission.get("problem") or {}
        if problem.get("contestId") and _problem_id(problem) == codeforces_id:
            return _submitted_at(submission)
    return None


def verification_problem(user_id: str) -> dict:
    """The problem this user must submit a compile error to.

    Deterministic in the user id, so the instructions the client showed a
    minute ago still match what we check — no server-side state to store, and
    nothing to expire.
    """
    return pick_problem(f"verify:{user_id}")


def has_compile_error(handle: str, codeforces_id: str) -> bool:
    """True when the handle deliberately failed to compile on that problem
    within the last [VERIFICATION_WINDOW].

    This is what proves ownership: reading a handle from the API says nothing
    about who typed it into our form, but only the account's owner can put a
    submission on it.
    """
    cutoff = clock.utc_now() - VERIFICATION_WINDOW

    for submission in _submissions(handle, 20):
        problem = submission.get("problem") or {}
        if not problem.get("contestId") or _problem_id(problem) != codeforces_id:
            continue
        if submission.get("verdict") != "COMPILATION_ERROR":
            continue
        if _submitted_at(submission) >= cutoff:
            return True
    return False
