SELECT

    -- Surrogate Key
    {{ dbt_utils.generate_surrogate_key(['store_id']) }}
        AS store_key,

    -- Natural key
    store_id,

    -- Store Attributes
    store_name,

    standardized_address AS address,

    region,

    store_type,

    opening_date,

    store_size_category AS size_category

FROM {{ ref('silver_store') }}