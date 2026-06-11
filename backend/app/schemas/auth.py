from pydantic import BaseModel, EmailStr, field_validator, model_validator
from typing import Any


class RegisterRequest(BaseModel):
    email:    EmailStr
    username: str
    password: str

    @model_validator(mode="before")
    @classmethod
    def map_login_to_username(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "username" not in data and "login" in data:
                data["username"] = data["login"]
        return data

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
    email:    str
    password: str


class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str
