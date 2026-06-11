from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.dependencies import get_db, get_current_user, require_admin
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    return user


@router.get("/all", response_model=List[UserResponse])
async def list_all_users(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    result = await db.execute(select(User))
    return result.scalars().all()


@router.put("/{user_guid}", response_model=UserResponse)
async def update_user(
    user_guid: str,
    body: UserUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    user = await db.get(User, user_guid)
    if not user:
        raise HTTPException(404, "Пользователь не найден")
    if body.is_active is not None:
        user.is_active = body.is_active
    if body.role is not None:
        user.role = body.role
    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/{user_guid}", status_code=204)
async def delete_user(
    user_guid: str,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    if user_guid == admin.guid:
        raise HTTPException(400, "Нельзя удалить самого себя")
    user = await db.get(User, user_guid)
    if not user:
        raise HTTPException(404, "Пользователь не найден")
    await db.delete(user)
    await db.commit()
