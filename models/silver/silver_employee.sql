WITH source AS (

    -- Source Data

    SELECT *
    FROM {{ ref('bronze_employee') }}

),

flattened AS (

    SELECT

        -- Employee Details

        f.value:employee_id::STRING               AS employee_id,

        f.value:first_name::STRING                AS first_name,
        f.value:last_name::STRING                 AS last_name,

        f.value:email::STRING                     AS email,
        f.value:phone::STRING                     AS phone,

        f.value:date_of_birth::STRING             AS date_of_birth,
        f.value:hire_date::STRING                 AS hire_date,
        f.value:last_modified_date::STRING        AS last_modified_date,

        -- Employment Details

        f.value:department::STRING                AS department,
        f.value:role::STRING                      AS role,
        f.value:education::STRING                 AS education,
        f.value:employment_status::STRING         AS employment_status,

        f.value:manager_id::STRING                AS manager_id,
        f.value:work_location::STRING             AS work_location,

        -- Performance Metrics

        f.value:salary::NUMBER(18,2)              AS salary,
        f.value:current_sales::NUMBER(18,2)       AS current_sales,
        f.value:sales_target::NUMBER(18,2)        AS sales_target,
        f.value:performance_rating::NUMBER(5,2)   AS performance_rating,

        f.value:certifications                    AS certifications,

        -- Address Details

        f.value:address:street::STRING            AS street,
        f.value:address:city::STRING              AS city,
        f.value:address:state::STRING             AS state,
        f.value:address:zip_code::STRING          AS zip_code

    FROM source,
    LATERAL FLATTEN(
        INPUT => _SOURCE_FILE:employees_data
    ) f

),

cleaned AS (

    SELECT

        -- Employee Key

        TRIM(employee_id) AS employee_id,

        -- Name Standardization

        INITCAP(TRIM(first_name)) AS first_name,

        INITCAP(TRIM(last_name)) AS last_name,

        CONCAT(
            INITCAP(TRIM(first_name)),
            ' ',
            INITCAP(TRIM(last_name))
        ) AS full_name,

        -- Email Validation

        LOWER(TRIM(email)) AS email_id,

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

        -- Phone Validation

        phone AS original_phone,

        CASE
            WHEN LENGTH(
                RIGHT(
                    REGEXP_REPLACE(phone, '[^0-9]', ''),
                    10
                )
            ) = 10
            THEN RIGHT(
                REGEXP_REPLACE(phone, '[^0-9]', ''),
                10
            )
            ELSE NULL
        END AS phn_no,

        CASE
            WHEN LENGTH(
                RIGHT(
                    REGEXP_REPLACE(phone, '[^0-9]', ''),
                    10
                )
            ) = 10
            THEN 'VALID'
            ELSE 'INVALID'
        END AS phone_status,

        -- Date Standardization

        TO_DATE(date_of_birth) AS date_of_birth,

        TO_DATE(hire_date) AS hire_date,

        TO_DATE(last_modified_date) AS last_modified_date,

        -- Tenure Calculation

        ROUND(
            DATEDIFF(
                DAY,
                TO_DATE(hire_date),
                CURRENT_DATE()
            ) / 365.25,
            2
        ) AS tenure_years,

        -- Attribute Standardization

        INITCAP(TRIM(department))
            AS department,

        INITCAP(TRIM(education))
            AS education,

        UPPER(TRIM(employment_status))
            AS employment_status,

        TRIM(manager_id)
            AS manager_id,

        UPPER(TRIM(work_location))
            AS work_location,

        -- Role Standardization

        CASE

            WHEN UPPER(TRIM(role))
                = 'SALES ASSOCIATE'
            THEN 'Associate'

            WHEN UPPER(TRIM(role))
                = 'STORE MANAGER'
            THEN 'Manager'

            WHEN UPPER(TRIM(role))
                = 'SENIOR MANAGER'
            THEN 'Senior Manager'

            ELSE INITCAP(TRIM(role))

        END AS standardized_role,

        -- Performance Measures

        COALESCE(salary,0)
            AS salary,

        COALESCE(current_sales,0)
            AS current_sales,

        COALESCE(sales_target,0)
            AS sales_target,

        COALESCE(performance_rating,0)
            AS performance_rating,

        CASE
            WHEN sales_target > 0
            THEN ROUND(
                (current_sales / sales_target) * 100,
                2
            )
            ELSE NULL
        END AS target_achievement_percentage,

        -- Certifications

        certifications,

        -- Address Standardization

        INITCAP(TRIM(street))
            AS street,

        INITCAP(TRIM(city))
            AS city,

        UPPER(TRIM(state))
            AS state,

        TRIM(zip_code)
            AS zip_code,

        CONCAT(
            INITCAP(TRIM(street)),
            ', ',
            INITCAP(TRIM(city)),
            ', ',
            UPPER(TRIM(state)),
            ' ',
            TRIM(zip_code)
        ) AS standardized_address

    FROM flattened

),

deduplicated AS (

    SELECT *

    FROM cleaned

    -- Latest Employee Record

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY employee_id
        ORDER BY last_modified_date DESC
    ) = 1

)

SELECT *
FROM deduplicated