from pydantic import model_validator

from app.schemas.code import CodeSubmission

# A prose-only answer still has to say something. `min_length` on the field
# cannot express "unless there is code", so the check lives in the validator
# below and this is the number it uses.
MIN_BODY_CHARS = 10


class _AnswerWrite(CodeSubmission):
    body: str = ""
    image_url: str | None = None

    @model_validator(mode="after")
    def _body_or_code(self):
        body = self.body.strip()
        if len(body) >= MIN_BODY_CHARS:
            return self

        if self.has_code:
            # The code is the answer. Requiring ten characters of prose on top
            # of a working solution is a rule that only produces "here you go".
            return self

        raise ValueError(
            f"Write at least {MIN_BODY_CHARS} characters, or attach some code."
        )


class AnswerCreate(_AnswerWrite):
    pass


class AnswerUpdate(_AnswerWrite):
    pass
