CREATE SCHEMA IF NOT EXISTS clickhouse.reports;

DROP TABLE IF EXISTS clickhouse.reports.rpt_product_sales;
CREATE TABLE clickhouse.reports.rpt_product_sales WITH (engine = 'MergeTree') AS
SELECT p.name AS product_name,
       p.category AS product_category,
       p.brand AS product_brand,
       count(*) AS sales_cnt,
       round(sum(f.total_price), 2) AS total_revenue,
       round(avg(CAST(p.price AS double)), 2) AS avg_price,
       round(avg(CAST(p.rating AS double)), 2) AS avg_rating,
       round(avg(CAST(p.reviews AS double)), 2) AS avg_reviews
FROM clickhouse.star.fact_sales f
JOIN clickhouse.star.dim_product p ON f.product_key = p.product_key
GROUP BY p.name, p.category, p.brand;

DROP TABLE IF EXISTS clickhouse.reports.rpt_customer_sales;
CREATE TABLE clickhouse.reports.rpt_customer_sales WITH (engine = 'MergeTree') AS
SELECT c.first_name AS first_name,
       c.last_name AS last_name,
       c.email AS email,
       c.country AS country,
       count(*) AS sales_cnt,
       round(sum(f.total_price), 2) AS total_revenue,
       round(avg(CAST(f.total_price AS double)), 2) AS avg_check
FROM clickhouse.star.fact_sales f
JOIN clickhouse.star.dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.first_name, c.last_name, c.email, c.country;

DROP TABLE IF EXISTS clickhouse.reports.rpt_time_sales;
CREATE TABLE clickhouse.reports.rpt_time_sales WITH (engine = 'MergeTree') AS
SELECT d.year,
       d.month,
       d.month_name AS month_name,
       count(*) AS sales_cnt,
       round(sum(f.total_price), 2) AS total_revenue,
       round(avg(CAST(f.total_price AS double)), 2) AS avg_order_size
FROM clickhouse.star.fact_sales f
JOIN clickhouse.star.dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name;

DROP TABLE IF EXISTS clickhouse.reports.rpt_store_sales;
CREATE TABLE clickhouse.reports.rpt_store_sales WITH (engine = 'MergeTree') AS
SELECT st.name AS store_name,
       st.city AS store_city,
       st.country AS store_country,
       count(*) AS sales_cnt,
       round(sum(f.total_price), 2) AS total_revenue,
       round(avg(CAST(f.total_price AS double)), 2) AS avg_check
FROM clickhouse.star.fact_sales f
JOIN clickhouse.star.dim_store st ON f.store_key = st.store_key
GROUP BY st.name, st.city, st.country;

DROP TABLE IF EXISTS clickhouse.reports.rpt_supplier_sales;
CREATE TABLE clickhouse.reports.rpt_supplier_sales WITH (engine = 'MergeTree') AS
SELECT sup.name AS supplier_name,
       sup.city AS supplier_city,
       sup.country AS supplier_country,
       t.sales_cnt,
       t.total_revenue,
       sp.avg_product_price
FROM (
    SELECT supplier_key, count(*) AS sales_cnt, round(sum(total_price), 2) AS total_revenue
    FROM clickhouse.star.fact_sales
    GROUP BY supplier_key
) t
JOIN clickhouse.star.dim_supplier sup ON t.supplier_key = sup.supplier_key
JOIN (
    SELECT supplier_key, round(avg(CAST(product_price AS double)), 2) AS avg_product_price
    FROM (
        SELECT DISTINCT f.supplier_key, p.price AS product_price
        FROM clickhouse.star.fact_sales f
        JOIN clickhouse.star.dim_product p ON f.product_key = p.product_key
    ) d
    GROUP BY supplier_key
) sp ON t.supplier_key = sp.supplier_key;

DROP TABLE IF EXISTS clickhouse.reports.rpt_product_quality;
CREATE TABLE clickhouse.reports.rpt_product_quality WITH (engine = 'MergeTree') AS
SELECT p.name AS product_name,
       p.category AS product_category,
       p.brand AS product_brand,
       round(avg(CAST(p.rating AS double)), 2) AS avg_rating,
       round(avg(CAST(p.reviews AS double)), 2) AS avg_reviews,
       count(*) AS sales_cnt,
       round(sum(f.total_price), 2) AS total_revenue
FROM clickhouse.star.fact_sales f
JOIN clickhouse.star.dim_product p ON f.product_key = p.product_key
GROUP BY p.name, p.category, p.brand;
