import pytest
import os

REG_FILES = {"email": "fileuser@example.com", "username": "fileuser", "password": "password123"}


async def _auth(client):
    r = await client.post("/api/users/register", json=REG_FILES)
    if r.status_code not in (200, 201):
        r = await client.post("/api/users/login",
                              json={"email": REG_FILES["email"], "password": REG_FILES["password"]})
    return r.json()["access_token"]


@pytest.mark.asyncio
async def test_file_upload_download_delete(client):
    token = await _auth(client)
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create a project
    resp_proj = await client.post("/api/projects", json={"name": "File Sandbox Project", "description": "Desc"}, headers=headers)
    assert resp_proj.status_code == 201
    proj_guid = resp_proj.json()["guid"]

    # 2. Upload file
    file_payload = {"file": ("requirements.txt", b"Database should run on Postgres", "text/plain")}
    resp_upload = await client.post(
        f"/api/projects/{proj_guid}/files?section_type=requirements",
        files=file_payload,
        headers=headers
    )
    assert resp_upload.status_code == 201
    file_data = resp_upload.json()
    assert file_data["filename"] == "requirements.txt"
    file_guid = file_data["guid"]

    # 3. List uploaded files
    resp_list = await client.get(
        f"/api/projects/{proj_guid}/files",
        headers=headers
    )
    assert resp_list.status_code == 200
    assert len(resp_list.json()) >= 1
    assert resp_list.json()[0]["guid"] == file_guid

    # List uploaded files filtering by section_type
    resp_list_filtered = await client.get(
        f"/api/projects/{proj_guid}/files?section_type=requirements",
        headers=headers
    )
    assert resp_list_filtered.status_code == 200
    assert len(resp_list_filtered.json()) >= 1

    # 4. Download file
    resp_dl = await client.get(
        f"/api/projects/{proj_guid}/files/{file_guid}/download",
        headers=headers
    )
    assert resp_dl.status_code == 200
    assert resp_dl.content == b"Database should run on Postgres"

    # Try downloading non-existent file
    resp_dl_fake = await client.get(
        f"/api/projects/{proj_guid}/files/00000000-0000-0000-0000-000000000000/download",
        headers=headers
    )
    assert resp_dl_fake.status_code == 404

    # 5. Delete file
    resp_del = await client.delete(
        f"/api/projects/{proj_guid}/files/{file_guid}",
        headers=headers
    )
    assert resp_del.status_code == 204

    # Try downloading deleted file
    resp_dl_deleted = await client.get(
        f"/api/projects/{proj_guid}/files/{file_guid}/download",
        headers=headers
    )
    assert resp_dl_deleted.status_code == 404
