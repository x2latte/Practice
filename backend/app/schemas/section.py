"""
Универсальные схемы для всех разделов ТЗ.
Каждый специфичный раздел наследует SectionBase.
"""
from pydantic import BaseModel, ConfigDict, computed_field
from datetime import datetime
from typing import Optional, Any, Dict


class SectionBase(BaseModel):
    title:   Optional[str] = None
    content: Optional[str] = None
    order:   int = 0


class SectionCreate(SectionBase):
    model_config = ConfigDict(extra='allow')
    extra: Optional[Dict[str, Any]] = None   # доп. поля для специфичных разделов


class SectionUpdate(BaseModel):
    model_config = ConfigDict(extra='allow')
    title:   Optional[str] = None
    content: Optional[str] = None
    order:   Optional[int] = None
    extra:   Optional[Dict[str, Any]] = None


class SectionResponse(SectionBase):
    model_config = ConfigDict(from_attributes=True, extra='allow')

    guid:         str
    project_guid: str
    created_by:   Optional[str]
    created_at:   datetime
    updated_at:   Optional[datetime]

    @computed_field
    def id(self) -> str:
        return self.guid

    @computed_field
    def description(self) -> Optional[str]:
        return self.content

    @computed_field
    def type(self) -> Optional[str]:
        # Возвращаем constraint_type или category, если они есть, иначе title
        if hasattr(self, 'constraint_type') and getattr(self, 'constraint_type'):
            return str(getattr(self, 'constraint_type'))
        if hasattr(self, 'category') and getattr(self, 'category'):
            return str(getattr(self, 'category'))
        return self.title


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
