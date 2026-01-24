from enum import Enum
from datetime import timedelta, UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status, Request
from fastapi.responses import RedirectResponse
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import Select, exc, select, update
from starlette.status import HTTP_400_BAD_REQUEST

# from google.oauth2 import id_token
# from google.auth.transport import requests as google_requests

from app.core.config import settings
from app.db import get_db

from app.auth.models import (
    USER_ID_T,
    AuthProvider,
    EmailVerificationToken,
    RefreshToken,
    User,
)
from app.auth.schemas import (
    AccessTokenRefresh,
    SessionRevoked,
    ActiveSessionMeta,
    UserInfoPublic,
    UserRegister,
    TokenResponse,
    LogoutRefreshToken,
    PasswordStrength,
    EmailVerificationRequest,
    GoogleAuthRequest,
)
import app.auth.security_utils as su
from app.auth import constants

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/{constants.AUTH_ROUTER_PREFIX}/login"
)


def is_account_locked(user: User) -> bool:
    """Check if account is locked due to failed login attempts"""
    if user.locked_until and user.locked_until > datetime.now(UTC):
        return True
    return False


async def lock_account(user: User, db: AsyncSession) -> None:
    """Lock account after too many failed attempts"""
    user.failed_login_attempts += 1

    if user.failed_login_attempts >= settings.MAX_FAILED_LOGIN_ATTEMPTS:
        user.locked_until = datetime.now(UTC) + timedelta(
            minutes=settings.LOCKED_ACCOUNT_TIMEOUT_MINUTES
        )
        user.failed_login_attempts = 0  # Reset counter

    await db.commit()


async def reset_failed_attempts(user: User, db: AsyncSession) -> None:
    """Reset failed login attempts on successful login"""
    user.failed_login_attempts = 0
    user.locked_until = None
    await db.commit()


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Get current authenticated user from JWT token"""
    payload = su.decode_access_token(token)
    user_id: USER_ID_T | None = payload.get("sub")

    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )

    result = await db.execute(select(User).filter(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found"
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Inactive user"
        )

    if is_account_locked(user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account temporarily locked due to failed login attempts",
        )

    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """Ensure user is active"""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user


async def get_current_verified_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """Ensure user has verified email"""
    if not current_user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Email not verified"
        )
    return current_user


async def get_current_superuser(current_user: User = Depends(get_current_user)) -> User:
    """Ensure user is superuser"""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not enough permissions"
        )
    return current_user


router = APIRouter(prefix=f"/{constants.AUTH_ROUTER_PREFIX}", tags=["authentication"])


@router.post("/register", response_model=TokenResponse)
async def register(
    user_data: UserRegister,
    request: Request,
    db: AsyncSession = Depends(get_db),  # Inject your get_db
):
    """
    Register new user with email/password

    Password requirements:
    - Minimum 8 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character
    """
    # Validate password strength
    try:
        PasswordStrength(password=user_data.password)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Check if user exists
    email_result = await db.execute(select(User).filter(User.email == user_data.email))
    if email_result.scalar_one_or_none() is not None:
        raise HTTPException(status_code=400, detail="Email already registered")

    username_result = await db.execute(
        select(User).filter(User.username == user_data.username)
    )
    if username_result.scalar_one_or_none() is not None:
        raise HTTPException(status_code=400, detail="Username already taken")

    # Create user
    user = User(
        email=user_data.email,
        username=user_data.username,
        hashed_password=su.hash_password(user_data.password),
        full_name=user_data.full_name,
        auth_provider=AuthProvider.LOCAL,
        password_changed_at=datetime.now(UTC),
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    # Create verification token
    verification_token = su.generate_high_entropy_token()
    token_hash = su.hash_token(verification_token)

    db_token = EmailVerificationToken(
        user_id=user.id,
        token_hash=token_hash,
        expires_at=datetime.now(UTC)
        + timedelta(minutes=settings.EMAIL_VERIFICATION_TOKEN_EXPIRE_MINUTES),
    )
    db.add(db_token)

    # TODO: Send verification email with verification_token

    if settings.ENVIRONMENT == "local":
        print(
            f"Verification link: localhost:8000{settings.API_V1_STR}/auth/verify-email?token={verification_token}"
        )

    # Generate tokens
    access_token = su.create_access_token(data={"sub": str(user.id)})
    refresh_token = su.create_refresh_token()

    # Store refresh token
    db_refresh = RefreshToken(
        user_id=user.id,
        token_hash=su.hash_token(refresh_token),
        device_info=request.headers.get("user-agent"),
        ip_address=su.get_client_ip(request),
        expires_at=datetime.now(UTC)
        + timedelta(minutes=settings.REFRESH_TOKEN_EXPIRE_MINUTES),
    )
    db.add(db_refresh)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # in s
    }


class VerifyEmailResult(str, Enum):
    SUCCESS = "success"
    ALREADY_VERIFIED = "already_verified"
    INVALID = "invalid"
    EXPIRED = "expired"
    ERROR = "error"


async def verify_email_logic(token: str, db: AsyncSession) -> VerifyEmailResult:
    token_hash = su.hash_token(token)

    result = await db.execute(
        select(EmailVerificationToken).where(
            EmailVerificationToken.token_hash == token_hash
        )
    )
    db_token = result.scalar_one_or_none()

    if db_token is None:
        return VerifyEmailResult.INVALID

    if db_token.expires_at < datetime.now(UTC):
        return VerifyEmailResult.EXPIRED

    user_result = await db.execute(select(User).where(User.id == db_token.user_id))
    user = user_result.scalar_one_or_none()

    if user is None:
        return VerifyEmailResult.ERROR

    if user.email_verified:
        return VerifyEmailResult.ALREADY_VERIFIED

    user.email_verified = True
    user.is_active = True

    await db.delete(db_token)

    return VerifyEmailResult.SUCCESS


# @router.post("/verify-email")
# async def verify_email(
#     verification: EmailVerificationRequest, db: AsyncSession = Depends(get_db)
# ):
#     """
#     Verify email with token
#     """
#     await verify_email_logic(verification.token, db)
#     return {"message": "Email verified successfully"}


