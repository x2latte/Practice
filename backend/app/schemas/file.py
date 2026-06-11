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
