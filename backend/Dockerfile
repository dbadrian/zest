FROM python:3.11

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN mkdir /code
WORKDIR /code
COPY poetry.lock pyproject.toml /code/
RUN apt-get update && apt-get install -y gettext libgettextpo-dev && apt-get clean \
    && pip install --upgrade pip>=24.0 \
    && pip install poetry \
    && pip install virtualenv \
    && poetry config installer.max-workers 10 \
    && poetry config virtualenvs.create false \
    && poetry install --no-interaction
COPY . /code/
