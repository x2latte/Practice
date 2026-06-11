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
