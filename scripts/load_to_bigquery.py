from pathlib import Path
from google.cloud import bigquery

PROJECT_ID = "olist-analytics-491211"
DATASET_ID = "olist_raw"
BASE_DIR = Path("data/raw")

TABLE_FILES = {
    "olist_orders_dataset": "olist_orders_dataset.csv",
    "olist_customers_dataset": "olist_customers_dataset.csv",
    "olist_order_items_dataset": "olist_order_items_dataset.csv",
    "olist_order_payments_dataset": "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset": "olist_order_reviews_dataset.csv",
    "olist_products_dataset": "olist_products_dataset.csv",
    "olist_sellers_dataset": "olist_sellers_dataset.csv",
    "olist_geolocation_dataset": "olist_geolocation_dataset.csv",
    "product_category_name_translation": "product_category_name_translation.csv",
}

client = bigquery.Client(project=PROJECT_ID)

job_config = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.CSV, #Because the files we are loading are in CSV format, 
    #we need to specify this in the job configuration so that BigQuery can correctly parse the data.
    skip_leading_rows=1, #Skip the first row of the CSV file, which typically contains the header information 
    #(column names). This is important to ensure that the header row is not treated as data 
    #and does not cause issues during the loading process.
    autodetect=True, #Enable schema autodetection, allowing BigQuery to automatically infer the data types of the
     #columns based on the content of the CSV file. This can simplify the loading process and reduce the need 
     #for manual schema definition.
    allow_quoted_newlines=True, #The reviews file contains line breaks inside quoted text fields.
    #This allows BigQuery to treat those embedded newlines as part of the same CSV record.
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE, #if the destination table already exists, 
    #it should be overwritten with the new data.
)

for table_name, file_name in TABLE_FILES.items():
    table_id = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"
    filepath = BASE_DIR / file_name

    with open(filepath, "rb") as source_file:
        load_job = client.load_table_from_file(source_file, table_id, job_config=job_config) 
    
    load_job.result()  # Waits for the job to complete.
    table = client.get_table(table_id)
    print(f"Loaded {table.num_rows} rows into {table_id}.")

