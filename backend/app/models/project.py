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
