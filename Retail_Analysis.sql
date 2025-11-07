/* ============================================================
   Retail Sales & Inventory Intelligence
   Author: Manikanta Pudi
   Purpose: Build schema, load constraints/indexes, and run
            analysis queries with consistent metric definitions.
   ============================================================ */


/* ------------------------------
   0) SCHEMAS & SEARCH PATH
   ------------------------------ */
   
CREATE SCHEMA IF NOT EXISTS sales;
CREATE SCHEMA IF NOT EXISTS production;
SET search_path = sales,production,public;

/* Sanity check: required schemas should be present */
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('sales','production')
ORDER BY schema_name;

/* see which tables exist in target schemas */
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('sales','production');

/* ------------------------------
    Table Creation — PRODUCTION DOMAIN
   ------------------------------ */

-- brands
CREATE TABLE IF NOT EXISTS production.brands (
brand_id INT PRIMARY KEY,
brand_name VARCHAR(255) NOT NULL
);

-- categories
CREATE TABLE IF NOT EXISTS production.categories (
category_id INT PRIMARY KEY,
category_name VARCHAR(255) NOT NULL
);

-- products
CREATE TABLE IF NOT EXISTS production.products (
product_id INT PRIMARY KEY,
product_name VARCHAR(255) NOT NULL,
brand_id INT NOT NULL,
category_id INT NOT NULL,
model_year SMALLINT CHECK (model_year BETWEEN 1900 AND 2100),
list_price NUMERIC(10,2) NOT NULL CHECK (list_price > 0),
CONSTRAINT fk_production_brand
	FOREIGN KEY (brand_id) REFERENCES production.brands(brand_id),
CONSTRAINT fk_production_category
	FOREIGN KEY (category_id) REFERENCES production.categories(category_id)
);

-- stocks
CREATE TABLE IF NOT EXISTS production.stocks (
store_id INT NOT NULL,
product_id INT NOT NULL,
quantity INT NOT NULL CHECK (quantity >=0),
PRIMARY KEY (store_id , product_id),
CONSTRAINT fk_stocks_product
	FOREIGN KEY (product_id) REFERENCES production.products(product_id)
);

/* ------------------------------
   Tables Creation — SALES DOMAIN
   ------------------------------ */
   
-- stores
CREATE TABLE IF NOT EXISTS sales.stores (
  store_id   INT PRIMARY KEY,
  store_name VARCHAR(255) NOT NULL,
  phone      VARCHAR(40),
  email      VARCHAR(255),
  street     VARCHAR(255),
  city       VARCHAR(100),
  state      VARCHAR(100),
  zip_code   VARCHAR(20)
);

-- customers
CREATE TABLE IF NOT EXISTS sales.customers (
  customer_id  INT PRIMARY KEY,
  first_name   VARCHAR(255) NOT NULL,
  last_name    VARCHAR(255) NOT NULL,
  phone        VARCHAR(40),     -- can be NULL
  email        VARCHAR(255),
  street       VARCHAR(255),
  city         VARCHAR(100),
  state        VARCHAR(100),
  zip_code     VARCHAR(20)
);

-- staffs
CREATE TABLE IF NOT EXISTS sales.staffs (
  staff_id   INT PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name  VARCHAR(255) NOT NULL,
  email      VARCHAR(255),
  phone      VARCHAR(40),
  active     BOOLEAN NOT NULL DEFAULT TRUE,
  store_id   INT NOT NULL,
  manager_id INT,
  CONSTRAINT fk_staffs_store
    FOREIGN KEY (store_id)  REFERENCES sales.stores(store_id),
  CONSTRAINT fk_staffs_manager
    FOREIGN KEY (manager_id) REFERENCES sales.staffs(staff_id)
);

-- orders
CREATE TABLE IF NOT EXISTS sales.orders (
  order_id       INT PRIMARY KEY,
  customer_id    INT NOT NULL,
  order_status   VARCHAR(50) NOT NULL,
  order_date     DATE NOT NULL,
  required_date  DATE,
  shipped_date   DATE,
  store_id       INT NOT NULL,
  staff_id       INT NOT NULL,
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES sales.customers(customer_id),
  CONSTRAINT fk_orders_store    FOREIGN KEY (store_id)    REFERENCES sales.stores(store_id),
  CONSTRAINT fk_orders_staff    FOREIGN KEY (staff_id)    REFERENCES sales.staffs(staff_id),
  -- logical guards:
  CONSTRAINT chk_required_ge_order CHECK (required_date IS NULL OR required_date >= order_date),
  CONSTRAINT chk_shipped_ge_order  CHECK (shipped_date  IS NULL OR shipped_date  >= order_date)
);

