import pytest

REGISTER_DATA = {"email": "test@example.com", "username": "testuser", "password": "secret123"}


@pytest.mark.asyncio
async def test_register(client):
    resp = await client.post("/api/users/register", json=REGISTER_DATA)
    assert resp.status_code == 201
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data


@pytest.mark.asyncio
async def test_login(client):
    await client.post("/api/users/register", json=REGISTER_DATA)
    resp = await client.post("/api/users/login",
                             json={"email": REGISTER_DATA["email"],
                                   "password": REGISTER_DATA["password"]})
    assert resp.status_code == 200
    assert "access_token" in resp.json()


@pytest.mark.asyncio
async def test_login_wrong_password(client):
    await client.post("/api/users/register", json=REGISTER_DATA)
    resp = await client.post("/api/users/login",
                             json={"email": REGISTER_DATA["email"], "password": "wrong"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_me(client):
    r = await client.post("/api/users/register", json=REGISTER_DATA)
    token = r.json()["access_token"]
    resp = await client.get("/api/users/me",
                            headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == REGISTER_DATA["email"]
