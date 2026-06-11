from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from app.dependencies import get_db, get_current_user, get_project_or_404
from app.models.user import User, UserRole
from app.models.project import Project, ProjectUser, ProjectUserRole
from app.schemas.project import (
    ProjectCreate, ProjectUpdate, ProjectResponse,
    ProjectMemberAdd, ProjectMemberUpdate, ProjectMemberResponse,
)
from app.schemas.section import ProjectStats
from app.services.stats import calculate_stats
from app.services.pdf import generate_pdf

router = APIRouter(prefix="/api/projects", tags=["projects"])


@router.get("", response_model=List[ProjectResponse])
async def list_projects(
    skip:       int = Query(0,   ge=0),
    limit:      int = Query(50,  ge=1, le=200),
    status:     Optional[str] = None,
    search:     Optional[str] = None,
    sort_by:    str = Query("created_at", enum=["created_at", "name", "status"]),
    sort_order: str = Query("desc", enum=["asc", "desc"]),
    db:    AsyncSession = Depends(get_db),
    user:  User = Depends(get_current_user),
):
    q = select(Project)
    if user.role != UserRole.admin:
        # владелец или участник
        member_subs = select(ProjectUser.project_guid).where(
            ProjectUser.user_guid == user.guid
        ).scalar_subquery()
        q = q.where(or_(Project.owner_guid == user.guid,
                        Project.guid.in_(member_subs)))
    if status:
        q = q.where(Project.status == status)
    if search:
        q = q.where(or_(
            Project.name.ilike(f"%{search}%"),
            Project.description.ilike(f"%{search}%"),
        ))
    col = getattr(Project, sort_by, Project.created_at)
    q   = q.order_by(col.desc() if sort_order == "desc" else col.asc())
    q   = q.offset(skip).limit(limit)
    result = await db.execute(q)
    return result.scalars().all()


@router.post("", response_model=ProjectResponse, status_code=201)
async def create_project(
    body: ProjectCreate,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    project = Project(**body.model_dump(), owner_guid=user.guid)
    db.add(project)
    await db.flush()
    # владелец тоже добавляется как участник
    db.add(ProjectUser(project_guid=project.guid, user_guid=user.guid,
                       role=ProjectUserRole.owner))
    await db.commit()
    await db.refresh(project)
    return project


@router.get("/{project_guid}", response_model=ProjectResponse)
async def get_project(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await get_project_or_404(project_guid, db, user)


@router.put("/{project_guid}", response_model=ProjectResponse)
async def update_project(
    project_guid: str,
    body: ProjectUpdate,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, user)
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(project, k, v)
    await db.commit()
    await db.refresh(project)
    return project


@router.delete("/{project_guid}", status_code=204)
async def delete_project(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, user)
    if project.owner_guid != user.guid and user.role != UserRole.admin:
        raise HTTPException(403, "Только владелец может удалить проект")
    await db.delete(project)
    await db.commit()


# ── Участники ────────────────────────────────────────────────────────

@router.get("/{project_guid}/users", response_model=List[ProjectMemberResponse])
async def list_members(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    result = await db.execute(
        select(ProjectUser).where(ProjectUser.project_guid == project_guid)
    )
    return result.scalars().all()


@router.post("/{project_guid}/users", response_model=ProjectMemberResponse, status_code=201)
async def add_member(
    project_guid: str,
    body: ProjectMemberAdd,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, user)
    if project.owner_guid != user.guid and user.role != UserRole.admin:
        raise HTTPException(403, "Только владелец добавляет участников")
    new_member = ProjectUser(
        project_guid=project_guid,
        user_guid=body.user_guid,
        role=body.role,
    )
    db.add(new_member)
    await db.commit()
    await db.refresh(new_member)
    return new_member


@router.put("/{project_guid}/users/{user_guid}", response_model=ProjectMemberResponse)
async def update_member(
    project_guid: str,
    user_guid:    str,
    body: ProjectMemberUpdate,
    db:   AsyncSession = Depends(get_db),
    cur_user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, cur_user)
    if project.owner_guid != cur_user.guid and cur_user.role != UserRole.admin:
        raise HTTPException(403, "Недостаточно прав")
    result = await db.execute(
        select(ProjectUser).where(
            ProjectUser.project_guid == project_guid,
            ProjectUser.user_guid    == user_guid,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(404, "Участник не найден")
    member.role = body.role
    await db.commit()
    await db.refresh(member)
    return member


@router.delete("/{project_guid}/users/{user_guid}", status_code=204)
async def remove_member(
    project_guid: str,
    user_guid:    str,
    db:   AsyncSession = Depends(get_db),
    cur_user: User = Depends(get_current_user),
):
    project = await get_project_or_404(project_guid, db, cur_user)
    if project.owner_guid != cur_user.guid and cur_user.role != UserRole.admin:
        raise HTTPException(403, "Недостаточно прав")
    result = await db.execute(
        select(ProjectUser).where(
            ProjectUser.project_guid == project_guid,
            ProjectUser.user_guid    == user_guid,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(404, "Участник не найден")
    await db.delete(member)
    await db.commit()


# ── Статистика / PDF ─────────────────────────────────────────────────

@router.get("/{project_guid}/stats", response_model=ProjectStats)
async def project_stats(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    return await calculate_stats(project_guid, db)


@router.get("/{project_guid}/export/pdf")
async def export_pdf(
    project_guid: str,
    db:   AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    pdf_bytes = await generate_pdf(project_guid, db)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="tz_{project_guid}.pdf"'},
    )
