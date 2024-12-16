FROM python:3.11
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y gettext libgettextpo-dev \
    && pip install --upgrade pip>=24.0 \
    && pip install poetry \
    && pip install virtualenv \
    && poetry config installer.max-workers 10 \
    && poetry config virtualenvs.create false \
    && mkdir /code
WORKDIR /code
COPY poetry.lock pyproject.toml /code/
RUN poetry install --no-interaction
COPY . /code/
