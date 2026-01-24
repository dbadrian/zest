from datetime import timedelta, datetime, UTC
from uuid import UUID
import secrets
import hashlib
import hmac
from collections.abc import Hashable
from typing import TypeVar

from argon2 import PasswordHasher, profiles  # used for password hashing
from argon2.exceptions import VerifyMismatchError
import jwt
from fastapi import HTTPException, Request, status
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

from app.core.config import settings


K = TypeVar("K", bound=Hashable)
V = TypeVar("V")

##############################
# Hashing related functions

# low-memory ->64mb standard config
pw_hasher = PasswordHasher.from_parameters(profiles.RFC_9106_LOW_MEMORY)


def hash_password(password: str) -> str:
    # TODO: Consider choosing different default parameters
    return pw_hasher.hash(password)


def verify_password(password: str, hash: str) -> bool:
    try:
        return pw_hasher.verify(hash, password)
    except VerifyMismatchError:
        return False


def needs_rehash(hash: str) -> bool:
    return pw_hasher.check_needs_rehash(hash)


def generate_high_entropy_token() -> str:
    """Should be high entropy"""
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> bytes:
    return hmac.new(
        settings.SECRET_KEY_REFRESH_TOKENS_DB.encode(),
        token.encode(),
        hashlib.sha256,
    ).digest()


def jwt_prepare(payload: dict):
    """Main purpose is to ensure the types are all safe to return"""
    return {k: str(v) if isinstance(v, UUID) else v for k, v in payload.items()}


def create_access_token(
    data: dict[str, V], expires_delta_override: timedelta | None = None
) -> str:
    """Short lived access token generation"""
    # TODO: copy is shallow?
    payload = data.copy()
    expires_in = datetime.now(UTC) + (
        expires_delta_override
        or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    payload.update(
        {
            "iss": settings.PROJECT_NAME,
            "exp": expires_in,
            "iat": datetime.now(UTC),
            "typ": "at+jwt",
            "jti": secrets.token_urlsafe(16),
        }
    )

    payload = jwt_prepare(payload)

    return jwt.encode(
        payload,
        settings.SECRET_KEY_ACCESS_TOKENS,
        algorithm=settings.JWT_HASH,
    )


def create_secure_token() -> str:
    return generate_high_entropy_token()


def decode_access_token(token: str) -> dict[str, V]:
    try:
        # TODO: Enforce require claims using options require?
        payload = jwt.decode(
            token,
            settings.SECRET_KEY_ACCESS_TOKENS,
            issuer=settings.PROJECT_NAME,
            algorithms=settings.JWT_HASH,
        )

        # sanity check if its access token
        if (typ := payload.get("typ", None)) is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing token type",
            )

        if typ != "at+jwt":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type",
            )

        return payload

    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidIssuerError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid issuer",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def verify_google_token(token: str) -> dict:
    """Verify Google ID token"""
    try:
        idinfo = id_token.verify_oauth2_token(
            token, google_requests.Request(), settings.GOOGLE_CLIENT_ID
        )

        # Verify issuer
        if idinfo["iss"] not in ["accounts.google.com", "https://accounts.google.com"]:
            raise ValueError("Wrong issuer")

        return {
            "email": idinfo["email"],
            "name": idinfo.get("name"),
            "picture": idinfo.get("picture"),
            "email_verified": idinfo.get("email_verified", False),
            "google_id": idinfo["sub"],
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Google token: {str(e)}",
        )


def get_client_ip(request: Request) -> str:
    """
    Get the real client IP address, accounting for proxies.
    """
    # Check X-Forwarded-For first (most common)
    if forwarded := request.headers.get("X-Forwarded-For"):
        return forwarded.split(",")[0].strip()

    # Check X-Real-IP (nginx)
    if real_ip := request.headers.get("X-Real-IP"):
        return real_ip

    # Check CF-Connecting-IP (CloudFlare)
    if cf_ip := request.headers.get("CF-Connecting-IP"):
        return cf_ip

    # Fallback to direct connection IP
    return request.client.host
