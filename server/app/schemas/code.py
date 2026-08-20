"""The code-submission fields shared by answers and challenge attempts.

Both carry the same four columns, so they share one mixin rather than two
copies that drift. Nothing here touches the database or Storage: the client
uploads an attachment straight to the public `submissions` bucket and sends us
the URL, and `code_body` is plain text small enough to live in Postgres.
"""

from pydantic import BaseModel, field_validator

# The languages the picker offers. Bounded because the column is varchar(20)
# and because a free-text language is a label nothing can render consistently.
# `text` is the honest fallback for anything not on the list.
LANGUAGES = (
    "text",
    "c",
    "cpp",
    "csharp",
    "java",
    "python",
    "javascript",
    "typescript",
    "dart",
    "go",
    "rust",
    "kotlin",
    "swift",
    "php",
    "ruby",
    "sql",
    "bash",
)

# A whole competitive-programming solution is a few kilobytes. This is a
# generous ceiling that still stops someone pasting a repository into a row.
MAX_CODE_CHARS = 20_000


class CodeSubmission(BaseModel):
    """Optional code + attachment on a write.

    Every field is nullable and every field is optional: omitting one leaves it
    untouched on an update, while sending an empty string clears it. That is
    the difference between "I did not edit my code" and "I removed it".
    """

    code_body: str | None = None
    code_language: str | None = None
    attachment_url: str | None = None
    attachment_name: str | None = None

    @field_validator("code_body")
    @classmethod
    def _check_code(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if len(value) > MAX_CODE_CHARS:
            raise ValueError(
                f"That code is too long — {MAX_CODE_CHARS} characters is the limit."
            )
        # Only trailing whitespace goes: leading indentation is meaningful in
        # Python, and stripping it would silently break the submitted code.
        return value.rstrip()

    @field_validator("code_language")
    @classmethod
    def _check_language(cls, value: str | None) -> str | None:
        if value is None or value == "":
            return value
        lowered = value.strip().lower()
        if lowered not in LANGUAGES:
            raise ValueError(f"'{value}' is not a language we can label.")
        return lowered

    @field_validator("attachment_url", "attachment_name")
    @classmethod
    def _trim(cls, value: str | None) -> str | None:
        return value.strip() if value is not None else None

    @property
    def has_code(self) -> bool:
        return bool(self.code_body and self.code_body.strip())


def apply_submission(row, data: CodeSubmission) -> None:
    """Copies the submitted fields onto an ORM row.

    A field left out of the request is left alone; an empty string clears the
    column to NULL, which is what "remove my attachment" has to mean.
    """
    for field in ("code_body", "code_language", "attachment_url", "attachment_name"):
        value = getattr(data, field)
        if value is None:
            continue
        setattr(row, field, value or None)

    # Code with no language is unlabelled rather than unknown — the reader
    # still needs something to put on the block.
    if getattr(row, "code_body", None) and not getattr(row, "code_language", None):
        row.code_language = "text"
