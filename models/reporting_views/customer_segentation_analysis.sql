
SELECT


    -- Customer Segmentation Attributes

    dc.segment AS customer_segment,

    dc.loyalty_tier,

    dc.income_bracket,

    -- Customer Metrics

    COUNT(DISTINCT dc.customer_id) AS total_customers,

    COUNT(DISTINCT fs.order_id) AS total_orders,

    -- Sales Metrics

    SUM(fs.quantity_sold) AS total_quantity_purchased,

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS total_revenue,

    ROUND(
        SUM(fs.profit_amount),
        2
    ) AS total_profit,

    ROUND(
        AVG(fs.total_sales_amount),
        2
    ) AS average_order_value,

    -- Customer Value Metrics

    ROUND(
        SUM(fs.total_sales_amount)
        / NULLIF(COUNT(DISTINCT dc.customer_id), 0),
        2
    ) AS revenue_per_customer,

    ROUND(
        COUNT(DISTINCT fs.order_id)
        / NULLIF(COUNT(DISTINCT dc.customer_id), 0),
        2
    ) AS orders_per_customer

FROM {{ ref('fact_sales') }} fs

    -- Customer Dimension

    INNER JOIN {{ ref('dim_customer') }} dc
        ON fs.customer_key = dc.customer_key

GROUP BY

    dc.segment,
    dc.loyalty_tier,
    dc.income_bracket

-- Highest revenue generating segments first

ORDER BY

    total_revenue DESC