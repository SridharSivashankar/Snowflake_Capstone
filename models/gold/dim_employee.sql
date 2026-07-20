SELECT

    -- Surrogate Key
    {{ dbt_utils.generate_surrogate_key(['employee_id']) }}
        AS employee_key,

    -- Natural Key

    employee_id,

    full_name,

    standardized_role AS role,

    work_location,

    tenure_years AS tenure,

    email_id,

    phn_no AS phone_number,

    -- Performance Metrics

    performance_rating,

    target_achievement_percentage,

    current_sales,

    sales_target

FROM {{ ref('silver_employees') }}