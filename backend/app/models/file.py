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
