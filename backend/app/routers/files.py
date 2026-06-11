import os
import uuid
import aiofiles
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from fastapi.responses import FileResponse as FastAPIFileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.dependencies import get_db, get_current_user, get_project_or_404
from app.models.user import User
from app.models.file import ProjectFile
from app.schemas.file import FileResponse
from app.config import settings

router = APIRouter(prefix="/api/projects/{project_guid}/files", tags=["files"])
MAX_BYTES = settings.MAX_FILE_SIZE_MB * 1024 * 1024


@router.post("", response_model=FileResponse, status_code=201)
async def upload_file(
    project_guid: str,
    section_type: Optional[str] = Query(None),
    section_guid: Optional[str] = Query(None),
    file: UploadFile = File(...),
    db:   AsyncSession = Depends(get_db),
    user: User         = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)

    content = await file.read()
    if len(content) > MAX_BYTES:
        raise HTTPException(413, f"Файл превышает {settings.MAX_FILE_SIZE_MB} МБ")

    upload_dir = os.path.join(settings.UPLOAD_DIR, project_guid)
    os.makedirs(upload_dir, exist_ok=True)

    file_guid = str(uuid.uuid4())
    ext       = os.path.splitext(file.filename or "")[1]
    disk_name = f"{file_guid}{ext}"
    filepath  = os.path.join(upload_dir, disk_name)

    async with aiofiles.open(filepath, "wb") as f:
        await f.write(content)

    pf = ProjectFile(
        guid=file_guid,
        project_guid=project_guid,
        section_type=section_type,
        section_guid=section_guid,
        filename=file.filename or disk_name,
        filepath=filepath,
        size_bytes=len(content),
        mime_type=file.content_type,
        uploaded_by=user.guid,
    )
    db.add(pf)
    await db.commit()
    await db.refresh(pf)
    return pf


@router.get("", response_model=List[FileResponse])
async def list_files(
    project_guid: str,
    section_type: Optional[str] = Query(None),
    db:   AsyncSession = Depends(get_db),
    user: User         = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    q = select(ProjectFile).where(ProjectFile.project_guid == project_guid)
    if section_type:
        q = q.where(ProjectFile.section_type == section_type)
    result = await db.execute(q.order_by(ProjectFile.created_at.desc()))
    return result.scalars().all()


@router.get("/{file_guid}/download")
async def download_file(
    project_guid: str,
    file_guid:    str,
    db:   AsyncSession = Depends(get_db),
    user: User         = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    pf = await db.get(ProjectFile, file_guid)
    if not pf or pf.project_guid != project_guid:
        raise HTTPException(404, "Файл не найден")
    if not os.path.exists(pf.filepath):
        raise HTTPException(410, "Файл был удалён с диска")
    return FastAPIFileResponse(
        path=pf.filepath,
        filename=pf.filename,
        media_type=pf.mime_type or "application/octet-stream",
    )


@router.delete("/{file_guid}", status_code=204)
async def delete_file(
    project_guid: str,
    file_guid:    str,
    db:   AsyncSession = Depends(get_db),
    user: User         = Depends(get_current_user),
):
    await get_project_or_404(project_guid, db, user)
    pf = await db.get(ProjectFile, file_guid)
    if not pf or pf.project_guid != project_guid:
        raise HTTPException(404, "Файл не найден")
    if os.path.exists(pf.filepath):
        os.remove(pf.filepath)
    await db.delete(pf)
    await db.commit()
