# BigDataTrino

Анализ больших данных - лабораторная работа №4 - ETL реализованный с помощью Trino.

Выполнил: Крючков Артемий Владимирович, группа М8О-205СВ-25.

## Как запустить лабораторную работу

Требуется установленный Docker (при первом запуске нужен интернет: качаются образы PostgreSQL, ClickHouse, Trino).

Из корня репозитория:

```bash
docker compose up -d
```

При старте автоматически выполняется:

1. Поднимается PostgreSQL 17 (порт на хосте 5435). В базу `bigdatatrino` загружается таблица `mock_data` из файлов 6–10: `MOCK_DATA (5).csv` … `MOCK_DATA (9).csv` (5000 строк).
2. Поднимается ClickHouse 24.8 (порты на хосте 8124 HTTP и 9001 native). В базу `raw` загружается таблица `mock_data` из файлов 1–5: `MOCK_DATA.csv`, `MOCK_DATA (1).csv` … `MOCK_DATA (4).csv` (5000 строк).
3. Поднимается Trino 455 (Web UI на http://localhost:8082) с каталогами `postgres` и `clickhouse`.

Дождитесь статуса `healthy` всех сервисов (`docker compose ps`), затем запустите Trino-скрипты.

Скрипт 1 — трансформация исходных данных из PostgreSQL и ClickHouse в модель звезда в ClickHouse (база `star`, примерно 2 минуты):

```bash
docker compose exec -T trino bash -c "trino -f /sql/01_create_star.sql"
```

Скрипт 2 — расчет 6 отчетов по звезде в ClickHouse (база `reports`, примерно 1 минута):

```bash
docker compose exec -T trino bash -c "trino -f /sql/02_create_reports.sql"
```

Каждый скрипт печатает `CREATE TABLE: N rows` по каждой таблице. Повторный запуск безопасен: таблицы пересоздаются, дубликатов не возникает.

## Подключение (DBeaver)

| БД         | URL / Host                      | Пользователь | Пароль     |
| ---------- | ------------------------------- | ------------ | ---------- |
| PostgreSQL | localhost:5435, база bigdatatrino | postgres   | postgres   |
| ClickHouse | localhost:8124 (HTTP), базы raw/star/reports | default | clickhouse |
| Trino      | jdbc:trino://localhost:8082      | любой        | —          |

## Проверка результата

Модель звезда в ClickHouse (база `star`): `fact_sales` + `dim_date`, `dim_customer`, `dim_seller`, `dim_product`, `dim_store`, `dim_supplier`. Суррогатные ключи назначает Trino через `row_number()`; исходные `id`/`sale_*_id` в данных не уникальны, поэтому измерения строятся по полным наборам атрибутов. Отчеты — база `reports`, 6 таблиц.

Контрольные значения (в DBeaver, подключение ClickHouse):

```sql
SELECT count(), sum(total_price) FROM star.fact_sales;
```

Ожидается: 10000, 2529852.12.

Наполнение измерений (ожидается 364, 10000, 10000, 10000, 10000, 10000):

```sql
SELECT (SELECT count() FROM star.dim_date),
       (SELECT count() FROM star.dim_customer),
       (SELECT count() FROM star.dim_seller),
       (SELECT count() FROM star.dim_product),
       (SELECT count() FROM star.dim_store),
       (SELECT count() FROM star.dim_supplier);
```

Строки отчетов (ожидается 3233, 10000, 12, 10000, 10000, 3233):

```sql
SELECT (SELECT count() FROM reports.rpt_product_sales),
       (SELECT count() FROM reports.rpt_customer_sales),
       (SELECT count() FROM reports.rpt_time_sales),
       (SELECT count() FROM reports.rpt_store_sales),
       (SELECT count() FROM reports.rpt_supplier_sales),
       (SELECT count() FROM reports.rpt_product_quality);
```

Примеры запросов по отчетам:

Топ-10 самых продаваемых продуктов по выручке:

```sql
SELECT product_name, product_brand, sales_cnt, total_revenue, avg_price, avg_rating, avg_reviews
FROM reports.rpt_product_sales
ORDER BY total_revenue DESC
LIMIT 10;
```

Выручка по категориям продуктов:

```sql
SELECT product_category, sum(total_revenue) AS revenue, sum(sales_cnt) AS sales_cnt
FROM reports.rpt_product_sales
GROUP BY product_category
ORDER BY revenue DESC;
```

Топ-10 клиентов по сумме покупок:

```sql
SELECT first_name, last_name, email, country, sales_cnt, total_revenue, avg_check
FROM reports.rpt_customer_sales
ORDER BY total_revenue DESC
LIMIT 10;
```

Распределение клиентов по странам:

```sql
SELECT country, count() AS customers, sum(sales_cnt) AS sales_cnt
FROM reports.rpt_customer_sales
GROUP BY country
ORDER BY customers DESC;
```

Месячные тренды продаж (средний размер заказа по месяцам):

```sql
SELECT year, month, month_name, sales_cnt, total_revenue, avg_order_size
FROM reports.rpt_time_sales
ORDER BY year, month;
```

Топ-5 магазинов по выручке:

```sql
SELECT store_name, store_city, store_country, sales_cnt, total_revenue, avg_check
FROM reports.rpt_store_sales
ORDER BY total_revenue DESC
LIMIT 5;
```

Топ-5 поставщиков по выручке и средняя цена их товаров:

```sql
SELECT supplier_name, supplier_country, sales_cnt, total_revenue, avg_product_price
FROM reports.rpt_supplier_sales
ORDER BY total_revenue DESC
LIMIT 5;
```

Корреляция между рейтингом и объемом продаж:

```sql
SELECT round(corr(toFloat64(avg_rating), toFloat64(sales_cnt)), 4)
FROM reports.rpt_product_quality;
```

Целостность (0 «висячих» ссылок факта на измерения):

```sql
SELECT count()
FROM star.fact_sales f
LEFT JOIN star.dim_date d ON f.date_key = d.date_key
LEFT JOIN star.dim_customer c ON f.customer_key = c.customer_key
LEFT JOIN star.dim_seller s ON f.seller_key = s.seller_key
LEFT JOIN star.dim_product p ON f.product_key = p.product_key
LEFT JOIN star.dim_store st ON f.store_key = st.store_key
LEFT JOIN star.dim_supplier sup ON f.supplier_key = sup.supplier_key
WHERE d.date_key IS NULL OR c.customer_key IS NULL OR s.seller_key IS NULL
   OR p.product_key IS NULL OR st.store_key IS NULL OR sup.supplier_key IS NULL;
```

## Управление

```bash
docker compose stop
docker compose down
docker compose down -v && docker compose up -d
```

`down -v` удаляет данные и запускает полную переинициализацию с нуля (после этого заново запустить оба Trino-скрипта).

## Состав решения

| Файл                        | Назначение                                                            |
| --------------------------- | --------------------------------------------------------------------- |
| `docker-compose.yml`        | PostgreSQL 17, ClickHouse 24.8, Trino 455 с загрузкой данных из CSV   |
| `init/postgres/01_mock_data.sql` | Таблица `mock_data` и загрузка файлов 6–10 в PostgreSQL          |
| `init/clickhouse/01_mock_data.sh` | База `raw`, таблица `mock_data` и загрузка файлов 1–5 в ClickHouse |
| `trino/catalog/postgres.properties` | Каталог Trino для PostgreSQL                                    |
| `trino/catalog/clickhouse.properties` | Каталог Trino для ClickHouse                                 |
| `sql/01_create_star.sql`    | Trino: федеративная трансформация PostgreSQL + ClickHouse в звезду в ClickHouse |
| `sql/02_create_reports.sql` | Trino: расчет 6 отчетов по звезде в ClickHouse                        |

---

## Исходное задание

Анализ больших данных - лабораторная работа №4 - ETL реализованный с помощью Trino

Одним из самых популярных фреймворков для анализа данных Big Data является Trino. Trino позволяет с помощью SQL анализировать большие объёмы данных.

Что необходимо сделать?

Необходимо реализовать ETL с помощью Trino, который трансформирует данные из источников ClickHouse (первые 5 файлов mock_data.csv) и PostgreSQL (следующие 5 файлов mock_data.csv) в модель данных снежинка/звезда в ClickHouse, а затем на основе модели данных снежинка/звезда создать ряд отчетов по данным в ClickHouse. Каждый отчет представляет собой отдельную таблицу в ClickHouse

Какие отчеты надо создать?
1. Витрина продаж по продуктам
Цель: Анализ выручки, количества продаж и популярности продуктов.
 - Топ-10 самых продаваемых продуктов.
 - Общая выручка по категориям продуктов.
 - Средний рейтинг и количество отзывов для каждого продукта.
2. Витрина продаж по клиентам
Цель: Анализ покупательского поведения и сегментация клиентов.
 - Топ-10 клиентов с наибольшей общей суммой покупок.
 - Распределение клиентов по странам.
 - Средний чек для каждого клиента.
3. Витрина продаж по времени
Цель: Анализ сезонности и трендов продаж.
 - Месячные и годовые тренды продаж.
 - Сравнение выручки за разные периоды.
 - Средний размер заказа по месяцам.
4. Витрина продаж по магазинам
Цель: Анализ эффективности магазинов.
 - Топ-5 магазинов с наибольшей выручкой.
 - Распределение продаж по городам и странам.
 - Средний чек для каждого магазина.
5. Витрина продаж по поставщикам
Цель: Анализ эффективности поставщиков.
 - Топ-5 поставщиков с наибольшей выручкой.
 - Средняя цена товаров от каждого поставщика.
 - Распределение продаж по странам поставщиков.
6. Витрина качества продукции
Цель: Анализ отзывов и рейтингов товаров.
 - Продукты с наивысшим и наименьшим рейтингом.
 - Корреляция между рейтингом и объемом продаж.
 - Продукты с наибольшим количеством отзывов.

![Лабораторная работа №4](https://github.com/user-attachments/assets/8cde5065-780b-46c3-867f-5d4332b42e28)


Алгоритм:
1. Клонируете к себе этот репозиторий.
2. Устанавливаете себе инструмент для работы с запросами SQL (рекомендую DBeaver).
3. Устанавливаете базу данных PostgreSQL (рекомендую установку через docker).
4. Устанавливаете базу данных ClickHouse (рекомендую установку через docker).
5. Устанавливаете Trino (рекомендую установку через Docker).
6. Скачиваете файлы с исходными данными mock_data( * ).csv, где ( * ) номера файлов. Всего 10 файлов, каждый по 1000 строк.
7. Импортируете данные в БД PostgreSQL (например, через механизм импорта csv в DBeaver). Всего в таблице mock_data должно находиться 5000 строк из 5 файлов.
8. Импортируете данные в БД ClickHouse (например, через механизм импорта csv в ClickHouse). Всего в таблице mock_data должно находиться 5000 строк из других 5 файлов.
9. Анализируете исходные данные с помощью запросов.
10. Выявляете сущности фактов и измерений.
11. Реализуете скрипты Trino, которые по аналогии с первой лабораторной работой перекладывают исходные данные из PostgreSQL и ClickHouse в модель снежинку/звезда в ClickHouse. (Убедитесь в коннективности Trino, PostgreSQL, ClickHouse настройте сеть между Trino, PostgreSQL, ClickHouse если используете Docker).
12. Устанавливаете ClickHouse (рекомендую установку через Docker. Убедитесь в коннективности Spark и Clickhouse, настройте сеть между Spark и ClickHouse).
13. Реализуете расчеты на Trino, которые создают все 6 перечисленных выше отчетов в виде 6 отдельных таблиц в ClickHouse.
14. Проверяете отчеты в каждой базе данных средствами языка самой БД (ClickHouse - SQL (DBeaver)).
15. Отправляете работу на проверку лаборантам.

Что должно быть результатом работы?

1. Репозиторий, в котором есть исходные данные mock_data().csv, где () номера файлов. Всего 10 файлов, каждый по 1000 строк.
2. Файл docker-compose.yml с установкой PostgreSQL, Trino, ClickHouse с заполненными данными в PostgreSQL, ClickHouse из файлов mock_data(*).csv.
3. Инструкция, как запускать Trino-скрипты для проверки лабораторной работы.
4. Код Trino трансформации данных из исходной модели в снежинку/звезду в ClickHouse.
5. Код Trino трансформации данных из снежинки/звезды в отчеты в ClickHouse.
