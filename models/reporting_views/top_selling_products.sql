
SELECT

    -- Product Information

    dp.product_name,

    dp.category,

    dp.brand,

    -- Sales Metrics

    SUM(fs.quantity_sold) AS total_quantity_sold,

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS total_sales_amount,

    ROUND(
        SUM(fs.profit_amount),
        2
    ) AS total_profit_amount,

    COUNT(DISTINCT fs.order_id) AS total_orders

FROM {{ ref('fact_sales') }} fs

    -- Product Dimension

    INNER JOIN {{ ref('dim_product') }} dp
        ON fs.product_key = dp.product_key

GROUP BY

    dp.product_name,
    dp.category,
    dp.brand

-- Highest selling products first

ORDER BY

    total_sales_amount DESC,
    total_quantity_sold DESC
    