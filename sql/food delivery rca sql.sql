-- Create Delivery Analysis Database

CREATE DATABASE delivery_analysis;
USE delivery_analysis;
DROP TABLE IF EXISTS delivery_raw;

CREATE TABLE delivery_raw (
    market_id VARCHAR(50),
    created_at VARCHAR(50),
    actual_delivery_time VARCHAR(50),
    store_id VARCHAR(50),
    store_primary_category VARCHAR(100),
    order_protocol VARCHAR(50),
    total_items VARCHAR(50),
    subtotal VARCHAR(50),
    num_distinct_items VARCHAR(50),
    min_item_price VARCHAR(50),
    max_item_price VARCHAR(50),
    total_onshift_partners VARCHAR(50),
    total_busy_partners VARCHAR(50),
    total_outstanding_orders VARCHAR(50)
);



-- Enable Local Infile on Server

SET GLOBAL local_infile = 1;
-- Check Local Infile

SHOW GLOBAL VARIABLES LIKE 'local_infile';
-- Fast CSV Import
-- Import Dataset

LOAD DATA LOCAL INFILE 'C:/Users/blues/Downloads/dataset.csv'
INTO TABLE delivery_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
# Install MySQL Connector

-- Check MySQL Import Folder

SHOW VARIABLES LIKE 'secure_file_priv';
-- Import Dataset into Staging Table

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.2/Uploads/dataset.csv'
INTO TABLE delivery_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
-- Get Exact MySQL Upload Folder

SELECT @@secure_file_priv;
-- Import Dataset

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.2/Uploads/dataset.csv'
INTO TABLE delivery_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
-- Check Imported Rows

SELECT COUNT(*) AS total_rows
FROM delivery_raw;
-- Check for Duplicate Rows

SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT_WS('|', 
        market_id,
        created_at,
        actual_delivery_time,
        store_id
    )) AS unique_rows
FROM delivery_raw;
-- Remove Previous Partial Import

TRUNCATE TABLE delivery_raw;
-- Import Clean Dataset

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.2/Uploads/dataset.csv'
INTO TABLE delivery_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
-- Verify Final Row Count

SELECT COUNT(*) AS total_rows
FROM delivery_raw;
-- Verify Imported Dataset

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT market_id) AS markets,
    COUNT(DISTINCT store_id) AS stores,
    COUNT(DISTINCT store_primary_category) AS categories
FROM delivery_raw;
-- Check Dataset Date Range

SELECT
    MIN(created_at) AS first_order,
    MAX(created_at) AS last_order
FROM delivery_raw;
-- Create Final Analysis Table

-- Create Final Analysis Table

DROP TABLE IF EXISTS delivery_analysis;

CREATE TABLE delivery_analysis AS
SELECT
    CAST(NULLIF(market_id, '') AS DECIMAL(10,2)) AS market_id,
    STR_TO_DATE(NULLIF(created_at, ''), '%Y-%m-%d %H:%i:%s') AS created_at,
    STR_TO_DATE(NULLIF(actual_delivery_time, ''), '%Y-%m-%d %H:%i:%s') AS actual_delivery_time,
    store_id,
    store_primary_category,
    CAST(NULLIF(order_protocol, '') AS DECIMAL(10,2)) AS order_protocol,
    CAST(NULLIF(total_items, '') AS DECIMAL(10,2)) AS total_items,
    CAST(NULLIF(subtotal, '') AS DECIMAL(12,2)) AS subtotal,
    CAST(NULLIF(num_distinct_items, '') AS DECIMAL(10,2)) AS num_distinct_items,
    CAST(NULLIF(min_item_price, '') AS DECIMAL(12,2)) AS min_item_price,
    CAST(NULLIF(max_item_price, '') AS DECIMAL(12,2)) AS max_item_price,
    CAST(NULLIF(total_onshift_partners, '') AS DECIMAL(12,2)) AS total_onshift_partners,
    CAST(NULLIF(total_busy_partners, '') AS DECIMAL(12,2)) AS total_busy_partners,
    CAST(NULLIF(total_outstanding_orders, '') AS DECIMAL(12,2)) AS total_outstanding_orders,

    TIMESTAMPDIFF(
        SECOND,
        STR_TO_DATE(NULLIF(created_at, ''), '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(NULLIF(actual_delivery_time, ''), '%Y-%m-%d %H:%i:%s')
    ) / 60.0 AS delivery_time_min

FROM delivery_raw
WHERE created_at <> ''
  AND actual_delivery_time <> '';
  -- Verify Final Analysis Table

SELECT
    COUNT(*) AS total_orders,
    ROUND(AVG(delivery_time_min), 2) AS avg_delivery_time,
    ROUND(MIN(delivery_time_min), 2) AS min_delivery_time,
    ROUND(MAX(delivery_time_min), 2) AS max_delivery_time
FROM delivery_analysis;
-- Overall Delivery Performance

SELECT
    COUNT(*) AS total_orders,
    ROUND(AVG(delivery_time_min), 2) AS avg_delivery_time,
    ROUND(MIN(delivery_time_min), 2) AS min_delivery_time,
    ROUND(MAX(delivery_time_min), 2) AS max_delivery_time
FROM delivery_analysis
WHERE delivery_time_min BETWEEN 1 AND 180;
-- Delivery Time by Demand Pressure

SELECT
    CASE
        WHEN total_outstanding_orders <= 13 THEN 'Low'
        WHEN total_outstanding_orders <= 56 THEN 'Medium'
        ELSE 'High'
    END AS demand_pressure,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_time_min), 2) AS avg_delivery_time,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct
