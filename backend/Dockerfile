FROM python:3.11
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y gettext libgettextpo-dev
RUN mkdir /code
WORKDIR /code
COPY poetry.lock pyproject.toml /code/
RUN pip install --upgrade pip>=24.0
RUN pip install poetry
RUN pip install virtualenv
# RUN poetry self update
RUN poetry config installer.max-workers 10
RUN poetry config virtualenvs.create false
RUN poetry install --no-interaction
COPY . /code/
