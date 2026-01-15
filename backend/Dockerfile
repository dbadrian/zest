FROM python:3.14

ENV PYTHONUNBUFFERED=1

WORKDIR /app/

# Install uv
# Ref: https://docs.astral.sh/uv/guides/integration/docker/#installing-uv
COPY --from=ghcr.io/astral-sh/uv:0.5.11 /uv /uvx /bin/

# Place executables in the environment at the front of the path
# Ref: https://docs.astral.sh/uv/guides/integration/docker/#using-the-environment
ENV PATH="/app/.venv/bin:$PATH"

# Compile bytecode
# Ref: https://docs.astral.sh/uv/guides/integration/docker/#compiling-bytecode
ENV UV_COMPILE_BYTECODE=1

# uv Cache
# Ref: https://docs.astral.sh/uv/guides/integration/docker/#caching
ENV UV_LINK_MODE=copy

# Install dependencies (this layer WILL be cached if lock files don't change)
# Ref: https://docs.astral.sh/uv/guides/integration/docker/#intermediate-layers
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project

ENV PYTHONPATH=/app

# cOPY CONFIGURATION FILES (LESS FREQUENTLY CHANGED - WILL BE CACHED)
COPY ./pyproject.toml ./uv.lock ./alembic.ini ./install_fixtures.py ./generate_recipes.py ./index_recipes.py /app/

# Build arg to control cache busting for code changes
ARG CODE_VERSION=dev
ENV CODE_VERSION=${CODE_VERSION}

# Copy source code LAST (most frequently changed)
# The CODE_VERSION arg above will bust the cache from here when it changes
COPY ./app /app/app
COPY ./fixtures /app/fixtures
COPY ./alembic /app/alembic
COPY ./tests /app/tests
COPY ./static /app/static

# Sync the project (will run when CODE_VERSION changes)
# Ref: https://docs.astral.sh/uv/guides/integration/docker/#intermediate-layers
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync

CMD ["fastapi", "dev", "--workers", "4", "app/main.py"]
