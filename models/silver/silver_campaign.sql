WITH source AS (

    -- Source Data

    SELECT *
    FROM {{ ref('bronze_campaign') }}

),

flattened AS (

    SELECT

        -- Campaign Details

        f.value:campaign_id::STRING         AS campaign_id,
        f.value:campaign_name::STRING       AS campaign_name,
        f.value:campaign_type::STRING       AS campaign_type,
        f.value:channel::STRING             AS channel,
        f.value:description::STRING         AS description,
        f.value:target_audience::STRING     AS target_audience,

        -- Financial Metrics

        f.value:budget::STRING              AS budget,
        f.value:total_cost::STRING          AS total_cost,
        f.value:total_revenue::STRING       AS total_revenue,

        -- Dates

        f.value:start_date::STRING          AS start_date,
        f.value:end_date::STRING            AS end_date,
        f.value:last_modified_date::STRING  AS last_modified_date,

        -- Campaign Performance

        f.value:roi_calculation::STRING     AS roi

    FROM source,
    LATERAL FLATTEN(
        INPUT => _SOURCE_FILE:campaigns_data
    ) f

),

cleaned AS (

    SELECT

        -- Campaign Key

        TRIM(campaign_id) AS campaign_id,

        -- Campaign Attributes

        INITCAP(
            COALESCE(
                TRIM(campaign_name),
                'Unknown Campaign'
            )
        ) AS campaign_name,

        INITCAP(
            COALESCE(
                TRIM(campaign_type),
                'Unknown'
            )
        ) AS campaign_type,

        TRIM(channel) AS channel,

        TRIM(description) AS description,

        TRIM(target_audience) AS target_audience,

        -- Financial Standardization

        TRY_TO_DECIMAL(
            REGEXP_REPLACE(
                budget,
                '[$,]',
                ''
            ),
            18,
            2
        ) AS budget,

        TRY_TO_DECIMAL(
            REGEXP_REPLACE(
                total_cost,
                '[$,]',
                ''
            ),
            18,
            2
        ) AS total_cost,

        TRY_TO_DECIMAL(
            REGEXP_REPLACE(
                total_revenue,
                '[$,]',
                ''
            ),
            18,
            2
        ) AS total_revenue,

        -- ROI Metrics

        TRY_TO_DECIMAL(
            roi,
            10,
            2
        ) AS roi,

        -- Date Standardization

        TO_TIMESTAMP_NTZ(start_date) AS start_date,

        TO_TIMESTAMP_NTZ(end_date) AS end_date,

        TO_DATE(last_modified_date) AS last_modified_date

    FROM flattened

),

deduplicated AS (

    SELECT *

    FROM cleaned

    -- Latest Campaign Record

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY campaign_id
        ORDER BY last_modified_date DESC
    ) = 1

)

SELECT *
FROM deduplicated