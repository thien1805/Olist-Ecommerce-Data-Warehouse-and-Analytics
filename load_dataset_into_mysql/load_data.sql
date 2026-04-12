LOAD DATA local INFILE '/var/lib/mysql-files/raw/product_category_name_translation.csv'
INTO TABLE product_category_name_translation FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA local INFILE '/var/lib/mysql-files/raw/olist_sellers_dataset.csv'
INTO TABLE sellers FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA local INFILE '/var/lib/mysql-files/raw/olist_customers_dataset.csv'
INTO TABLE customers FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA local INFILE '/var/lib/mysql-files/raw/olist_products_dataset.csv'
INTO TABLE products FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
	
LOAD DATA local INFILE '/var/lib/mysql-files/raw/olist_orders_dataset.csv'
INTO TABLE orders FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA local INFILE '/var/lib/mysql-files/raw/olist_order_items_dataset.csv'
INTO TABLE order_items FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA local INFILE '/var/lib/mysql-files/raw/olist_order_payments_dataset.csv'
INTO TABLE payments FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA local INFILE '/var/lib/mysql-files/raw/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA local INFILE '/var/lib/mysql-files/raw/olist_geolocation_dataset.csv'
INTO TABLE geolocation FIELDS TERMINATED BY ',' enclosed by '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS;