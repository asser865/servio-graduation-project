def enrich_with_vendors(finishing_plans: list, db_connection) -> list:
    """
    Replace Gemini's estimated prices with real vendor prices from the database.
    For each material in each plan, query the vendor catalog and substitute real prices.
    """
    for plan in finishing_plans:
        for material in plan.get("materials", []):
            try:
                vendors = db_connection.execute("""
                    SELECT vendor_name, product_name, price_per_unit, unit, vendor_url
                    FROM vendor_catalog
                    WHERE category = ?
                      AND LOWER(product_name) LIKE ?
                    ORDER BY price_per_unit ASC
                    LIMIT 3
                """, [
                    material.get("category", ""),
                    f"%{material.get('name', '').split()[0].lower()}%"
                ]).fetchall()

                if vendors:
                    material["unit_price_egp"] = vendors[0]["price_per_unit"]
                    material["total_egp"] = round(
                        material["quantity"] * vendors[0]["price_per_unit"], 0
                    )
                    material["vendors"] = [
                        {
                            "name":    v["vendor_name"],
                            "product": v["product_name"],
                            "price":   v["price_per_unit"],
                            "url":     v["vendor_url"]
                        } for v in vendors
                    ]
            except Exception:
                # Keep Gemini's estimate if vendor lookup fails
                pass

        materials_total = sum(m.get("total_egp", 0) for m in plan.get("materials", []))
        labor_total     = sum(l.get("total_egp", 0) for l in plan.get("labor", []))
        plan["materials_subtotal_egp"] = materials_total
        plan["labor_subtotal_egp"]     = labor_total
        plan["total_cost_egp"]         = materials_total + labor_total

    return finishing_plans
