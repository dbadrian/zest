from datetime import datetime
from uuid import UUID
import re

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.core.constants import (
    EMAIL_MAX_LENGTH,
    EMAIL_REGEX_PATTERN,
    PASSWORD_MAX_LENGTH,
    PASSWORD_MIN_LENGTH,
    PASSWORD_SPECIAL_CHARS,
    USERNAME_MAX_LENGTH,
    USERNAME_MIN_LENGTH,
    USERNAME_REGEX_PATTERN,
)


class UserBase(BaseModel):
    """
    Base user schema with common validation rules.

    This schema contains fields and validators shared across all user-related
    request/response models.

    Attributes:
        username: User's unique display name (3-128 chars, alphanumeric + _-)
    """

    username: str = Field(
        ...,
        min_length=USERNAME_MIN_LENGTH,
        max_length=max(USERNAME_MAX_LENGTH, EMAIL_MAX_LENGTH),
    )

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        """
        Validate username format.

        Usernames must contain only letters, numbers, underscores, and hyphens.
        This prevents special characters that could cause issues in URLs or
        display contexts.

        Args:
            v: The username to validate

        Returns:
            The validated username

        Raises:
            ValueError: If username contains invalid characters
        """
        # Named patterns for clarity

        if re.match(EMAIL_REGEX_PATTERN, v):
            return v

        if re.match(USERNAME_REGEX_PATTERN, v):
            return v

        raise ValueError(
            "Username can be either a valid email address or only contain letters, numbers, underscores, and hyphens"
        )


class PasswordStrength(BaseModel):
    """
    Validate password strength and complexity requirements.

    Enforces security best practices including minimum length, character
    diversity, and complexity requirements.

    Attributes:
        password: Plain text password meeting all strength requirements
    """

    password: str = Field(
        ..., min_length=PASSWORD_MIN_LENGTH, max_length=PASSWORD_MAX_LENGTH
    )

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        """
        Validate password meets security requirements.

        Requirements:
        - Length:  characters
        - At least one uppercase letter (A-Z)
        - At least one lowercase letter (a-z)
        - At least one digit (0-9)
        - At least one special character (!@#$%^&*(),.?":{}|<>)

        Args:
            v: The password to validate

        Returns:
            The validated password

        Raises:
            ValueError: If password doesn't meet any requirement
        """
        if len(v) < PASSWORD_MIN_LENGTH:
            raise ValueError(
                f"Password must be at least {PASSWORD_MIN_LENGTH} characters"
            )
        if len(v) > PASSWORD_MAX_LENGTH:
            raise ValueError(
                f"Password too long (max {PASSWORD_MAX_LENGTH} characters)"
            )
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        if not re.search(PASSWORD_SPECIAL_CHARS, v):
            raise ValueError(
                "Password must contain at least one special character: "
                + PASSWORD_SPECIAL_CHARS
            )
        return v


class UserLogin(UserBase):
    """
    Schema for user login requests.

    Used for authenticating users with username and password.
    Note: Login does not enforce password strength validation since
    existing passwords may not meet current strength requirements.

    Attributes:
        username: User's unique identifier
        password: Plain text password (will be hashed server-side)
    """

    password: str


class UserRegister(UserBase, PasswordStrength):
    """
    Schema for new user registration.

    Combines username validation from UserBase with password strength
    validation from PasswordStrength. Adds additional required and optional
    fields for creating a complete user profile.

    Attributes:
        username: Unique username (3-128 chars, alphanumeric + _-)
        password: Strong password meeting all complexity requirements
        email: Valid email address
        full_name: Optional full legal name for the user
    """

    email: EmailStr
    full_name: str | None = None


class UserBase(BaseModel):
    """
    Base user schema with common validation rules.

    This schema contains fields and validators shared across all user-related
    request/response models.

    Attributes:
        username: User's unique display name (3-128 chars, alphanumeric + _-)
    """

    username: str = Field(
        ...,
        min_length=USERNAME_MIN_LENGTH,
        max_length=max(USERNAME_MAX_LENGTH, EMAIL_MAX_LENGTH),
    )

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        """
        Validate username format.

        Usernames must contain only letters, numbers, underscores, and hyphens.
        This prevents special characters that could cause issues in URLs or
        display contexts.

        Args:
            v: The username to validate

        Returns:
            The validated username

        Raises:
            ValueError: If username contains invalid characters
        """
        # Named patterns for clarity

        if re.match(EMAIL_REGEX_PATTERN, v):
            return v

        if re.match(USERNAME_REGEX_PATTERN, v):
            return v

        raise ValueError(
            "Username can be either a valid email address or only contain letters, numbers, underscores, and hyphens"
        )


