from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator

from mysql_operator import MySQLOperator
from postgresql_operator import PostgresOperators


TABLE_CONFIGS = {
    "product_category_name_translation": ["product_category_name"],
    "geolocation": ["geolocation_zip_code_prefix"],
    "sellers": ["seller_id"],
    "customers": ["customer_id"],
    "products": ["product_id"],
    "orders": ["order_id"],
    "order_items": ["order_id", "order_item_id"],
    "payments": ["order_id", "payment_sequential"],
    "order_reviews": ["review_id", "order_id"],
}


def extract_and_load_to_staging(**kwargs):
    source_operator = MySQLOperator("mysql")
    staging_operator = PostgresOperators("postgres")
    
    # Ensure target schemas exist before pandas.to_sql writes tables.
    staging_operator.execute_query("CREATE SCHEMA IF NOT EXISTS staging;")
    staging_operator.execute_query("CREATE SCHEMA IF NOT EXISTS warehouse;")

    for table, key_columns in TABLE_CONFIGS.items():
        df = source_operator.get_data_to_pd(f"SELECT * FROM {table}")
        staging_operator.upsert_dataframe_to_postgres(
            df,
            f"stg_{table}",
            key_columns=key_columns,
            schema="staging",
        )

        print(
            f"Da upsert {len(df)} dong tu MySQL bang {table} "
            f"vao PostgreSQL staging.stg_{table}"
        )

