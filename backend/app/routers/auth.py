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
