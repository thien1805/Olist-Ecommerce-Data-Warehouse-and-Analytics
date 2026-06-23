from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.email import EmailOperator
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import LoadMode, TestBehavior
from cosmos.profiles import PostgresUserPasswordProfileMapping
from datetime import datetime, timedelta
from extract_data import extract_and_load_to_staging

# === Email alert config ===
ALERT_EMAILS = ['burizamon@gmail.com']

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 6, 1),
    'email': ALERT_EMAILS,
    'email_on_failure': True,
    'email_on_retry': True,
    'retries': 0,
    'retry_delay': timedelta(minutes=5),
}

DBT_PROJECT = "/opt/airflow/dbt"
DBT_PROFILES = "/home/airflow/.dbt"
DBT_EXECUTABLE = "/home/airflow/.local/bin/dbt"
DBT_MANIFEST = f"{DBT_PROJECT}/target/manifest.json"

dbt_profile_config = ProfileConfig(
    profile_name="dbt_olist",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="postgres",
        profile_args={
            "schema": "warehouse",
        },
    ),
)

with DAG(
    dag_id='e_commerce_elt',
    default_args=default_args,
    description='ELT: Airflow Extract + Cosmos dbt Transform (staging/intermediate/marts)',
    schedule_interval=timedelta(days=1),
    catchup=False,
) as dag:
    # Phase 1: Extract & incremental load (Airflow)
    extract_task = PythonOperator(
        task_id='extract_and_upsert_to_staging',
        python_callable=extract_and_load_to_staging,
    )

    # Phase 2: Transform & test with Astronomer Cosmos
    # Cosmos renders each dbt model/test as an Airflow task, making lineage and failures easier to inspect.
    dbt_transform = DbtTaskGroup(
        group_id='dbt_transform',
        project_config=ProjectConfig(
            dbt_project_path=DBT_PROJECT,
            manifest_path=DBT_MANIFEST,
            install_dbt_deps=False,
        ),
        profile_config=dbt_profile_config,
        execution_config=ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE),
        render_config=RenderConfig(
            emit_datasets=False,
            load_method=LoadMode.DBT_MANIFEST,
            test_behavior=TestBehavior.AFTER_ALL,
            dbt_deps=False,
        ),
        operator_args={
            "install_deps": False,
        },
    )

    # Phase 4: Email thông báo thành công
    send_success_email = EmailOperator(
        task_id='send_success_email',
        to=ALERT_EMAILS,
        subject='[SUCCESS] Olist ELT Pipeline - {{ ds }} - dbt tests passed',
        retries=3,
        retry_delay=timedelta(minutes=2),
        email_on_failure=False,
        html_content="""
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#f4f7fb; border-collapse:collapse; margin:0; padding:0;">
            <tr>
                <td align="center" style="padding:16px 10px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="width:100%; max-width:640px; background:#ffffff; border:1px solid #e5e7eb; border-collapse:collapse; font-family:Arial, Helvetica, sans-serif; color:#1f2937;">
                        <tr>
                            <td style="background:#166534; color:#ffffff; padding:20px 18px;">
                                <div style="font-size:12px; line-height:18px; letter-spacing:.3px; text-transform:uppercase;">
                                    Olist Analytics Platform
                                </div>
                                <div style="font-size:22px; line-height:28px; font-weight:700; margin-top:4px;">
                                    ELT Pipeline Completed Successfully
                                </div>
                                <div style="font-size:14px; line-height:21px; color:#dcfce7; margin-top:8px;">
                                    Dữ liệu đã được extract, upsert, transform và kiểm thử dbt thành công.
                                </div>
                            </td>
                        </tr>

                        <tr>
                            <td style="padding:18px;">
                                <div style="font-size:18px; line-height:24px; font-weight:700; margin-bottom:10px;">
                                    Run Summary
                                </div>

                                <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse; margin-bottom:18px;">
                                    <tr>
                                        <td style="padding:10px 12px; border:1px solid #e5e7eb; background:#f8fafc;">
                                            <div style="font-size:12px; line-height:18px; color:#64748b;">DAG</div>
                                            <div style="font-size:15px; line-height:22px; font-weight:700; word-break:break-word;">{{ dag.dag_id }}</div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding:10px 12px; border:1px solid #e5e7eb;">
                                            <div style="font-size:12px; line-height:18px; color:#64748b;">Business date</div>
                                            <div style="font-size:15px; line-height:22px; font-weight:700;">{{ ds }}</div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding:10px 12px; border:1px solid #e5e7eb; background:#f8fafc;">
                                            <div style="font-size:12px; line-height:18px; color:#64748b;">Run ID</div>
                                            <div style="font-size:12px; line-height:18px; font-family:Consolas, Menlo, monospace; word-break:break-all;">{{ dag_run.run_id }}</div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding:10px 12px; border:1px solid #e5e7eb;">
                                            <div style="font-size:12px; line-height:18px; color:#64748b;">Execution time</div>
                                            <div style="font-size:12px; line-height:18px; font-family:Consolas, Menlo, monospace; word-break:break-all;">{{ ts }}</div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding:10px 12px; border:1px solid #e5e7eb; background:#f8fafc;">
                                            <div style="font-size:12px; line-height:18px; color:#64748b;">Data interval</div>
                                            <div style="font-size:12px; line-height:18px; font-family:Consolas, Menlo, monospace; word-break:break-all;">
                                                {{ data_interval_start }} to {{ data_interval_end }}
                                            </div>
                                        </td>
                                    </tr>
                                </table>

                                <div style="font-size:18px; line-height:24px; font-weight:700; margin-bottom:10px;">
                                    Pipeline Status
                                </div>

                                <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse; margin-bottom:18px;">
                                    <tr>
                                        <td style="padding:12px; border-left:4px solid #16a34a; background:#f0fdf4;">
                                            <div style="font-size:15px; line-height:22px; font-weight:700;">1. Extract & Upsert</div>
                                            <div style="font-size:13px; line-height:20px; color:#475569;">
                                                MySQL Olist source đã được nạp incremental vào PostgreSQL schema <strong>staging</strong>.
                                            </div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding:8px 0;"></td>
                                    </tr>
                                    <tr>
                                        <td style="padding:12px; border-left:4px solid #16a34a; background:#f0fdf4;">
                                            <div style="font-size:15px; line-height:22px; font-weight:700;">2. dbt Transform</div>
                                            <div style="font-size:13px; line-height:20px; color:#475569;">
                                                Cosmos đã chạy dbt models từ staging, intermediate đến marts.
                                            </div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding:8px 0;"></td>
                                    </tr>
                                    <tr>
                                        <td style="padding:12px; border-left:4px solid #16a34a; background:#f0fdf4;">
                                            <div style="font-size:15px; line-height:22px; font-weight:700;">3. dbt Data Tests</div>
                                            <div style="font-size:13px; line-height:20px; color:#475569;">
                                                Task <strong>dbt_transform.dbt_test</strong> đã pass trước khi email này được gửi.
                                            </div>
                                        </td>
                                    </tr>
                                </table>

                                <div style="font-size:18px; line-height:24px; font-weight:700; margin-bottom:10px;">
                                    Warehouse Outputs
                                </div>

                                <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse; margin-bottom:18px;">
                                    <tr>
                                        <td style="padding:12px; border:1px solid #e5e7eb;">
                                            <div style="font-size:15px; line-height:22px; font-weight:700;">staging</div>
                                            <div style="font-size:13px; line-height:20px; color:#475569;">
                                                stg_orders, stg_order_items, stg_payments, stg_customers, stg_products
                                            </div>
                                            <div style="font-size:13px; line-height:20px; color:#64748b; margin-top:4px;">
                                                Raw tables đã được upsert từ MySQL.
                                            </div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding:8px 0;"></td>
                                    </tr>
                                    <tr>
                                        <td style="padding:12px; border:1px solid #e5e7eb;">
                                            <div style="font-size:15px; line-height:22px; font-weight:700;">staging_dbt</div>
                                            <div style="font-size:13px; line-height:20px; color:#475569;">
                                                Cleaned dbt staging views
                                            </div>
                                            <div style="font-size:13px; line-height:20px; color:#64748b; margin-top:4px;">
                                                Chuẩn hóa tên cột, kiểu dữ liệu và logic làm sạch.
                                            </div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding:8px 0;"></td>
                                    </tr>
                                    <tr>
                                        <td style="padding:12px; border:1px solid #e5e7eb;">
                                            <div style="font-size:15px; line-height:22px; font-weight:700;">warehouse</div>
                                            <div style="font-size:13px; line-height:20px; color:#475569;">
                                                dim_*, fact_orders, fact_order_items, agg_*
                                            </div>
                                            <div style="font-size:13px; line-height:20px; color:#64748b; margin-top:4px;">
                                                Bảng phân tích sẵn sàng cho Tableau/BI.
                                            </div>
                                        </td>
                                    </tr>
                                </table>

                                <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse; margin-bottom:18px;">
                                    <tr>
                                        <td style="background:#eff6ff; border:1px solid #bfdbfe; padding:12px;">
                                            <div style="font-size:15px; line-height:22px; font-weight:700; color:#1d4ed8;">BI readiness</div>
                                            <div style="font-size:13px; line-height:20px; color:#334155; margin-top:4px;">
                                                Tableau có thể refresh từ PostgreSQL schema <strong>warehouse</strong>.
                                                Metrics chính: <strong>agg_monthly_sales</strong>,
                                                <strong>agg_product_category_performance</strong>,
                                                <strong>agg_seller_performance</strong>,
                                                <strong>agg_delivery_performance</strong>.
                                            </div>
                                        </td>
                                    </tr>
                                </table>

                                <table role="presentation" cellpadding="0" cellspacing="0" style="border-collapse:collapse; margin-bottom:18px;">
                                    <tr>
                                        <td style="background:#2563eb; padding:12px 16px;">
                                            <a href="http://localhost:8080/dags/e_commerce_elt/grid"
                                               style="display:block; color:#ffffff; text-decoration:none; font-size:14px; line-height:20px; font-weight:700;">
                                                Open Airflow DAG
                                            </a>
                                        </td>
                                    </tr>
                                </table>

                                <div style="font-size:12px; line-height:18px; color:#64748b;">
                                    Đây là email tự động từ Airflow. Email này chỉ được gửi khi toàn bộ pipeline,
                                    bao gồm dbt tests, đã hoàn tất thành công.
                                </div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
        </table>
        """,
    )

    extract_task >> dbt_transform >> send_success_email
