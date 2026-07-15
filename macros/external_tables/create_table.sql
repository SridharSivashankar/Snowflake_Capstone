{% macro create_external_table(
    table_name,
    stage_name,
    folder_path,
    columns=none,
    file_pattern='.*\\.json',
    auto_refresh=false,
    replace=false,
    file_format_options="STRIP_OUTER_ARRAY = TRUE" 
)%}

    {% set replace_clause = "OR REPLACE" if replace else "" %}
    {% set refresh_clause = "AUTO_REFRESH = TRUE" if auto_refresh else "AUTO_REFRESH = FALSE" %}

    {% set sql %}
    CREATE {{ replace_clause }} EXTERNAL TABLE {{ table_name }} (
        filename VARCHAR AS metadata$filename
        {%- if columns -%}
            {%- for col_name, col_expr in columns.items() -%}
                , {{ col_name }} {{ col_expr }}
            {%- endfor -%}
        {%- endif -%}
    )
    WITH LOCATION = @{{ stage_name }}/{{ folder_path }}
    FILE_FORMAT = (TYPE = 'JSON' {{ file_format_options }})
    PATTERN = '{{ file_pattern }}'
    {{ refresh_clause }}
    ;
    {% endset %}

    {% do run_query(sql) %}

{% endmacro %}
