select
    VALUE,
    COL1 as _source_file,
    current_timestamp as _loaded_at,
    from {{ source('rawdata_bronze', 'EXT_CUSTOMER') }}

{% if is_incremental() %}
where source_file not in (
    select distinct _source_file
    from {{ this }}
)
 
{% endif %}