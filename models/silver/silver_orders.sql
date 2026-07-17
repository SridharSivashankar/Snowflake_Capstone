WITH source AS (

    SELECT *
    FROM {{ ref('bronze_orders') }}

),

orders_flattened AS (

    SELECT

        f.value:order_id::STRING                    AS order_id,
        f.value:customer_id::STRING                 AS customer_id,
        f.value:employee_id::STRING                 AS employee_id,
        f.value:campaign_id::STRING                 AS campaign_id,
        f.value:store_id::STRING                    AS store_id,

        INITCAP(TRIM(f.value:order_source::STRING)) AS order_source,
        INITCAP(TRIM(f.value:order_status::STRING)) AS order_status,
        INITCAP(TRIM(f.value:payment_method::STRING)) AS payment_method,
        INITCAP(TRIM(f.value:shipping_method::STRING)) AS shipping_method,

        COALESCE(
            f.value:discount_amount::NUMBER(18,6),
            0
        ) AS order_discount,

        COALESCE(
            f.value:shipping_cost::NUMBER(18,2),
            0
        ) AS shipping_cost,

        COALESCE(
            f.value:tax_amount::NUMBER(18,2),
            0
        ) AS tax_amount,

        COALESCE(
            f.value:total_amount::NUMBER(18,2),
            0
        ) AS total_amount,

        TO_TIMESTAMP_NTZ(f.value:created_at::STRING)
            AS created_at,

        TO_TIMESTAMP_NTZ(f.value:order_date::STRING)
            AS order_date,

        TO_TIMESTAMP_NTZ(f.value:shipping_date::STRING)
            AS shipping_date,

        TO_TIMESTAMP_NTZ(f.value:delivery_date::STRING)
            AS delivery_date,

        TO_TIMESTAMP_NTZ(f.value:estimated_delivery_date::STRING)
            AS estimated_delivery_date,

        INITCAP(TRIM(f.value:billing_address:street::STRING))
            AS billing_street,

        INITCAP(TRIM(f.value:billing_address:city::STRING))
            AS billing_city,

        UPPER(TRIM(f.value:billing_address:state::STRING))
            AS billing_state,

        TRIM(f.value:billing_address:zip_code::STRING)
            AS billing_zip_code,

        INITCAP(TRIM(f.value:shipping_address:street::STRING))
            AS shipping_street,

        INITCAP(TRIM(f.value:shipping_address:city::STRING))
            AS shipping_city,

        UPPER(TRIM(f.value:shipping_address:state::STRING))
            AS shipping_state,

        TRIM(f.value:shipping_address:zip_code::STRING)
            AS shipping_zip_code,

        item.value:product_id::STRING AS product_id,

        COALESCE(
            item.value:quantity::NUMBER,
            0
        ) AS quantity,

        COALESCE(
            item.value:unit_price::NUMBER(18,2),
            0
        ) AS unit_price,

        COALESCE(
            item.value:cost_price::NUMBER(18,2),
            0
        ) AS cost_price,

        COALESCE(
            item.value:discount_amount::NUMBER(18,6),
            0
        ) AS item_discount

    FROM source,
    LATERAL FLATTEN(
        INPUT => _SOURCE_FILE:orders_data
    ) f,
    LATERAL FLATTEN(
        INPUT => f.value:order_items
    ) item

),

order_item_metrics AS (

    SELECT

        *,

        ------------------------------------------------
        -- Treat discounts as percentages
        ------------------------------------------------

        ROUND(
            quantity * unit_price * (1 - (item_discount / 100)),
            2
        ) AS line_revenue_amount,

        ROUND(
            quantity * cost_price,
            2
        ) AS line_cost_amount

    FROM orders_flattened

),

