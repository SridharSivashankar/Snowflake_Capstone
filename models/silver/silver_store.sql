WITH source AS (

    SELECT *
    FROM {{ ref('bronze_store') }}

),

flattened AS (

    SELECT

        f.value:store_id::STRING                 AS store_id,
        f.value:store_name::STRING               AS store_name,
        f.value:store_type::STRING               AS store_type,

        f.value:email::STRING                    AS email,
        f.value:phone_number::STRING             AS phone_number,

        f.value:manager_id::STRING               AS manager_id,

        f.value:region::STRING                   AS region,

        f.value:size_sq_ft::NUMBER               AS size_sq_ft,

        f.value:employee_count::NUMBER           AS employee_count,

        f.value:current_sales::NUMBER(18,2)      AS current_sales,
        f.value:sales_target::NUMBER(18,2)       AS sales_target,
        f.value:monthly_rent::NUMBER(18,2)       AS monthly_rent,

        f.value:is_active::BOOLEAN               AS is_active,

        f.value:opening_date::STRING             AS opening_date,
        f.value:last_modified_date::STRING       AS last_modified_date,

        f.value:services                         AS services,

        f.value:operating_hours:weekdays::STRING AS weekday_hours,
        f.value:operating_hours:weekends::STRING AS weekend_hours,
        f.value:operating_hours:holidays::STRING AS holiday_hours,

        f.value:address:street::STRING           AS street,
        f.value:address:city::STRING             AS city,
        f.value:address:state::STRING            AS state,
        f.value:address:country::STRING          AS country,
        f.value:address:zip_code::STRING         AS zip_code

    FROM source,
    LATERAL FLATTEN(
        INPUT => _SOURCE_FILE:stores_data
    ) f

),

cleaned AS (

    SELECT


        TRIM(store_id) AS store_id,



        INITCAP(TRIM(store_name))
            AS store_name,

        INITCAP(TRIM(store_type))
            AS store_type,

        INITCAP(TRIM(region))
            AS region,

        TRIM(manager_id)
            AS manager_id,


        LOWER(TRIM(email))
            AS email_id,

        CASE
            WHEN REGEXP_LIKE(
                LOWER(TRIM(email)),
                '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
            )
            THEN LOWER(TRIM(email))
            ELSE NULL
        END AS valid_email_id,

        CASE
            WHEN REGEXP_LIKE(
                LOWER(TRIM(email)),
                '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
            )
            THEN 'VALID'
            ELSE 'INVALID'
        END AS email_status,



        phone_number AS original_phone,

        CASE
            WHEN LENGTH(
                RIGHT(
                    REGEXP_REPLACE(phone_number,'[^0-9]',''),
                    10
                )
            ) = 10
            THEN RIGHT(
                REGEXP_REPLACE(phone_number,'[^0-9]',''),
                10
            )
            ELSE NULL
        END AS phn_no,

        CASE
            WHEN LENGTH(
                RIGHT(
                    REGEXP_REPLACE(phone_number,'[^0-9]',''),
                    10
                )
            ) = 10
            THEN 'VALID'
            ELSE 'INVALID'
        END AS phone_status,



        INITCAP(TRIM(street))
            AS street,

        INITCAP(TRIM(city))
            AS city,

        UPPER(TRIM(state))
            AS state,

        UPPER(TRIM(country))
            AS country,

        TRIM(zip_code)
            AS zip_code,

        CASE
            WHEN REGEXP_LIKE(
                TRIM(zip_code),
                '^[0-9]{5}$'
            )
            THEN 'VALID'
            ELSE 'INVALID'
        END AS postal_code_status,

        CONCAT(
            INITCAP(TRIM(street)),
            ', ',
            INITCAP(TRIM(city)),
            ', ',
            UPPER(TRIM(state)),
            ', ',
            TRIM(zip_code),
            ', ',
            UPPER(TRIM(country))
        ) AS standardized_address,


        TO_DATE(opening_date)
            AS opening_date,

        TO_DATE(last_modified_date)
            AS last_modified_date,


        ROUND(
            DATEDIFF(
                DAY,
                TO_DATE(opening_date),
                CURRENT_DATE()
            ) / 365.25,
            2
        ) AS store_age_years,


        COALESCE(size_sq_ft,0)
            AS size_sq_ft,

        CASE

            WHEN size_sq_ft < 5000
            THEN 'Small'

            WHEN size_sq_ft BETWEEN 5000 AND 10000
            THEN 'Medium'

            WHEN size_sq_ft > 10000
            THEN 'Large'

            ELSE 'Unknown'

        END AS store_size_category,


        COALESCE(employee_count,0)
            AS employee_count,

        COALESCE(current_sales,0)
            AS current_sales,

        COALESCE(sales_target,0)
            AS sales_target,

        COALESCE(monthly_rent,0)
            AS monthly_rent,

        is_active,



        CASE
            WHEN sales_target > 0
            THEN ROUND(
                (current_sales / sales_target) * 100,
                2
            )
            ELSE NULL
        END AS sales_target_achievement_percentage,

        CASE
            WHEN size_sq_ft > 0
            THEN ROUND(
                current_sales / size_sq_ft,
                2
            )
            ELSE NULL
        END AS revenue_per_sq_ft,

        CASE
            WHEN employee_count > 0
            THEN ROUND(
                current_sales / employee_count,
                2
            )
            ELSE NULL
        END AS employee_efficiency,

        CASE
            WHEN sales_target > 0
                 AND ((current_sales / sales_target) * 100) < 90
            THEN 'PERFORMANCE ISSUE'
            ELSE 'HEALTHY'
        END AS performance_flag,


        weekday_hours,
        weekend_hours,
        holiday_hours,

        services

    FROM flattened

),

deduplicated AS (

    SELECT *

    FROM cleaned

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY store_id
        ORDER BY last_modified_date DESC
    ) = 1

)

SELECT *
FROM deduplicated