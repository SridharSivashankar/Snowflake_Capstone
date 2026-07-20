
--   Since the source data contains one product per row in silver_orders, order-level amounts such as discount
--   and shipping cost are stored directly on each fact row.

--   No allocation is required because there is no multi-product order represented within a single row.


WITH sales AS (

    SELECT *
    FROM {{ ref('silver_orders') }}

),

customers AS (

    SELECT *
    FROM {{ ref('dim_customer') }}
    WHERE is_current = TRUE

),

products AS (

    SELECT *
    FROM {{ ref('dim_product') }}

),

stores AS (

    SELECT *
    FROM {{ ref('dim_store') }}

),

employees AS (

    SELECT *
    FROM {{ ref('dim_employee') }}

),

dates AS (

    SELECT *
    FROM {{ ref('dim_date') }}

)

SELECT

    -- Fact Surrogate Key
    {{ dbt_utils.generate_surrogate_key([
        's.order_id',
        's.product_id'
    ]) }} AS sales_key,

    -- Degenerate Dimension

    s.order_id,

    -- Dimension Foreign Keys
    c.customer_key,

    p.product_key,

    st.store_key,

    d.date_key,

    e.employee_key,

    -- Measures
    s.total_quantity
        AS quantity_sold,

    p.unit_price,

    ROUND(
        s.total_quantity * p.unit_price,
        2
    ) AS total_sales_amount,

    ROUND(
        s.total_quantity * p.cost_price,
        2
    ) AS cost_amount,

-- Discount is assumed as percentage of total sales amount

    COALESCE(
        round(s.total_discount*total_sales_amount/100,2),
        0
    ) AS discount_amount,

    COALESCE(
        s.shipping_cost,
        0
    ) AS shipping_cost,

    ROUND(
        (
            (s.total_quantity * p.unit_price)
            -
            (s.total_quantity * p.cost_price)
            -
            COALESCE(s.total_discount,0)
            -
            COALESCE(s.shipping_cost,0)
        ),
        2
    ) AS profit_amount,

    st.region,

    CASE
        WHEN UPPER(s.order_source) IN (
            'WEBSITE',
            'MOBILE APP'
        )
        THEN 'Online'

        WHEN UPPER(s.order_source) = 'IN-STORE'
        THEN 'In-Store'

        ELSE 'Unknown'
    END AS sales_channel,

    c.segment
        AS customer_segment_impact

FROM sales s

LEFT JOIN customers c
    ON s.customer_id = c.customer_id

LEFT JOIN products p
    ON s.product_id = p.product_id

LEFT JOIN stores st
    ON s.store_id = st.store_id

LEFT JOIN employees e
    ON s.employee_id = e.employee_id

LEFT JOIN dates d
    ON CAST(s.order_date AS DATE) = d.full_date