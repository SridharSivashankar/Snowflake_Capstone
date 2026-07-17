SELECT
    ------------------------------------------------------------
    -- Employee Attributes

    de.employee_id,

    de.full_name,

    de.role,

    de.work_location,

    de.tenure,

    de.performance_rating,

    ------------------------------------------------------------
    -- Sales Performance Metrics

    COUNT(DISTINCT fs.order_id) AS total_orders,

    SUM(fs.quantity_sold) AS total_quantity_sold,

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
    -- Productivity Metrics

    ROUND(
        SUM(fs.total_sales_amount)
        / NULLIF(COUNT(DISTINCT fs.order_id), 0),
        2
    ) AS sales_per_order,

    ROUND(
        SUM(fs.profit_amount)
        / NULLIF(COUNT(DISTINCT fs.order_id), 0),
        2
    ) AS profit_per_order

FROM {{ ref('fact_sales') }} fs

    ------------------------------------------------------------
    -- Employee Dimension

    INNER JOIN {{ ref('dim_employee') }} de
        ON fs.employee_key = de.employee_key

GROUP BY

    de.employee_id,
    de.full_name,
    de.role,
    de.work_location,
    de.tenure,
    de.performance_rating

------------------------------------------------------------
-- Highest sales employees first

ORDER BY

    total_sales_amount DESC