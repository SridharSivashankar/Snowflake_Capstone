SELECT

    ------------------------------------------------------------
    -- Customer Information
    ------------------------------------------------------------
    dc.customer_id,

    dc.full_name,

    dc.segment AS customer_segment,

    dc.loyalty_tier,

    ------------------------------------------------------------
    -- Purchase Frequency Metrics

    COUNT(DISTINCT fs.order_id) AS total_orders,

    CASE
        WHEN COUNT(DISTINCT fs.order_id) > 1
        THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS customer_type,

    ------------------------------------------------------------
    -- Revenue Metrics

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS total_revenue,

    ROUND(
        AVG(fs.total_sales_amount),
        2
    ) AS average_order_value,

    ------------------------------------------------------------
    -- Repeat Purchase Indicator

    CASE
        WHEN COUNT(DISTINCT fs.order_id) > 1
        THEN 1
        ELSE 0
    END AS repeat_purchase_flag

FROM {{ ref('fact_sales') }} fs

    ------------------------------------------------------------
    -- Customer Dimension

    INNER JOIN {{ ref('dim_customer') }} dc
        ON fs.customer_key = dc.customer_key

GROUP BY

    dc.customer_id,
    dc.full_name,
    dc.segment,
    dc.loyalty_tier

------------------------------------------------------------
-- Customers with highest purchase frequency first

ORDER BY

    total_revenue DESC,
    total_orders DESC
    