-- order_items
CREATE TABLE IF NOT EXISTS sales.order_items (
  order_id    INT NOT NULL,
  item_id     INT NOT NULL,
  product_id  INT NOT NULL,
  quantity    INT NOT NULL CHECK (quantity > 0),
  list_price  NUMERIC(10,2) NOT NULL CHECK (list_price > 0),
  discount    NUMERIC(5,2)  NOT NULL DEFAULT 0 CHECK (discount >= 0 AND discount <= 1),
  PRIMARY KEY (order_id, item_id),
  CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES sales.orders(order_id) ON DELETE CASCADE,
  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES production.products(product_id)
);

/* Add missing FK from stocks to stores (post-create) */
ALTER TABLE production.stocks
  ADD CONSTRAINT fk_stocks_store
  FOREIGN KEY (store_id)
  REFERENCES sales.stores(store_id);

/* ------------------------------
              INDEXES
   ------------------------------ */

-- On orders
CREATE INDEX IF NOT EXISTS idx_orders_customer  ON sales.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_store     ON sales.orders(store_id);
CREATE INDEX IF NOT EXISTS idx_orders_staff     ON sales.orders(staff_id);

-- On order_items
CREATE INDEX IF NOT EXISTS idx_items_product    ON sales.order_items(product_id);

-- On stocks
CREATE INDEX IF NOT EXISTS idx_stocks_product   ON production.stocks(product_id);
CREATE INDEX IF NOT EXISTS idx_stocks_store     ON production.stocks(store_id);

-- Time-series
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON sales.orders(order_date);

-- Product slicing
CREATE INDEX IF NOT EXISTS idx_products_brand    ON production.products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON production.products(category_id);

/* ====================================
          ANALYSIS QUERIES
   ==================================== */

/* ------------------------------
         Store-wise sales
   ------------------------------ */
SELECT s.store_id, s.store_name, s.city, s.state,
	Count(DISTINCT o.order_id) as orders_count,
	SUM(oi.quantity) as units_sold,
	SUM(oi.quantity * oi.list_price * (1 - oi.discount)) as net_sales,
	SUM(oi.quantity * oi.list_price * (1- oi.discount))/ COUNT(DISTINCT o.order_id) as Aov
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
JOIN sales.stores s ON s.store_id = o.store_id
GROUP BY s.store_id, s.store_name, s.city, s.state
ORDER BY net_sales DESC;

/* ------------------------------
        Region-wise sales
   ------------------------------ */
SELECT s.state, 
	COUNT(DISTINCT o.order_id) as orders_count,
	SUM(oi.quantity * oi.list_price * (1 - oi.discount)) as net_sales,
	 ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount))/ NULLIF(COUNT(DISTINCT o.order_id), 0), 2 ) as Aov
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
JOIN sales.stores s ON s.store_id = o.store_id
GROUP BY s.state
ORDER BY net_sales DESC;

/* ------------------------------
   Product-wise sales performance
   ------------------------------ */
SELECT p.product_id, p.product_name, b.brand_name, c.category_name,
	SUM(oi.quantity) as units_sold,
	SUM(oi.quantity * oi.list_price * (1 - oi.discount)) as net_sales,
	SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / SUM(oi.quantity) as avg_price_per_unit
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN brands b ON b.brand_id = p.brand_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY p.product_id , p.product_name, b.brand_name, c.category_name
ORDER BY net_sales DESC;

/* ------------------------------
   Inventory trend — store snapshot
   ------------------------------ */
SELECT 
    s.store_name,
    SUM(st.quantity) AS total_stock_units,
    COUNT(st.product_id) AS total_products_stocked,
    ROUND(AVG(st.quantity),2) AS avg_stock_per_product
FROM production.stocks st
JOIN sales.stores s ON s.store_id = st.store_id
GROUP BY s.store_name
ORDER BY total_stock_units DESC;

/* ------------------------------
  	Inventory efficiency — stock vs demand
   ------------------------------ */
SELECT 
    s.store_name,
    SUM(st.quantity) AS total_stock_units,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(
        SUM(st.quantity)::numeric / NULLIF(SUM(oi.quantity), 0), 2
    ) AS stock_to_sales_ratio
FROM production.stocks st
JOIN sales.stores s        ON s.store_id = st.store_id
JOIN sales.orders o        ON o.store_id = s.store_id
JOIN sales.order_items oi  ON oi.order_id = o.order_id
GROUP BY s.store_name
ORDER BY stock_to_sales_ratio DESC;

