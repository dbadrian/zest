FROM python:3.11-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set arguments for PostgreSQL configuration
ARG POSTGRES_DB
ARG POSTGRES_USER
ARG POSTGRES_PW
ARG POSTGRES_PORT=5432

ARG UID=1000
ARG GID=1000

# Set environment variables for PostgreSQL
ENV POSTGRES_DB=${POSTGRES_DB} \
    POSTGRES_USER=${POSTGRES_USER} \
    POSTGRES_PW=${POSTGRES_PW} \
    POSTGRES_PORT=${POSTGRES_PORT}

# Install PostgreSQL and other necessary packages
RUN apt-get update && apt-get install -y \
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    sudo \
    gettext libgettextpo-dev nano vim \
    && rm -rf /var/lib/apt/lists/* \ 
    && mkdir /code

# Switch to the postgres user to set up the database
USER postgres

# Set up PostgreSQL database and user creation
RUN service postgresql start && \
    psql -c "CREATE DATABASE ${POSTGRES_DB};" && \
    psql -c "CREATE USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PW}';" && \
    psql -c "ALTER DATABASE ${POSTGRES_DB} OWNER TO ${POSTGRES_USER};" && \
    psql -c "ALTER USER ${POSTGRES_USER} CREATEDB;" && \
    psql -c "ALTER ROLE ${POSTGRES_USER} SET client_encoding TO 'utf8';" && \
    psql -c "ALTER ROLE ${POSTGRES_USER} SET default_transaction_isolation TO 'read committed';" && \
    psql -c "ALTER ROLE ${POSTGRES_USER} SET timezone TO 'UTC';" && \
    psql -c "GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};" && \
    psql -c "GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};" && \
    psql -c "GRANT CREATE ON SCHEMA public TO ${POSTGRES_USER};"

# Expose the PostgreSQL port
EXPOSE ${POSTGRES_PORT} 5432 6379

USER root

WORKDIR /code
COPY backend/poetry.lock backend/pyproject.toml /code/
RUN pip install --upgrade pip>=24.0 \
    && pip install poetry \
    && pip install virtualenv \
    && poetry config installer.max-workers 10 \
    && poetry config virtualenvs.create false \
    && poetry install --no-interaction
# COPY backend/ /code/

# start entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    groupadd -g $GID zest && useradd -u $UID -g $GID -m zest && \
    passwd -d zest && \
    echo 'zest ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
ENTRYPOINT ["/entrypoint.sh"]

# Default command to run Bash
CMD ["/bin/bash"]