from uuid import uuid7
import pytest
from datetime import datetime, timedelta, UTC
from httpx import AsyncClient

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import init_db
from app.core.config import settings
from app.auth.models import User, RefreshToken, EmailVerificationToken
import app.auth.security_utils as su


@pytest.fixture(scope="function", autouse=True)
async def prepare_database():
    # call your async DB init
    await init_db()
    yield


def valid_payload(**overrides):
    payload = {
        "username": "testuser",
        "email": "testuser@example.com",
        "password": "Valid*Pass123",
    }
    payload.update(overrides)
    return payload


async def create_verified_user(db_session: AsyncSession, **overrides) -> User:
    """Helper to create a verified, active user for login tests"""
    user_data = {
        "username": "testuser",
        "email": "test@example.com",
        "password": "Valid*Pass123",
    }
    user_data.update(overrides)

    user = User(
        email=user_data["email"],
        username=user_data["username"],
        hashed_password=su.hash_password(user_data["password"]),
        email_verified=True,
        is_active=True,
        password_changed_at=datetime.now(UTC),
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


class TestRegistrationSuccess:
    @pytest.mark.anyio
    async def test_register_success(self, client: AsyncClient):
        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(),
        )

        assert response.status_code == 200  # or 201

        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert data["expires_in"] == 60 * settings.ACCESS_TOKEN_EXPIRE_MINUTES

    @pytest.mark.anyio
    async def test_register_creates_verification_token(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(),
        )

        assert response.status_code == 200

        # Check verification token was created
        result = await db_session.execute(select(EmailVerificationToken))
        token = result.scalar_one_or_none()
        assert token is not None
        assert token.expires_at > datetime.now(UTC)

    @pytest.mark.anyio
    async def test_register_creates_refresh_token(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(),
        )

        assert response.status_code == 200

        # Check refresh token was stored
        result = await db_session.execute(select(RefreshToken))
        refresh = result.scalar_one_or_none()
        assert refresh is not None
        assert not refresh.revoked


class TestRegistrationDuplicates:
    @pytest.mark.anyio
    async def test_duplicate_username_not_allowed(self, client: AsyncClient):
        payload = valid_payload()

        await client.post(f"{settings.API_V1_STR}/auth/register", json=payload)

        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(email="other@example.com"),
        )

        assert response.status_code == 400

    @pytest.mark.anyio
    async def test_duplicate_email_not_allowed(self, client: AsyncClient):
        payload = valid_payload()

        await client.post(f"{settings.API_V1_STR}/auth/register", json=payload)

        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(username="otheruser"),
        )

        assert response.status_code == 400


class TestPasswordValidation:
    @pytest.mark.anyio
    @pytest.mark.parametrize(
        "password, error_type",
        [
            ("Ab1*", "string_too_short"),  # < 8 chars
            ("lowercase1*", "value_error"),  # no uppercase
            ("UPPERCASE1*", "value_error"),  # no lowercase
            ("NoNumber*", "value_error"),  # no number
            ("NoSpecial1", "value_error"),  # no special char
        ],
    )
    async def test_password_rules(
        self,
        client: AsyncClient,
        password: str,
        error_type: str,
    ):
        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(password=password),
        )

        assert response.status_code == 422

        data = response.json()
        assert data["detail"][0]["type"] == error_type


class TestUsernameValidation:
    @pytest.mark.anyio
    @pytest.mark.parametrize(
        "username",
        [
            "ab",  # too short
            "user name",  # space
            "user@",  # special char
            # "123",  # numeric only (if invalid)
        ],
    )
    async def test_invalid_username(self, client: AsyncClient, username: str):
        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(username=username),
        )

        assert response.status_code == 422


class TestEmailValidation:
    @pytest.mark.anyio
    @pytest.mark.parametrize(
        "email",
        [
            "not-an-email",
            "missing-at.com",
            "missing-domain@",
            "@missing-user.com",
        ],
    )
    async def test_invalid_email(self, client: AsyncClient, email: str):
        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(email=email),
        )

        assert response.status_code == 422


class TestLoginSuccess:
    @pytest.mark.anyio
    async def test_login_with_valid_credentials(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.anyio
    async def test_login_updates_last_login(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )
        assert user.last_login is None

        await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        await db_session.refresh(user)
        assert user.last_login is not None
        assert user.last_login <= datetime.now(UTC)

    @pytest.mark.anyio
    async def test_login_resets_failed_attempts(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )
        user.failed_login_attempts = 3
        await db_session.commit()

        await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        await db_session.refresh(user)
        assert user.failed_login_attempts == 0

    @pytest.mark.anyio
    async def test_login_with_email_as_username(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        """Test that email can be used in username field"""
        await create_verified_user(
            db_session, username="test@example.com", password="Valid*Pass123"
        )

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "test@example.com", "password": "Valid*Pass123"},
        )

        assert response.status_code == 200


