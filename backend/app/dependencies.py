from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.user import User, UserRole
from app.services.auth import decode_token

bearer_scheme = HTTPBearer()


async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    token = credentials.credentials
    payload = decode_token(token)

    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Токен недействителен или истёк")

    user_guid = payload.get("sub")
    result = await db.execute(select(User).where(User.guid == user_guid))
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Пользователь не найден или заблокирован")
    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail="Требуются права администратора")
    return user


async def get_project_or_404(
    project_guid: str,
    db: AsyncSession,
    user: User,
):
    from app.models.project import Project, ProjectUser
    result = await db.execute(select(Project).where(Project.guid == project_guid))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Проект не найден")

    # owner или участник или admin
    if project.owner_guid != user.guid and user.role != UserRole.admin:
        member = await db.execute(
            select(ProjectUser).where(
                ProjectUser.project_guid == project_guid,
                ProjectUser.user_guid    == user.guid,
            )
        )
        if not member.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="Нет доступа к проекту")
    return project
