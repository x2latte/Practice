#!/usr/bin/env bash
# =======================================================================
#  setup_backend.sh — Полная установка бэкенда системы управления ТЗ
#  Запуск: chmod +x setup_backend.sh && ./setup_backend.sh
#  Требования: Python 3.11+, pip, PostgreSQL (или Docker)
# =======================================================================
set -euo pipefail
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}✅  $*${NC}"; }
info() { echo -e "${BLUE}►  $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }

PROJ="tz_backend"
info "=== Создаём проект: ./${PROJ} ==="

mkdir -p "${PROJ}/app/models" \
         "${PROJ}/app/schemas" \
         "${PROJ}/app/routers" \
         "${PROJ}/app/services" \
         "${PROJ}/migrations/versions" \
         "${PROJ}/uploads" \
         "${PROJ}/.github/workflows"
cd "${PROJ}"

# ── Пустые __init__.py ──────────────────────────────────────────────────
touch app/__init__.py app/models/__init__.py \
      app/schemas/__init__.py app/routers/__init__.py \
      app/services/__init__.py

# ═══════════════════════════════════════════════════════════════════════
#  requirements.txt
# ═══════════════════════════════════════════════════════════════════════
cat > requirements.txt << 'PYEOF'
fastapi==0.110.2
uvicorn[standard]==0.29.0
sqlalchemy[asyncio]==2.0.29
asyncpg==0.29.0
alembic==1.13.1
pydantic==2.7.1
pydantic-settings==2.2.1
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.9
aiofiles==23.2.1
reportlab==4.2.2
pillow==10.3.0
python-dotenv==1.0.1
httpx==0.27.0
pytest==8.1.1
pytest-asyncio==0.23.6
PYEOF
log "requirements.txt"

# ═══════════════════════════════════════════════════════════════════════
#  .env.example  (копируется в .env)
# ═══════════════════════════════════════════════════════════════════════
cat > .env.example << 'PYEOF'
DATABASE_URL=postgresql+asyncpg://tzuser:tzpass@localhost:5432/tz_db
SECRET_KEY=CHANGE_THIS_SECRET_KEY_MUST_BE_32_CHARS_MINIMUM_PLEASE
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30
UPLOAD_DIR=./uploads
MAX_FILE_SIZE_MB=50
DEBUG=false
PYEOF
cp .env.example .env
log ".env.example / .env"

# ═══════════════════════════════════════════════════════════════════════
#  app/config.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/config.py << 'PYEOF'
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
PYEOF
log "app/config.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/database.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/database.py << 'PYEOF'
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    pass
PYEOF
log "app/database.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/models/user.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/models/user.py << 'PYEOF'
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Enum as SAEnum, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base


class UserRole(str, enum.Enum):
    admin = "admin"
    user = "user"


class User(Base):
    __tablename__ = "users"

    guid            = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    email           = Column(String(255), unique=True, nullable=False, index=True)
    username        = Column(String(100), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    role            = Column(SAEnum(UserRole), default=UserRole.user, nullable=False)
    is_active       = Column(Boolean, default=True, nullable=False)
    created_at      = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at      = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owned_projects      = relationship("Project", back_populates="owner", cascade="all, delete-orphan")
    project_memberships = relationship("ProjectUser", back_populates="user", cascade="all, delete-orphan")
    refresh_tokens      = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    guid       = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    token      = Column(String(500), unique=True, nullable=False, index=True)
    user_guid  = Column(String(36), ForeignKey("users.guid", ondelete="CASCADE"), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    is_revoked = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="refresh_tokens")
PYEOF
log "app/models/user.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/models/project.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/models/project.py << 'PYEOF'
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Text, DateTime, Enum as SAEnum, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base


class ProjectStatus(str, enum.Enum):
    draft     = "draft"
    active    = "active"
    archived  = "archived"
    completed = "completed"


class ProjectUserRole(str, enum.Enum):
    owner  = "owner"
    editor = "editor"
    viewer = "viewer"


class Project(Base):
    __tablename__ = "projects"

    guid        = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    name        = Column(String(500), nullable=False)
    description = Column(Text, nullable=True)
    status      = Column(SAEnum(ProjectStatus), default=ProjectStatus.draft, nullable=False)
    owner_guid  = Column(String(36), ForeignKey("users.guid", ondelete="CASCADE"), nullable=False, index=True)
    created_at  = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owner   = relationship("User", back_populates="owned_projects")
    members = relationship("ProjectUser", back_populates="project", cascade="all, delete-orphan")
    files   = relationship("ProjectFile", back_populates="project", cascade="all, delete-orphan")


class ProjectUser(Base):
    __tablename__ = "project_users"

    guid         = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_guid = Column(String(36), ForeignKey("projects.guid", ondelete="CASCADE"), nullable=False, index=True)
    user_guid    = Column(String(36), ForeignKey("users.guid",    ondelete="CASCADE"), nullable=False)
    role         = Column(SAEnum(ProjectUserRole), default=ProjectUserRole.viewer, nullable=False)
    created_at   = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project",  back_populates="members")
    user    = relationship("User",     back_populates="project_memberships")
PYEOF
log "app/models/project.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/models/section.py  — все 17 разделов ТЗ
# ═══════════════════════════════════════════════════════════════════════
cat > app/models/section.py << 'PYEOF'
"""
Все разделы ТЗ.  Общий миксин SectionMixin + специфичные поля у некоторых.
"""
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Text, Integer, DateTime, ForeignKey, Enum as SAEnum
from app.database import Base


def _guid():
    return str(uuid.uuid4())


def _now():
    return datetime.utcnow()


# ── миксин ───────────────────────────────────────────────────────────
class SectionMixin:
    guid         = Column(String(36), primary_key=True, default=_guid, index=True)
    project_guid = Column(String(36), ForeignKey("projects.guid", ondelete="CASCADE"),
                          nullable=False, index=True)
    title        = Column(String(500), nullable=True)
    content      = Column(Text, nullable=True)
    order        = Column(Integer, default=0, nullable=False)
    created_by   = Column(String(36), ForeignKey("users.guid", ondelete="SET NULL"), nullable=True)
    created_at   = Column(DateTime, default=_now, nullable=False)
    updated_at   = Column(DateTime, default=_now, onupdate=_now)


# ── 1. Первичный список требований ───────────────────────────────────
class RequirementPriority(str, enum.Enum):
    low = "low"; medium = "medium"; high = "high"; critical = "critical"


class RequirementStatus(str, enum.Enum):
    new = "new"; accepted = "accepted"; rejected = "rejected"; deferred = "deferred"


class Requirement(SectionMixin, Base):
    __tablename__ = "requirements"
    source   = Column(String(255), nullable=True)
    priority = Column(SAEnum(RequirementPriority), default=RequirementPriority.medium)
    status   = Column(SAEnum(RequirementStatus),   default=RequirementStatus.new)
    category = Column(String(100), nullable=True)


# ── 2. Аннотация ─────────────────────────────────────────────────────
class Annotation(SectionMixin, Base):
    __tablename__ = "annotations"
    purpose          = Column(Text, nullable=True)
    info_sources     = Column(Text, nullable=True)


# ── 3. Бизнес-цели ───────────────────────────────────────────────────
class BusinessGoal(SectionMixin, Base):
    __tablename__ = "business_goals"
    metric       = Column(String(255), nullable=True)
    deadline     = Column(String(100), nullable=True)


# ── 4. Аналоги и патентная чистота ───────────────────────────────────
class Analog(SectionMixin, Base):
    __tablename__ = "analogs"
    source       = Column(String(500), nullable=True)
    patent_notes = Column(Text, nullable=True)


# ── 5. Классы пользователей ──────────────────────────────────────────
class UserClass(SectionMixin, Base):
    __tablename__ = "user_classes"
    frequency     = Column(String(100), nullable=True)
    privileges    = Column(Text, nullable=True)


# ── 6. Пользовательские истории ──────────────────────────────────────
class UserStoryStatus(str, enum.Enum):
    todo = "todo"; in_progress = "in_progress"; done = "done"


class UserStory(SectionMixin, Base):
    __tablename__ = "user_stories"
    role    = Column(String(255), nullable=True)
    action  = Column(Text, nullable=True)
    benefit = Column(Text, nullable=True)
    priority = Column(SAEnum(RequirementPriority), default=RequirementPriority.medium)
    status   = Column(SAEnum(UserStoryStatus),     default=UserStoryStatus.todo)
    acceptance_criteria = Column(Text, nullable=True)


# ── 7. Глоссарий ─────────────────────────────────────────────────────
class GlossaryTerm(SectionMixin, Base):
    __tablename__ = "glossary_terms"
    term       = Column(String(255), nullable=True)
    definition = Column(Text, nullable=True)
    source     = Column(String(255), nullable=True)


# ── 8. Use Cases ─────────────────────────────────────────────────────
class UseCase(SectionMixin, Base):
    __tablename__ = "use_cases"
    actor          = Column(String(255), nullable=True)
    preconditions  = Column(Text, nullable=True)
    main_flow      = Column(Text, nullable=True)
    alt_flows      = Column(Text, nullable=True)
    postconditions = Column(Text, nullable=True)


# ── 9. Архитектура ───────────────────────────────────────────────────
class DiagramType(str, enum.Enum):
    plantuml = "plantuml"; mermaid = "mermaid"; text = "text"


class Architecture(SectionMixin, Base):
    __tablename__ = "architecture"
    diagram_type    = Column(SAEnum(DiagramType), default=DiagramType.text)
    diagram_content = Column(Text, nullable=True)
    layer           = Column(String(100), nullable=True)


# ── 10. Потоки данных ────────────────────────────────────────────────
class DataFlow(SectionMixin, Base):
    __tablename__ = "data_flows"
    diagram_type    = Column(SAEnum(DiagramType), default=DiagramType.text)
    diagram_content = Column(Text, nullable=True)
    actors          = Column(Text, nullable=True)


# ── 11. Словарь данных ───────────────────────────────────────────────
class DataDictionaryEntry(SectionMixin, Base):
    __tablename__ = "data_dictionary"
    entity      = Column(String(255), nullable=True)
    attributes  = Column(Text, nullable=True)
    data_type   = Column(String(100), nullable=True)
    constraints = Column(Text, nullable=True)


# ── 12. Нефункциональные требования ─────────────────────────────────
class NFRCategory(str, enum.Enum):
    performance   = "performance"
    security      = "security"
    reliability   = "reliability"
    scalability   = "scalability"
    usability     = "usability"
    maintainability = "maintainability"
    other         = "other"


class NonFunctionalRequirement(SectionMixin, Base):
    __tablename__ = "non_functional_requirements"
    category = Column(SAEnum(NFRCategory), default=NFRCategory.other)
    metric   = Column(String(255), nullable=True)
    value    = Column(String(255), nullable=True)


# ── 13. Ограничения ──────────────────────────────────────────────────
class ConstraintType(str, enum.Enum):
    technical    = "technical"
    business     = "business"
    legal        = "legal"
    resource     = "resource"


class Constraint(SectionMixin, Base):
    __tablename__ = "constraints"
    constraint_type = Column(SAEnum(ConstraintType), default=ConstraintType.technical)
    impact          = Column(Text, nullable=True)


# ── 14. Системные требования ─────────────────────────────────────────
class SystemRequirement(SectionMixin, Base):
    __tablename__ = "system_requirements"
    component      = Column(String(255), nullable=True)
    specification  = Column(Text, nullable=True)


# ── 15. Черновая версия ТЗ ───────────────────────────────────────────
class DraftTZ(SectionMixin, Base):
    __tablename__ = "draft_tz"
    version   = Column(String(50), nullable=True)
    notes     = Column(Text, nullable=True)


# ── 16. Итоговое ТЗ (аттестованное) ──────────────────────────────────
class FinalTZ(SectionMixin, Base):
    __tablename__ = "final_tz"
    version       = Column(String(50), nullable=True)
    approved_by   = Column(String(255), nullable=True)
    approved_at   = Column(DateTime, nullable=True)


# ── 17. Управление изменениями ───────────────────────────────────────
class ChangeType(str, enum.Enum):
    added    = "added"
    modified = "modified"
    removed  = "removed"


class ChangeRecord(SectionMixin, Base):
    __tablename__ = "change_records"
    version     = Column(String(50), nullable=True)
    change_type = Column(SAEnum(ChangeType), default=ChangeType.modified)
    section_ref = Column(String(255), nullable=True)
    reason      = Column(Text, nullable=True)
    author      = Column(String(255), nullable=True)
PYEOF
log "app/models/section.py (17 разделов)"

# ═══════════════════════════════════════════════════════════════════════
#  app/models/file.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/models/file.py << 'PYEOF'
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base


class ProjectFile(Base):
    __tablename__ = "project_files"

    guid         = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    project_guid = Column(String(36), ForeignKey("projects.guid", ondelete="CASCADE"),
                          nullable=False, index=True)
    section_type = Column(String(100), nullable=True)
    section_guid = Column(String(36),  nullable=True)
    filename     = Column(String(500), nullable=False)
    filepath     = Column(String(1000), nullable=False)
    size_bytes   = Column(Integer, nullable=False, default=0)
    mime_type    = Column(String(200), nullable=True)
    uploaded_by  = Column(String(36), ForeignKey("users.guid", ondelete="SET NULL"), nullable=True)
    created_at   = Column(DateTime, default=datetime.utcnow, nullable=False)

    project = relationship("Project", back_populates="files")
PYEOF
log "app/models/file.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/models/__init__.py  — импортируем всё для Alembic
# ═══════════════════════════════════════════════════════════════════════
cat > app/models/__init__.py << 'PYEOF'
from app.models.user    import User, RefreshToken          # noqa
from app.models.project import Project, ProjectUser        # noqa
from app.models.section import (                           # noqa
    Requirement, Annotation, BusinessGoal, Analog,
    UserClass, UserStory, GlossaryTerm, UseCase,
    Architecture, DataFlow, DataDictionaryEntry,
    NonFunctionalRequirement, Constraint, SystemRequirement,
    DraftTZ, FinalTZ, ChangeRecord,
)
from app.models.file import ProjectFile                    # noqa
PYEOF
log "app/models/__init__.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/schemas/auth.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/schemas/auth.py << 'PYEOF'
from pydantic import BaseModel, EmailStr, field_validator


class RegisterRequest(BaseModel):
    email:    EmailStr
    username: str
    password: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Пароль должен содержать не менее 8 символов")
        return v

    @field_validator("username")
    @classmethod
    def username_valid(cls, v):
        if len(v) < 3:
            raise ValueError("Имя пользователя — минимум 3 символа")
        return v.strip()


class LoginRequest(BaseModel):
    email:    EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str
PYEOF
log "app/schemas/auth.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/schemas/user.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/schemas/user.py << 'PYEOF'
from pydantic import BaseModel, EmailStr, ConfigDict
from datetime import datetime
from typing import Optional
from app.models.user import UserRole


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    guid:       str
    email:      EmailStr
    username:   str
    role:       UserRole
    is_active:  bool
    created_at: datetime


class UserUpdate(BaseModel):
    is_active: Optional[bool] = None
    role:      Optional[UserRole] = None
PYEOF
log "app/schemas/user.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/schemas/project.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/schemas/project.py << 'PYEOF'
from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional
from app.models.project import ProjectStatus, ProjectUserRole


class ProjectCreate(BaseModel):
    name:        str
    description: Optional[str] = None
    status:      Optional[ProjectStatus] = ProjectStatus.draft


class ProjectUpdate(BaseModel):
    name:        Optional[str] = None
    description: Optional[str] = None
    status:      Optional[ProjectStatus] = None


class ProjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    guid:        str
    name:        str
    description: Optional[str]
    status:      ProjectStatus
    owner_guid:  str
    created_at:  datetime
    updated_at:  Optional[datetime]


class ProjectMemberAdd(BaseModel):
    user_guid: str
    role:      ProjectUserRole = ProjectUserRole.viewer


class ProjectMemberUpdate(BaseModel):
    role: ProjectUserRole


class ProjectMemberResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    guid:         str
    project_guid: str
    user_guid:    str
    role:         ProjectUserRole
    created_at:   datetime
PYEOF
log "app/schemas/project.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/schemas/section.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/schemas/section.py << 'PYEOF'
"""
Универсальные схемы для всех разделов ТЗ.
Каждый специфичный раздел наследует SectionBase.
"""
from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional, Any, Dict


class SectionBase(BaseModel):
    title:   Optional[str] = None
    content: Optional[str] = None
    order:   int = 0


class SectionCreate(SectionBase):
    extra: Optional[Dict[str, Any]] = None   # доп. поля для специфичных разделов


class SectionUpdate(BaseModel):
    title:   Optional[str] = None
    content: Optional[str] = None
    order:   Optional[int] = None
    extra:   Optional[Dict[str, Any]] = None


class SectionResponse(SectionBase):
    model_config = ConfigDict(from_attributes=True)

    guid:         str
    project_guid: str
    created_by:   Optional[str]
    created_at:   datetime
    updated_at:   Optional[datetime]


# ── Специфичные схемы (только доп. поля) ─────────────────────────────

class RequirementCreate(SectionBase):
    source:   Optional[str] = None
    priority: Optional[str] = "medium"
    status:   Optional[str] = "new"
    category: Optional[str] = None


class UserStoryCreate(SectionBase):
    role:                Optional[str] = None
    action:              Optional[str] = None
    benefit:             Optional[str] = None
    priority:            Optional[str] = "medium"
    status:              Optional[str] = "todo"
    acceptance_criteria: Optional[str] = None


class GlossaryCreate(SectionBase):
    term:       Optional[str] = None
    definition: Optional[str] = None
    source:     Optional[str] = None


class UseCaseCreate(SectionBase):
    actor:          Optional[str] = None
    preconditions:  Optional[str] = None
    main_flow:      Optional[str] = None
    alt_flows:      Optional[str] = None
    postconditions: Optional[str] = None


class ArchitectureCreate(SectionBase):
    diagram_type:    Optional[str] = "text"
    diagram_content: Optional[str] = None
    layer:           Optional[str] = None


class ChangeRecordCreate(SectionBase):
    version:     Optional[str] = None
    change_type: Optional[str] = "modified"
    section_ref: Optional[str] = None
    reason:      Optional[str] = None
    author:      Optional[str] = None


class ProjectStats(BaseModel):
    project_guid:     str
    readiness_score:  float           # 0–100
    filled_sections:  int
    total_sections:   int
    sections_detail:  Dict[str, int]  # section_name -> count
PYEOF
log "app/schemas/section.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/schemas/file.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/schemas/file.py << 'PYEOF'
from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional


class FileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    guid:         str
    project_guid: str
    section_type: Optional[str]
    section_guid: Optional[str]
    filename:     str
    size_bytes:   int
    mime_type:    Optional[str]
    uploaded_by:  Optional[str]
    created_at:   datetime
PYEOF
log "app/schemas/file.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/services/auth.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/services/auth.py << 'PYEOF'
from datetime import datetime, timedelta
from typing import Optional
from jose import jwt, JWTError
from passlib.context import CryptContext
from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def _encode(data: dict, expires_delta: timedelta) -> str:
    payload = data.copy()
    payload["exp"] = datetime.utcnow() + expires_delta
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_access_token(user_guid: str, role: str) -> str:
    return _encode(
        {"sub": user_guid, "role": role, "type": "access"},
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    )


def create_refresh_token(user_guid: str) -> str:
    return _encode(
        {"sub": user_guid, "type": "refresh"},
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )


def decode_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        return None
PYEOF
log "app/services/auth.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/services/stats.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/services/stats.py << 'PYEOF'
"""
Расчёт готовности проекта: взвешенный процент заполненных разделов.
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.models.section import (
    Requirement, Annotation, BusinessGoal, Analog, UserClass,
    UserStory, GlossaryTerm, UseCase, Architecture, DataFlow,
    DataDictionaryEntry, NonFunctionalRequirement, Constraint,
    SystemRequirement, DraftTZ, FinalTZ, ChangeRecord,
)

# (модель, вес, отображаемое имя)
SECTION_WEIGHTS = [
    (Annotation,                "annotation",                   5),
    (BusinessGoal,              "business_goals",               8),
    (Analog,                    "analogs",                      3),
    (Requirement,               "requirements",                10),
    (UserClass,                 "user_classes",                 5),
    (UserStory,                 "user_stories",                 8),
    (GlossaryTerm,              "glossary_terms",               5),
    (UseCase,                   "use_cases",                    8),
    (Architecture,              "architecture",                 8),
    (DataFlow,                  "data_flows",                   6),
    (DataDictionaryEntry,       "data_dictionary",              6),
    (NonFunctionalRequirement,  "non_functional_requirements",  8),
    (Constraint,                "constraints",                  5),
    (SystemRequirement,         "system_requirements",          8),
    (DraftTZ,                   "draft_tz",                     5),
    (FinalTZ,                   "final_tz",                     6),
    (ChangeRecord,              "change_records",               2),
]

TOTAL_WEIGHT = sum(w for _, _, w in SECTION_WEIGHTS)


async def calculate_stats(project_guid: str, db: AsyncSession) -> dict:
    sections_detail: dict[str, int] = {}
    earned_weight = 0

    for model, name, weight in SECTION_WEIGHTS:
        result = await db.execute(
            select(func.count()).where(model.project_guid == project_guid)
        )
        count = result.scalar_one()
        sections_detail[name] = count
        if count > 0:
            earned_weight += weight

    filled   = sum(1 for c in sections_detail.values() if c > 0)
    total    = len(SECTION_WEIGHTS)
    score    = round(earned_weight / TOTAL_WEIGHT * 100, 1)

    return {
        "project_guid":    project_guid,
        "readiness_score": score,
        "filled_sections": filled,
        "total_sections":  total,
        "sections_detail": sections_detail,
    }
PYEOF
log "app/services/stats.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/services/pdf.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/services/pdf.py << 'PYEOF'
"""
Генерация PDF-отчёта ТЗ с помощью reportlab.
"""
import io
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.project import Project
from app.models.section import (
    Annotation, BusinessGoal, Requirement, UserStory,
    GlossaryTerm, UseCase, Architecture, DataFlow,
    DataDictionaryEntry, NonFunctionalRequirement,
    Constraint, SystemRequirement, ChangeRecord,
)


SECTION_ORDER = [
    ("Аннотация",                       Annotation,               ["purpose", "info_sources"]),
    ("Бизнес-цели",                     BusinessGoal,             ["title", "content", "metric"]),
    ("Первичный список требований",     Requirement,              ["title", "content", "priority", "status"]),
    ("Пользовательские истории",        UserStory,                ["title", "role", "action", "benefit"]),
    ("Глоссарий",                       GlossaryTerm,             ["term", "definition"]),
    ("Use Cases",                       UseCase,                  ["title", "actor", "main_flow"]),
    ("Архитектура",                     Architecture,             ["title", "content", "diagram_content"]),
    ("Потоки данных",                   DataFlow,                 ["title", "content"]),
    ("Словарь данных",                  DataDictionaryEntry,      ["entity", "attributes"]),
    ("Нефункциональные требования",     NonFunctionalRequirement, ["title", "content", "metric", "value"]),
    ("Ограничения",                     Constraint,               ["title", "content", "impact"]),
    ("Системные требования",            SystemRequirement,        ["title", "specification"]),
    ("Управление изменениями",          ChangeRecord,             ["version", "change_type", "reason"]),
]


def _style():
    styles = getSampleStyleSheet()
    h1 = ParagraphStyle("H1", parent=styles["Heading1"], fontSize=16,
                         spaceAfter=8, textColor=colors.HexColor("#1a237e"))
    h2 = ParagraphStyle("H2", parent=styles["Heading2"], fontSize=13,
                         spaceAfter=6, textColor=colors.HexColor("#283593"))
    body = ParagraphStyle("Body", parent=styles["Normal"], fontSize=10,
                           leading=14, spaceAfter=4)
    return styles, h1, h2, body


def _safe(val):
    if val is None:
        return "—"
    return str(val).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


async def generate_pdf(project_guid: str, db: AsyncSession) -> bytes:
    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4,
                             leftMargin=2*cm, rightMargin=2*cm,
                             topMargin=2*cm,  bottomMargin=2*cm)
    styles, h1_style, h2_style, body_style = _style()
    story = []

    # Заголовок проекта
    proj = await db.get(Project, project_guid)
    if proj:
        story.append(Paragraph(f"Техническое задание", styles["Title"]))
        story.append(Paragraph(f"Проект: {_safe(proj.name)}", h1_style))
        story.append(Paragraph(
            f"Статус: {proj.status.value} | Создан: {proj.created_at.strftime('%d.%m.%Y')}",
            body_style,
        ))
        story.append(HRFlowable(width="100%", thickness=1, color=colors.grey))
        story.append(Spacer(1, 0.4*cm))
        if proj.description:
            story.append(Paragraph(_safe(proj.description), body_style))
            story.append(Spacer(1, 0.3*cm))

    # Разделы
    for section_title, model, fields in SECTION_ORDER:
        result = await db.execute(
            select(model).where(model.project_guid == project_guid).order_by(model.order)
        )
        items = result.scalars().all()
        if not items:
            continue

        story.append(Paragraph(section_title, h1_style))
        story.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#9fa8da")))
        story.append(Spacer(1, 0.2*cm))

        for idx, item in enumerate(items, 1):
            rows = []
            for field in fields:
                val = getattr(item, field, None)
                if val:
                    rows.append([field.replace("_", " ").capitalize(), _safe(val)])
            if rows:
                if hasattr(item, "title") and item.title:
                    story.append(Paragraph(f"{idx}. {_safe(item.title)}", h2_style))
                tbl = Table(rows, colWidths=[4.5*cm, 12*cm])
                tbl.setStyle(TableStyle([
                    ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#e8eaf6")),
                    ("FONTSIZE",   (0, 0), (-1, -1), 9),
                    ("GRID",       (0, 0), (-1, -1), 0.3, colors.HexColor("#c5cae9")),
                    ("VALIGN",     (0, 0), (-1, -1), "TOP"),
                    ("TOPPADDING", (0, 0), (-1, -1), 4),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ]))
                story.append(tbl)
                story.append(Spacer(1, 0.2*cm))

        story.append(Spacer(1, 0.4*cm))

    # Футер
    story.append(HRFlowable(width="100%", thickness=1, color=colors.grey))
    story.append(Paragraph(
        f"Документ создан: {datetime.utcnow().strftime('%d.%m.%Y %H:%M')} UTC",
        body_style,
    ))

    doc.build(story)
    return buf.getvalue()
PYEOF
log "app/services/pdf.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/dependencies.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/dependencies.py << 'PYEOF'
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.user import User, UserRole
from app.services.auth import decode_token

bearer_scheme = HTTPBearer()


async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    token = credentials.credentials
    payload = decode_token(token)

    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Токен недействителен или истёк")

    user_guid = payload.get("sub")
    result = await db.execute(select(User).where(User.guid == user_guid))
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Пользователь не найден или заблокирован")
    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail="Требуются права администратора")
    return user


async def get_project_or_404(
    project_guid: str,
    db: AsyncSession,
    user: User,
):
    from app.models.project import Project, ProjectUser
    result = await db.execute(select(Project).where(Project.guid == project_guid))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Проект не найден")

    # owner или участник или admin
    if project.owner_guid != user.guid and user.role != UserRole.admin:
        member = await db.execute(
            select(ProjectUser).where(
                ProjectUser.project_guid == project_guid,
                ProjectUser.user_guid    == user.guid,
            )
        )
        if not member.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="Нет доступа к проекту")
    return project
PYEOF
log "app/dependencies.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/routers/auth.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/routers/auth.py << 'PYEOF'
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.dependencies import get_db, get_current_user
from app.models.user import User
from app.models.user import RefreshToken
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, RefreshRequest
from app.services.auth import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token,
)
from app.config import settings

router = APIRouter(prefix="/api/users", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # проверка уникальности
    existing = await db.execute(
        select(User).where((User.email == body.email) | (User.username == body.username))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Email или username уже занят")

    user = User(
        email=body.email,
        username=body.username,
        hashed_password=hash_password(body.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    access  = create_access_token(user.guid, user.role.value)
    refresh = create_refresh_token(user.guid)
    rt = RefreshToken(
        token=refresh,
        user_guid=user.guid,
        expires_at=datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )
    db.add(rt)
    await db.commit()
    return TokenResponse(access_token=access, refresh_token=refresh)


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(401, "Неверный email или пароль")
    if not user.is_active:
        raise HTTPException(403, "Аккаунт заблокирован")

    access  = create_access_token(user.guid, user.role.value)
    refresh = create_refresh_token(user.guid)
    rt = RefreshToken(
        token=refresh,
        user_guid=user.guid,
        expires_at=datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )
    db.add(rt)
    await db.commit()
    return TokenResponse(access_token=access, refresh_token=refresh)


@router.post("/logout", status_code=204)
async def logout(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token == body.refresh_token)
    )
    rt = result.scalar_one_or_none()
    if rt:
        rt.is_revoked = True
        await db.commit()


@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = decode_token(body.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(401, "Токен недействителен")

    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token == body.refresh_token)
    )
    rt = result.scalar_one_or_none()
    if not rt or rt.is_revoked or rt.expires_at < datetime.utcnow():
        raise HTTPException(401, "Refresh-токен истёк или отозван")

    user = await db.get(User, rt.user_guid)
    if not user or not user.is_active:
        raise HTTPException(401, "Пользователь не найден")

    rt.is_revoked = True
    new_access  = create_access_token(user.guid, user.role.value)
    new_refresh = create_refresh_token(user.guid)
    new_rt = RefreshToken(
        token=new_refresh,
        user_guid=user.guid,
        expires_at=datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )
    db.add(new_rt)
    await db.commit()
    return TokenResponse(access_token=new_access, refresh_token=new_refresh)
PYEOF
log "app/routers/auth.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/routers/users.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/routers/users.py << 'PYEOF'
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.dependencies import get_db, get_current_user, require_admin
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    return user


@router.get("/all", response_model=List[UserResponse])
async def list_all_users(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    result = await db.execute(select(User))
    return result.scalars().all()


@router.put("/{user_guid}", response_model=UserResponse)
async def update_user(
    user_guid: str,
    body: UserUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    user = await db.get(User, user_guid)
    if not user:
        raise HTTPException(404, "Пользователь не найден")
    if body.is_active is not None:
        user.is_active = body.is_active
    if body.role is not None:
        user.role = body.role
    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/{user_guid}", status_code=204)
async def delete_user(
    user_guid: str,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    if user_guid == admin.guid:
        raise HTTPException(400, "Нельзя удалить самого себя")
    user = await db.get(User, user_guid)
    if not user:
        raise HTTPException(404, "Пользователь не найден")
    await db.delete(user)
    await db.commit()
PYEOF
log "app/routers/users.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/routers/projects.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/routers/projects.py << 'PYEOF'
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from app.dependencies import get_db, get_current_user, get_project_or_404
from app.models.user import User, UserRole
from app.models.project import Project, ProjectUser, ProjectUserRole
from app.schemas.project import (
    ProjectCreate, ProjectUpdate, ProjectResponse,
    ProjectMemberAdd, ProjectMemberUpdate, ProjectMemberResponse,
)
from app.schemas.section import ProjectStats
from app.services.stats import calculate_stats
from app.services.pdf import generate_pdf

router = APIRouter(prefix="/api/projects", tags=["projects"])


@router.get("", response_model=List[ProjectResponse])
async def list_projects(
    skip:       int = Query(0,   ge=0),
    limit:      int = Query(50,  ge=1, le=200),
    status:     Optional[str] = None,
    search:     Optional[str] = None,
    sort_by:    str = Query("created_at", enum=["created_at", "name", "status"]),
    sort_order: str = Query("desc", enum=["asc", "desc"]),
    db:    AsyncSession = Depends(get_db),
    user:  User = Depends(get_current_user),
):
    q = select(Project)
    if user.role != UserRole.admin:
        # владелец или участник
        member_subs = select(ProjectUser.project_guid).where(
            ProjectUser.user_guid == user.guid
        ).scalar_subquery()
        q = q.where(or_(Project.owner_guid == user.guid,
                        Project.guid.in_(member_subs)))
    if status:
        q = q.where(Project.status == status)
    if search:
        q = q.where(or_(
            Project.name.ilike(f"%{search}%"),
            Project.description.ilike(f"%{search}%"),
        ))
    col = getattr(Project, sort_by, Project.created_at)
    q   = q.order_by(col.desc() if sort_order == "desc" else col.asc())
    q   = q.offset(skip).limit(limit)
    result = await db.execute(q)
    return result.scalars().all()


@router.post("", response_model=ProjectResponse, status_code=201)
async def create_project(
    body: ProjectCreate,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    project = Project(**body.model_dump(), owner_guid=user.guid)
    db.add(project)
    await db.flush()
    # владелец тоже добавляется как участник
    db.add(ProjectUser(project_guid=project.guid, user_guid=user.guid,
                       role=ProjectUserRole.owner))
    await db.commit()
    await db.refresh(project)
    return project


@router.get("/{project_guid}", response_model=ProjectResponse)
async def get_project(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await get_project_or_404(project_guid, db, user)


@router.put("/{project_guid}", response_model=ProjectResponse)
async def update_project(
    project_guid: str,
    body: ProjectUpdate,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, user)
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(project, k, v)
    await db.commit()
    await db.refresh(project)
    return project


@router.delete("/{project_guid}", status_code=204)
async def delete_project(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, user)
    if project.owner_guid != user.guid and user.role != UserRole.admin:
        raise HTTPException(403, "Только владелец может удалить проект")
    await db.delete(project)
    await db.commit()


# ── Участники ────────────────────────────────────────────────────────

@router.get("/{project_guid}/users", response_model=List[ProjectMemberResponse])
async def list_members(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    result = await db.execute(
        select(ProjectUser).where(ProjectUser.project_guid == project_guid)
    )
    return result.scalars().all()


@router.post("/{project_guid}/users", response_model=ProjectMemberResponse, status_code=201)
async def add_member(
    project_guid: str,
    body: ProjectMemberAdd,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, user)
    if project.owner_guid != user.guid and user.role != UserRole.admin:
        raise HTTPException(403, "Только владелец добавляет участников")
    new_member = ProjectUser(
        project_guid=project_guid,
        user_guid=body.user_guid,
        role=body.role,
    )
    db.add(new_member)
    await db.commit()
    await db.refresh(new_member)
    return new_member


@router.put("/{project_guid}/users/{user_guid}", response_model=ProjectMemberResponse)
async def update_member(
    project_guid: str,
    user_guid:    str,
    body: ProjectMemberUpdate,
    db:   AsyncSession = Depends(get_db),
    cur_user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, cur_user)
    if project.owner_guid != cur_user.guid and cur_user.role != UserRole.admin:
        raise HTTPException(403, "Недостаточно прав")
    result = await db.execute(
        select(ProjectUser).where(
            ProjectUser.project_guid == project_guid,
            ProjectUser.user_guid    == user_guid,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(404, "Участник не найден")
    member.role = body.role
    await db.commit()
    await db.refresh(member)
    return member


@router.delete("/{project_guid}/users/{user_guid}", status_code=204)
async def remove_member(
    project_guid: str,
    user_guid:    str,
    db:   AsyncSession = Depends(get_db),
    cur_user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, cur_user)
    if project.owner_guid != cur_user.guid and cur_user.role != UserRole.admin:
        raise HTTPException(403, "Недостаточно прав")
    result = await db.execute(
        select(ProjectUser).where(
            ProjectUser.project_guid == project_guid,
            ProjectUser.user_guid    == user_guid,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(404, "Участник не найден")
    await db.delete(member)
    await db.commit()


# ── Статистика / PDF ─────────────────────────────────────────────────

@router.get("/{project_guid}/stats", response_model=ProjectStats)
async def project_stats(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    return await calculate_stats(project_guid, db)


@router.get("/{project_guid}/export/pdf")
async def export_pdf(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    pdf_bytes = await generate_pdf(project_guid, db)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="tz_{project_guid}.pdf"'},
    )
PYEOF
log "app/routers/projects.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/routers/sections.py  — фабрика роутеров для всех разделов ТЗ
# ═══════════════════════════════════════════════════════════════════════
cat > app/routers/sections.py << 'PYEOF'
"""
Фабрика CRUD-роутеров для всех разделов ТЗ.
Один вызов make_section_router() → полноценный роутер с
GET (list), POST, GET /{item_guid}, PUT /{item_guid}, DELETE /{item_guid}.
"""
from typing import List, Optional, Type
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from app.dependencies import get_db, get_current_user, get_project_or_404
from app.models.user import User
from app.schemas.section import SectionCreate, SectionUpdate, SectionResponse


def make_section_router(model: Type, url_prefix: str, tag: str) -> APIRouter:
    router = APIRouter(
        prefix=f"/api/projects/{{project_guid}}/{url_prefix}",
        tags=[tag],
    )

    @router.get("", response_model=List[SectionResponse])
    async def list_items(
        project_guid: str,
        skip:         int = Query(0, ge=0),
        limit:        int = Query(100, ge=1, le=500),
        search:       Optional[str] = None,
        sort_by:      str = Query("order", enum=["order", "created_at", "title"]),
        sort_order:   str = Query("asc", enum=["asc", "desc"]),
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        q = select(model).where(model.project_guid == project_guid)
        if search and hasattr(model, "title") and hasattr(model, "content"):
            q = q.where(or_(
                model.title.ilike(f"%{search}%"),
                model.content.ilike(f"%{search}%"),
            ))
        col = getattr(model, sort_by, model.order)
        q   = q.order_by(col.desc() if sort_order == "desc" else col.asc())
        q   = q.offset(skip).limit(limit)
        result = await db.execute(q)
        return result.scalars().all()

    @router.post("", response_model=SectionResponse, status_code=201)
    async def create_item(
        project_guid: str,
        body:  SectionCreate,
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        data = body.model_dump(exclude={"extra"})
        # применяем extra-поля если переданы
        extra = body.extra or {}
        item = model(project_guid=project_guid, created_by=user.guid, **data, **extra)
        db.add(item)
        await db.commit()
        await db.refresh(item)
        return item

    @router.get("/{item_guid}", response_model=SectionResponse)
    async def get_item(
        project_guid: str,
        item_guid:    str,
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        item = await db.get(model, item_guid)
        if not item or item.project_guid != project_guid:
            raise HTTPException(404, "Запись не найдена")
        return item

    @router.put("/{item_guid}", response_model=SectionResponse)
    async def update_item(
        project_guid: str,
        item_guid:    str,
        body:  SectionUpdate,
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        item = await db.get(model, item_guid)
        if not item or item.project_guid != project_guid:
            raise HTTPException(404, "Запись не найдена")
        for k, v in body.model_dump(exclude_none=True, exclude={"extra"}).items():
            if hasattr(item, k):
                setattr(item, k, v)
        for k, v in (body.extra or {}).items():
            if hasattr(item, k):
                setattr(item, k, v)
        await db.commit()
        await db.refresh(item)
        return item

    @router.delete("/{item_guid}", status_code=204)
    async def delete_item(
        project_guid: str,
        item_guid:    str,
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        item = await db.get(model, item_guid)
        if not item or item.project_guid != project_guid:
            raise HTTPException(404, "Запись не найдена")
        await db.delete(item)
        await db.commit()

    return router


# ── Регистрируем все 17 разделов ─────────────────────────────────────
from app.models.section import (
    Requirement, Annotation, BusinessGoal, Analog, UserClass,
    UserStory, GlossaryTerm, UseCase, Architecture, DataFlow,
    DataDictionaryEntry, NonFunctionalRequirement, Constraint,
    SystemRequirement, DraftTZ, FinalTZ, ChangeRecord,
)

section_routers: List[APIRouter] = [
    make_section_router(Requirement,               "requirements",               "requirements"),
    make_section_router(Annotation,                "annotation",                 "annotation"),
    make_section_router(BusinessGoal,              "business-goals",             "business-goals"),
    make_section_router(Analog,                    "analogs",                    "analogs"),
    make_section_router(UserClass,                 "user-classes",               "user-classes"),
    make_section_router(UserStory,                 "user-stories",               "user-stories"),
    make_section_router(GlossaryTerm,              "glossary-terms",             "glossary-terms"),
    make_section_router(UseCase,                   "use-cases",                  "use-cases"),
    make_section_router(Architecture,              "architecture",               "architecture"),
    make_section_router(DataFlow,                  "data-flows",                 "data-flows"),
    make_section_router(DataDictionaryEntry,       "data-dictionary",            "data-dictionary"),
    make_section_router(NonFunctionalRequirement,  "non-functional-requirements","non-functional-requirements"),
    make_section_router(Constraint,                "constraints",                "constraints"),
    make_section_router(SystemRequirement,         "system-requirements",        "system-requirements"),
    make_section_router(DraftTZ,                   "draft-tz",                   "draft-tz"),
    make_section_router(FinalTZ,                   "final-tz",                   "final-tz"),
    make_section_router(ChangeRecord,              "changes",                    "changes"),
]
PYEOF
log "app/routers/sections.py (17 разделов через фабрику)"

# ═══════════════════════════════════════════════════════════════════════
#  app/routers/files.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/routers/files.py << 'PYEOF'
import os
import uuid
import aiofiles
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from fastapi.responses import FileResponse as FastAPIFileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.dependencies import get_db, get_current_user, get_project_or_404
from app.models.user import User
from app.models.file import ProjectFile
from app.schemas.file import FileResponse
from app.config import settings

router = APIRouter(prefix="/api/projects/{project_guid}/files", tags=["files"])
MAX_BYTES = settings.MAX_FILE_SIZE_MB * 1024 * 1024


@router.post("", response_model=FileResponse, status_code=201)
async def upload_file(
    project_guid: str,
    section_type: Optional[str] = Query(None),
    section_guid: Optional[str] = Query(None),
    file: UploadFile = File(...),
    db:   AsyncSession = Depends(get_db),
    user: User         = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)

    content = await file.read()
    if len(content) > MAX_BYTES:
        raise HTTPException(413, f"Файл превышает {settings.MAX_FILE_SIZE_MB} МБ")

    upload_dir = os.path.join(settings.UPLOAD_DIR, project_guid)
    os.makedirs(upload_dir, exist_ok=True)

    file_guid = str(uuid.uuid4())
    ext       = os.path.splitext(file.filename or "")[1]
    disk_name = f"{file_guid}{ext}"
    filepath  = os.path.join(upload_dir, disk_name)

    async with aiofiles.open(filepath, "wb") as f:
        await f.write(content)

    pf = ProjectFile(
        guid=file_guid,
        project_guid=project_guid,
        section_type=section_type,
        section_guid=section_guid,
        filename=file.filename or disk_name,
        filepath=filepath,
        size_bytes=len(content),
        mime_type=file.content_type,
        uploaded_by=user.guid,
    )
    db.add(pf)
    await db.commit()
    await db.refresh(pf)
    return pf


@router.get("", response_model=List[FileResponse])
async def list_files(
    project_guid: str,
    section_type: Optional[str] = Query(None),
    db:   AsyncSession = Depends(get_db),
    user: User         = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    q = select(ProjectFile).where(ProjectFile.project_guid == project_guid)
    if section_type:
        q = q.where(ProjectFile.section_type == section_type)
    result = await db.execute(q.order_by(ProjectFile.created_at.desc()))
    return result.scalars().all()


@router.get("/{file_guid}/download")
async def download_file(
    project_guid: str,
    file_guid:    str,
    db:   AsyncSession = Depends(get_db),
    user: User         = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    pf = await db.get(ProjectFile, file_guid)
    if not pf or pf.project_guid != project_guid:
        raise HTTPException(404, "Файл не найден")
    if not os.path.exists(pf.filepath):
        raise HTTPException(410, "Файл был удалён с диска")
    return FastAPIFileResponse(
        path=pf.filepath,
        filename=pf.filename,
        media_type=pf.mime_type or "application/octet-stream",
    )


@router.delete("/{file_guid}", status_code=204)
async def delete_file(
    project_guid: str,
    file_guid:    str,
    db:   AsyncSession = Depends(get_db),
    user: User         = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    pf = await db.get(ProjectFile, file_guid)
    if not pf or pf.project_guid != project_guid:
        raise HTTPException(404, "Файл не найден")
    if os.path.exists(pf.filepath):
        os.remove(pf.filepath)
    await db.delete(pf)
    await db.commit()
PYEOF
log "app/routers/files.py"

# ═══════════════════════════════════════════════════════════════════════
#  app/main.py
# ═══════════════════════════════════════════════════════════════════════
cat > app/main.py << 'PYEOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, users, projects, files
from app.routers.sections import section_routers

app = FastAPI(
    title="TZ Management System API",
    version="1.0.0",
    description="Система управления техническими заданиями",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # в проде — укажи конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Основные роутеры
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(projects.router)
app.include_router(files.router)

# 17 роутеров разделов ТЗ
for r in section_routers:
    app.include_router(r)


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok"}
PYEOF
log "app/main.py"

# ═══════════════════════════════════════════════════════════════════════
#  alembic.ini
# ═══════════════════════════════════════════════════════════════════════
cat > alembic.ini << 'PYEOF'
[alembic]
script_location = migrations
prepend_sys_path = .
version_path_separator = os
sqlalchemy.url = postgresql+asyncpg://tzuser:tzpass@localhost:5432/tz_db

[post_write_hooks]

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
PYEOF
log "alembic.ini"

# ═══════════════════════════════════════════════════════════════════════
#  migrations/env.py  (async Alembic)
# ═══════════════════════════════════════════════════════════════════════
cat > migrations/env.py << 'PYEOF'
import asyncio
import os
import sys
from logging.config import fileConfig

from sqlalchemy.ext.asyncio import async_engine_from_config
from sqlalchemy import pool
from alembic import context

# добавляем корень проекта в путь
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.config import settings
from app.database import Base
import app.models  # noqa — регистрирует все модели

config = context.config
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
PYEOF

cat > migrations/script.py.mako << 'PYEOF'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

revision: str = ${repr(up_revision)}
down_revision: Union[str, None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
PYEOF
log "migrations/env.py + script.py.mako"

# ═══════════════════════════════════════════════════════════════════════
#  Dockerfile
# ═══════════════════════════════════════════════════════════════════════
cat > Dockerfile << 'PYEOF'
FROM python:3.11-slim

WORKDIR /app

# Системные зависимости для asyncpg / reportlab
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p uploads

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
PYEOF
log "Dockerfile"

# ═══════════════════════════════════════════════════════════════════════
#  docker-compose.yml
# ═══════════════════════════════════════════════════════════════════════
cat > docker-compose.yml << 'PYEOF'
version: "3.9"

services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER:     tzuser
      POSTGRES_PASSWORD: tzpass
      POSTGRES_DB:       tz_db
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "tzuser", "-d", "tz_db"]
      interval: 5s
      timeout: 5s
      retries: 10

  backend:
    build: .
    restart: unless-stopped
    env_file: .env
    environment:
      DATABASE_URL: postgresql+asyncpg://tzuser:tzpass@db:5432/tz_db
    volumes:
      - ./uploads:/app/uploads
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
    command: >
      sh -c "alembic upgrade head &&
             uvicorn app.main:app --host 0.0.0.0 --port 8000"

volumes:
  pgdata:
PYEOF
log "docker-compose.yml"

# ═══════════════════════════════════════════════════════════════════════
#  .gitlab-ci.yml
# ═══════════════════════════════════════════════════════════════════════
cat > .gitlab-ci.yml << 'PYEOF'
stages:
  - lint
  - test
  - build
  - deploy

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"
  DOCKER_IMAGE: "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"

cache:
  paths:
    - .cache/pip
    - venv/

# ── Lint ─────────────────────────────────────────────────────────────
ruff:
  stage: lint
  image: python:3.11-slim
  script:
    - pip install ruff
    - ruff check app/

# ── Tests ────────────────────────────────────────────────────────────
pytest:
  stage: test
  image: python:3.11-slim
  services:
    - postgres:16-alpine
  variables:
    POSTGRES_USER:     tzuser
    POSTGRES_PASSWORD: tzpass
    POSTGRES_DB:       tz_db
    DATABASE_URL: postgresql+asyncpg://tzuser:tzpass@postgres/tz_db
    SECRET_KEY: ci_test_secret_key_at_least_32_chars_ok
  script:
    - apt-get update && apt-get install -y libpq-dev gcc
    - pip install -r requirements.txt
    - alembic upgrade head
    - pytest -v

# ── Build Docker image ───────────────────────────────────────────────
docker-build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    - docker build -t "$DOCKER_IMAGE" .
    - docker push "$DOCKER_IMAGE"
  only:
    - main
    - develop

# ── Deploy (пример через SSH) ────────────────────────────────────────
deploy-prod:
  stage: deploy
  image: alpine:3.19
  before_script:
    - apk add --no-cache openssh-client
    - eval $(ssh-agent -s)
    - echo "$DEPLOY_SSH_KEY" | tr -d '\r' | ssh-add -
  script:
    - ssh -o StrictHostKeyChecking=no "$DEPLOY_USER@$DEPLOY_HOST"
        "cd /opt/tz_backend &&
         docker pull $DOCKER_IMAGE &&
         docker-compose down &&
         IMAGE=$DOCKER_IMAGE docker-compose up -d"
  environment:
    name: production
  only:
    - main
  when: manual
PYEOF
log ".gitlab-ci.yml"

# ═══════════════════════════════════════════════════════════════════════
#  Makefile
# ═══════════════════════════════════════════════════════════════════════
# Важно: Makefile требует TAB-отступы, поэтому создаём через Python
python3 -c "
content = '''
.PHONY: install run migrate-create migrate-run migrate-down \
        docker docker-stop test lint dump

install:
\tpython3 -m venv venv && . venv/bin/activate && pip install -r requirements.txt

run:
\t. venv/bin/activate && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

migrate-create:
\t. venv/bin/activate && alembic revision --autogenerate -m \"\$(MSG)\"

migrate-run:
\t. venv/bin/activate && alembic upgrade head

migrate-down:
\t. venv/bin/activate && alembic downgrade -1

docker:
\tdocker-compose up -d --build

docker-stop:
\tdocker-compose down

test:
\t. venv/bin/activate && pytest -v

lint:
\t. venv/bin/activate && ruff check app/

dump:
\tdocker exec tz_backend_db_1 pg_dump -U tzuser tz_db > dump_\$(date +%Y%m%d_%H%M%S).sql
'''
with open('Makefile', 'w') as f:
    f.write(content.lstrip())
"
log "Makefile"

# ═══════════════════════════════════════════════════════════════════════
#  Базовый тест  tests/test_auth.py
# ═══════════════════════════════════════════════════════════════════════
mkdir -p tests
touch tests/__init__.py

cat > tests/conftest.py << 'PYEOF'
import asyncio
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from app.main import app
from app.database import Base
from app.dependencies import get_db
import os

TEST_DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://tzuser:tzpass@localhost:5432/tz_db_test"
)

test_engine = create_async_engine(TEST_DB_URL, echo=False)
TestSession  = async_sessionmaker(test_engine, expire_on_commit=False)


@pytest_asyncio.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def setup_db():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session(setup_db):
    async with TestSession() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def client(db_session):
    async def override_get_db():
        yield db_session
    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
PYEOF

cat > tests/test_auth.py << 'PYEOF'
import pytest

REGISTER_DATA = {"email": "test@example.com", "username": "testuser", "password": "secret123"}


@pytest.mark.asyncio
async def test_register(client):
    resp = await client.post("/api/users/register", json=REGISTER_DATA)
    assert resp.status_code == 201
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data


@pytest.mark.asyncio
async def test_login(client):
    await client.post("/api/users/register", json=REGISTER_DATA)
    resp = await client.post("/api/users/login",
                             json={"email": REGISTER_DATA["email"],
                                   "password": REGISTER_DATA["password"]})
    assert resp.status_code == 200
    assert "access_token" in resp.json()


@pytest.mark.asyncio
async def test_login_wrong_password(client):
    await client.post("/api/users/register", json=REGISTER_DATA)
    resp = await client.post("/api/users/login",
                             json={"email": REGISTER_DATA["email"], "password": "wrong"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_me(client):
    r = await client.post("/api/users/register", json=REGISTER_DATA)
    token = r.json()["access_token"]
    resp = await client.get("/api/users/me",
                            headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == REGISTER_DATA["email"]
PYEOF

cat > tests/test_projects.py << 'PYEOF'
import pytest

REG = {"email": "proj@example.com", "username": "projuser", "password": "secret123"}


async def _auth(client):
    r = await client.post("/api/users/register", json=REG)
    if r.status_code not in (200, 201):
        r = await client.post("/api/users/login",
                              json={"email": REG["email"], "password": REG["password"]})
    return r.json()["access_token"]


@pytest.mark.asyncio
async def test_create_project(client):
    token = await _auth(client)
    resp = await client.post(
        "/api/projects",
        json={"name": "Test Project", "description": "Desc"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    assert resp.json()["name"] == "Test Project"


@pytest.mark.asyncio
async def test_list_projects(client):
    token = await _auth(client)
    await client.post("/api/projects",
                      json={"name": "P1"},
                      headers={"Authorization": f"Bearer {token}"})
    resp = await client.get("/api/projects",
                            headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert len(resp.json()) >= 1
PYEOF
log "tests/"

# ═══════════════════════════════════════════════════════════════════════
#  pytest.ini
# ═══════════════════════════════════════════════════════════════════════
cat > pytest.ini << 'PYEOF'
[pytest]
asyncio_mode = auto
testpaths = tests
PYEOF

# ═══════════════════════════════════════════════════════════════════════
#  .gitignore
# ═══════════════════════════════════════════════════════════════════════
cat > .gitignore << 'PYEOF'
__pycache__/
*.pyc
*.pyo
venv/
.env
uploads/
*.egg-info/
dist/
.pytest_cache/
.ruff_cache/
*.sql
PYEOF

# ═══════════════════════════════════════════════════════════════════════
#  УСТАНОВКА зависимостей
# ═══════════════════════════════════════════════════════════════════════
info "Создаём виртуальное окружение и устанавливаем зависимости..."
python3 -m venv venv
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
log "Зависимости установлены"

# ═══════════════════════════════════════════════════════════════════════
#  Итоговые инструкции
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Проект создан! Следующие шаги:                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║  1) Запусти PostgreSQL (или Docker):                     ║${NC}"
echo -e "${BLUE}║     make docker                                           ║${NC}"
echo -e "${GREEN}║     — или вручную:                                       ║${NC}"
echo -e "${BLUE}║     docker-compose up -d db                              ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║  2) Отредактируй .env (DATABASE_URL, SECRET_KEY)        ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║  3) Создай и примени миграцию:                          ║${NC}"
echo -e "${BLUE}║     make migrate-create MSG=\"initial\"                    ║${NC}"
echo -e "${BLUE}║     make migrate-run                                      ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║  4) Запусти сервер:                                      ║${NC}"
echo -e "${BLUE}║     make run                                              ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║  5) Swagger UI: http://localhost:8000/docs               ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║  6) Тесты:  make test                                   ║${NC}"
echo -e "${GREEN}║  7) Дамп БД: make dump                                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
warn "Не забудь изменить SECRET_KEY в .env перед деплоем!"