@router.get("/verify-email")
async def verify_email_from_url(
    token: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
) -> RedirectResponse:
    if token is None or not token.strip():
        return RedirectResponse(
            url=f"http://{settings.HOST_DOMAIN}/static/failure.html",
            status_code=status.HTTP_302_FOUND,
        )

    try:
        ret = await verify_email_logic(token, db=db)
    except:
        return RedirectResponse(
            url=f"http://{settings.HOST_DOMAIN}/static/failure.html",
            status_code=status.HTTP_302_FOUND,
        )
    if ret == VerifyEmailResult.ALREADY_VERIFIED:
        return RedirectResponse(
            url=f"http://{settings.HOST_DOMAIN}/static/email-verification-already-verified.html",
            status_code=status.HTTP_302_FOUND,
        )
    elif ret == VerifyEmailResult.EXPIRED:
        return RedirectResponse(
            url=f"http://{settings.HOST_DOMAIN}/static/email-verification-failure.html",
            status_code=status.HTTP_302_FOUND,
        )
    elif ret == VerifyEmailResult.INVALID:
        return RedirectResponse(
            url=f"http://{settings.HOST_DOMAIN}/static/email-verification-failure.html",
            status_code=status.HTTP_302_FOUND,
        )
    elif ret == VerifyEmailResult.SUCCESS:
        return RedirectResponse(
            url=f"http://{settings.HOST_DOMAIN}/static/email-verification-failure.html",
            status_code=status.HTTP_302_FOUND,
        )

    # shouldnt reach. but failure if it does...
    return RedirectResponse(
        url=f"http://{settings.HOST_DOMAIN}/static/failure.html",
        status_code=status.HTTP_302_FOUND,
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    """
    Login with username/password

    Returns:
    - access_token: Short-lived JWT
    - refresh_token: Long-lived token to obtain new access_token. Will be rotated.
    """

    user_ret = await db.execute(
        select(User).filter(User.username == form_data.username)
    )

    if (user := user_ret.scalar_one_or_none()) is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    # Check if account is currently locked due failed login attempts
    if is_account_locked(user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account temporarily locked. Try again in {settings.LOCKED_ACCOUNT_TIMEOUT_MINUTES} minutes.",
        )

    # Verify password
    # TODO: user should always have hashed password..
    if not user.hashed_password or not su.verify_password(
        form_data.password, user.hashed_password
    ):
        await lock_account(user, db)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    # We only care about email verified if the user never logged in before
    if not user.email_verified and user.last_login is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account is inactive. Activate your email first.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is inactive. Contact admin.",
        )

    # All good, reset any failed attempt to this point
    await reset_failed_attempts(user, db)

    # Update last login
    user.last_login = datetime.now(UTC)

    # Check if password needs rehashing
    if su.needs_rehash(user.hashed_password):
        user.hashed_password = su.hash_password(form_data.password)

    # Generate tokens
    access_token = su.create_access_token(data={"sub": user.id})
    refresh_token = su.create_refresh_token()

    # Store refresh token
    db_refresh = RefreshToken(
        user_id=user.id,
        token_hash=su.hash_token(refresh_token),
        device_info=request.headers.get("user-agent") if request else None,
        ip_address=su.get_client_ip(request) if request else None,
        expires_at=datetime.now(UTC)
        + timedelta(minutes=settings.REFRESH_TOKEN_EXPIRE_MINUTES),
    )
    db.add(db_refresh)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    }


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    token_data: AccessTokenRefresh, request: Request, db: AsyncSession = Depends(get_db)
):
    """
    Refresh access token using refresh token

    Returns new access and refresh tokens
    """
    token_hash = su.hash_token(token_data.refresh_token)

    db_token = await db.execute(
        Select(RefreshToken).filter(
            RefreshToken.token_hash == token_hash, RefreshToken.revoked == False
        )
    )
    db_token = db_token.scalar_one_or_none()

    if not db_token or db_token.expires_at < datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )
    user = await db.execute(Select(User).filter(User.id == db_token.user_id))
    user = user.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )

    # Revoke old refresh token
    db_token.revoked = True
    db_token.revoked_at = datetime.now(UTC)

    # Generate new tokens
    access_token = su.create_access_token(data={"sub": user.id})
    new_refresh_token = su.create_refresh_token()

    # Store refresh token
    db_refresh = RefreshToken(
        user_id=user.id,
        token_hash=su.hash_token(new_refresh_token),
        device_info=request.headers.get("user-agent") if request else None,
        ip_address=su.get_client_ip(request) if request else None,
        expires_at=datetime.now(UTC)
        + timedelta(minutes=settings.REFRESH_TOKEN_EXPIRE_MINUTES),
    )
    db.add(db_refresh)

    return {
        "access_token": access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    }


