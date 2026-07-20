SELECT

    
    {{ dbt_utils.generate_surrogate_key([
        'p.product_id'
    ]) }} AS product_key,


    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    p.color,
    p.size,
    p.unit_price,
    p.cost_price,

    s.supplier_id,
    s.supplier_name,
    s.supplier_type

FROM {{ ref('silver_product') }} p

LEFT JOIN {{ ref('silver_supplier') }} s
    ON p.supplier_id = s.supplier_id