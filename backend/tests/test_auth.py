import pytest
from app.models.user import User, UserRole
from sqlalchemy import select

REGISTER_DATA = {"email": "test@example.com", "username": "testuser", "password": "secret123"}


@pytest.mark.asyncio
async def test_register(client):
    resp = await client.post("/api/users/register", json=REGISTER_DATA)
    assert resp.status_code == 201
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data

    # Test duplicate register
    resp2 = await client.post("/api/users/register", json=REGISTER_DATA)
    assert resp2.status_code == 400


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
async def test_blocked_login(client, db_session):
    # Register and then manually block in db_session
    r = await client.post("/api/users/register", json=REGISTER_DATA)
    assert r.status_code == 201

    # Fetch and deactivate user
    result = await db_session.execute(select(User).where(User.email == REGISTER_DATA["email"]))
    user = result.scalar_one()
    user.is_active = False
    await db_session.commit()

    resp = await client.post("/api/users/login",
                             json={"email": REGISTER_DATA["email"],
                                   "password": REGISTER_DATA["password"]})
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_logout(client):
    r = await client.post("/api/users/register", json=REGISTER_DATA)
    tokens = r.json()
    logout_resp = await client.post("/api/users/logout", json={"refresh_token": tokens["refresh_token"]})
    assert logout_resp.status_code == 204


@pytest.mark.asyncio
async def test_refresh(client):
    r = await client.post("/api/users/register", json=REGISTER_DATA)
    tokens = r.json()
    refresh_resp = await client.post("/api/users/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refresh_resp.status_code == 200
    assert "access_token" in refresh_resp.json()


@pytest.mark.asyncio
async def test_me(client):
    r = await client.post("/api/users/register", json=REGISTER_DATA)
    token = r.json()["access_token"]
    resp = await client.get("/api/users/me",
                            headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == REGISTER_DATA["email"]


@pytest.mark.asyncio
async def test_users_admin_endpoints(client, db_session):
    # 1. Register regular user
    r1 = await client.post("/api/users/register", json=REGISTER_DATA)
    u_token = r1.json()["access_token"]

    # 2. Register admin user
    admin_data = {"email": "admin@example.com", "username": "adminuser", "password": "adminpassword"}
    r2 = await client.post("/api/users/register", json=admin_data)
    a_token = r2.json()["access_token"]

    # Manually make adminuser an administrator in the DB
    res = await db_session.execute(select(User).where(User.username == "adminuser"))
    admin_user = res.scalar_one()
    admin_user.role = UserRole.admin
    await db_session.commit()

    # Regular user tries to list all users -> Forbidden/Unauthorized
    resp_list_fail = await client.get("/api/users/all", headers={"Authorization": f"Bearer {u_token}"})
    assert resp_list_fail.status_code == 403

    # Admin lists all users -> OK
    resp_list_ok = await client.get("/api/users/all", headers={"Authorization": f"Bearer {a_token}"})
    assert resp_list_ok.status_code == 200
    all_users = resp_list_ok.json()
    assert len(all_users) >= 2

    # Get regular user's guid
    res_reg = await db_session.execute(select(User).where(User.username == "testuser"))
    reg_user = res_reg.scalar_one()
    reg_guid = reg_user.guid

    # Regular user tries to update -> Forbidden
    resp_up_fail = await client.put(f"/api/users/{reg_guid}", json={"role": "admin"}, headers={"Authorization": f"Bearer {u_token}"})
    assert resp_up_fail.status_code == 403

    # Admin updates regular user to be inactive
    resp_up_ok = await client.put(f"/api/users/{reg_guid}", json={"is_active": False, "role": "admin"}, headers={"Authorization": f"Bearer {a_token}"})
    assert resp_up_ok.status_code == 200
    assert resp_up_ok.json()["is_active"] is False

    # Try updating non-existent user as admin
    resp_up_fake = await client.put("/api/users/00000000-0000-0000-0000-000000000000", json={"is_active": True}, headers={"Authorization": f"Bearer {a_token}"})
    assert resp_up_fake.status_code == 404

    # Admin tries to delete self -> Error
    resp_del_self = await client.delete(f"/api/users/{admin_user.guid}", headers={"Authorization": f"Bearer {a_token}"})
    assert resp_del_self.status_code == 400

    # Admin deletes regular user
    resp_del_user = await client.delete(f"/api/users/{reg_guid}", headers={"Authorization": f"Bearer {a_token}"})
    assert resp_del_user.status_code == 204

    # Deleted user doesn't exist anymore
    resp_del_fake = await client.delete(f"/api/users/{reg_guid}", headers={"Authorization": f"Bearer {a_token}"})
    assert resp_del_fake.status_code == 404
