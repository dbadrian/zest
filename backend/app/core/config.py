# MIT License
#
# Copyright (c) 2025 David Adrian
# Copyright (c) 2019 Sebastián Ramírez
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import secrets
from urllib.parse import quote_plus
import warnings
from typing import Annotated, Any, Literal
import os
from pathlib import Path

from pydantic import (
    AnyUrl,
    BeforeValidator,
    EmailStr,
    HttpUrl,
    PostgresDsn,
    computed_field,
    model_validator,
)
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing_extensions import Self

SHOW_DOCS_IN_ENVS = ("local", "staging")

APP_DIR = Path(__file__).parent

# Build the path to the .env file relative to this file
env_file_path = APP_DIR.parent.parent / f".env.{os.getenv('ZEST_ENV', 'dev')}"
print("Current setting env", env_file_path)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        # Use top level .env file (one level above ./backend/)
        env_file=env_file_path,
        env_ignore_empty=True,
        extra="ignore",
    )

    # General Options
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str = "changethis"
    ENVIRONMENT: Literal["local", "test", "staging", "production"] = "local"
    PROJECT_NAME: str
    HOST_DOMAIN: str = "localhost:8000"

    PAGINATION_DEFAULT_PAGE_SIZE: int = 100
    PAGINATION_MAX_PAGE_SIZE: int = 5000

    # Security/Auth related settings
    SECRET_KEY_ACCESS_TOKENS: str = "changethis"
    SECRET_KEY_REFRESH_TOKENS_DB: str = "changethis"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1  # 5
    REFRESH_TOKEN_EXPIRE_MINUTES: int = 1  # 60 * 24 * 30  # 30 days
    PASSWORD_RESET_TOKEN_EXPIRE_MINUTES: int = 30
    EMAIL_VERIFICATION_TOKEN_EXPIRE_MINUTES: int = 60 * 24
    JWT_HASH: str = "HS256"  # NOTE:Succifient if the mobile app does not need to verify
    # Google OAuth2
    GOOGLE_CLIENT_ID: str | None = None
    GOOGLE_CLIENT_SECRET: str | None = None
    GOOGLE_REDIRECT_URL: str = f"http://{HOST_DOMAIN}{API_V1_STR}/auth/google/callback"  # TODO: too many magic variables

    LOCKED_ACCOUNT_TIMEOUT_MINUTES: int = 15
    MAX_FAILED_LOGIN_ATTEMPTS: int = 5

    # Database
    POSTGRES_SERVER: str
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str = "changethis"
    POSTGRES_DB: str = ""

    MEILISEARCH_URL: str | None
    MEILISEARCH_MASTER_KEY: str = "changethis"

    GEMINI_API_KEY: str | None = None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def SQLALCHEMY_DATABASE_URI(self) -> PostgresDsn:
        password_encoded = quote_plus(self.POSTGRES_PASSWORD)
        
        return PostgresDsn.build(
            scheme="postgresql+psycopg",
            username=self.POSTGRES_USER,
            password=password_encoded,
            host=self.POSTGRES_SERVER,
            port=self.POSTGRES_PORT,
            path=self.POSTGRES_DB,
        )

    # EMAIL related things?
    SMTP_TLS: bool = True
    SMTP_SSL: bool = False
    SMTP_PORT: int = 587
    SMTP_HOST: str | None = None
    SMTP_USER: str | None = None
    SMTP_PASSWORD: str | None = None
    EMAILS_FROM_EMAIL: EmailStr | None = None
    EMAILS_FROM_NAME: str | None = None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def emails_enabled(self) -> bool:
        return bool(self.SMTP_HOST and self.EMAILS_FROM_EMAIL)

    FIRST_SUPERUSER: EmailStr
    FIRST_SUPERUSER_PASSWORD: str

    def _check_default_secret(self, var_name: str, value: str | None) -> None:
        if value == "changethis":
            message = (
                f'The value of {var_name} is "changethis", '
                "for security, please change it, at least for deployments."
            )
            if self.ENVIRONMENT in ["local", "test"]:
                warnings.warn(message, stacklevel=1)
            else:
                raise ValueError(message)

    @model_validator(mode="after")
    def _enforce_non_default_secrets(self) -> Self:
        self._check_default_secret("SECRET_KEY", self.SECRET_KEY)
        self._check_default_secret(
            "SECRET_KEY_ACCESS_TOKENS", self.SECRET_KEY_ACCESS_TOKENS
        )
        self._check_default_secret(
            "SECRET_KEY_REFRESH_TOKENS_DB", self.SECRET_KEY_REFRESH_TOKENS_DB
        )
        self._check_default_secret("POSTGRES_PASSWORD", self.POSTGRES_PASSWORD)
        self._check_default_secret(
            "FIRST_SUPERUSER_PASSWORD", self.FIRST_SUPERUSER_PASSWORD
        )
        self._check_default_secret(
            "MEILISEARCH_MASTER_KEY", self.MEILISEARCH_MASTER_KEY
        )

        return self


settings = Settings()  # type: ignore