class TestLoginFailures:
    @pytest.mark.anyio
    async def test_login_with_wrong_password(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "WrongPassword123*"},
        )

        assert response.status_code == 401
        assert "incorrect" in response.json()["detail"].lower()

    @pytest.mark.anyio
    async def test_login_with_nonexistent_user(self, client: AsyncClient):
        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "nonexistent", "password": "Valid*Pass123"},
        )

        assert response.status_code == 401
        assert "incorrect" in response.json()["detail"].lower()

    @pytest.mark.anyio
    async def test_login_increments_failed_attempts(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        _ = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "WrongPassword*123"},
        )

        await db_session.refresh(user)
        assert user.failed_login_attempts == 1

    @pytest.mark.anyio
    async def test_login_with_inactive_account(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )
        user.is_active = False
        await db_session.commit()

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        assert response.status_code == 403
        assert "inactive" in response.json()["detail"].lower()

    @pytest.mark.anyio
    async def test_login_with_unverified_email_first_time(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        """Unverified email should block login for users who never logged in"""
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )
        user.email_verified = False
        user.last_login = None
        await db_session.commit()

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        assert response.status_code == 403
        assert "email" in response.json()["detail"].lower()

    @pytest.mark.anyio
    async def test_login_with_unverified_email_returning_user(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        """Unverified email should NOT block returning users"""
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )
        user.email_verified = False
        user.last_login = datetime.now(UTC) - timedelta(days=1)
        await db_session.commit()

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        assert response.status_code == 200


