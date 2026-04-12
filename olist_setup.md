# OLIST E-COMMERCE DATA WAREHOUSE PROJECT
## Step-by-Step Implementation Guide

### Dựa trên: https://github.com/nguyenthanhhungDE/Build-data-warehouse-with-Airflow-Python-for-E-commerce

---

## 📋 MỤC LỤC

1. [Giới thiệu Project](#1-giới-thiệu-project)
2. [Prerequisites & Setup](#2-prerequisites--setup)
3. [Clone Repository](#3-clone-repository)
4. [Download Dataset](#4-download-dataset)
5. [Start Docker Services](#5-start-docker-services)
6. [Load Data vào MySQL](#6-load-data-vào-mysql)
7. [Thiết kế Data Warehouse](#7-thiết-kế-data-warehouse)
8. [Airflow DAG Implementation](#8-airflow-dag-implementation)
9. [Power BI Dashboard](#9-power-bi-dashboard)
10. [Tools để vẽ Diagrams](#10-tools-để-vẽ-diagrams)

---

## 1. GIỚI THIỆU PROJECT

### 🎯 Tổng quan

Project này xây dựng **End-to-End Data Warehouse** cho dữ liệu E-commerce từ dataset Olist (Brazil). 

**Điểm mạnh**:
- ✅ **Đơn giản hơn Stock Market project** - không cần Hadoop/Spark
- ✅ **Chạy hoàn toàn local** - Docker Compose, không cần GCP
- ✅ **Production-ready architecture** - ELT pattern chuẩn công nghiệp
- ✅ **Perfect for beginners** - clear steps, good documentation

### 🏗️ Architecture Overview

```
┌──────────────┐
│  Olist CSV   │  Raw Data (9 files)
│   Dataset    │
└──────┬───────┘
       │ Python Script
       ▼
┌──────────────┐
│    MySQL     │  Source Database (OLTP)
│  (Port 3306) │  Simulated production DB
└──────┬───────┘
       │ Airflow DAG: Extract → Load
       ▼
┌──────────────┐
│ PostgreSQL   │  Staging Area
│  (Port 5433) │  Temporary storage
└──────┬───────┘
       │ Airflow DAG: Transform → Load
       ▼
┌──────────────┐
│ PostgreSQL   │  Data Warehouse (Star Schema)
│  (Port 5434) │  Analytics-ready
└──────┬───────┘
       │ Direct Connect
       ▼
┌──────────────┐
│  Power BI    │  Dashboards & Reports
│ (Analytics)  │
└──────────────┘

All orchestrated by Apache Airflow
```

### 🛠️ Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Container Platform** | Docker + Docker Compose | Orchestrate all services |
| **Source Database** | MySQL 8.0 | OLTP database (simulated) |
| **Staging Area** | PostgreSQL 13 | Temporary data storage |
| **Data Warehouse** | PostgreSQL 13 | Final analytics database |
| **Orchestration** | Apache Airflow 2.7 | Workflow automation |
| **Programming** | Python 3.10+ | ETL scripts |
| **Visualization** | Power BI Desktop | Dashboards & reports |
| **Version Control** | Git/GitHub | Code management |

---

## 2. PREREQUISITES & SETUP

### 📦 System Requirements

| Requirement | Specification |
|------------|---------------|
| **Operating System** | Windows 10/11, macOS, or Linux |
| **RAM** | 8GB minimum, 16GB recommended |
| **Disk Space** | 20GB free space |
| **Docker Desktop** | Latest version (4.x+) |
| **Python** | 3.10 or higher |
| **Git** | Latest version |
| **Power BI Desktop** | Latest version (Windows only) |
| **Text Editor** | VS Code recommended |

### 🐳 Cài đặt Docker Desktop

#### Windows:
1. Download Docker Desktop từ https://www.docker.com/products/docker-desktop
2. Chạy installer, chọn "Install required Windows components for WSL 2"
3. Restart máy sau khi cài đặt
4. Mở Docker Desktop, verify status = Running

#### macOS:
```bash
# Using Homebrew
brew install --cask docker

# Or download from website
# https://www.docker.com/products/docker-desktop
```

#### Linux (Ubuntu):
```bash
# Install Docker Engine
sudo apt update
sudo apt install docker.io docker-compose -y

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker-compose --version
```

### 🐍 Cài đặt Python & Tools

```bash
# Verify Python version
python --version  # Should be 3.10+

# Install pip if needed
python -m ensurepip --upgrade

# Install essential packages
pip install pandas sqlalchemy pymysql psycopg2-binary kaggle

# Verify installations
python -c "import pandas; print(pandas.__version__)"
python -c "import sqlalchemy; print(sqlalchemy.__version__)"
```

### 🔑 Setup Kaggle API

Để download Olist dataset:

1. Đăng nhập **Kaggle.com**
2. Vào **Account Settings → API → Create New API Token**
3. Download file **kaggle.json**

**Windows:**
```cmd
# Create .kaggle folder
mkdir %USERPROFILE%\.kaggle

# Copy kaggle.json
copy Downloads\kaggle.json %USERPROFILE%\.kaggle\
```

**macOS/Linux:**
```bash
# Create .kaggle folder
mkdir -p ~/.kaggle

# Move kaggle.json
mv ~/Downloads/kaggle.json ~/.kaggle/

# Set permissions
chmod 600 ~/.kaggle/kaggle.json
```

---

## 3. CLONE REPOSITORY

### 📥 Clone GitHub Repository

```bash
# Clone the repository
git clone https://github.com/nguyenthanhhungDE/Build-data-warehouse-with-Airflow-Python-for-E-commerce.git

# Navigate to project folder
cd Build-data-warehouse-with-Airflow-Python-for-E-commerce

# Check project structure
ls -la
```

### 📁 Project Structure

```
Build-data-warehouse-with-Airflow-Python-for-E-commerce/
├── dags/                          # Airflow DAG files
│   ├── elt_pipeline.py           # Main ELT workflow
│   └── (other DAGs)
│
├── dataset/                       # Olist CSV files (9 files)
│   ├── olist_customers_dataset.csv
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   └── ... (6 other files)
│
├── load_dataset_into_mysql/      # Scripts to load CSV → MySQL
│   ├── load_data.py
│   └── create_tables.sql
│
├── plugins/                       # Airflow custom operators/hooks
│   ├── operators/
│   └── hooks/
│
├── docker-compose.yaml            # Docker services definition
├── Dockerfile                     # Custom Airflow image
├── requirements.txt               # Python dependencies
├── .env                          # Environment variables
├── pg_hba.conf                   # PostgreSQL configuration
├── query.sql                     # Sample DW queries
├── makefile                      # Helper commands
└── README.md                     # Documentation
```

### 🔍 Phân tích Components chính

**docker-compose.yaml**
- Định nghĩa tất cả services: Airflow, MySQL, PostgreSQL (staging & DW)

**dags/**
- Chứa Airflow DAG files
- Main ELT pipeline logic

**plugins/**
- Custom Airflow operators và hooks
- Helper functions cho data processing

**.env**
- Environment variables cho databases
- Credentials cho MySQL, PostgreSQL

---

## 4. DOWNLOAD DATASET

### 📊 Download via Kaggle CLI

```bash
# Navigate to dataset folder
cd dataset/

# Download dataset từ Kaggle
kaggle datasets download -d olistbr/brazilian-ecommerce

# Unzip downloaded file
unzip brazilian-ecommerce.zip

# Verify files (should have 9 CSV files)
ls -la *.csv
```

### ✅ Verify Dataset Files

Bạn phải có đủ **9 files** sau:

| File Name | Approx. Rows |
|-----------|--------------|
| olist_customers_dataset.csv | ~99,441 |
| olist_geolocation_dataset.csv | ~1,000,163 |
| olist_order_items_dataset.csv | ~112,650 |
| olist_order_payments_dataset.csv | ~103,886 |
| olist_order_reviews_dataset.csv | ~99,224 |
| olist_orders_dataset.csv | ~99,441 |
| olist_products_dataset.csv | ~32,951 |
| olist_sellers_dataset.csv | ~3,095 |
| product_category_name_translation.csv | 71 |

### 🧪 Validate Data Quality

Tạo script `validate_dataset.py`:

```python
#!/usr/bin/env python3
"""Validate Olist Dataset"""
import pandas as pd
import os

dataset_files = [
    'olist_customers_dataset.csv',
    'olist_orders_dataset.csv',
    'olist_order_items_dataset.csv',
    'olist_products_dataset.csv',
    'olist_sellers_dataset.csv',
    'olist_geolocation_dataset.csv',
    'olist_order_payments_dataset.csv',
    'olist_order_reviews_dataset.csv',
    'product_category_name_translation.csv'
]

print("Validating Olist Dataset...")
print("=" * 60)

for file in dataset_files:
    if not os.path.exists(file):
        print(f"❌ MISSING: {file}")
        continue
    
    df = pd.read_csv(file, nrows=5)
    file_size = os.path.getsize(file) / (1024 * 1024)  # MB
    
    print(f"✓ {file}")
    print(f"  Rows (sample): {len(df)}")
    print(f"  Columns: {len(df.columns)}")
    print(f"  Size: {file_size:.2f} MB")
    print(f"  Column names: {', '.join(df.columns[:5])}...")
    print()

print("Validation complete!")
```

Chạy validation:
```bash
cd dataset/
python validate_dataset.py
```

---

## 5. START DOCKER SERVICES

### 🐋 Review docker-compose.yaml

```bash
# View docker-compose.yaml
cat docker-compose.yaml

# Key services được định nghĩa:
# - postgres (Airflow metadata - port 5432)
# - mysql (Source database - port 3306)
# - postgres-staging (Staging area - port 5433)
# - postgres-dw (Data Warehouse - port 5434)
# - airflow-webserver (UI - port 8080)
# - airflow-scheduler (Task executor)
```

### 🚀 Build & Start Services

```bash
# Make sure you're in project root
cd Build-data-warehouse-with-Airflow-Python-for-E-commerce/

# Build custom Airflow image (first time only)
docker-compose build

# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# Expected output: All services should be "Up" or "healthy"
```

### ✓ Verify Services Running

**Check Docker logs:**
```bash
# View logs for all services
docker-compose logs

# View specific service logs
docker-compose logs airflow-webserver
docker-compose logs mysql
docker-compose logs postgres-staging

# Follow logs in real-time
docker-compose logs -f airflow-scheduler
```

**Test database connections:**
```bash
# Connect to MySQL
docker exec -it <mysql-container-id> mysql -uroot -p
# Password from .env file

# Connect to PostgreSQL Staging
docker exec -it <postgres-staging-container-id> psql -U airflow -d staging

# Connect to PostgreSQL DW
docker exec -it <postgres-dw-container-id> psql -U airflow -d datawarehouse

# Exit from database
\q
```

**Access Airflow UI:**
1. Mở browser: **http://localhost:8080**
2. Login: **Username: airflow, Password: airflow**
3. Bạn sẽ thấy Airflow dashboard

### 🔧 Troubleshooting Common Issues

| Problem | Solution |
|---------|----------|
| Port 8080 already in use | Stop other services using port 8080 hoặc change port in docker-compose.yaml |
| Docker out of memory | Increase Docker memory in Docker Desktop Settings → Resources → Memory (recommend 4GB+) |
| Services not starting | Run: `docker-compose down -v && docker-compose up -d` |
| Cannot connect to database | Check .env file credentials match docker-compose.yaml |

---

## 6. LOAD DATA VÀO MYSQL

### 🎯 Mục đích

MySQL database đóng vai trò **OLTP production database**. Trong real-world, data sẽ được generate liên tục từ web application. Ở đây ta **simulate** bằng cách load CSV vào MySQL.

### 🗄️ Create MySQL Tables Schema

File: `load_dataset_into_mysql/create_tables.sql`

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS olist_source;
USE olist_source;

-- Table 1: Customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(2)
);

-- Table 2: Orders
CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(20),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Table 3: Order Items
CREATE TABLE IF NOT EXISTS order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- Table 4: Products
CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

-- Table 5: Sellers
CREATE TABLE IF NOT EXISTS sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(2)
);

-- Table 6: Geolocation
CREATE TABLE IF NOT EXISTS geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(10,8),
    geolocation_lng DECIMAL(10,8),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(2)
);

-- Table 7: Order Payments
CREATE TABLE IF NOT EXISTS order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(20),
    payment_installments INT,
    payment_value DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- Table 8: Order Reviews
CREATE TABLE IF NOT EXISTS order_reviews (
    review_id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);

-- Table 9: Product Category Translation
CREATE TABLE IF NOT EXISTS product_category_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);
```

### 📝 Load Data Script

File: `load_dataset_into_mysql/load_data.py`

```python
#!/usr/bin/env python3
"""
Load Olist CSV data into MySQL database
"""
import pandas as pd
import pymysql
from sqlalchemy import create_engine
import os
from pathlib import Path

# Database connection
MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
MYSQL_PORT = int(os.getenv('MYSQL_PORT', 3306))
MYSQL_USER = os.getenv('MYSQL_USER', 'root')
MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', 'your_password')
MYSQL_DATABASE = 'olist_source'

# Create connection string
connection_string = f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DATABASE}"
engine = create_engine(connection_string)

# Dataset folder
DATASET_DIR = Path('../dataset')

# Table mapping: CSV filename -> MySQL table name
table_mapping = {
    'olist_customers_dataset.csv': 'customers',
    'olist_orders_dataset.csv': 'orders',
    'olist_order_items_dataset.csv': 'order_items',
    'olist_products_dataset.csv': 'products',
    'olist_sellers_dataset.csv': 'sellers',
    'olist_geolocation_dataset.csv': 'geolocation',
    'olist_order_payments_dataset.csv': 'order_payments',
    'olist_order_reviews_dataset.csv': 'order_reviews',
    'product_category_name_translation.csv': 'product_category_translation'
}

def load_csv_to_mysql(csv_file, table_name):
    """Load single CSV file into MySQL table"""
    print(f"Loading {csv_file} into {table_name}...")
    
    csv_path = DATASET_DIR / csv_file
    
    if not csv_path.exists():
        print(f"  ❌ File not found: {csv_path}")
        return
    
    # Read CSV
    df = pd.read_csv(csv_path, low_memory=False)
    
    # Handle datetime columns
    date_columns = [col for col in df.columns if 'date' in col.lower() or 'timestamp' in col.lower()]
    for col in date_columns:
        df[col] = pd.to_datetime(df[col], errors='coerce')
    
    # Load to MySQL
    try:
        df.to_sql(
            name=table_name,
            con=engine,
            if_exists='replace',  # Replace if table exists
            index=False,
            chunksize=1000
        )
        print(f"  ✓ Loaded {len(df)} rows into {table_name}")
        
    except Exception as e:
        print(f"  ❌ Error loading {table_name}: {e}")

def main():
    print("=" * 60)
    print("Loading Olist Dataset into MySQL")
    print("=" * 60)
    
    # Test connection
    try:
        connection = engine.connect()
        print("✓ Successfully connected to MySQL")
        connection.close()
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return
    
    # Load each CSV file
    for csv_file, table_name in table_mapping.items():
        load_csv_to_mysql(csv_file, table_name)
    
    print("=" * 60)
    print("Data loading complete!")
    print("=" * 60)
    
    # Verify data
    print("\nTable row counts:")
    with engine.connect() as conn:
        for table_name in table_mapping.values():
            result = conn.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = result.fetchone()[0]
            print(f"  {table_name}: {count:,} rows")

if __name__ == "__main__":
    main()
```

### ▶️ Execute Load Process

```bash
# Navigate to load folder
cd load_dataset_into_mysql/

# Set environment variables
export MYSQL_HOST=localhost
export MYSQL_PASSWORD=your_password

# Run load script
python load_data.py
```

### ✅ Verify Data in MySQL

```bash
# Connect to MySQL container
docker exec -it <mysql-container-name> mysql -uroot -p

# Use database
USE olist_source;

# Check tables
SHOW TABLES;

# Sample data
SELECT * FROM customers LIMIT 5;

# Check order statistics
SELECT 
    order_status,
    COUNT(*) as count
FROM orders
GROUP BY order_status;

# Exit
exit;
```

---

## 7. THIẾT KẾ DATA WAREHOUSE

### ⭐ Star Schema Design

Project này sử dụng **Star Schema** - mô hình phổ biến nhất cho DW vì:
- ✅ Đơn giản, dễ hiểu
- ✅ Performance tốt (ít joins)
- ✅ Phù hợp BI tools (Power BI, Tableau)

### 📊 Dimension Tables

```sql
-- 1. dim_customers
CREATE TABLE dim_customers (
    customer_key SERIAL PRIMARY KEY,
    customer_id VARCHAR(50) UNIQUE,
    customer_unique_id VARCHAR(50),
    customer_city VARCHAR(100),
    customer_state VARCHAR(2),
    customer_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(10,8),
    geolocation_lng DECIMAL(10,8)
);

-- 2. dim_products
CREATE TABLE dim_products (
    product_key SERIAL PRIMARY KEY,
    product_id VARCHAR(50) UNIQUE,
    product_category VARCHAR(100),
    product_category_english VARCHAR(100),
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

-- 3. dim_sellers
CREATE TABLE dim_sellers (
    seller_key SERIAL PRIMARY KEY,
    seller_id VARCHAR(50) UNIQUE,
    seller_city VARCHAR(100),
    seller_state VARCHAR(2),
    seller_zip_code_prefix VARCHAR(10)
);

-- 4. dim_date
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE,
    day INT,
    month INT,
    quarter INT,
    year INT,
    day_of_week INT,
    day_name VARCHAR(10),
    month_name VARCHAR(10),
    is_weekend BOOLEAN
);
```

### 📈 Fact Tables

```sql
-- Fact: Sales/Orders
CREATE TABLE fact_sales (
    sale_key SERIAL PRIMARY KEY,
    order_id VARCHAR(50),
    customer_key INT REFERENCES dim_customers(customer_key),
    product_key INT REFERENCES dim_products(product_key),
    seller_key INT REFERENCES dim_sellers(seller_key),
    order_date_key INT REFERENCES dim_date(date_key),
    approved_date_key INT REFERENCES dim_date(date_key),
    delivered_date_key INT REFERENCES dim_date(date_key),
    
    -- Metrics
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    total_value DECIMAL(10,2),
    payment_value DECIMAL(10,2),
    payment_installments INT,
    
    -- Order info
    order_status VARCHAR(20),
    review_score INT
);
```

### 🗺️ Star Schema Diagram

```
           dim_date
               |
               |
dim_customers --+-- fact_sales --+-- dim_products
               |                 |
               |                 |
          dim_sellers       (other dims)
```

---

## 8. AIRFLOW DAG IMPLEMENTATION

### 🔄 ELT DAG Structure

File: `dags/elt_pipeline.py`

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.mysql.hooks.mysql import MySqlHook
from airflow.providers.postgres.hooks.postgres import PostgresHook
from datetime import datetime, timedelta
import pandas as pd

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'olist_elt_pipeline',
    default_args=default_args,
    description='ELT pipeline for Olist e-commerce data',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['olist', 'elt']
)

# Task 1: Extract from MySQL to Staging
def extract_to_staging(**kwargs):
    """Extract data from MySQL source to PostgreSQL staging"""
    mysql_hook = MySqlHook(mysql_conn_id='mysql_source')
    postgres_hook = PostgresHook(postgres_conn_id='postgres_staging')
    
    tables = ['customers', 'orders', 'order_items', 'products', 
              'sellers', 'order_payments', 'order_reviews']
    
    for table in tables:
        # Extract from MySQL
        df = mysql_hook.get_pandas_df(f"SELECT * FROM {table}")
        
        # Load to Staging
        postgres_hook.insert_rows(
            table=f"staging_{table}",
            rows=df.values.tolist(),
            target_fields=df.columns.tolist()
        )
        print(f"Loaded {len(df)} rows into staging_{table}")

extract_task = PythonOperator(
    task_id='extract_to_staging',
    python_callable=extract_to_staging,
    dag=dag
)

# Task 2: Transform & Load to DW
def transform_load_dw(**kwargs):
    """Transform staging data and load to data warehouse"""
    staging_hook = PostgresHook(postgres_conn_id='postgres_staging')
    dw_hook = PostgresHook(postgres_conn_id='postgres_dw')
    
    # Build dim_customers
    customers_sql = """
        INSERT INTO dim_customers (customer_id, customer_city, customer_state)
        SELECT DISTINCT 
            customer_id, 
            customer_city, 
            customer_state
        FROM staging_customers
        ON CONFLICT (customer_id) DO NOTHING
    """
    dw_hook.run(customers_sql)
    
    # Build fact_sales
    sales_sql = """
        INSERT INTO fact_sales (
            order_id, customer_key, product_key, seller_key,
            price, freight_value, total_value, order_status
        )
        SELECT 
            o.order_id,
            c.customer_key,
            p.product_key,
            s.seller_key,
            oi.price,
            oi.freight_value,
            (oi.price + oi.freight_value) as total_value,
            o.order_status
        FROM staging_orders o
        JOIN staging_order_items oi ON o.order_id = oi.order_id
        JOIN dim_customers c ON o.customer_id = c.customer_id
        JOIN dim_products p ON oi.product_id = p.product_id
        JOIN dim_sellers s ON oi.seller_id = s.seller_id
        WHERE NOT EXISTS (
            SELECT 1 FROM fact_sales WHERE order_id = o.order_id
        )
    """
    dw_hook.run(sales_sql)

transform_task = PythonOperator(
    task_id='transform_load_dw',
    python_callable=transform_load_dw,
    dag=dag
)

# Define dependencies
extract_task >> transform_task
```

### 🔗 Setup Airflow Connections

Trong Airflow UI (http://localhost:8080):

1. **Admin → Connections → + (Add new connection)**

**Connection 1: mysql_source**
- Conn Id: `mysql_source`
- Conn Type: `MySQL`
- Host: `mysql`
- Schema: `olist_source`
- Login: `root`
- Password: `<from .env>`
- Port: `3306`

**Connection 2: postgres_staging**
- Conn Id: `postgres_staging`
- Conn Type: `Postgres`
- Host: `postgres-staging`
- Schema: `staging`
- Login: `airflow`
- Password: `airflow`
- Port: `5433`

**Connection 3: postgres_dw**
- Conn Id: `postgres_dw`
- Conn Type: `Postgres`
- Host: `postgres-dw`
- Schema: `datawarehouse`
- Login: `airflow`
- Password: `airflow`
- Port: `5434`

### ▶️ Run DAG

1. Trong Airflow UI, tìm DAG **'olist_elt_pipeline'**
2. Toggle switch để **enable DAG**
3. Click **'Trigger DAG'** để run manually
4. Monitor task execution trong **Graph View**
5. Check logs nếu có errors

---

## 9. POWER BI DASHBOARD

### 🔌 Connect Power BI to PostgreSQL

1. Mở **Power BI Desktop**
2. **Get Data → PostgreSQL database**
3. **Server**: `localhost:5434`
4. **Database**: `datawarehouse`
5. **Credentials**: `airflow / airflow`
6. Select tables: `fact_sales`, `dim_customers`, `dim_products`, `dim_sellers`, `dim_date`

### 🔗 Create Relationships

Trong **Model view**, tạo relationships:
- `fact_sales.customer_key` → `dim_customers.customer_key`
- `fact_sales.product_key` → `dim_products.product_key`
- `fact_sales.seller_key` → `dim_sellers.seller_key`
- `fact_sales.order_date_key` → `dim_date.date_key`

### 📊 Build Dashboards

**Dashboard 1: Sales Overview**
- Total Sales (Card visual)
- Sales Trend (Line chart by month)
- Top Products (Bar chart)
- Sales by State (Map visual)

**Dashboard 2: Customer Analytics**
- Total Customers (Card)
- Customer Distribution by State (Pie chart)
- Average Order Value (Gauge)
- Review Score Distribution (Column chart)

---

## 10. TOOLS ĐỂ VẼ DIAGRAMS

### 🎨 Công cụ vẽ sơ đồ

Các sơ đồ trong README được vẽ bằng:

#### **1. Draw.io (diagrams.net)** ⭐ RECOMMENDED
- **FREE**, web-based, dễ sử dụng nhất
- Website: https://app.diagrams.net/
- Có sẵn templates cho: Flowcharts, ER diagrams, Cloud architecture
- Export: PNG, SVG, PDF

#### **2. Lucidchart**
- Professional, có free tier
- Website: https://www.lucidchart.com/
- Nhiều templates chuyên nghiệp

#### **3. dbdiagram.io**
- Chuyên vẽ ERD từ code
- Website: https://dbdiagram.io/
- Syntax đơn giản, export PNG/PDF

### 📝 Hướng dẫn vẽ với Draw.io

1. Mở https://app.diagrams.net/
2. Chọn **'Create New Diagram'** → **Blank Diagram**
3. Từ sidebar bên trái, kéo shapes:
   - **Rectangle** (cho tables)
   - **Diamond** (cho decisions)
   - **Arrows** (cho relationships)
4. Vẽ **Fact table ở giữa**, **Dimension tables xung quanh**
5. Nối các tables bằng **arrows** (1-to-many relationships)
6. Export: **File → Export as → PNG**

### 🎯 Tips vẽ Star Schema

- **Fact table**: Hình chữ nhật lớn, màu sáng (yellow/orange)
- **Dimension tables**: Hình chữ nhật nhỏ hơn, màu xanh/blue
- **Arrows**: Từ Dimension → Fact (many-to-one)
- **Labels**: Tên table rõ ràng, font size đủ lớn

---

## ✅ CHECKLIST HOÀN THÀNH

- [ ] Docker Desktop installed và running
- [ ] Olist dataset downloaded (9 CSV files)
- [ ] All Docker services running (MySQL, PostgreSQL, Airflow)
- [ ] Data loaded vào MySQL source database
- [ ] Star Schema created trong PostgreSQL DW
- [ ] Airflow DAG running successfully
- [ ] Power BI dashboards created

---

## 🚀 NEXT STEPS & ENHANCEMENTS

### Phase 2: Advanced Features

1. **Incremental Loading** - Implement CDC (Change Data Capture)
2. **Data Quality** - Add Great Expectations tests
3. **Advanced Analytics** - RFM segmentation, cohort analysis
4. **Machine Learning** - Churn prediction model
5. **CI/CD** - GitHub Actions for automated testing

### Learning Resources

- **Hadoop Documentation**: https://hadoop.apache.org/docs/
- **Airflow Best Practices**: https://airflow.apache.org/docs/
- **PostgreSQL Tutorial**: https://www.postgresqltutorial.com/
- **Power BI Guides**: https://learn.microsoft.com/en-us/power-bi/

---

## 📞 SUPPORT & COMMUNITY

- **GitHub Issues**: Report bugs hoặc request features
- **Stack Overflow**: Tag `apache-airflow`, `postgresql`, `data-engineering`
- **LinkedIn**: Share your project khi hoàn thành!

---

## 🎉 CONGRATULATIONS!

Bạn đã hoàn thành **End-to-End Data Warehouse Project**!

**Keep learning, keep building!** 💪

---

**Document created**: 2026-03-05  
**Version**: 1.0  
**Based on**: https://github.com/nguyenthanhhungDE/Build-data-warehouse-with-Airflow-Python-for-E-commerce