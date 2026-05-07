from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.utils.task_group import TaskGroup
from datetime import datetime, timedelta
from extract_data import extract_and_load_to_staging

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 6, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

DBT_PROJECT = "/opt/airflow/dbt"
DBT_PROFILES = "/home/airflow/.dbt"

with DAG(
    dag_id='e_commerce_elt',
    default_args=default_args,
    description='ELT: Airflow Extract + dbt Transform (3-layer)',
    schedule_interval=timedelta(days=1),
    catchup=False,
) as dag:

    # Phase 0: Drop dbt staging views trước khi extract
    # (Views trong staging_dbt phụ thuộc vào raw tables trong staging,
    #  nếu không drop trước thì Airflow không thể REPLACE raw tables)
    drop_dbt_views = BashOperator(
        task_id='drop_dbt_staging_views',
        bash_command=(
            "dbt run-operation drop_staging_views "
            f"--project-dir {DBT_PROJECT} --profiles-dir {DBT_PROFILES} "
            "2>/dev/null || true"
        ),
    )

    # Phase 1: Extract & Load (Airflow)
    extract_task = PythonOperator(
        task_id='extract_and_load_to_staging',
        python_callable=extract_and_load_to_staging,
    )

    # Phase 2: Install dbt packages
    dbt_deps = BashOperator(
        task_id='dbt_deps',
        bash_command=f"dbt deps --project-dir {DBT_PROJECT} --profiles-dir {DBT_PROFILES}",
    )

    # Phase 3: Transform with dbt
    dbt_run = BashOperator(
        task_id='dbt_run',
        bash_command=f"dbt run --project-dir {DBT_PROJECT} --profiles-dir {DBT_PROFILES}",
    )

    # Phase 4: Test data quality
    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command=f"dbt test --project-dir {DBT_PROJECT} --profiles-dir {DBT_PROFILES}",
    )

    drop_dbt_views >> extract_task >> dbt_deps >> dbt_run >> dbt_test