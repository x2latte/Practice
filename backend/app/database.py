from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

is_sqlite = settings.DATABASE_URL.startswith('sqlite')
engine_kwargs = {"echo": settings.DEBUG, "pool_pre_ping": not is_sqlite}
if not is_sqlite:
    engine_kwargs.update({"pool_size": 10, "max_overflow": 20})

engine = create_async_engine(settings.DATABASE_URL, **engine_kwargs)

AsyncSessionLocal = async_sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False,
    autocommit=False, autoflush=False,
)

class Base(DeclarativeBase):
    pass
