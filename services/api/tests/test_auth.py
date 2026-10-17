"""Tests for authentication and user onboarding."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_send_and_verify_otp(client: AsyncClient):
    # 1. Send OTP
    phone = "+919876543210"
    res = await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": "artisan"})
    assert res.status_code == 200
    data = res.json()
    assert data["message"] == "OTP sent successfully"
    assert "mock_code" in data
    code = data["mock_code"]

    # 2. Verify OTP
    verify_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": code, "name": "Rameshwar Chitrakar", "language": "hi"},
    )
    assert verify_res.status_code == 200
    verify_data = verify_res.json()
    assert "access_token" in verify_data
    assert verify_data["is_artisan"] is True
    assert verify_data["name"] == "Rameshwar Chitrakar"
    token = verify_data["access_token"]

    # 3. Access protected /auth/me
    headers = {"Authorization": f"Bearer {token}"}
    me_res = await client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert me_data["phone"] == phone
    assert me_data["role"] == "artisan"


@pytest.mark.asyncio
async def test_otp_send_rate_limiting(client: AsyncClient):
    """Test that requesting OTP more than 5 times in 10 minutes returns 429."""
    phone = "+919811111111"
    # First 5 should succeed
    for _ in range(5):
        res = await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": "artisan"})
        assert res.status_code == 200

    # 6th should be rejected with 429 Too Many Requests
    res6 = await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": "artisan"})
    assert res6.status_code == 429
    assert "Too many OTP requests" in res6.json()["detail"]


@pytest.mark.asyncio
async def test_otp_verify_lockout(client: AsyncClient):
    """Test that 5 consecutive failed verification attempts locks out the user."""
    phone = "+919822222222"
    # Send initial OTP
    await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": "buyer"})

    # Submit 5 incorrect codes
    for _ in range(5):
        res = await client.post(
            "/api/v1/auth/otp/verify",
            json={"phone": phone, "code": "000000", "name": "Test User"},
        )
        assert res.status_code == 400

    # 6th attempt should be locked out with 429
    res6 = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": "123456", "name": "Test User"},
    )
    assert res6.status_code == 429
    assert "Too many failed verification attempts" in res6.json()["detail"]

