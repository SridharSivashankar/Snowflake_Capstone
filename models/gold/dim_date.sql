{{ config(
    materialized='table'
) }}

WITH date_spine AS (

    {{
        dbt_utils.date_spine(
            datepart = "day",
            start_date = "'2024-04-01'",
            end_date = "'2024-09-30'"
        )
    }}

),

date_dimension AS (

    SELECT

        ----------------------------------------------------------------
        -- Surrogate Key
        ----------------------------------------------------------------
        TO_NUMBER(
            TO_CHAR(date_day,'YYYYMMDD')
        ) AS date_key,

        ----------------------------------------------------------------
        -- Date Attributes
        ----------------------------------------------------------------
        date_day AS full_date,

        YEAR(date_day) AS year,

        QUARTER(date_day) AS quarter,

        MONTH(date_day) AS month,

        WEEK(date_day) AS week,

        DAYOFWEEKISO(date_day) AS day_of_week,

        DAYNAME(date_day) AS day_name,

-- example dates
        CASE
            WHEN date_day IN (
                '2024-05-27', -- Memorial Day
                '2024-06-19', -- Juneteenth
                '2024-07-04', -- Independence Day
                '2024-09-02'  -- Labor Day
            )
            THEN TRUE
            ELSE FALSE
        END AS holiday_flag,

        ----------------------------------------------------------------
        -- Season
        ----------------------------------------------------------------
        CASE

            WHEN MONTH(date_day) IN (12,1,2)
                THEN 'Winter'

            WHEN MONTH(date_day) IN (3,4,5)
                THEN 'Spring'

            WHEN MONTH(date_day) IN (6,7,8)
                THEN 'Summer'

            WHEN MONTH(date_day) IN (9,10,11)
                THEN 'Fall'

        END AS season

    FROM date_spine

)

SELECT *
FROM date_dimension
ORDER BY full_date