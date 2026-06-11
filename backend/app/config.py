from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://tzuser:tzpass@localhost:5432/tz_db"
    SECRET_KEY: str = "CHANGE_THIS_SECRET_KEY_MUST_BE_32_CHARS_MINIMUM_PLEASE"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    UPLOAD_DIR: str = "./uploads"
    MAX_FILE_SIZE_MB: int = 50
    DEBUG: bool = False

    class Config:
        env_file = ".env"


settings = Settings()
