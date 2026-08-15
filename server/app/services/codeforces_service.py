"""Thin client for the public Codeforces API.

Everything here talks to codeforces.com and nothing here touches the database,
so a Codeforces outage degrades one feature instead of breaking a request that
also had points to move. Failures raise `CodeforcesError`, which the callers
turn into a 502/503 with an honest message.
"""

import hashlib
from datetime import datetime, timedelta, timezone

import httpx

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


def handle_exists(handle: str) -> bool:
    try:
        _get("user.info", {"handles": handle})
        return True
    except CodeforcesError:
        return False


def _submissions(handle: str, count: int) -> list[dict]:
    result = _get("user.status", {"handle": handle, "from": 1, "count": count})
    return list(result)


def has_solved(handle: str, codeforces_id: str) -> bool:
    """True when the handle has an accepted submission for the problem.

    Looks at the most recent 200 submissions only: the challenge is a
    same-day thing, so an older solve is not what earned today's bonus.
    """
    for submission in _submissions(handle, 200):
        problem = submission.get("problem") or {}
        if not problem.get("contestId"):
            continue
        if _problem_id(problem) != codeforces_id:
            continue
        if submission.get("verdict") == "OK":
            return True
    return False


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
    cutoff = datetime.now(timezone.utc) - VERIFICATION_WINDOW

    for submission in _submissions(handle, 20):
        problem = submission.get("problem") or {}
        if not problem.get("contestId") or _problem_id(problem) != codeforces_id:
            continue
        if submission.get("verdict") != "COMPILATION_ERROR":
            continue
        created = datetime.fromtimestamp(
            submission.get("creationTimeSeconds", 0), tz=timezone.utc
        )
        if created >= cutoff:
            return True
    return False
