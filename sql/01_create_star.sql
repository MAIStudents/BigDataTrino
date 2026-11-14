CREATE SCHEMA IF NOT EXISTS clickhouse.star;

DROP TABLE IF EXISTS clickhouse.star.dim_date;
CREATE TABLE clickhouse.star.dim_date WITH (engine = 'MergeTree') AS
SELECT sale_date AS date_key,
       day(sale_date) AS day,
       month(sale_date) AS month,
       CASE month(sale_date)
           WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
           WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
           WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
           WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
       END AS month_name,
       quarter(sale_date) AS quarter,
       year(sale_date) AS year,
       day_of_week(sale_date) AS day_of_week,
       CASE day_of_week(sale_date)
           WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday' WHEN 3 THEN 'Wednesday'
           WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' WHEN 6 THEN 'Saturday' WHEN 7 THEN 'Sunday'
       END AS day_name,
       CASE WHEN day_of_week(sale_date) >= 6 THEN 1 ELSE 0 END AS is_weekend
FROM (
    SELECT DISTINCT sale_date
    FROM (
        SELECT sale_date FROM postgres.public.mock_data
        UNION ALL
        SELECT sale_date FROM clickhouse.raw.mock_data
    ) u
) m;

DROP TABLE IF EXISTS clickhouse.star.dim_customer;
CREATE TABLE clickhouse.star.dim_customer WITH (engine = 'MergeTree') AS
SELECT row_number() OVER (ORDER BY email) AS customer_key,
       first_name, last_name, email, country, postal_code, pet_type, pet_name, pet_breed
FROM (
    SELECT DISTINCT customer_first_name AS first_name,
           customer_last_name AS last_name,
           customer_email AS email,
           customer_country AS country,
           NULLIF(customer_postal_code, '') AS postal_code,
           customer_pet_type AS pet_type,
           customer_pet_name AS pet_name,
           customer_pet_breed AS pet_breed
    FROM (
        SELECT customer_first_name, customer_last_name, customer_email, customer_country,
               customer_postal_code, customer_pet_type, customer_pet_name, customer_pet_breed
        FROM postgres.public.mock_data
        UNION ALL
        SELECT customer_first_name, customer_last_name,
               customer_email, customer_country,
               NULLIF(customer_postal_code, ''),
               customer_pet_type, customer_pet_name,
               customer_pet_breed
        FROM clickhouse.raw.mock_data
    ) u
) d;

DROP TABLE IF EXISTS clickhouse.star.dim_seller;
CREATE TABLE clickhouse.star.dim_seller WITH (engine = 'MergeTree') AS
SELECT row_number() OVER (ORDER BY email) AS seller_key,
       first_name, last_name, email, country, postal_code
FROM (
    SELECT DISTINCT seller_first_name AS first_name,
           seller_last_name AS last_name,
           seller_email AS email,
           seller_country AS country,
           NULLIF(seller_postal_code, '') AS postal_code
    FROM (
        SELECT seller_first_name, seller_last_name, seller_email, seller_country, seller_postal_code
        FROM postgres.public.mock_data
        UNION ALL
        SELECT seller_first_name, seller_last_name,
               seller_email, seller_country,
               NULLIF(seller_postal_code, '')
        FROM clickhouse.raw.mock_data
    ) u
) d;

DROP TABLE IF EXISTS clickhouse.star.dim_product;
CREATE TABLE clickhouse.star.dim_product WITH (engine = 'MergeTree') AS
SELECT row_number() OVER (ORDER BY name, brand) AS product_key,
       name, category, pet_category, brand, color, size, material, description,
       price, weight, rating, reviews, release_date, expiry_date
FROM (
    SELECT DISTINCT product_name AS name,
           product_category AS category,
           pet_category,
           product_brand AS brand,
           product_color AS color,
           product_size AS size,
           product_material AS material,
           product_description AS description,
           product_price AS price,
           product_weight AS weight,
           product_rating AS rating,
           product_reviews AS reviews,
           product_release_date AS release_date,
           product_expiry_date AS expiry_date
    FROM (
        SELECT product_name, product_category, pet_category, product_brand, product_color,
               product_size, product_material, product_description, product_price,
               product_weight, product_rating, product_reviews, product_release_date, product_expiry_date
        FROM postgres.public.mock_data
        UNION ALL
        SELECT product_name, product_category,
               pet_category, product_brand,
               product_color, product_size,
               product_material, product_description,
               product_price, product_weight, product_rating, product_reviews,
               product_release_date, product_expiry_date
        FROM clickhouse.raw.mock_data
    ) u
) d;

DROP TABLE IF EXISTS clickhouse.star.dim_store;
CREATE TABLE clickhouse.star.dim_store WITH (engine = 'MergeTree') AS
SELECT row_number() OVER (ORDER BY name, city) AS store_key,
       name, location, city, state, country, phone, email
FROM (
    SELECT DISTINCT store_name AS name,
           store_location AS location,
           store_city AS city,
           NULLIF(store_state, '') AS state,
           store_country AS country,
           store_phone AS phone,
           store_email AS email
    FROM (
        SELECT store_name, store_location, store_city, store_state, store_country, store_phone, store_email
        FROM postgres.public.mock_data
        UNION ALL
        SELECT store_name, store_location, store_city,
               NULLIF(store_state, ''), store_country,
               store_phone, store_email
        FROM clickhouse.raw.mock_data
    ) u
) d;