/* ------------------------------
    Inventory trend by category
   ------------------------------ */
SELECT
    s.store_name,
    c.category_name,
    SUM(st.quantity) AS total_stock_units,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(
        SUM(st.quantity)::numeric / NULLIF(SUM(oi.quantity), 0), 2
    ) AS stock_to_sales_ratio
FROM production.stocks st
JOIN sales.stores s        ON s.store_id = st.store_id
JOIN production.products p ON p.product_id = st.product_id
JOIN production.categories c ON c.category_id = p.category_id
JOIN sales.orders o        ON o.store_id = s.store_id
JOIN sales.order_items oi  ON oi.order_id = o.order_id AND oi.product_id = p.product_id
GROUP BY s.store_name, c.category_name
ORDER BY s.store_name, stock_to_sales_ratio DESC;

/* ------------------------------
         Staff performance
   ------------------------------ */
SELECT
    st.staff_id,
    st.first_name || ' ' || st.last_name AS staff_name,
    st.store_id,
    COUNT(DISTINCT o.order_id) AS orders_handled,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS net_sales,
    ROUND(AVG(
        CASE 
            WHEN o.shipped_date IS NOT NULL 
            THEN (o.shipped_date - o.order_date)
        END
    ), 2) AS avg_fulfillment_days
FROM sales.staffs st
LEFT JOIN sales.orders o ON st.staff_id = o.staff_id
LEFT JOIN sales.order_items oi ON o.order_id = oi.order_id
GROUP BY st.staff_id, st.first_name, st.last_name, st.store_id
ORDER BY net_sales DESC NULLS LAST;

/* ------------------------------
    Customer orders & frequency 
   ------------------------------ */
SELECT
    c.customer_id,
    (c.first_name || ' ' || c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id)                          AS orders_count,
    MIN(o.order_date)                                   AS first_order_date,
    MAX(o.order_date)                                   AS last_order_date,
    SUM(oi.quantity)                                    AS total_units,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount))            AS total_spent,
    ROUND(
        SUM(oi.quantity * oi.list_price * (1 - oi.discount))
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    )                                                   AS avg_order_value,
    ROUND(
        ((MAX(o.order_date) - MIN(o.order_date))::numeric)
        / NULLIF(COUNT(DISTINCT o.order_id) - 1, 0), 1
    )                                                   AS avg_days_between_orders
FROM sales.customers      c
JOIN sales.orders         o  ON o.customer_id = c.customer_id
JOIN sales.order_items    oi ON oi.order_id   = o.order_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC;

/* ------------------------------
        Order fulfillment
   ------------------------------ */
   
-- I.1 Line-level classification
SELECT
    o.order_id,
    o.order_date,
    o.required_date,
    o.shipped_date,
    CASE
        WHEN o.shipped_date IS NULL THEN 'Pending'
        WHEN o.required_date IS NULL THEN 'Shipped (No SLA)'
        WHEN o.shipped_date <= o.required_date THEN 'On Time'
        ELSE 'Late'
    END AS fulfillment_status,
    ROUND( (o.shipped_date - o.order_date), 1 ) AS fulfillment_days
FROM sales.orders o
ORDER BY o.order_date;

-- I.2 Status summary
SELECT
    CASE
        WHEN shipped_date IS NULL THEN 'Pending'
        WHEN required_date IS NULL THEN 'Shipped (No SLA)'
        WHEN shipped_date <= required_date THEN 'On Time'
        ELSE 'Late'
    END AS fulfillment_status,
    COUNT(*) AS orders_count,
    ROUND(AVG(shipped_date - order_date), 1) AS avg_fulfillment_days
FROM sales.orders
GROUP BY fulfillment_status
ORDER BY orders_count DESC;

/* ------------------------------
    Category × Brand performance
   ------------------------------ */
SELECT
    c.category_name,
    b.brand_name,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_sales,
    ROUND(
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / NULLIF(SUM(oi.quantity), 0), 2
    ) AS avg_price_per_unit
FROM sales.order_items oi
JOIN production.products p ON oi.product_id = p.product_id
JOIN production.categories c ON p.category_id = c.category_id
JOIN production.brands b ON p.brand_id = b.brand_id
GROUP BY c.category_name, b.brand_name
ORDER BY net_sales DESC;

/* ------------------------------
       Store profitability
   ------------------------------ */
   --    Note: estimated_profit assumes constant 30% margin.
   --    If you get COGS later, replace the assumption here.
