from enum import Enum
from datetime import datetime, timedelta, UTC
from uuid import UUID, uuid7

from sqlalchemy import (
    ForeignKey,
    LargeBinary,
    String,
    DateTime,
    Enum as SQLEnum,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from pydantic import BaseModel, EmailStr, Field, field_validator


from app.core.config import Settings
from app.db import Base
from app.recipes.associations import user_favorite_recipes


class AuthProvider(str, Enum):
    """Describes supported authenticatio method/providers.
    Probably should be somewhere else, but for now, due to circular imports here."""

    LOCAL = "local"
    GOOGLE = "google"


###############################################################################################
## User
###############################################################################################
USER_ID_T = UUID


class User(Base):
    """
    Core user model with authentication and security features.

    Supports both local authentication (email/password) and OAuth providers
    (Google, GitHub, etc.). Includes security features like account locking,
    email verification, and password management.

    Attributes:
        id: UUID primary key for globally unique identification
        email: User's email address, must be unique
        username: User's display name, must be unique
        full_name: Optional full name
        hashed_password: Hashed password (None for OAuth users)

        auth_provider: Authentication method (LOCAL, GOOGLE, GITHUB, etc.)
        oauth_provider_id: Unique ID from OAuth provider

        email_verified: Whether email address has been confirmed
        is_active: Whether account is enabled (for soft deletion)
        is_superuser: Whether user has admin privileges
        failed_login_attempts: Counter for rate limiting
        locked_until: Timestamp when account lock expires

        created_at: When the account was created
        updated_at: Last modification timestamp (auto-updates)
        last_login: Most recent successful login
        password_changed_at: When password was last changed
        force_password_change: Whether user must reset password on next login
    """

    __tablename__ = "users"

    # Identity
    id: Mapped[USER_ID_T] = mapped_column(
        primary_key=True, index=True, default=uuid7, insert_default=uuid7
    )
    email: Mapped[EmailStr] = mapped_column(String, unique=True, index=True)
    username: Mapped[str] = mapped_column(String, unique=True, index=True)
    full_name: Mapped[str | None] = mapped_column(String)
    hashed_password: Mapped[str | None] = mapped_column(String)

    # Authentication
    auth_provider: Mapped[AuthProvider] = mapped_column(
        SQLEnum(AuthProvider),
        default=AuthProvider.LOCAL,
        insert_default=AuthProvider.LOCAL,
    )
    oauth_provider_id: Mapped[str | None] = mapped_column(String, unique=True)

    # Security
    email_verified: Mapped[bool] = mapped_column(default=False, insert_default=False)
    is_active: Mapped[bool] = mapped_column(default=False, insert_default=False)
    is_superuser: Mapped[bool] = mapped_column(default=False, insert_default=False)
    failed_login_attempts: Mapped[int] = mapped_column(default=0, insert_default=0)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        insert_default=lambda: datetime.now(UTC),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        insert_default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
    last_login: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Password management
    password_changed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True)
    )
    force_password_change: Mapped[bool] = mapped_column(
        default=False, insert_default=False
    )

    favorite_recipes = relationship(
        "Recipe",
        secondary=user_favorite_recipes,
        back_populates="favorited_by",
        lazy="selectin",  # better for async queries
    )


###############################################################################################
## Tokens
###############################################################################################


class RefreshToken(Base):
    """
    Stores refresh tokens for maintaining user sessions.

    Refresh tokens allow users to obtain new access tokens without
    re-authenticating. Each token is hashed for security and can be
    revoked independently.

    Attributes:
        id: Primary key
        user_id: Foreign key to the user who owns this token
        token_hash: Hashed version of the refresh token
        device_info: Optional device fingerprint for security tracking
        ip_address: IP address where token was issued
        expires_at: When the token becomes invalid
        created_at: When the token was created
        revoked: Whether the token has been manually revoked
        revoked_at: When the token was revoked, if applicable
    """

    __tablename__ = "refresh_tokens"

    @staticmethod
    def _default_expires_at():
        return datetime.now(UTC) + timedelta(
            minutes=Settings.REFRESH_TOKEN_EXPIRE_MINUTES
        )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[USER_ID_T] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[bytes] = mapped_column(
        LargeBinary(32),  # 32 bytes for SHA-256 / BLAKE2b
        unique=True,
        index=True,
        nullable=False,
    )
    device_info: Mapped[str | None] = mapped_column(String)
    ip_address: Mapped[str | None] = mapped_column(String)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=_default_expires_at,
        insert_default=_default_expires_at,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        insert_default=lambda: datetime.now(UTC),
    )
    revoked: Mapped[bool] = mapped_column(default=False, insert_default=False)
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class PasswordResetToken(Base):
    """
    Stores one-time tokens for password reset requests.

    These tokens are sent to users via email when they request a password
    reset. Each token can only be used once and expires after a set time.

    Attributes:
        id: Primary key
        user_id: Foreign key to the user requesting the reset
        token_hash: Hashed version of the reset token
        expires_at: When the token becomes invalid
        created_at: When the token was created
        used: Whether the token has been consumed
        ip_address: IP address where reset was requested
    """

    __tablename__ = "password_reset_tokens"

    @staticmethod
    def _default_expires_at():
        return datetime.now(UTC) + timedelta(
            minutes=Settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
        )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[USER_ID_T] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[bytes] = mapped_column(LargeBinary(32), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=_default_expires_at,
        insert_default=_default_expires_at,
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(UTC), insert_default=lambda: datetime.now(UTC)
    )
    used: Mapped[bool] = mapped_column(default=False, insert_default=False)
    ip_address: Mapped[str | None] = mapped_column(String)


class EmailVerificationToken(Base):
    """
    Stores tokens for email address verification.

    These tokens are sent to new users or when users change their email
    address to verify ownership of the email account.

    Attributes:
        id: Primary key
        user_id: Foreign key to the user verifying their email
        token_hash: Hashed version of the verification token
        expires_at: When the token becomes invalid
        created_at: When the token was created
    """

    __tablename__ = "email_verification_tokens"

    @staticmethod
    def _default_expires_at():
        return datetime.now(UTC) + timedelta(
            minutes=Settings.EMAIL_VERIFICATION_TOKEN_EXPIRE_MINUTES
        )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[USER_ID_T] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[bytes] = mapped_column(LargeBinary(32), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=_default_expires_at,
        insert_default=_default_expires_at,
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(UTC), insert_default=lambda: datetime.now(UTC)
    )