DROP TABLE IF EXISTS clickhouse.star.dim_supplier;
CREATE TABLE clickhouse.star.dim_supplier WITH (engine = 'MergeTree') AS
SELECT row_number() OVER (ORDER BY name, email) AS supplier_key,
       name, contact, email, phone, address, city, country
FROM (
    SELECT DISTINCT supplier_name AS name,
           supplier_contact AS contact,
           supplier_email AS email,
           supplier_phone AS phone,
           supplier_address AS address,
           supplier_city AS city,
           supplier_country AS country
    FROM (
        SELECT supplier_name, supplier_contact, supplier_email, supplier_phone, supplier_address, supplier_city, supplier_country
        FROM postgres.public.mock_data
        UNION ALL
        SELECT supplier_name, supplier_contact,
               supplier_email, supplier_phone,
               supplier_address, supplier_city,
               supplier_country
        FROM clickhouse.raw.mock_data
    ) u
) d;

DROP TABLE IF EXISTS clickhouse.star.fact_sales;
CREATE TABLE clickhouse.star.fact_sales WITH (engine = 'MergeTree') AS
SELECT row_number() OVER (ORDER BY d.date_key, c.customer_key) AS sale_key,
       d.date_key,
       c.customer_key,
       s.seller_key,
       p.product_key,
       st.store_key,
       sup.supplier_key,
       m.sale_quantity AS quantity,
       m.sale_total_price AS total_price
FROM (
    SELECT sale_date, sale_quantity, sale_total_price,
           customer_first_name, customer_last_name, customer_email, customer_country,
           customer_postal_code, customer_pet_type, customer_pet_name, customer_pet_breed,
           seller_first_name, seller_last_name, seller_email, seller_country, seller_postal_code,
           product_name, product_category, pet_category, product_brand, product_color, product_size,
           product_material, product_description, product_price, product_weight, product_rating,
           product_reviews, product_release_date, product_expiry_date,
           store_name, store_location, store_city, store_state, store_country, store_phone, store_email,
           supplier_name, supplier_contact, supplier_email, supplier_phone, supplier_address, supplier_city, supplier_country
    FROM postgres.public.mock_data
    UNION ALL
    SELECT sale_date, sale_quantity, sale_total_price,
           customer_first_name, customer_last_name,
           customer_email, customer_country,
           NULLIF(customer_postal_code, ''),
           customer_pet_type, customer_pet_name,
           customer_pet_breed,
           seller_first_name, seller_last_name,
           seller_email, seller_country,
           NULLIF(seller_postal_code, ''),
           product_name, product_category,
           pet_category, product_brand,
           product_color, product_size,
           product_material, product_description,
           product_price, product_weight, product_rating, product_reviews,
           product_release_date, product_expiry_date,
           store_name, store_location, store_city,
           NULLIF(store_state, ''), store_country,
           store_phone, store_email,
           supplier_name, supplier_contact,
           supplier_email, supplier_phone,
           supplier_address, supplier_city,
           supplier_country
    FROM clickhouse.raw.mock_data
) m
JOIN clickhouse.star.dim_date d ON m.sale_date = d.date_key
JOIN clickhouse.star.dim_customer c
    ON c.first_name = m.customer_first_name
   AND c.last_name = m.customer_last_name
   AND c.email = m.customer_email
   AND c.country = m.customer_country
   AND coalesce(c.postal_code, '') = coalesce(m.customer_postal_code, '')
   AND c.pet_type = m.customer_pet_type
   AND c.pet_name = m.customer_pet_name
   AND c.pet_breed = m.customer_pet_breed
JOIN clickhouse.star.dim_seller s
    ON s.first_name = m.seller_first_name
   AND s.last_name = m.seller_last_name
   AND s.email = m.seller_email
   AND s.country = m.seller_country
   AND coalesce(s.postal_code, '') = coalesce(m.seller_postal_code, '')
JOIN clickhouse.star.dim_product p
    ON p.name = m.product_name
   AND p.category = m.product_category
   AND p.pet_category = m.pet_category
   AND p.brand = m.product_brand
   AND p.color = m.product_color
   AND p.size = m.product_size
   AND p.material = m.product_material
   AND p.description = m.product_description
   AND p.price = m.product_price
   AND p.weight = m.product_weight
   AND p.rating = m.product_rating
   AND p.reviews = m.product_reviews
   AND p.release_date = m.product_release_date
   AND p.expiry_date = m.product_expiry_date
JOIN clickhouse.star.dim_store st
    ON st.name = m.store_name
   AND st.location = m.store_location
   AND st.city = m.store_city
   AND coalesce(st.state, '') = coalesce(m.store_state, '')
   AND st.country = m.store_country
   AND st.phone = m.store_phone
   AND st.email = m.store_email
JOIN clickhouse.star.dim_supplier sup
    ON sup.name = m.supplier_name
   AND sup.contact = m.supplier_contact
   AND sup.email = m.supplier_email
   AND sup.phone = m.supplier_phone
   AND sup.address = m.supplier_address
   AND sup.city = m.supplier_city
   AND sup.country = m.supplier_country;
