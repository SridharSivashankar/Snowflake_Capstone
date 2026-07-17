{% macro create_external_table(
        database_name,
        schema_name,
        stage_name,
        folder_name,
        table_name = none
    ) %}

    {% set ext_table_name =
        table_name if table_name is not none
        else 'ext_' ~ folder_name.replace('_data','')
    %}

    {% set sql %}

    CREATE OR REPLACE EXTERNAL TABLE
    {{ database_name }}.{{ schema_name }}.{{ ext_table_name }}
    (
        COL1 VARIANT AS (VALUE)
    )
    LOCATION = @{{ stage_name }}/{{ folder_name }}
    FILE_FORMAT = (
        TYPE = JSON
        STRIP_OUTER_ARRAY = TRUE
    )
    AUTO_REFRESH = FALSE

    {% endset %}

    {{ run_query(sql) }}

{% endmacro %}