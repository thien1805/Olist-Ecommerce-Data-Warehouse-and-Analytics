import pandas as pd
from postgresql_operator import PostgresOperators

def transform_fact_orders():
    staging_operator = PostgresOperators('postgres')
    warehouse_operator = PostgresOperators('postgres')

    # Đọc dữ liệu từ staging
    df_orders = staging_operator.get_data_to_pd("SELECT * FROM staging.stg_orders")
    df_order_items = staging_operator.get_data_to_pd("SELECT * FROM staging.stg_order_items")
    df_order_payments = staging_operator.get_data_to_pd("SELECT * FROM staging.stg_payments")
    df_customers = staging_operator.get_data_to_pd("SELECT customer_id, customer_zip_code_prefix FROM staging.stg_customers")

    # Đọc các dimension trong warehouse để map surrogate key cho fact
    dim_customers = warehouse_operator.get_data_to_pd(
        "SELECT customer_id, customer_key FROM warehouse.dim_customers"
    )
    dim_products = warehouse_operator.get_data_to_pd(
        "SELECT product_id, product_key FROM warehouse.dim_products"
    )
    dim_sellers = warehouse_operator.get_data_to_pd(
        "SELECT seller_id, seller_key FROM warehouse.dim_sellers"
    )
    dim_geolocation = warehouse_operator.get_data_to_pd(
        "SELECT geolocation_zip_code_prefix, geolocation_key FROM warehouse.dim_geolocation"
    )
    dim_payments = warehouse_operator.get_data_to_pd(
        "SELECT order_id, payment_sequential, payment_key FROM warehouse.dim_payments"
    )
    dim_dates = warehouse_operator.get_data_to_pd(
        "SELECT date_key FROM warehouse.dim_dates"
    )

    # Kết hợp dữ liệu
    df = pd.merge(df_orders, df_order_items, on='order_id', how='left')
    df = pd.merge(df, df_order_payments, on='order_id', how='left')
    df = pd.merge(df, df_customers, on='customer_id', how='left')

    #Kiểm tra các cột trong DataFrame
    print("Các cột trong DataFrame sau khi merge:")
    print(df.columns)

    #Transform và làm sạch dữ liệu 
    df['order_status'] =  df['order_status'].str.lower()
    df['order_purchase_timestamp'] = pd.to_datetime(df['order_purchase_timestamp'])
    df['order_approved_at' ] = pd.to_datetime(df['order_approved_at'])
    df['order_delivered_carrier_date'] = pd.to_datetime(df['order_delivered_carrier_date'])
    df['order_delivered_customer_date'] = pd.to_datetime(df['order_delivered_customer_date'])
    df['order_estimated_delivery_date'] = pd.to_datetime(df['order_estimated_delivery_date'])
    
    # TÍnh toán các metrics
    df['total_amount'] = df['price'] * df['freight_value']
    df['delivery_time'] = (df['order_delivered_customer_date'] - df['order_purchase_timestamp']).dt.total_seconds() / 86400
    df['estimated_delivery_time'] = (df['order_estimated_delivery_date'] - df['order_purchase_timestamp']).dt.total_seconds() / 86400

    # Chuẩn hóa key business để join với các dimension
    df['customer_zip_code_prefix'] = df['customer_zip_code_prefix'].astype(str).str.zfill(5)
    dim_geolocation['geolocation_zip_code_prefix'] = dim_geolocation['geolocation_zip_code_prefix'].astype(str).str.zfill(5)
    dim_dates['date_key'] = pd.to_datetime(dim_dates['date_key']).dt.date
    df['order_date_key'] = df['order_purchase_timestamp'].dt.date

    # Map surrogate keys từ dimension
    df = pd.merge(df, dim_customers, on='customer_id', how='left')
    df = pd.merge(df, dim_products, on='product_id', how='left')
    df = pd.merge(df, dim_sellers, on='seller_id', how='left')
    df = pd.merge(
        df,
        dim_geolocation,
        left_on='customer_zip_code_prefix',
        right_on='geolocation_zip_code_prefix',
        how='left'
    )
    df = pd.merge(df, dim_payments, on=['order_id', 'payment_sequential'], how='left')
    df = pd.merge(df, dim_dates, left_on='order_date_key', right_on='date_key', how='left')

    # Dùng date_key từ dim_dates làm FK chuẩn cho fact
    df['order_date_key'] = df['date_key']

    # Giữ kiểu số nguyên nullable cho các surrogate keys
    for key_col in ['customer_key', 'product_key', 'seller_key', 'geolocation_key', 'payment_key']:
        df[key_col] = df[key_col].astype('Int64')

    #Chọn các cột cần thiết trong bảng fact
    fact_columns = ['order_id', 'customer_key', 'product_key', 'seller_key', 'geolocation_key', 'payment_key', 'order_date_key',
                    'order_status', 'price', 'freight_value', 'total_amount', 'payment_value',
                    'delivery_time', 'estimated_delivery_time']
    
    df_fact = df[fact_columns]

    # Lưu dữ liệu vào bảng fact_orders
    warehouse_operator.save_data_to_postgres(
        df_fact,
        'fact_orders',
        schema='warehouse',
        if_exists='replace'
    )
    
    print("Đã transform và lưu dữ liệu vào fact_orders")