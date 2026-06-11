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
