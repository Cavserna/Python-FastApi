FROM python:3.10.12-slim  AS development_build

ENV WEBAPP_DIR=/code/app \ 
    STATUS_ENV=${STATUS_ENV} \
    # build:
    BUILD_ONLY_PACKAGES='' \
    # python:
    PYTHONFAULTHANDLER=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONHASHSEED=random \
    PYTHONDONTWRITEBYTECODE=1 \
    POETRY_VERSION=1.5.1 \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_CACHE_DIR='/var/cache/pypoetry' \
    POETRY_HOME="/usr/local"

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    gcc \
    curl \
    $BUILD_ONLY_PACKAGES \
    && curl -sSL 'https://install.python-poetry.org' | python3 - \
    && poetry --version \
    && apt-get remove -y $BUILD_ONLY_PACKAGES \
    # Cleaning cache:
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

WORKDIR $WEBAPP_DIR

RUN groupadd -r web && useradd -d /code -r -g web web \
  && chown web:web -R /code 

COPY --chown=web:web ./poetry.lock ./pyproject.toml  $WEBAPP_DIR/

RUN echo "$POETRY_HOME" && echo "$STATUS_ENV" && poetry version \
    # Install deps:
    && poetry lock  --no-update \
    && poetry install --no-root --only main 
    #     $(if [ "$STATUS_ENV" = 'production' ]; then echo '--no-dev'; fi) \
    #     --no-interaction --no-ansi \
    # # Cleaning poetry installation's cache for production:
    # && if [ "$STATUS_ENV" = 'production' ]; then rm -rf "$POETRY_CACHE_DIR"; fi

COPY . $WEBAPP_DIR/

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80", "--reload"]
# CMD alembic upgrade head && \
#     gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker -b 0.0.0.0
