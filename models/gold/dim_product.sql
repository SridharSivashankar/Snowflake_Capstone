SELECT

    ROW_NUMBER() OVER (ORDER BY p.product_id) AS product_key,

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

FROM {{ ref('silver_products') }} p

LEFT JOIN {{ ref('silver_suppliers') }} s
    ON p.supplier_id = s.supplier_id