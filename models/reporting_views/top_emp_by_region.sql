
SELECT

    ------------------------------------------------------------
    -- Region and Employee Attributes

    ds.region,

    de.employee_id,

    de.full_name,

    de.role,

    ------------------------------------------------------------
    -- Performance Metrics

    COUNT(DISTINCT fs.order_id) AS total_orders,

    SUM(fs.quantity_sold) AS total_quantity_sold,

    ------------------------------------------------------------
    -- Revenue Metrics

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS total_sales_amount,

    ROUND(
        SUM(fs.profit_amount),
        2
    ) AS total_profit_amount,

    ROUND(
        AVG(fs.total_sales_amount),
        2
    ) AS average_order_value,

    ------------------------------------------------------------
    -- Regional Employee Ranking

    DENSE_RANK() OVER (
        PARTITION BY ds.region
        ORDER BY SUM(fs.total_sales_amount) DESC
    ) AS regional_rank

FROM {{ ref('fact_sales') }} fs

    ------------------------------------------------------------
    -- Employee Dimension

    INNER JOIN {{ ref('dim_employee') }} de
        ON fs.employee_key = de.employee_key

    ------------------------------------------------------------
    -- Store Dimension

    INNER JOIN {{ ref('dim_store') }} ds
        ON fs.store_key = ds.store_key

GROUP BY

    ds.region,
    de.employee_id,
    de.full_name,
    de.role

------------------------------------------------------------
-- Best performers within each region

ORDER BY

    ds.region,
    regional_rank