from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str
    SUPABASE_URL: str
    SUPABASE_PUBLISHABLE_KEY: str

    # Comma-separated browser origins allowed to call the API. Only Flutter web
    # needs this; "*" is fine for local development.
    CORS_ORIGINS: str = "*"

    # Powers POST /api/ai/hint. Both are optional: with neither set the
    # endpoint returns 503 saying hints are not configured rather than
    # pretending to work.
    #
    # AI_BASE_URL points at any OpenAI-compatible /chat/completions endpoint —
    # Google Gemini, Groq, OpenRouter and Cerebras all expose one, and all four
    # have a free tier. It takes precedence when set, so a paid Anthropic key
    # can stay in .env without being used.
    AI_BASE_URL: str = ""
    AI_API_KEY: str = ""
    AI_MODEL: str = ""

    ANTHROPIC_API_KEY: str = ""
    ANTHROPIC_MODEL: str = "claude-opus-5"

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


settings = Settings()
