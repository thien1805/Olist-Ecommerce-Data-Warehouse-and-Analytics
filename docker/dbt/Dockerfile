FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip \
    && pip install dbt-core==1.8.7 dbt-postgres==1.8.2

WORKDIR /usr/app/dbt

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["tail -f /dev/null"]
