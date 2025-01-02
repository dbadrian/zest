FROM python:3.11-alpine

ARG POSTGRES_DB
ARG POSTGRES_USER
ARG POSTGRES_PW
ARG POSTGRES_PORT=5432
ARG UID=1000
ARG GID=1000

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    POSTGRES_DB=${POSTGRES_DB} \
    POSTGRES_USER=${POSTGRES_USER} \
    POSTGRES_PW=${POSTGRES_PW} \
    POSTGRES_PORT=${POSTGRES_PORT}


COPY backend/poetry.lock backend/pyproject.toml /code/

WORKDIR /code

# Install PostgreSQL and other necessary packages
RUN apk add --no-cache \
    postgresql \
    postgresql-contrib \
    redis \
    nginx \
    sudo \
    bash \
    && pip install --no-cache-dir --upgrade 'pip>=24.0' \
    && pip install poetry \
    && pip install virtualenv \
    && poetry config installer.max-workers 10 \
    && poetry config virtualenvs.create false \
    && poetry install --no-interaction --without dev,docs \
    && poetry cache clear --all . \
    # create relevant folders 
    && mkdir /run/postgresql && chown postgres:postgres /run/postgresql/ \
    && addgroup -g $GID zest \
    && adduser -u $UID -G zest -D zest \
    && echo 'zest ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && rm -rf /var/cache/apk/* /root/.cache/pip /root/.cache/pypoetry/* \
    && su - postgres -c "cd && \
    mkdir -p /var/lib/postgresql/data && \
    # pretty liberal permission...just for this dev docker
    chmod 0777 /var/lib/postgresql/data && \
    initdb -D /var/lib/postgresql/data && \
    pg_ctl start -D /var/lib/postgresql/data && \
    while ! netstat -tuln | grep -q ':5432'; do echo 'Waiting for PostgreSQL...'; sleep 1; done && \
    echo 'PostgreSQL is up on port 5432!' && \
    psql -c 'CREATE DATABASE ${POSTGRES_DB};' && \
    psql -c 'CREATE USER ${POSTGRES_USER} WITH PASSWORD '\''${POSTGRES_PW}'\'';' && \
    psql -c 'ALTER DATABASE ${POSTGRES_DB} OWNER TO ${POSTGRES_USER};' && \
    psql -c 'ALTER USER ${POSTGRES_USER} CREATEDB;' && \
    psql -c 'ALTER ROLE ${POSTGRES_USER} SET client_encoding TO '\''utf8'\'';' && \
    psql -c 'ALTER ROLE ${POSTGRES_USER} SET default_transaction_isolation TO '\''read committed'\'';' && \
    psql -c 'ALTER ROLE ${POSTGRES_USER} SET timezone TO '\''UTC'\'';' && \
    psql -c 'GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};' && \
    psql -c 'GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};' && \
    psql -c 'GRANT CREATE ON SCHEMA public TO ${POSTGRES_USER};'"

# Expose the PostgreSQL port
EXPOSE ${POSTGRES_PORT} 5432 6379

USER root
    
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
# Default command to run Bash
CMD ["/bin/bash"]