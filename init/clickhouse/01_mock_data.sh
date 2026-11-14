clickhouse-client --password "$CLICKHOUSE_PASSWORD" --multiquery <<'SQL'
CREATE DATABASE IF NOT EXISTS raw;

CREATE TABLE raw.mock_data
(
    id Int32,
    customer_first_name String,
    customer_last_name String,
    customer_age Int32,
    customer_email String,
    customer_country String,
    customer_postal_code Nullable(String),
    customer_pet_type String,
    customer_pet_name String,
    customer_pet_breed String,
    seller_first_name String,
    seller_last_name String,
    seller_email String,
    seller_country String,
    seller_postal_code Nullable(String),
    product_name String,
    product_category String,
    product_price Decimal(10, 2),
    product_quantity Int32,
    sale_date Date,
    sale_customer_id Int32,
    sale_seller_id Int32,
    sale_product_id Int32,
    sale_quantity Int32,
    sale_total_price Decimal(12, 2),
    store_name String,
    store_location String,
    store_city String,
    store_state Nullable(String),
    store_country String,
    store_phone String,
    store_email String,
    pet_category String,
    product_weight Decimal(10, 2),
    product_color String,
    product_size String,
    product_brand String,
    product_material String,
    product_description String,
    product_rating Decimal(3, 1),
    product_reviews Int32,
    product_release_date Date,
    product_expiry_date Date,
    supplier_name String,
    supplier_contact String,
    supplier_email String,
    supplier_phone String,
    supplier_address String,
    supplier_city String,
    supplier_country String
)
ENGINE = MergeTree
ORDER BY tuple();

CREATE TABLE raw.mock_data_csv
(
    id String,
    customer_first_name String,
    customer_last_name String,
    customer_age String,
    customer_email String,
    customer_country String,
    customer_postal_code Nullable(String),
    customer_pet_type String,
    customer_pet_name String,
    customer_pet_breed String,
    seller_first_name String,
    seller_last_name String,
    seller_email String,
    seller_country String,
    seller_postal_code Nullable(String),
    product_name String,
    product_category String,
    product_price String,
    product_quantity String,
    sale_date String,
    sale_customer_id String,
    sale_seller_id String,
    sale_product_id String,
    sale_quantity String,
    sale_total_price String,
    store_name String,
    store_location String,
    store_city String,
    store_state Nullable(String),
    store_country String,
    store_phone String,
    store_email String,
    pet_category String,
    product_weight String,
    product_color String,
    product_size String,
    product_brand String,
    product_material String,
    product_description String,
    product_rating String,
    product_reviews String,
    product_release_date String,
    product_expiry_date String,
    supplier_name String,
    supplier_contact String,
    supplier_email String,
    supplier_phone String,
    supplier_address String,
    supplier_city String,
    supplier_country String
)
ENGINE = Memory;
SQL

for file in "MOCK_DATA.csv" "MOCK_DATA (1).csv" "MOCK_DATA (2).csv" "MOCK_DATA (3).csv" "MOCK_DATA (4).csv"; do
    clickhouse-client --password "$CLICKHOUSE_PASSWORD" \
        --query "INSERT INTO raw.mock_data_csv FORMAT CSVWithNames" \
        < "/data/$file"
done

clickhouse-client --password "$CLICKHOUSE_PASSWORD" --multiquery <<'SQL'
INSERT INTO raw.mock_data
SELECT
    toInt32(id), customer_first_name, customer_last_name, toInt32(customer_age),
    customer_email, customer_country, nullIf(customer_postal_code, ''),
    customer_pet_type, customer_pet_name, customer_pet_breed,
    seller_first_name, seller_last_name, seller_email, seller_country,
    nullIf(seller_postal_code, ''), product_name, product_category,
    toDecimal32(product_price, 2), toInt32(product_quantity),
    toDate(concat(splitByChar('/', sale_date)[3], '-', leftPad(splitByChar('/', sale_date)[1], 2, '0'), '-', leftPad(splitByChar('/', sale_date)[2], 2, '0'))),
    toInt32(sale_customer_id), toInt32(sale_seller_id), toInt32(sale_product_id), toInt32(sale_quantity),
    toDecimal64(sale_total_price, 2), store_name, store_location, store_city,
    nullIf(store_state, ''), store_country, store_phone, store_email, pet_category,
    toDecimal32(product_weight, 2), product_color, product_size, product_brand,
    product_material, product_description, toDecimal32(product_rating, 1), toInt32(product_reviews),
    toDate(concat(splitByChar('/', product_release_date)[3], '-', leftPad(splitByChar('/', product_release_date)[1], 2, '0'), '-', leftPad(splitByChar('/', product_release_date)[2], 2, '0'))),
    toDate(concat(splitByChar('/', product_expiry_date)[3], '-', leftPad(splitByChar('/', product_expiry_date)[1], 2, '0'), '-', leftPad(splitByChar('/', product_expiry_date)[2], 2, '0'))),
    supplier_name, supplier_contact, supplier_email, supplier_phone, supplier_address, supplier_city, supplier_country
FROM raw.mock_data_csv;

DROP TABLE raw.mock_data_csv;
SQL