@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout(refresh_token: LogoutRefreshToken, db=Depends(get_db)):
    """
    Logout and revoke refresh token
    """
    token_hash = su.hash_token(refresh_token.refresh_token)

    db_token = await db.execute(
        Select(RefreshToken).filter(RefreshToken.token_hash == token_hash)
    )
    db_token = db_token.scalar_one_or_none()
    if db_token is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="auth.session.logout.session_not_found",
        )

    db_token.revoked = True
    db_token.revoked_at = datetime.now(UTC)

    return {"message": "Successfully logged out"}


@router.post("/logout-all")
async def logout_all(
    current_user: User = Depends(get_current_user), db=Depends(get_db)
):
    """
    Logout from all devices (revoke all refresh tokens)
    """
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == current_user.id)
        .values(revoked=True, revoked_at=datetime.now(UTC))
    )
    return {"message": "Logged out from all devices"}


@router.get("/me", response_model=UserInfoPublic, status_code=status.HTTP_200_OK)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """
    Get current user information
    """
    return current_user
    return {
        "id": current_user.id,
        "email": current_user.email,
        "username": current_user.username,
        "full_name": current_user.full_name,
        "auth_provider": current_user.auth_provider,
        "email_verified": current_user.email_verified,
        "is_active": current_user.is_active,
        "created_at": current_user.created_at,
        "last_login": current_user.last_login,
    }


@router.get(
    "/sessions", response_model=list[ActiveSessionMeta], status_code=status.HTTP_200_OK
)
async def get_active_sessions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Get all active sessions (refresh tokens) for current user
    """
    sessions = await db.execute(
        Select(RefreshToken).filter(
            RefreshToken.user_id == current_user.id,
            RefreshToken.revoked == False,
            RefreshToken.expires_at > datetime.now(UTC),
        )
    )
    sessions = sessions.scalars().all()
    return sessions


@router.delete(
    "/sessions/{session_id}",
    response_model=SessionRevoked,
    status_code=status.HTTP_200_OK,
)
async def revoke_session(
    session_id: int, current_user: User = Depends(get_current_user), db=Depends(get_db)
):
    """
    Revoke a specific session (logout from specific device)
    """
    ret = await db.execute(
        Select(RefreshToken).filter(
            RefreshToken.id == session_id, RefreshToken.user_id == current_user.id
        )
    )
    session = ret.scalar_one_or_none()
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
        )

    if session.revoked:
        return SessionRevoked(
            success=False, message="auth.session.revoke.is_already_revoked"
        )

    session.revoked = True
    session.revoked_at = datetime.now(UTC)

    return SessionRevoked(success=True, message="auth.session.revoke.success")


#
# async def google_auth(
#     auth_request: GoogleAuthRequest,
#     request: Request,
#     db: AsyncSession = Depends(get_db),
# ):
#     """
#     Authenticate with Google OAuth2
#
#     Send the Google ID token from the client
#     """
#     if not settings.GOOGLE_CLIENT_ID:
#         raise HTTPException(
#             status_code=status.HTTP_501_NOT_IMPLEMENTED,
#             detail="Google authentication not configured",
#         )
#
#     # Verify Google token
#     google_data = await su.verify_google_token(auth_request.id_token)
#
#     # Find user by Google ID
#     result = await db.execute(
#         select(User).filter(User.oauth_provider_id == google_data["google_id"])
#     )
#     user = result.scalar_one_or_none()
#
#     if not user:
#         # Check if email exists
#         result = await db.execute(
#             select(User).filter(User.email == google_data["email"])
#         )
#         user = result.scalar_one_or_none()
#
#         if user:
#             # Link Google account to existing user
#             user.oauth_provider_id = google_data["google_id"]
#             user.auth_provider = AuthProvider.GOOGLE
#         else:
#             # Create new user with unique username
#             username = google_data["email"].split("@")[0]
#             base_username = username
#             counter = 1
#
#             # Ensure unique username
#             while True:
#                 result = await db.execute(
#                     select(User).filter(User.username == username)
#                 )
#                 if result.scalar_one_or_none() is None:
#                     break
#                 username = f"{base_username}{counter}"
#                 counter += 1
#
#             user = User(
#                 email=google_data["email"],
#                 username=username,
#                 full_name=google_data.get("name"),
#                 auth_provider=AuthProvider.GOOGLE,
#                 oauth_provider_id=google_data["google_id"],
#                 email_verified=google_data["email_verified"],
#             )
#             db.add(user)
#             await db.flush()  # Get user.id
#             await db.refresh(user)
#
#     # Update last login
#     user.last_login = datetime.now(UTC)
#
#     # Generate tokens
#     access_token = su.create_access_token(data={"sub": user.id})
#     refresh_token = su.create_refresh_token()
#
#     # Store refresh token
#     db_refresh = RefreshToken(
#         user_id=user.id,
#         token_hash=su.hash_token(refresh_token),
#         device_info=auth_request.device_info or request.headers.get("user-agent"),
#         ip_address=su.get_client_ip(request),
#         expires_at=datetime.now(UTC)
#         + timedelta(minutes=settings.REFRESH_TOKEN_EXPIRE_MINUTES),
#     )
#     db.add(db_refresh)
#
#     return {
#         "access_token": access_token,
#         "refresh_token": refresh_token,
#         "token_type": "bearer",
#         "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
#     }
