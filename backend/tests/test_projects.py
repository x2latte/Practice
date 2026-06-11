import pytest

REG = {"email": "proj@example.com", "username": "projuser", "password": "secret123"}


async def _auth(client):
    r = await client.post("/api/users/register", json=REG)
    if r.status_code not in (200, 201):
        r = await client.post("/api/users/login",
                              json={"email": REG["email"], "password": REG["password"]})
    return r.json()["access_token"]


@pytest.mark.asyncio
async def test_create_project(client):
    token = await _auth(client)
    resp = await client.post(
        "/api/projects",
        json={"name": "Test Project", "description": "Desc"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    assert resp.json()["name"] == "Test Project"


@pytest.mark.asyncio
async def test_list_projects(client):
    token = await _auth(client)
    await client.post("/api/projects",
                      json={"name": "P1"},
                      headers={"Authorization": f"Bearer {token}"})
    resp = await client.get("/api/projects",
                            headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert len(resp.json()) >= 1