class PasswordStrength(BaseModel):
    """
    Validate password strength and complexity requirements.

    Enforces security best practices including minimum length, character
    diversity, and complexity requirements.

    Attributes:
        password: Plain text password meeting all strength requirements
    """

    password: str = Field(
        ..., min_length=PASSWORD_MIN_LENGTH, max_length=PASSWORD_MAX_LENGTH
    )

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        """
        Validate password meets security requirements.

        Requirements:
        - Length:  characters
        - At least one uppercase letter (A-Z)
        - At least one lowercase letter (a-z)
        - At least one digit (0-9)
        - At least one special character (!@#$%^&*(),.?":{}|<>)

        Args:
            v: The password to validate

        Returns:
            The validated password

        Raises:
            ValueError: If password doesn't meet any requirement
        """
        if len(v) < PASSWORD_MIN_LENGTH:
            raise ValueError(
                f"Password must be at least {PASSWORD_MIN_LENGTH} characters"
            )
        if len(v) > PASSWORD_MAX_LENGTH:
            raise ValueError(
                f"Password too long (max {PASSWORD_MAX_LENGTH} characters)"
            )
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        if not re.search(PASSWORD_SPECIAL_CHARS, v):
            raise ValueError(
                "Password must contain at least one special character: "
                + PASSWORD_SPECIAL_CHARS
            )
        return v


class UserLogin(UserBase):
    """
    Schema for user login requests.

    Used for authenticating users with username and password.
    Note: Login does not enforce password strength validation since
    existing passwords may not meet current strength requirements.

    Attributes:
        username: User's unique identifier
        password: Plain text password (will be hashed server-side)
    """

    password: str


class UserRegister(UserBase, PasswordStrength):
    """
    Schema for new user registration.

    Combines username validation from UserBase with password strength
    validation from PasswordStrength. Adds additional required and optional
    fields for creating a complete user profile.

    Attributes:
        username: Unique username (3-128 chars, alphanumeric + _-)
        password: Strong password meeting all complexity requirements
        email: Valid email address
        full_name: Optional full legal name for the user
    """

    email: EmailStr
    full_name: str | None = None


# Token and Authentication Response Schemas
class TokenResponse(BaseModel):
    """
    OAuth2-compliant token response.

    Returned after successful authentication (login, registration, or token refresh).
    Contains both access token for API calls and refresh token for obtaining new
    access tokens.

    Attributes:
        access_token: JWT token for authenticating API requests
        refresh_token: Long-lived token for obtaining new access tokens
        token_type: OAuth2 token type, always "bearer"
        expires_in: Access token lifetime in seconds
    """

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class AccessTokenRefresh(BaseModel):
    """
    Request schema for refreshing access tokens.

    Used when the access token expires but the refresh token is still valid.

    Attributes:
        refresh_token: Valid refresh token from previous authentication
    """

    refresh_token: str


class LogoutRefreshToken(BaseModel):
    refresh_token: str


# OAuth Schemas


class GoogleAuthRequest(BaseModel):
    """
    Request schema for Google OAuth authentication.

    After user authenticates with Google, the frontend sends the ID token
    to the backend for verification and account creation/login.

    Attributes:
        id_token: JWT ID token from Google Sign-In
        device_info: Optional device fingerprint for security tracking
    """

    id_token: str
    device_info: str | None = None


# Password Management Schemas


class PasswordResetRequest(BaseModel):
    """
    Request schema for initiating password reset flow.

    User submits their email address to receive a password reset link.

    Attributes:
        email: Email address associated with the account
    """

    email: EmailStr


class PasswordResetConfirm(PasswordStrength):
    """
    Request schema for completing password reset.

    User submits the token from their email along with their new password.
    Inherits password strength validation to ensure secure passwords.

    Attributes:
        token: One-time reset token from email
        password: New password meeting all strength requirements
    """

    token: str


class PasswordChange(PasswordStrength):
    """
    Request schema for changing password while authenticated.

    Requires current password for verification before allowing change.
    New password must meet strength requirements.

    Attributes:
        current_password: User's existing password for verification
        password: New password meeting all strength requirements
    """

    current_password: str


# Email Verification Schema


class EmailVerificationRequest(BaseModel):
    """
    Request schema for verifying email address.

    User clicks link in verification email which contains the token.

    Attributes:
        token: One-time verification token from email
    """

    token: str


class UserInfoPublic(BaseModel):
    id: UUID
    email: EmailStr
    username: str
    full_name: str | None
    auth_provider: str
    email_verified: bool
    is_active: bool
    created_at: datetime
    last_login: datetime | None


class ActiveSessionMeta(BaseModel):
    id: int
    device_info: str
    ip_address: str
    created_at: datetime
    expires_at: datetime


class SessionRevoked(BaseModel):
    success: bool
    message: str
