{% macro external_table_creation () %}
{%set folders = [
    'customer_data',
    'product_data',
    'supplier_data',
    'employee_data',
    'orders_data',
    'campaign_data',
    'store_data'
] %}
{% for folder in folders%}
    {% set table_name = 'ext_'~ folder.replace('_data', '')%}
    {% set sql %}
    CREATE OR REPLACE EXTERNAL TABLE
    {{ target.database}}.{{target.schema}}.{{table_name}}
    (COL1 VARIANT as(VALUE))
    LOCATION = @CT_SRIDHAR_SIVASHANKAR_DB.CAPSTONEPROJECT_23613.Azure_stage/Capstone_Project_Data/{{folder}}
    FILE_FORMAT = (TYPE = JSON
                    STRIP_OUTER_ARRAY = TRUE)
    AUTO_REFRESH = FALSE;
    {% endset %}

    {{run_query(sql)}}
{% endfor%}

{% endmacro%}