SELECT
    s.store_id,
    s.store_name,
    s.city,
    s.state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.list_price), 2) AS gross_sales,
    ROUND(SUM(oi.quantity * oi.list_price * oi.discount), 2) AS discount_amount,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_sales,
    ROUND(
        (SUM(oi.quantity * oi.list_price * oi.discount)
         / NULLIF(SUM(oi.quantity * oi.list_price), 0)) * 100, 2
    ) AS avg_discount_pct,
    ROUND(
        (SUM(oi.quantity * oi.list_price * (1 - oi.discount)) * 0.3), 2
    ) AS estimated_profit, -- assuming 30% profit margin
    ROUND(
        ((SUM(oi.quantity * oi.list_price * (1 - oi.discount)) * 0.3)
         / NULLIF(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0)) * 100, 2
    ) AS profit_margin_pct,
    ROUND(
        SUM(oi.quantity * oi.list_price * (1 - oi.discount))
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS avg_order_value
FROM sales.stores s
JOIN sales.orders o ON o.store_id = s.store_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY s.store_id, s.store_name, s.city, s.state
ORDER BY net_sales DESC;

/* ============================================================
             REUSABLE ANALYTICAL VIEWS
   ============================================================ */

-- 0) Create schema + search_path
CREATE SCHEMA IF NOT EXISTS analytics;
SET search_path = analytics, sales, production, public;

/* ------------------------------------------------------------
                STORE-WISE SALES
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW analytics.vw_store_sales AS
SELECT 
    s.store_id,
    s.store_name,
    s.city,
    s.state,
    COUNT(DISTINCT o.order_id) AS orders_cnt,
    SUM(oi.quantity)           AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_sales,
    ROUND(
      SUM(oi.quantity * oi.list_price * (1 - oi.discount))
      / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS aov
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN sales.stores s       ON s.store_id  = o.store_id
GROUP BY s.store_id, s.store_name, s.city, s.state;

/* ------------------------------------------------------------
               REGION (STATE)-WISE SALES
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW analytics.vw_region_sales AS
SELECT 
    s.state AS region,
    COUNT(DISTINCT o.order_id) AS orders_cnt,
    SUM(oi.quantity)           AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_sales,
    ROUND(
      SUM(oi.quantity * oi.list_price * (1 - oi.discount))
      / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS aov
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN sales.stores s       ON s.store_id  = o.store_id
GROUP BY s.state;

/* ------------------------------------------------------------
               PRODUCT-WISE SALES PERFORMANCE
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW analytics.vw_product_sales AS
SELECT
    p.product_id,
    p.product_name,
    b.brand_name,
    c.category_name,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_sales,
    ROUND(
      SUM(oi.quantity * oi.list_price * (1 - oi.discount))
      / NULLIF(SUM(oi.quantity), 0), 2
    ) AS avg_price_per_unit
FROM sales.order_items oi
JOIN production.products   p ON p.product_id  = oi.product_id
JOIN production.brands     b ON b.brand_id    = p.brand_id
JOIN production.categories c ON c.category_id = p.category_id
GROUP BY p.product_id, p.product_name, b.brand_name, c.category_name;

/* ------------------------------------------------------------
            CATEGORY × BRAND SALES PERFORMANCE
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW analytics.vw_category_brand_sales AS
SELECT
    c.category_name,
    b.brand_name,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_sales,
    ROUND(
      SUM(oi.quantity * oi.list_price * (1 - oi.discount))
      / NULLIF(SUM(oi.quantity), 0), 2
    ) AS avg_price_per_unit
FROM sales.order_items oi
JOIN production.products   p ON p.product_id  = oi.product_id
JOIN production.categories c ON c.category_id = p.category_id
JOIN production.brands     b ON b.brand_id    = p.brand_id
GROUP BY c.category_name, b.brand_name;

/* ------------------------------------------------------------
                       STAFF PERFORMANCE
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW analytics.vw_staff_performance AS
SELECT
    st.staff_id,
    st.first_name || ' ' || st.last_name AS staff_name,
    st.store_id,
    COUNT(DISTINCT o.order_id) AS orders_handled,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_sales,
    ROUND(AVG(
      CASE WHEN o.shipped_date IS NOT NULL
           THEN (o.shipped_date - o.order_date)
      END
    ), 2) AS avg_fulfillment_days
FROM sales.staffs st
LEFT JOIN sales.orders      o  ON o.staff_id  = st.staff_id
LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY st.staff_id, st.first_name, st.last_name, st.store_id;

/* ------------------------------------------------------------
            CUSTOMER ORDERS & ORDER FREQUENCY
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW analytics.vw_customer_orders_frequency AS
SELECT
    c.customer_id,
    (c.first_name || ' ' || c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id) AS orders_count,
    MIN(o.order_date)          AS first_order_date,
    MAX(o.order_date)          AS last_order_date,
    SUM(oi.quantity)           AS total_units,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_spent,
    ROUND(
      SUM(oi.quantity * oi.list_price * (1 - oi.discount))
      / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS avg_order_value,
    ROUND(
      ((MAX(o.order_date) - MIN(o.order_date))::numeric)
      / NULLIF(COUNT(DISTINCT o.order_id) - 1, 0), 1
    ) AS avg_days_between_orders
FROM sales.customers c
JOIN sales.orders    o  ON o.customer_id = c.customer_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;

/* ------------------------------------------------------------
               ORDER FULFILLMENT (line level)
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW analytics.vw_order_fulfillment AS
SELECT
    o.order_id,
    o.order_date,
    o.required_date,
    o.shipped_date,
    CASE
      WHEN o.shipped_date IS NULL            THEN 'Pending'
      WHEN o.required_date IS NULL           THEN 'Shipped (No SLA)'
      WHEN o.shipped_date <= o.required_date THEN 'On Time'
      ELSE 'Late'
    END AS fulfillment_status,
    (o.shipped_date - o.order_date) AS fulfillment_days
FROM sales.orders o;

-- Compact summary for KPI cards
CREATE OR REPLACE VIEW analytics.vw_order_fulfillment_summary AS
SELECT
    fulfillment_status,
    COUNT(*)                          AS orders_count,
    ROUND(AVG(fulfillment_days), 1)   AS avg_fulfillment_days
FROM analytics.vw_order_fulfillment
GROUP BY fulfillment_status;

/* ------------------------------------------------------------
                     INVENTORY TRENDS
   ------------------------------------------------------------ */

