"""
Фабрика CRUD-роутеров для всех разделов ТЗ.
Один вызов make_section_router() → полноценный роутер с
GET (list), POST, GET /{item_guid}, PUT /{item_guid}, DELETE /{item_guid}.
"""
from typing import List, Optional, Type
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from app.dependencies import get_db, get_current_user, get_project_or_404
from app.models.user import User
from app.schemas.section import SectionCreate, SectionUpdate, SectionResponse


def make_section_router(model: Type, url_prefix: str, tag: str) -> APIRouter:
    router = APIRouter(
        prefix=f"/api/projects/{{project_guid}}/{url_prefix}",
        tags=[tag],
    )

    @router.get("", response_model=List[SectionResponse])
    async def list_items(
        project_guid: str,
        skip:         int = Query(0, ge=0),
        limit:        int = Query(100, ge=1, le=500),
        search:       Optional[str] = None,
        sort_by:      str = Query("order", enum=["order", "created_at", "title"]),
        sort_order:   str = Query("asc", enum=["asc", "desc"]),
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        q = select(model).where(model.project_guid == project_guid)
        if search and hasattr(model, "title") and hasattr(model, "content"):
            q = q.where(or_(
                model.title.ilike(f"%{search}%"),
                model.content.ilike(f"%{search}%"),
            ))
        col = getattr(model, sort_by, model.order)
        q   = q.order_by(col.desc() if sort_order == "desc" else col.asc())
        q   = q.offset(skip).limit(limit)
        result = await db.execute(q)
        return result.scalars().all()

    @router.post("", response_model=SectionResponse, status_code=201)
    async def create_item(
        project_guid: str,
        body:  SectionCreate,
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        data = body.model_dump(exclude={"extra"})
        # применяем extra-поля если переданы
        extra = body.extra or {}
        item = model(project_guid=project_guid, created_by=user.guid, **data, **extra)
        db.add(item)
        await db.commit()
        await db.refresh(item)
        return item

    @router.get("/{item_guid}", response_model=SectionResponse)
    async def get_item(
        project_guid: str,
        item_guid:    str,
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        item = await db.get(model, item_guid)
        if not item or item.project_guid != project_guid:
            raise HTTPException(404, "Запись не найдена")
        return item

    @router.put("/{item_guid}", response_model=SectionResponse)
    async def update_item(
        project_guid: str,
        item_guid:    str,
        body:  SectionUpdate,
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        item = await db.get(model, item_guid)
        if not item or item.project_guid != project_guid:
            raise HTTPException(404, "Запись не найдена")
        for k, v in body.model_dump(exclude_none=True, exclude={"extra"}).items():
            if hasattr(item, k):
                setattr(item, k, v)
        for k, v in (body.extra or {}).items():
            if hasattr(item, k):
                setattr(item, k, v)
        await db.commit()
        await db.refresh(item)
        return item

    @router.delete("/{item_guid}", status_code=204)
    async def delete_item(
        project_guid: str,
        item_guid:    str,
        db:   AsyncSession = Depends(get_db),
        user: User         = Depends(get_current_user),
    ):
        await get_project_or_404(project_guid, db, user)
        item = await db.get(model, item_guid)
        if not item or item.project_guid != project_guid:
            raise HTTPException(404, "Запись не найдена")
        await db.delete(item)
        await db.commit()

    return router


# ── Регистрируем все 17 разделов ─────────────────────────────────────
from app.models.section import (
    Requirement, Annotation, BusinessGoal, Analog, UserClass,
    UserStory, GlossaryTerm, UseCase, Architecture, DataFlow,
    DataDictionaryEntry, NonFunctionalRequirement, Constraint,
    SystemRequirement, DraftTZ, FinalTZ, ChangeRecord,
)

section_routers: List[APIRouter] = [
    make_section_router(Requirement,               "requirements",               "requirements"),
    make_section_router(Annotation,                "annotation",                 "annotation"),
    make_section_router(BusinessGoal,              "business-goals",             "business-goals"),
    make_section_router(Analog,                    "analogs",                    "analogs"),
    make_section_router(UserClass,                 "user-classes",               "user-classes"),
    make_section_router(UserStory,                 "user-stories",               "user-stories"),
    make_section_router(GlossaryTerm,              "glossary-terms",             "glossary-terms"),
    make_section_router(UseCase,                   "use-cases",                  "use-cases"),
    make_section_router(Architecture,              "architecture",               "architecture"),
    make_section_router(DataFlow,                  "data-flows",                 "data-flows"),
    make_section_router(DataDictionaryEntry,       "data-dictionary",            "data-dictionary"),
    make_section_router(NonFunctionalRequirement,  "non-functional-requirements","non-functional-requirements"),
    make_section_router(Constraint,                "constraints",                "constraints"),
    make_section_router(SystemRequirement,         "system-requirements",        "system-requirements"),
    make_section_router(DraftTZ,                   "draft-tz",                   "draft-tz"),
    make_section_router(FinalTZ,                   "final-tz",                   "final-tz"),
    make_section_router(ChangeRecord,              "changes",                    "changes"),
]
