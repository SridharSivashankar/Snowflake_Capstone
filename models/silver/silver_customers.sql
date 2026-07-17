WITH source AS (

    SELECT *
    FROM {{ ref('bronze_customer') }}

),

flattened AS (

    SELECT

        f.value:customer_id::STRING              AS customer_id,
        f.value:first_name::STRING               AS first_name,
        f.value:last_name::STRING                AS last_name,
        f.value:email::STRING                    AS email,
        f.value:phone::STRING                    AS phone,

        f.value:birth_date::STRING               AS birth_date,
        f.value:registration_date::STRING        AS registration_date,
        f.value:last_purchase_date::STRING       AS last_purchase_date,
        f.value:last_modified_date::STRING       AS last_modified_date,

        f.value:income_bracket::STRING           AS income_bracket,
        f.value:loyalty_tier::STRING             AS loyalty_tier,
        f.value:occupation::STRING               AS occupation,

        f.value:preferred_communication::STRING  AS preferred_communication,
        f.value:preferred_payment_method::STRING AS preferred_payment_method,

        f.value:marketing_opt_in::BOOLEAN        AS marketing_opt_in,

        f.value:total_purchases::NUMBER          AS total_purchases,
        f.value:total_spend::NUMBER(18,2)        AS total_spend,

        f.value:address:street::STRING           AS street,
        f.value:address:city::STRING             AS city,
        f.value:address:state::STRING            AS state,
        f.value:address:country::STRING          AS country,
        f.value:address:zip_code::STRING         AS zip_code

    FROM source,
    LATERAL FLATTEN(
        INPUT => _SOURCE_FILE:customers_data
    ) f

),


cleaned AS (

    SELECT

        ----------------------------------------------------
        -- Customer Key
        ----------------------------------------------------

        TRIM(customer_id) AS customer_id,

        ----------------------------------------------------
        -- Name Standardization
        ----------------------------------------------------

        INITCAP(TRIM(first_name)) AS first_name,

        INITCAP(TRIM(last_name)) AS last_name,

        CONCAT(
            INITCAP(TRIM(first_name)),
            ' ',
            INITCAP(TRIM(last_name))
        ) AS full_name,

        ----------------------------------------------------
        -- Email Validation
        ----------------------------------------------------

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

      ----------------------------------------------------
        -- Phone Validation
        ----------------------------------------------------

            phone AS original_phone,

            UPPER(
                REGEXP_REPLACE(
                    TRIM(phone),
                    '[^0-9X]',
                    ''
                )
            ) AS cleaned_phone,

            CASE

                ------------------------------------------------
                -- Formats ending with X
                -- Examples:
                -- 555.857.336X
                -- 555-857-336X
                -- 555 857 336X
                -- (555) 857-336X
                -- 555857336X
                ------------------------------------------------
                WHEN REGEXP_LIKE(
                    UPPER(
                        REGEXP_REPLACE(
                            TRIM(phone),
                            '[^0-9X]',
                            ''
                        )
                    ),
                    '^555[0-9]{6}X$'
                )
                THEN UPPER(
                    REGEXP_REPLACE(
                        TRIM(phone),
                        '[^0-9X]',
                        ''
                    )
                )

                ------------------------------------------------
                -- +1 prefixed formats ending with X
                -- Examples:
                -- +1 555 857 336X
                -- +1-555-857-336X
                -- +1555857336X
                ------------------------------------------------
                WHEN REGEXP_LIKE(
                    UPPER(
                        REGEXP_REPLACE(
                            TRIM(phone),
                            '[^0-9X]',
                            ''
                        )
                    ),
                    '^1555[0-9]{6}X$'
                )
                THEN RIGHT(
                    UPPER(
                        REGEXP_REPLACE(
                            TRIM(phone),
                            '[^0-9X]',
                            ''
                        )
                    ),
                    10
                )

                ------------------------------------------------
                -- Fully numeric format
                -- Example:
                -- 5551234567
                ------------------------------------------------
                WHEN REGEXP_LIKE(
                    REGEXP_REPLACE(
                        TRIM(phone),
                        '[^0-9]',
                        ''
                    ),
                    '^555[0-9]{7}$'
                )
                THEN REGEXP_REPLACE(
                    TRIM(phone),
                    '[^0-9]',
                    ''
                )

                ELSE NULL

            END AS phn_no,

            CASE

                WHEN REGEXP_LIKE(
                    UPPER(
                        REGEXP_REPLACE(
                            TRIM(phone),
                            '[^0-9X]',
                            ''
                        )
                    ),
                    '^555[0-9]{6}X$'
                )
                THEN 'VALID'

                WHEN REGEXP_LIKE(
                    UPPER(
                        REGEXP_REPLACE(
                            TRIM(phone),
                            '[^0-9X]',
                            ''
                        )
                    ),
                    '^1555[0-9]{6}X$'
                )
                THEN 'VALID'

                WHEN REGEXP_LIKE(
                    REGEXP_REPLACE(
                        TRIM(phone),
                        '[^0-9]',
                        ''
                    ),
                    '^555[0-9]{7}$'
                )
                THEN 'VALID'

                ELSE 'INVALID'

            END AS phone_status,
        ----------------------------------------------------
        -- Date Standardization
        ----------------------------------------------------

        COALESCE(
            TRY_TO_DATE(birth_date,'YYYY-MM-DD'),
            TRY_TO_DATE(birth_date,'MM/DD/YYYY')
        ) AS birth_date,

        TO_DATE(registration_date) AS registration_date,

        TO_DATE(last_purchase_date) AS last_purchase_date,

        TO_DATE(last_modified_date) AS last_modified_date,

        ----------------------------------------------------
        -- Age Calculation
        ----------------------------------------------------

        FLOOR(
            DATEDIFF(
                DAY,
                COALESCE(
                    TRY_TO_DATE(birth_date,'YYYY-MM-DD'),
                    TRY_TO_DATE(birth_date,'MM/DD/YYYY')
                ),
                CURRENT_DATE()
            ) / 365.25
        ) AS customer_age,

        ----------------------------------------------------
        -- Customer Segment
        ----------------------------------------------------

        CASE

            WHEN FLOOR(
                DATEDIFF(
                    DAY,
                    COALESCE(
                        TRY_TO_DATE(birth_date,'YYYY-MM-DD'),
                        TRY_TO_DATE(birth_date,'MM/DD/YYYY')
                    ),
                    CURRENT_DATE()
                ) / 365.25
            ) IS NULL
            THEN 'Invalid'

            WHEN FLOOR(
                DATEDIFF(
                    DAY,
                    COALESCE(
                        TRY_TO_DATE(birth_date,'YYYY-MM-DD'),
                        TRY_TO_DATE(birth_date,'MM/DD/YYYY')
                    ),
                    CURRENT_DATE()
                ) / 365.25
            ) BETWEEN 18 AND 35
            THEN 'Young'

            WHEN FLOOR(
                DATEDIFF(
                    DAY,
                    COALESCE(
                        TRY_TO_DATE(birth_date,'YYYY-MM-DD'),
                        TRY_TO_DATE(birth_date,'MM/DD/YYYY')
                    ),
                    CURRENT_DATE()
                ) / 365.25
            ) BETWEEN 36 AND 55
            THEN 'Middle-aged'

            WHEN FLOOR(
                DATEDIFF(
                    DAY,
                    COALESCE(
                        TRY_TO_DATE(birth_date,'YYYY-MM-DD'),
                        TRY_TO_DATE(birth_date,'MM/DD/YYYY')
                    ),
                    CURRENT_DATE()
                ) / 365.25
            ) >= 56
            THEN 'Senior'

            ELSE 'Invalid'

        END AS customer_segment,

        ----------------------------------------------------
        -- Standardization
        ----------------------------------------------------

        UPPER(TRIM(income_bracket))
            AS income_bracket,

        UPPER(TRIM(loyalty_tier))
            AS loyalty_tier,

        INITCAP(TRIM(occupation))
            AS occupation,

        UPPER(TRIM(preferred_communication))
            AS preferred_communication,

        INITCAP(TRIM(preferred_payment_method))
            AS preferred_payment_method,

        marketing_opt_in,

        ----------------------------------------------------
        -- Metrics
        ----------------------------------------------------

        COALESCE(total_purchases,0)
            AS total_purchases,

        COALESCE(total_spend,0)
            AS total_spend,

        ----------------------------------------------------
        -- Address Standardization
        ----------------------------------------------------

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
        ) AS standardized_address

    FROM flattened

),

deduplicated AS (

    SELECT *

    FROM cleaned

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY last_modified_date DESC
    ) = 1

)

SELECT *
FROM deduplicated
