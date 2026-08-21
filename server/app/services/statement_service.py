"""Fetching a Codeforces problem statement, and making it safe to render.

The Codeforces API does not expose statements — `problemset.problems` returns a
name, a rating and tags, which is why a challenge's stored `body` is a generated
summary. The only source for the real text is the problem page itself.

That page is behind Cloudflare, which serves a 403 "Just a moment" challenge to
anything it thinks is automated, and a datacenter IP (which is what the API runs
on) is exactly what it is suspicious of. So this is best effort *by
construction*:

* a statement that arrives is cached on the challenge row and never fetched
  again — problem statements do not change, and every refetch is another roll of
  the Cloudflare dice;
* a statement that does not arrive leaves the screen showing the summary it
  already had, plus the button that opens the real page. It never blocks the
  challenge, and it never invents a statement.

The HTML is sanitised here rather than in the client: it is rendered in a WebView
that has a JavaScript channel open to the app, so scripts arriving from a third
party must not survive the trip.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from urllib.parse import urljoin

import httpx
from bs4 import BeautifulSoup

from app.services import codeforces_service as cf

ORIGIN = "https://codeforces.com"

# Cloudflare 403s a bare "Mozilla/5.0". A descriptive agent that says who we are
# gets through, which is also the honest thing to send.
USER_AGENT = "Mozilla/5.0 (compatible; QuestBoard/1.0; +https://github.com/Saif-Sakib/questboard)"

TIMEOUT = 12.0

# Anything that could execute, phone home, or frame something. The statement is
# third-party HTML going into a WebView with a channel back into the app.
_FORBIDDEN_TAGS = ("script", "style", "iframe", "object", "embed", "form", "link")

# `onclick`, `onerror`, and friends — the other way to get script into a page.
_EVENT_ATTR = re.compile(r"^on", re.IGNORECASE)


class StatementError(RuntimeError):
    """The statement could not be fetched or could not be understood."""


@dataclass
class Statement:
    """One problem statement, cleaned and ready to render."""

    html: str
    time_limit: str = ""
    memory_limit: str = ""
    samples: list[dict] = field(default_factory=list)


def _text_of(node) -> str:
    """The text of a header cell, without its own label.

    Codeforces writes `<div class="time-limit"><div class="property-title">time
    limit per test</div>1 second</div>`, so lifting the whole thing out gives
    "time limit per test1 second".
    """
    if node is None:
        return ""
    clone = BeautifulSoup(str(node), "html.parser")
    for label in clone.select(".property-title"):
        label.decompose()
    return clone.get_text(" ", strip=True)


def _pre_text(pre) -> str:
    """The literal text of a sample block.

    Codeforces wraps every line of a multi-test sample in its own
    `div.test-example-line`, so `get_text()` on the `<pre>` runs all the lines
    together into one. Older problems are still a plain `<pre>` with newlines in
    it, and both shapes are live on the site right now.
    """
    lines = pre.select("div.test-example-line")
    if lines:
        return "\n".join(line.get_text() for line in lines).strip("\n")
    return pre.get_text().strip("\n")


def _samples(statement) -> list[dict]:
    out: list[dict] = []
    for test in statement.select("div.sample-test"):
        inputs = test.select("div.input pre")
        outputs = test.select("div.output pre")
        for i, source in enumerate(inputs):
            expected = outputs[i] if i < len(outputs) else None
            out.append(
                {
                    "input": _pre_text(source),
                    "output": _pre_text(expected) if expected is not None else "",
                }
            )
    return out


def _sanitise(statement, base_url: str) -> None:
    """Strips anything executable and makes every URL absolute, in place."""
    for tag in statement.find_all(_FORBIDDEN_TAGS):
        tag.decompose()

    for tag in statement.find_all(True):
        for name in [a for a in tag.attrs if _EVENT_ATTR.match(a)]:
            del tag[name]

        # Relative image paths resolve against codeforces.com, not against the
        # WebView's about:blank.
        for name in ("src", "href"):
            value = tag.get(name)
            if not value:
                continue
            if value.startswith(("http://", "https://", "data:")):
                continue
            if value.startswith("javascript:"):
                del tag[name]
                continue
            tag[name] = urljoin(base_url, value)


def fetch(codeforces_id: str) -> Statement:
    """The statement for `codeforces_id` ("1873/D"), cleaned.

    Raises [StatementError] for anything that goes wrong — an unreachable site,
    a Cloudflare challenge, or a page whose shape we no longer recognise. The
    caller degrades; it never substitutes something made up.
    """
    url = cf.problem_url(codeforces_id)

    try:
        response = httpx.get(
            url,
            timeout=TIMEOUT,
            follow_redirects=True,
            headers={"User-Agent": USER_AGENT, "Accept-Language": "en"},
        )
    except Exception as e:
        raise StatementError("Could not reach Codeforces.") from e

    if response.status_code != 200:
        raise StatementError(
            f"Codeforces returned {response.status_code} for the problem page."
        )

    soup = BeautifulSoup(response.text, "html.parser")
    statement = soup.select_one("div.problem-statement")
    if statement is None:
        # Almost always the Cloudflare interstitial, which is a 200 sometimes.
        raise StatementError("Codeforces did not serve the problem statement.")

    header = statement.select_one("div.header")
    time_limit = _text_of(header.select_one(".time-limit")) if header else ""
    memory_limit = _text_of(header.select_one(".memory-limit")) if header else ""

    samples = _samples(statement)

    # The header carries the title and the limits, all of which the app already
    # draws in its own chrome. Leaving it in would print the problem title twice.
    if header is not None:
        header.decompose()

    _sanitise(statement, url)

    html = statement.decode_contents().strip()
    if not html:
        raise StatementError("The problem statement came back empty.")

    return Statement(
        html=html,
        time_limit=time_limit,
        memory_limit=memory_limit,
        samples=samples,
    )
