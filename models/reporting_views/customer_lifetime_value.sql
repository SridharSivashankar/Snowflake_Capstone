
SELECT

    -- Customer Information

    dc.customer_id,

    dc.full_name,

    dc.segment AS customer_segment,

    dc.loyalty_tier,

    -- Purchase Metrics

    COUNT(DISTINCT fs.order_id) AS total_orders,

    SUM(fs.quantity_sold) AS total_quantity_purchased,

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS lifetime_revenue,

    ROUND(
        SUM(fs.profit_amount),
        2
    ) AS lifetime_profit,

    -- Customer Activity

    MIN(dd.full_date) AS first_purchase_date,

    MAX(dd.full_date) AS latest_purchase_date,

    DATEDIFF(
        DAY,
        MIN(dd.full_date),
        MAX(dd.full_date)
    ) AS customer_lifetime_days,

    -- Customer Lifetime Value

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS customer_lifetime_value

FROM {{ ref('fact_sales') }} fs

    -- Customer Dimension

    INNER JOIN {{ ref('dim_customer') }} dc
        ON fs.customer_key = dc.customer_key

    -- Date Dimension

    INNER JOIN {{ ref('dim_date') }} dd
        ON fs.date_key = dd.date_key

GROUP BY

    dc.customer_id,
    dc.full_name,
    dc.segment,
    dc.loyalty_tier

-- Highest CLV customers first

ORDER BY

    customer_lifetime_value DESC