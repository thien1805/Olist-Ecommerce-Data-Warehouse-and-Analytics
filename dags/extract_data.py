from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator

from mysql_operator import MySQLOperator
from postgresql_operator import PostgresOperators


def extract_and_load_to_staging(**kwargs):
    source_operator = MySQLOperator("mysql")
    staging_operator = PostgresOperators("postgres")

    # Ensure target schemas exist before pandas.to_sql writes tables.
    staging_operator.execute_query("CREATE SCHEMA IF NOT EXISTS staging;")
    staging_operator.execute_query("CREATE SCHEMA IF NOT EXISTS warehouse;")

    tables = [
        "product_category_name_translation",
        "geolocation",
        "sellers",
        "customers",
        "products",
        "orders",
        "order_items",
        "payments",
        "order_reviews",
    ]

    for table in tables:
        df = source_operator.get_data_to_pd(f"SELECT * FROM {table}")
        staging_operator.save_data_to_postgres(
            df,
            f"stg_{table}",
            schema="staging",
            if_exists="replace",
        )

        print(f"Da trich xuat va luu bang {table} tu MySQL vao PostgreSQL schema staging")