FROM delivery_analysis
WHERE delivery_time_min BETWEEN 1 AND 180
GROUP BY demand_pressure
ORDER BY
    FIELD(demand_pressure, 'Low', 'Medium', 'High');
    -- Delivery Time by Partner Load

SELECT
    ROUND(
        total_busy_partners / NULLIF(total_onshift_partners, 0),
        2
    ) AS busy_ratio,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_time_min), 2) AS avg_delivery_time
FROM delivery_analysis
WHERE delivery_time_min BETWEEN 1 AND 180
  AND total_onshift_partners > 0
GROUP BY busy_ratio
ORDER BY busy_ratio;
-- Demand Pressure and Order Size

SELECT
    CASE
        WHEN total_outstanding_orders <= 13 THEN 'Low'
        WHEN total_outstanding_orders <= 56 THEN 'Medium'
        ELSE 'High'
    END AS demand_pressure,

    CASE
        WHEN total_items <= 2 THEN 'Small'
        WHEN total_items <= 4 THEN 'Medium'
        ELSE 'Large'
    END AS order_size,

    COUNT(*) AS orders,
    ROUND(AVG(delivery_time_min), 2) AS avg_delivery_time
FROM delivery_analysis
WHERE delivery_time_min BETWEEN 1 AND 180
GROUP BY
    demand_pressure,
    order_size
ORDER BY
    FIELD(demand_pressure, 'Low', 'Medium', 'High'),
    FIELD(order_size, 'Small', 'Medium', 'Large');
    -- Market Performance

SELECT
    market_id,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_time_min), 2) AS avg_delivery_time,
    ROUND(
        AVG(
            CASE
                WHEN delivery_time_min > 60 THEN 1
                ELSE 0
            END
        ) * 100,
        2
    ) AS delayed_orders_pct
FROM delivery_analysis
WHERE delivery_time_min BETWEEN 1 AND 180
GROUP BY market_id
ORDER BY avg_delivery_time DESC;
SHOW VARIABLES
WHERE Variable_name IN ('hostname', 'port');
-- Check Current MySQL User

SELECT USER();
-- Check Root Authentication Plugin

SELECT
    user,
    host,
    plugin
FROM mysql.user
WHERE user = 'root';
-- Create Power BI User

CREATE USER 'powerbi'@'localhost'
IDENTIFIED WITH mysql_native_password BY 'PowerBI@1234';
-- Create Power BI User

CREATE USER 'powerbi'@'localhost'
IDENTIFIED WITH caching_sha2_password BY 'PowerBI@1234';
-- Give Power BI Read Access

GRANT SELECT ON delivery_analysis.* TO 'powerbi'@'localhost';

FLUSH PRIVILEGES;
-- Verify Power BI User

SELECT user, host, plugin
FROM mysql.user
WHERE user = 'powerbi';