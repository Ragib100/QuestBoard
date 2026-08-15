from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str
    SUPABASE_URL: str
    SUPABASE_PUBLISHABLE_KEY: str

    # Comma-separated browser origins allowed to call the API. Only Flutter web
    # needs this; "*" is fine for local development.
    CORS_ORIGINS: str = "*"

    # Powers POST /api/ai/hint. Optional: without it the endpoint returns a
    # 503 saying hints are not configured rather than pretending to work.
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
