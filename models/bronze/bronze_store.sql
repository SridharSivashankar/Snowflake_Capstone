SELECT
    VALUE,
    Col1 as _source_file,
    METADATA$FILENAME AS source_file_name,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM {{ source('rawdata_bronze','EXT_STORE') }}

{% if is_incremental() %}

where md5(to_varchar(col1)) not in (

    select
        md5(to_varchar(_source_file))
    from {{ this }}

)

{% endif %}