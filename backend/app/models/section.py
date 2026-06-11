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
