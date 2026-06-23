# Docker Compose Services

This document describes the services defined in docker-compose.yaml, where they run, and how the project uses them.

## Overview

All services run as Docker containers on your local machine and share the same Docker network: data_network.

## Services

### mysql
- Purpose: Source operational-like database for raw Olist datasets.
- Image: mysql:8.0
- Ports: 3307 (host) -> 3306 (container)
- Volumes:
  - mysql_h:/var/lib/mysql (persistent MySQL data)
  - ./data/raw:/tmp/data/raw (raw CSV files mounted into container)
  - ./load_dataset_into_mysql:/tmp/load_dataset (SQL scripts for loading)
- Used by: Initial ingestion of raw CSVs into MySQL.

### de_psql
- Purpose: Project data warehouse database.
- Image: postgres:14-alpine
- Ports: 5433 (host) -> 5432 (container)
- Volumes:
  - postgres_data_h:/var/lib/postgresql/data (persistent warehouse data)
  - ./pg_hba.conf:/tmp/pg_hba.conf (custom pg_hba config)
- Used by: Target warehouse schema for staging and marts. dbt models run here.

### postgres (Airflow metadata)
- Purpose: Metadata database for Airflow.
- Image: postgres:13
- Ports: Not published to host; available inside Docker network.
- Volumes:
  - postgres-db-volume:/var/lib/postgresql/data (persistent Airflow metadata)
- Used by: Airflow scheduler/webserver metadata storage.

### airflow-webserver
- Purpose: Airflow UI and API.
- Build: Local Dockerfile in repo root (build: .)
- Ports: 8080 (host) -> 8080 (container)
- Volumes:
  - ./dags:/opt/airflow/dags
  - ./logs:/opt/airflow/logs
  - ./config:/opt/airflow/config
  - ./plugins:/opt/airflow/plugins
- Depends on: postgres (Airflow metadata), airflow-init

### airflow-scheduler
- Purpose: Airflow scheduler for DAG execution.
- Build: Local Dockerfile in repo root (build: .)
- Ports: Not published to host; available inside Docker network.
- Volumes: Same as airflow-webserver.
- Depends on: postgres (Airflow metadata), airflow-init

### airflow-init
- Purpose: One-time initialization for Airflow (DB migration, user creation).
- Build: Local Dockerfile in repo root (build: .)
- Volumes:
  - ./:/sources (project mounted for initialization)
- Runs once during startup, then exits successfully.

### airflow-cli (debug profile)
- Purpose: Debug/CLI access to Airflow.
- Build: Local Dockerfile in repo root (build: .)
- Profile: debug
- Usage: Start only when needed.

### dbt
- Purpose: Transformation tool using dbt.
- Build: docker/dbt/Dockerfile
- Working dir: /usr/app/dbt
- Volumes:
  - ./dbt_olist:/usr/app/dbt (dbt project)
  - ./dbt_olist/profiles:/root/.dbt (dbt profiles)
- Depends on: de_psql
- Usage: Container is started idle (tail -f /dev/null). Run dbt commands with docker exec.

### metabase
- Purpose: BI/analytics dashboard.
- Image: metabase/metabase:latest
- Ports: 3000 (host) -> 3000 (container)
- Volumes:
  - metabase_data:/metabase-data (persistent Metabase data)
- Depends on: de_psql

## How the project uses Docker Compose

1) Start the stack:
   - docker compose up -d

2) Load raw data into MySQL (source system):
   - Use scripts in load_dataset_into_mysql or custom SQL runs.

3) Orchestrate extraction/loading with Airflow:
   - DAGs in dags/ read from MySQL and load into Postgres (de_psql).

4) Transform with dbt:
   - Run dbt models inside the dbt container to build staging and marts in de_psql.

5) Explore with Metabase:
   - Connect Metabase to de_psql and use models from dbt for dashboards.

## Ports Summary

- 8080: Airflow web UI
- 3000: Metabase UI
- 3307: MySQL
- 5433: Postgres warehouse

## Notes

- Airflow metadata database is internal and not exposed to the host.
- All services share the data_network Docker bridge network.
