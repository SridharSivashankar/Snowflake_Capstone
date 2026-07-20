SELECT

    dp.category,
    dp.subcategory,

    -- Number of sales transactions (order-product combinations)

    COUNT(*) AS total_order_lines,

    -- Total quantity sold

    SUM(fs.quantity_sold) AS total_quantity_sold,

    -- Revenue generated

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS total_sales_amount,

    -- Total profit generated

    ROUND(
        SUM(fs.profit_amount),
        2
    ) AS total_profit_amount

FROM {{ ref('fact_sales') }} fs

    -- Join Product Dimension to access product hierarchy

    INNER JOIN {{ ref('dim_product') }} dp
        ON fs.product_key = dp.product_key

-- Aggregate metrics at Category and Subcategory level

GROUP BY

    dp.category,
    dp.subcategory

-- Show Subcategories ranked within each Category

ORDER BY

    dp.category,
    total_sales_amount DESC