aggregated_orders AS (

    SELECT

        ------------------------------------------------
        -- Keys
        ------------------------------------------------

        order_id,
        product_id,
        customer_id,
        employee_id,
        campaign_id,
        store_id,
        
        ------------------------------------------------
        -- Order Attributes
        ------------------------------------------------

        order_source,
        order_status,
        payment_method,
        shipping_method,

        order_discount,

        shipping_cost,
        tax_amount,
        total_amount,

        created_at,
        order_date,
        shipping_date,
        delivery_date,
        estimated_delivery_date,

        ------------------------------------------------
        -- Addresses
        ------------------------------------------------

        CONCAT(
            billing_street,
            ', ',
            billing_city,
            ', ',
            billing_state,
            ' ',
            billing_zip_code
        ) AS billing_address,

        CONCAT(
            shipping_street,
            ', ',
            shipping_city,
            ', ',
            shipping_state,
            ' ',
            shipping_zip_code
        ) AS shipping_address,

        ------------------------------------------------
        -- Aggregated Order Metrics
        ------------------------------------------------

        COUNT(product_id) AS total_items,

        SUM(quantity) AS total_quantity,

        ROUND(
            SUM(quantity * unit_price),
            2
        ) AS gross_sales_amount,

        ROUND(
            SUM(quantity * cost_price),
            2
        ) AS total_cost,

        ROUND(
            SUM(item_discount),
            2
        ) AS total_discount,

        ------------------------------------------------
        -- Profitability Base Metrics
        ------------------------------------------------

        ROUND(
            SUM(line_revenue_amount),
            2
        ) AS line_revenue,

        ROUND(
            SUM(line_cost_amount),
            2
        ) AS line_cost

    FROM order_item_metrics

    GROUP BY

        order_id,
        product_id,
        customer_id,
        employee_id,
        campaign_id,
        store_id,

        order_source,
        order_status,
        payment_method,
        shipping_method,

        order_discount,

        shipping_cost,
        tax_amount,
        total_amount,

        created_at,
        order_date,
        shipping_date,
        delivery_date,
        estimated_delivery_date,

        billing_street,
        billing_city,
        billing_state,
        billing_zip_code,

        shipping_street,
        shipping_city,
        shipping_state,
        shipping_zip_code

),

final_transformed AS (

    SELECT

        *,

        ------------------------------------------------
        -- Profitability Metrics
        ------------------------------------------------

        ROUND(
            (
                (line_revenue * (1 - (order_discount / 100)))
                - line_cost
                - shipping_cost
                - tax_amount
            ),
            2
        ) AS profit_amount,

        CASE
            WHEN line_revenue > 0
            THEN ROUND(
                (
                    (
                        (
                            (line_revenue * (1 - (order_discount / 100)))
                            - line_cost
                            - shipping_cost
                            - tax_amount
                        )
                        / line_revenue
                    )
                ) * 100,
                2
            )
            ELSE NULL
        END AS profit_margin_percentage,

        ------------------------------------------------
        -- Time Of Day
        ------------------------------------------------

        CASE

            WHEN DATE_PART(HOUR, order_date) >= 5
             AND DATE_PART(HOUR, order_date) < 12
            THEN 'Morning'

            WHEN DATE_PART(HOUR, order_date) >= 12
             AND DATE_PART(HOUR, order_date) < 17
            THEN 'Afternoon'

            WHEN DATE_PART(HOUR, order_date) >= 17
             AND DATE_PART(HOUR, order_date) < 22
            THEN 'Evening'

            ELSE 'Night'

        END AS order_time_of_day,

        ------------------------------------------------
        -- Calendar Dimensions
        ------------------------------------------------

        YEAR(order_date) AS order_year,

        QUARTER(order_date) AS order_quarter,

        MONTH(order_date) AS order_month,

        WEEK(order_date) AS order_week,

        ------------------------------------------------
        -- Shipping Efficiency Metrics
        ------------------------------------------------

        DATEDIFF(
            DAY,
            order_date,
            shipping_date
        ) AS processing_days,

        DATEDIFF(
            DAY,
            shipping_date,
            delivery_date
        ) AS shipping_days,

        CASE

            WHEN delivery_date IS NOT NULL
                 AND delivery_date <= estimated_delivery_date
            THEN 'On Time'

            WHEN delivery_date IS NOT NULL
                 AND delivery_date > estimated_delivery_date
            THEN 'Delayed'

            WHEN delivery_date IS NULL
                 AND CURRENT_DATE() > CAST(estimated_delivery_date AS DATE)
            THEN 'Potentially Delayed'

            ELSE 'In Transit'

        END AS delivery_status

    FROM aggregated_orders

),

deduplicated AS (

    SELECT *

    FROM final_transformed

        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY order_id, product_id
            ORDER BY created_at DESC
        ) = 1

)

SELECT *
FROM deduplicated