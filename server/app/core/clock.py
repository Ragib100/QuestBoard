"""The one clock the whole server reads.

Everything user-facing happens in Bangladesh: the daily challenge rolls over at
midnight Dhaka, a streak counts a Dhaka day, and the age decay counts Dhaka
days. Reading `datetime.now(timezone.utc)` instead meant the challenge changed
at 6am local and a solve at 1am counted for the day before — the class of bug
that only shows up on the wrong side of midnight.

Instants are still *stored* in UTC (see [decisions.md](../../../docs/decisions.md)
D29). This module is about the calendar, not the storage format: `today()` is
the answer to "what day is it for our users", which is the only thing the rest
of the code should ever ask.
"""

from datetime import date, datetime, timedelta, timezone

# Asia/Dhaka is UTC+6 and has had no DST since 2009, so a fixed offset is the
# whole truth here and needs no tz database on the deploy host.
DHAKA = timezone(timedelta(hours=6), "Asia/Dhaka")


def now() -> datetime:
    """The current instant, expressed in Bangladesh time."""
    return datetime.now(DHAKA)


def today() -> date:
    """The calendar day it is in Bangladesh right now."""
    return now().date()


def utc_now() -> datetime:
    """The current instant in UTC — for comparing against stored timestamps."""
    return datetime.now(timezone.utc)


def naive_utc_now() -> datetime:
    """`utc_now()` with the tzinfo stripped, for our naive `timestamp` columns.

    Postgres stores these without a zone, so writing an aware value would be
    silently truncated anyway; doing it here makes the choice visible.
    """
    return datetime.now(timezone.utc).replace(tzinfo=None)


def start_of_day(day: date) -> datetime:
    """Midnight in Dhaka on `day`, as an aware instant.

    Used to ask Codeforces "was this submitted on or after the challenge's own
    day", which is a question about Dhaka midnight, not UTC midnight.
    """
    return datetime.combine(day, datetime.min.time(), tzinfo=DHAKA)