-- 1) Store snapshot: how much & how broad the stock is
CREATE OR REPLACE VIEW analytics.vw_inventory_store_snapshot AS
SELECT 
    s.store_name,
    SUM(st.quantity)         AS total_stock_units,
    COUNT(st.product_id)     AS total_products_stocked,
    ROUND(AVG(st.quantity),2) AS avg_stock_per_product
FROM production.stocks st
JOIN sales.stores s ON s.store_id = st.store_id
GROUP BY s.store_name;

-- 2) Store efficiency: stock vs total units sold
CREATE OR REPLACE VIEW analytics.vw_inventory_store_efficiency AS
SELECT 
    s.store_name,
    SUM(st.quantity) AS total_stock_units,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(st.quantity)::numeric / NULLIF(SUM(oi.quantity), 0), 2) AS stock_to_sales_ratio
FROM production.stocks st
JOIN sales.stores s       ON s.store_id = st.store_id
JOIN sales.orders o       ON o.store_id = s.store_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY s.store_name;

-- 3) Category-wise efficiency within each store
CREATE OR REPLACE VIEW analytics.vw_inventory_category_efficiency AS
SELECT
    s.store_name,
    c.category_name,
    SUM(st.quantity) AS total_stock_units,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(st.quantity)::numeric / NULLIF(SUM(oi.quantity), 0), 2) AS stock_to_sales_ratio
FROM production.stocks st
JOIN sales.stores s          ON s.store_id    = st.store_id
JOIN production.products p   ON p.product_id  = st.product_id
JOIN production.categories c ON c.category_id = p.category_id
JOIN sales.orders o          ON o.store_id    = s.store_id
JOIN sales.order_items oi    ON oi.order_id   = o.order_id
                             AND oi.product_id = p.product_id
GROUP BY s.store_name, c.category_name
ORDER BY s.store_name, stock_to_sales_ratio DESC;

/* ------------------------------------------------------------
   STORE PROFITABILITY (revenue/discount/AOV; 30% profit assumption)
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW analytics.vw_store_profitability AS
SELECT
    s.store_id,
    s.store_name,
    s.city,
    s.state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity)           AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.list_price), 2)                     AS gross_sales,
    ROUND(SUM(oi.quantity * oi.list_price * oi.discount), 2)       AS discount_amount,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_sales,
    ROUND(
      (SUM(oi.quantity * oi.list_price * oi.discount)
       / NULLIF(SUM(oi.quantity * oi.list_price), 0)) * 100, 2
    ) AS avg_discount_pct,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) * 0.30, 2) AS estimated_profit,
    ROUND(
      SUM(oi.quantity * oi.list_price * (1 - oi.discount))
      / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS avg_order_value
FROM sales.stores s
JOIN sales.orders o       ON o.store_id  = s.store_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY s.store_id, s.store_name, s.city, s.state;


