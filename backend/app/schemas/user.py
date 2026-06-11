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
