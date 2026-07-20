
SELECT


    -- Calendar Attributes

    dd.year,

    dd.month,

    -- Geographic Dimension

    ds.region,

    -- Sales Metrics

    COUNT(*) AS total_order_lines,

    SUM(fs.quantity_sold) AS total_quantity_sold,

    ROUND(
        SUM(fs.total_sales_amount),
        2
    ) AS total_sales_amount,

    ROUND(
        SUM(fs.profit_amount),
        2
    ) AS total_profit_amount

FROM {{ ref('fact_sales') }} fs

    -- Date Dimension for Year and Month analysis

    INNER JOIN {{ ref('dim_date') }} dd
        ON fs.date_key = dd.date_key

    -- Store Dimension for Regional analysis
  
    INNER JOIN {{ ref('dim_store') }} ds
        ON fs.store_key = ds.store_key

GROUP BY

    dd.year,
    dd.month,
    ds.region

-- Show trend chronologically

ORDER BY

    dd.year,
    dd.month,
    ds.region