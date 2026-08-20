from pydantic import Field, model_validator

from app.schemas.code import CodeSubmission

# An answer has to say something, but "something" is not a character count —
# "yes, use a set" is a complete answer. The only floor is non-empty, and code
# satisfies it on its own. The ceiling is there to bound the row, not the
# writer, so the client never shows it.
MAX_BODY_CHARS = 50_000


class _AnswerWrite(CodeSubmission):
    body: str = Field(default="", max_length=MAX_BODY_CHARS)
    image_url: str | None = None

    @model_validator(mode="after")
    def _body_or_code(self):
        if self.body.strip():
            return self

        if self.has_code:
            # The code is the answer. Demanding prose on top of a working
            # solution is a rule that only ever produced "here you go".
            return self

        raise ValueError("Write an answer, or attach some code.")


class AnswerCreate(_AnswerWrite):
    pass


class AnswerUpdate(_AnswerWrite):
    pass
