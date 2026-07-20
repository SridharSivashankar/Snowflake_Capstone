WITH source AS (

    -- Source Data

    SELECT *
    FROM {{ ref('bronze_product') }}

),

flattened AS (

    SELECT

        -- Product Details

        f.value:product_id::STRING            AS product_id,
        f.value:name::STRING                  AS product_name,
        f.value:short_description::STRING     AS short_description,
        f.value:technical_specs::STRING       AS technical_specs,

        f.value:brand::STRING                 AS brand,

        f.value:category::STRING              AS category,
        f.value:subcategory::STRING           AS subcategory,
        f.value:product_line::STRING          AS product_line,

        f.value:color::STRING                 AS color,
        f.value:size::STRING                  AS size,

        f.value:weight::STRING                AS weight,
        f.value:dimensions::STRING            AS dimensions,

        f.value:warranty_period::STRING       AS warranty_period,

        -- Supplier Details

        f.value:supplier_id::STRING           AS supplier_id,

        -- Pricing

        f.value:cost_price::NUMBER(18,2)      AS cost_price,
        f.value:unit_price::NUMBER(18,2)      AS unit_price,

        -- Inventory

        f.value:stock_quantity::NUMBER        AS stock_quantity,
        f.value:reorder_level::NUMBER         AS reorder_level,

        f.value:is_featured::BOOLEAN          AS is_featured,

        -- Dates

        f.value:launch_date::STRING           AS launch_date,
        f.value:last_modified_date::STRING    AS last_modified_date

    FROM source,
    LATERAL FLATTEN(
        INPUT => _SOURCE_FILE:products_data
    ) f

),

cleaned AS (

    SELECT

        -- Product Key

        TRIM(product_id) AS product_id,

        -- Product Standardization

        INITCAP(TRIM(product_name))
            AS product_name,

        INITCAP(TRIM(brand))
            AS brand,

        INITCAP(TRIM(category))
            AS category,

        INITCAP(TRIM(subcategory))
            AS subcategory,

        INITCAP(TRIM(product_line))
            AS product_line,

        INITCAP(TRIM(color))
            AS color,

        INITCAP(TRIM(size))
            AS size,

        INITCAP(TRIM(warranty_period))
            AS warranty_period,

        INITCAP(TRIM(short_description))
            AS short_description,

        technical_specs,

        -- Product Description

        CONCAT(
            INITCAP(TRIM(product_name)),
            ' | ',
            INITCAP(TRIM(short_description)),
            ' | ',
            TRIM(technical_specs)
        ) AS product_full_description,

        -- Product Hierarchy

        CONCAT(
            INITCAP(TRIM(category)),
            ' > ',
            INITCAP(TRIM(subcategory)),
            ' > ',
            INITCAP(TRIM(product_line))
        ) AS product_hierarchy,

        -- Pricing Metrics

        COALESCE(cost_price,0)
            AS cost_price,

        COALESCE(unit_price,0)
            AS unit_price,

        ROUND(
            unit_price - cost_price,
            2
        ) AS profit_amount,

        CASE
            WHEN unit_price > 0
            THEN ROUND(
                (
                    (unit_price - cost_price)
                    / unit_price
                ) * 100,
                2
            )
            ELSE NULL
        END AS profit_margin_percentage,

        -- Inventory Metrics

        COALESCE(stock_quantity,0)
            AS stock_quantity,

        COALESCE(reorder_level,0)
            AS reorder_level,

        CASE
            WHEN stock_quantity < reorder_level
            THEN TRUE
            ELSE FALSE
        END AS is_low_stock,

        CASE
            WHEN stock_quantity < reorder_level
            THEN 'LOW STOCK'
            ELSE 'IN STOCK'
        END AS stock_status,

        is_featured,

        -- Supplier Reference

        TRIM(supplier_id)
            AS supplier_id,

        -- Physical Attributes

        TRIM(weight)
            AS weight,

        TRIM(dimensions)
            AS dimensions,

        -- Date Standardization

        TO_DATE(launch_date)
            AS launch_date,

        TO_DATE(last_modified_date)
            AS last_modified_date

    FROM flattened

),

deduplicated AS (

    SELECT *

    FROM cleaned

    -- Latest Product Record

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY product_id
        ORDER BY last_modified_date DESC
    ) = 1

)

SELECT *
FROM deduplicated