import os
from dotenv import load_dotenv
from pydantic_settings import BaseSettings

# Load configuration values from files into os.environ
backend_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
project_root = os.path.dirname(backend_root)

# Try loading from the current working directory first
load_dotenv(".env", override=True)
load_dotenv(".app_config", override=True)

# Try loading from backend root
load_dotenv(os.path.join(backend_root, ".env"), override=True)
load_dotenv(os.path.join(backend_root, ".app_config"), override=True)

# Try loading from project root
load_dotenv(os.path.join(project_root, ".env"), override=True)
load_dotenv(os.path.join(project_root, ".app_config"), override=True)


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://tzuser:tzpass@localhost:5432/tz_db"
    SECRET_KEY: str = "CHANGE_THIS_SECRET_KEY_MUST_BE_32_CHARS_MINIMUM_PLEASE"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    UPLOAD_DIR: str = "./uploads"
    MAX_FILE_SIZE_MB: int = 50
    DEBUG: bool = False

    def __init__(self, **values):
        # Allow DB_URI to act as a seamless fallback alias for DATABASE_URL
        db_uri = os.environ.get("DB_URI") or os.environ.get("DATABASE_URL")
        if db_uri:
            values["DATABASE_URL"] = db_uri
        super().__init__(**values)

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