class TestAccountLocking:
    @pytest.mark.anyio
    async def test_account_locks_after_max_attempts(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        _ = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        for _ in range(settings.MAX_FAILED_LOGIN_ATTEMPTS):
            _ = await client.post(
                f"{settings.API_V1_STR}/auth/login",
                data={"username": "loginuser", "password": "WrongPassword*123"},
            )

        result = await db_session.execute(
            select(User).filter(User.username == "loginuser")
        )
        user = result.scalar_one()
        assert user.locked_until is not None
        assert user.locked_until > datetime.now(UTC)

    @pytest.mark.anyio
    async def test_locked_account_cannot_login(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )
        user.locked_until = datetime.now(UTC) + timedelta(minutes=30)
        await db_session.commit()

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        assert response.status_code == 403
        assert "locked" in response.json()["detail"].lower()

    @pytest.mark.anyio
    async def test_expired_lock_allows_login(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )
        user.locked_until = datetime.now(UTC) - timedelta(minutes=1)
        await db_session.commit()

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        assert response.status_code == 200


class TestGetCurrentUser:
    @pytest.mark.anyio
    async def test_get_user_info_with_valid_token(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        _ = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        login_response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )
        token = login_response.json()["access_token"]

        response = await client.get(
            f"{settings.API_V1_STR}/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "loginuser"
        assert data["email_verified"] is True
        assert data["is_active"] is True

    @pytest.mark.anyio
    async def test_get_user_info_without_token(self, client: AsyncClient):
        response = await client.get(f"{settings.API_V1_STR}/auth/me")

        assert response.status_code == 401

    @pytest.mark.anyio
    async def test_get_user_info_with_invalid_token(self, client: AsyncClient):
        response = await client.get(
            f"{settings.API_V1_STR}/auth/me",
            headers={"Authorization": "Bearer invalid_token"},
        )

        assert response.status_code == 401

    @pytest.mark.anyio
    async def test_get_user_info_with_expired_token(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        # Create an expired token
        expired_token = su.create_access_token(
            data={"sub": str(user.id)}, expires_delta_override=timedelta(seconds=-1)
        )

        response = await client.get(
            f"{settings.API_V1_STR}/auth/me",
            headers={"Authorization": f"Bearer {expired_token}"},
        )

        assert response.status_code == 401
        assert "expired" in response.json()["detail"].lower()


class TestEmailVerification:
    @pytest.mark.anyio
    async def test_verify_email_with_valid_token(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        # Register user
        response = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(username="verifyuser"),
        )
        assert response.status_code == 200

        # Get verification token
        result = await db_session.execute(select(EmailVerificationToken))
        db_token = result.scalar_one()

        # Generate the actual token (not the hash)
        token = su.generate_high_entropy_token()
        db_token.token_hash = su.hash_token(token)
        await db_session.commit()

        # Verify email
        response = await client.get(
            f"{settings.API_V1_STR}/auth/verify-email",
            params={"token": token},
        )

        assert response.status_code == 302  # Redirect

        # Check user is verified
        result = await db_session.execute(
            select(User).filter(User.username == "verifyuser")
        )
        user = result.scalar_one()
        assert user.email_verified is True
        assert user.is_active is True

    @pytest.mark.anyio
    async def test_verify_email_with_invalid_token(self, client: AsyncClient):
        response = await client.get(
            f"{settings.API_V1_STR}/auth/verify-email",
            params={"token": "invalid_token"},
        )

        assert response.status_code == 302
        assert "failure" in response.headers["location"]

    @pytest.mark.anyio
    async def test_verify_email_with_expired_token(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        # Create expired token
        user = await create_verified_user(
            db_session, username="testuser", password="Valid*Pass123"
        )
        user.email_verified = False

        token = su.generate_high_entropy_token()
        db_token = EmailVerificationToken(
            user_id=user.id,
            token_hash=su.hash_token(token),
            expires_at=datetime.now(UTC) - timedelta(minutes=1),
        )
        db_session.add(db_token)
        await db_session.commit()

        response = await client.get(
            f"{settings.API_V1_STR}/auth/verify-email",
            params={"token": token},
        )

        assert response.status_code == 302
        assert "failure" in response.headers["location"]

    @pytest.mark.anyio
    async def test_verify_email_deletes_token_after_use(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        _ = await client.post(
            f"{settings.API_V1_STR}/auth/register",
            json=valid_payload(username="verifyuser"),
        )

        result = await db_session.execute(select(EmailVerificationToken))
        db_token = result.scalar_one()

        token = su.generate_high_entropy_token()
        db_token.token_hash = su.hash_token(token)
        await db_session.commit()

        _ = await client.get(
            f"{settings.API_V1_STR}/auth/verify-email",
            params={"token": token},
        )

        # Token should be deleted
        result = await db_session.execute(select(EmailVerificationToken))
        assert result.scalar_one_or_none() is None


class TestTokenGeneration:
    @pytest.mark.anyio
    async def test_access_token_contains_user_id(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        user = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        token = response.json()["access_token"]
        payload = su.decode_access_token(token)

        assert payload["sub"] == str(user.id)
        assert payload["typ"] == "at+jwt"
        assert payload["iss"] == settings.PROJECT_NAME

    @pytest.mark.anyio
    async def test_refresh_token_is_stored_hashed(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        _ = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        response = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        refresh_token = response.json()["refresh_token"]

        # Check that stored token is hashed, not plain text
        result = await db_session.execute(select(RefreshToken))
        db_refresh = result.scalar_one()

        assert db_refresh.token_hash == su.hash_token(refresh_token)
        assert len(db_refresh.token_hash) == 32  # SHA-256 output


class TestSecurityHeaders:
    @pytest.mark.anyio
    async def test_refresh_token_stores_device_info(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        _ = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        _ = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
            headers={"user-agent": "TestBrowser/1.0"},
        )

        result = await db_session.execute(select(RefreshToken))
        db_refresh = result.scalar_one()

        assert db_refresh.device_info == "TestBrowser/1.0"

    @pytest.mark.anyio
    async def test_refresh_token_stores_ip_address(
        self, client: AsyncClient, db_session: AsyncSession
    ):
        _ = await create_verified_user(
            db_session, username="loginuser", password="Valid*Pass123"
        )

        _ = await client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": "loginuser", "password": "Valid*Pass123"},
        )

        result = await db_session.execute(select(RefreshToken))
        db_refresh = result.scalar_one()

        assert db_refresh.ip_address is not None


class TestLogout:
    @pytest.mark.anyio
    async def test_logout_success(self, client, db_session):
        raw_refresh_token = "valid-refresh-token"
        token_hash = su.hash_token(raw_refresh_token)
        user = await create_verified_user(
            db_session,
        )
        refresh_token = RefreshToken(
            user_id=user.id,
            token_hash=token_hash,
            device_info="test-device",
            ip_address="127.0.0.1",
            expires_at=datetime.now(UTC)
            + timedelta(minutes=settings.REFRESH_TOKEN_EXPIRE_MINUTES),
            created_at=datetime.now(UTC),
        )
        db_session.add(refresh_token)
        await db_session.commit()

        # response = await client.post(
        #     f"{settings.API_V1_STR}/auth/logout",
        #     json={"refresh_token": raw_refresh_token},
        # )
        #
        # assert response.status_code == 200
        # assert response.json() == {"message": "Successfully logged out"}
        #
        # db_token = await db_session.scalar(
        #     select(RefreshToken).where(RefreshToken.id == refresh_token.id)
        # )
        #
        # assert db_token.revoked is True
        # assert db_token.revoked_at is not None
        # assert isinstance(db_token.revoked_at, datetime)
        #

    #
    @pytest.mark.anyio
    async def test_logout_invalid_refresh_token(self, client):
        response = await client.post(
            f"{settings.API_V1_STR}/auth/logout",
            json={"refresh_token": "non-existent-token"},
        )

        assert response.status_code == 404
        assert response.json() == {"detail": "auth.session.logout.session_not_found"}
