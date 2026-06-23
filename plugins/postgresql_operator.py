from airflow.providers.postgres.hooks.postgres import PostgresHook
import pandas as pd
from sqlalchemy import create_engine, inspect, text

class PostgresOperators:
    def __init__(self, conn_id):
        self.conn_id = conn_id
        self.hook = PostgresHook(postgres_conn_id=self.conn_id)

    def get_connection(self):
        return self.hook.get_conn()

    def get_data_to_pd(self, sql):
        return self.hook.get_pandas_df(sql)

    def save_data_to_postgres(self, df, table_name, schema='public', if_exists='replace'):
        conn = self.hook.get_uri()
        engine = create_engine(conn)
        df.to_sql(table_name, engine, schema=schema, if_exists=if_exists, index=False)

    def upsert_dataframe_to_postgres(self, df, table_name, key_columns, schema='public'):
        """
        Incrementally load a DataFrame into PostgreSQL.

        The target table is created on the first run. Later runs load into a temporary
        table and upsert by the configured natural key, so dbt staging views can keep
        referencing stable raw table objects.
        """
        if df.empty:
            print(f"No rows to upsert into {schema}.{table_name}")
            return

        missing_keys = [column for column in key_columns if column not in df.columns]
        if missing_keys:
            raise ValueError(f"Missing key columns for {schema}.{table_name}: {missing_keys}")

        original_count = len(df)
        df = df.drop_duplicates(subset=key_columns, keep='last')
        if len(df) != original_count:
            print(
                f"Deduplicated {schema}.{table_name}: {original_count} -> {len(df)} "
                f"rows by keys {key_columns}"
            )

        conn = self.hook.get_uri()
        engine = create_engine(conn)
        temp_table = f"tmp_{table_name}"

        with engine.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{schema}"'))
            inspector = inspect(connection)

            if not inspector.has_table(table_name, schema=schema):
                df.to_sql(table_name, connection, schema=schema, if_exists='fail', index=False)
            else:
                df.to_sql(temp_table, connection, schema=schema, if_exists='replace', index=False)

                quoted_target = f'"{schema}"."{table_name}"'
                quoted_temp = f'"{schema}"."{temp_table}"'
                key_match = " AND ".join([f't."{column}" = s."{column}"' for column in key_columns])
                update_columns = [column for column in df.columns if column not in key_columns]

                if update_columns:
                    set_clause = ", ".join([f'"{column}" = s."{column}"' for column in update_columns])
                    connection.execute(text(
                        f"""
                        UPDATE {quoted_target} AS t
                        SET {set_clause}
                        FROM {quoted_temp} AS s
                        WHERE {key_match}
                        """
                    ))

                columns = list(df.columns)
                quoted_columns = ", ".join([f'"{column}"' for column in columns])
                source_columns = ", ".join([f's."{column}"' for column in columns])
                null_check = " AND ".join([f't."{column}" IS NULL' for column in key_columns])

                connection.execute(text(
                    f"""
                    INSERT INTO {quoted_target} ({quoted_columns})
                    SELECT {source_columns}
                    FROM {quoted_temp} AS s
                    LEFT JOIN {quoted_target} AS t
                        ON {key_match}
                    WHERE {null_check}
                    """
                ))

                connection.execute(text(f'DROP TABLE IF EXISTS {quoted_temp}'))

    def execute_query(self, sql):
        self.hook.run(sql)
