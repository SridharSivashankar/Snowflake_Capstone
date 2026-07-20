SELECT

    -- Employee Attributes

    de.role,

    -- Employee Sales Metrics

    COUNT(DISTINCT fs.order_id) AS total_orders,

    SUM(fs.quantity_sold) AS total_quantity_sold,

    -- Revenue Metrics

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS total_sales_amount,


    ROUND(
        SUM(fs.profit_amount),
        2
    ) AS total_profit_amount,

    -- Contribution Metrics

    ROUND(
        100 * SUM(fs.total_sales_amount)
        / SUM(SUM(fs.total_sales_amount)) OVER (),
        2
    ) AS sales_contribution_percentage

FROM {{ ref('fact_sales') }} fs

    -- Employee Dimension

    INNER JOIN {{ ref('dim_employee') }} de
        ON fs.employee_key = de.employee_key

GROUP BY

    de.role

-- Highest contributing roles first

ORDER BY

    total_sales_amount DESC