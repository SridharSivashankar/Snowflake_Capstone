-- Tests are present only for dim_customers, dim_date and fact_sales since these are the tables that
-- are newly created or have additional refernces. The other tables have no tests since they directly
-- reference the already tested silver models


SELECT

    ------------------------------------------------------------------
    -- Surrogate Key
    ------------------------------------------------------------------
    {{ dbt_utils.generate_surrogate_key([
        'customer_id',
        'dbt_valid_from'
    ]) }} AS customer_key,


    customer_id,


    full_name,

    email_id AS email,

    phn_no AS phone,


    street,
    city,
    state,
    zip_code,
    standardized_address,


    customer_age,
    income_bracket,
    occupation,
    loyalty_tier,


    customer_segment AS segment,

    registration_date,

    ------------------------------------------------------------------
    -- Type 2 SCD Columns
    ------------------------------------------------------------------
    dbt_valid_from AS valid_from,

    dbt_valid_to AS valid_to,

    CASE
        WHEN dbt_valid_to IS NULL
        THEN TRUE
        ELSE FALSE
    END AS is_current

FROM {{ ref('customer_snapshot') }}