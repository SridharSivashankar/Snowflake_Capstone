WITH source AS (

    SELECT *
    FROM {{ ref('bronze_supplier') }}

),

flattened AS (

    SELECT

        f.value:supplier_id::STRING                    AS supplier_id,
        f.value:supplier_name::STRING                  AS supplier_name,
        f.value:supplier_type::STRING                  AS supplier_type,

        f.value:tax_id::STRING                         AS tax_id,
        f.value:website::STRING                        AS website,

        f.value:credit_rating::STRING                  AS credit_rating,

        f.value:is_active::BOOLEAN                     AS is_active,

        f.value:lead_time_days::NUMBER                 AS lead_time_days,
        f.value:minimum_order_quantity::NUMBER         AS minimum_order_quantity,

        f.value:payment_terms::STRING                  AS payment_terms,
        f.value:preferred_carrier::STRING              AS preferred_carrier,

        f.value:year_established::NUMBER               AS year_established,

        f.value:last_order_date::STRING                AS last_order_date,
        f.value:last_modified_date::STRING             AS last_modified_date,

        f.value:categories_supplied                    AS categories_supplied,

        ----------------------------------------------------
        -- Contact Information
        ----------------------------------------------------

        f.value:contact_information:contact_person::STRING
            AS contact_person,

        f.value:contact_information:email::STRING
            AS email,

        f.value:contact_information:phone::STRING
            AS phone,

        f.value:contact_information:address::STRING
            AS address,

        ----------------------------------------------------
        -- Contract
        ----------------------------------------------------

        f.value:contract_details:contract_id::STRING
            AS contract_id,

        f.value:contract_details:start_date::STRING
            AS contract_start_date,

        f.value:contract_details:end_date::STRING
            AS contract_end_date,

        f.value:contract_details:renewal_option::BOOLEAN
            AS renewal_option,

        f.value:contract_details:exclusivity::BOOLEAN
            AS exclusivity,

        ----------------------------------------------------
        -- Performance Metrics
        ----------------------------------------------------

        f.value:performance_metrics:average_delay_days::NUMBER(18,2)
            AS average_delay_days,

        f.value:performance_metrics:defect_rate::NUMBER(18,2)
            AS defect_rate,

        f.value:performance_metrics:on_time_delivery_rate::NUMBER(18,2)
            AS on_time_delivery_rate,

        f.value:performance_metrics:quality_rating::STRING
            AS quality_rating,

        f.value:performance_metrics:response_time_hours::NUMBER(18,2)
            AS response_time_hours,

        f.value:performance_metrics:returns_percentage::NUMBER(18,2)
            AS returns_percentage

    FROM source,
    LATERAL FLATTEN(
        INPUT => _SOURCE_FILE:suppliers_data
    ) f

),

cleaned AS (

    SELECT

        ----------------------------------------------------
        -- Keys
        ----------------------------------------------------

        TRIM(supplier_id) AS supplier_id,

        ----------------------------------------------------
        -- Supplier Standardization
        ----------------------------------------------------

        INITCAP(TRIM(supplier_name))
            AS supplier_name,

        INITCAP(TRIM(supplier_type))
            AS supplier_type,

        TRIM(tax_id)
            AS tax_id,

        LOWER(TRIM(website))
            AS website,

        UPPER(TRIM(credit_rating))
            AS credit_rating,

        ----------------------------------------------------
        -- Contact Person
        ----------------------------------------------------

        INITCAP(TRIM(contact_person))
            AS contact_person,

        ----------------------------------------------------
        -- Email Validation
        ----------------------------------------------------

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

        ----------------------------------------------------
        -- Phone Validation
        ----------------------------------------------------

        phone AS original_phone,

        CASE
            WHEN LENGTH(
                RIGHT(
                    REGEXP_REPLACE(phone,'[^0-9]',''),
                    10
                )
            ) = 10
            THEN RIGHT(
                REGEXP_REPLACE(phone,'[^0-9]',''),
                10
            )
            ELSE NULL
        END AS phn_no,

        CASE
            WHEN LENGTH(
                RIGHT(
                    REGEXP_REPLACE(phone,'[^0-9]',''),
                    10
                )
            ) = 10
            THEN 'VALID'
            ELSE 'INVALID'
        END AS phone_status,

        ----------------------------------------------------
        -- Address
        ----------------------------------------------------

        TRIM(address)
            AS address,

        ----------------------------------------------------
        -- Dates
        ----------------------------------------------------

        TO_DATE(last_order_date)
            AS last_order_date,

        TO_DATE(last_modified_date)
            AS last_modified_date,

        TO_DATE(contract_start_date)
            AS contract_start_date,

        TO_DATE(contract_end_date)
            AS contract_end_date,

        ----------------------------------------------------
        -- Contract Metrics
        ----------------------------------------------------

        DATEDIFF(
            DAY,
            TO_DATE(contract_start_date),
            TO_DATE(contract_end_date)
        ) AS contract_duration_days,

        CASE
            WHEN TO_DATE(contract_end_date) >= CURRENT_DATE()
            THEN 'ACTIVE'
            ELSE 'EXPIRED'
        END AS contract_status,

        ----------------------------------------------------
        -- Supplier Age
        ----------------------------------------------------

        YEAR(CURRENT_DATE()) - year_established
            AS supplier_age_years,

        ----------------------------------------------------
        -- Business Metrics
        ----------------------------------------------------

        COALESCE(lead_time_days,0)
            AS lead_time_days,

        COALESCE(minimum_order_quantity,0)
            AS minimum_order_quantity,

        payment_terms,

        preferred_carrier,

        is_active,

        renewal_option,

        exclusivity,

        ----------------------------------------------------
        -- Performance Metrics
        ----------------------------------------------------

        COALESCE(average_delay_days,0)
            AS average_delay_days,

        COALESCE(defect_rate,0)
            AS defect_rate,

        COALESCE(on_time_delivery_rate,0)
            AS on_time_delivery_rate,

        INITCAP(TRIM(quality_rating))
            AS quality_rating,

        COALESCE(response_time_hours,0)
            AS response_time_hours,

        COALESCE(returns_percentage,0)
            AS returns_percentage,

        ----------------------------------------------------
        -- Multi-value Attribute
        ----------------------------------------------------

        categories_supplied

    FROM flattened

),

deduplicated AS (

    SELECT *

    FROM cleaned

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY supplier_id
        ORDER BY last_modified_date DESC
    ) = 1

)

SELECT *
FROM deduplicated