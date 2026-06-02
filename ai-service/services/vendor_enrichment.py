import os
import sqlite3


# ---------------------------------------------------------------------------
# Category → vendor specialty map
# Used to suggest real Egyptian vendor names when no catalog DB is present
# ---------------------------------------------------------------------------
MATERIAL_VENDOR_MAP = {
    "flooring": {
        "ceramic":    ["Ceramica Cleopatra", "El-Nasr Tiles", "Nile Ceramics"],
        "porcelain":  ["RAK Ceramics Egypt", "Ceramin", "Ceramica Cleopatra"],
        "marble":     ["Shams Marble", "Egyptian Marble Company", "Marmo Egypt"],
        "hardwood":   ["Al-Mansour Wood", "Delta Wood", "EgyWood"],
        "default":    ["Ceramica Cleopatra", "El-Nasr Tiles"],
    },
    "walls": {
        "paint":      ["Delta Paints", "Jotun Egypt", "Sigma Coatings"],
        "wallpaper":  ["3A for Decoration", "Modern Home Egypt"],
        "plaster":    ["Sika Egypt", "Boral Egypt"],
        "default":    ["Delta Paints", "Jotun Egypt"],
    },
    "painting": {
        "default":    ["Delta Paints", "Jotun Egypt", "Sigma Coatings"],
    },
    "ceiling": {
        "gypsum":     ["Lafarge Egypt", "Gypsum Industries Egypt", "National Gypsum"],
        "default":    ["Lafarge Egypt", "Gypsum Industries Egypt"],
    },
    "lighting": {
        "chandelier": ["Crystal World Egypt", "Luminex Egypt"],
        "default":    ["Philips Egypt", "Osram Egypt", "Al-Nour Lighting"],
    },
    "electrical": {
        "default":    ["Schneider Electric Egypt", "ABB Egypt", "Legrand Egypt"],
    },
    "plumbing": {
        "default":    ["Ideal Standard Egypt", "Grohe Egypt", "Roca Egypt"],
    },
    "doors": {
        "default":    ["Al-Mansour Doors", "Egypt Wood Industries"],
    },
    "windows": {
        "default":    ["Kemalex", "Orouba for Aluminium"],
    },
}


# ---------------------------------------------------------------------------
# Fallback price table (EGP per unit) when vendor catalog DB is unavailable
# Keyed by (category, material_name_fragment)
# ---------------------------------------------------------------------------
_PRICE_TABLE_FALLBACK = {
    # flooring
    ("flooring", "marble"):           1800,
    ("flooring", "italian marble"):   2500,
    ("flooring", "granite"):           950,
    ("flooring", "porcelain"):         450,
    ("flooring", "large format"):      600,
    ("flooring", "ceramic"):           200,
    ("flooring", "hardwood"):         1200,
    ("flooring", "engineered wood"):   800,
    # walls
    ("walls",    "venetian plaster"):  350,
    ("walls",    "textured"):          120,
    ("painting", "paint"):              90,
    # ceiling
    ("ceiling",  "gypsum"):            180,
    ("ceiling",  "coffered"):          450,
}

_CATEGORY_DEFAULT_PRICE = {
    "flooring":   280,
    "walls":      120,
    "painting":    80,
    "ceiling":    160,
    "doors":     2500,
    "windows":   1800,
    "electrical":  300,
    "plumbing":    400,
    "other":       200,
}


def _lookup_fallback_price(category: str, name: str) -> float:
    """Return best-match fallback unit price from PRICE_TABLE_FALLBACK."""
    cat = category.lower()
    name_lower = name.lower()
    for (tbl_cat, fragment), price in _PRICE_TABLE_FALLBACK.items():
        if tbl_cat == cat and fragment in name_lower:
            return price
    return _CATEGORY_DEFAULT_PRICE.get(cat, 200)


def _get_vendor_suggestions(category: str, material_name: str) -> list:
    """Return 2-3 suggested vendor names for a material category."""
    cat = category.lower()
    name_lower = material_name.lower()
    cat_vendors = MATERIAL_VENDOR_MAP.get(cat, {})
    for keyword, vendors in cat_vendors.items():
        if keyword != "default" and keyword in name_lower:
            return vendors
    return cat_vendors.get("default", ["Local vendor"])


def get_vendor_db_connection():
    """
    Return a sqlite3 connection to the vendor catalog DB, or None if unavailable.
    Path is configurable via AI_SERVICE_DB_PATH env var.
    Defaults to ./data/vendor_catalog.db relative to the service root.
    """
    db_path = os.getenv("AI_SERVICE_DB_PATH", "./data/vendor_catalog.db")
    if not os.path.exists(db_path):
        return None
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        return conn
    except Exception as e:
        print(f"Vendor DB connect failed: {e}")
        return None


def enrich_with_vendors(finishing_plans: list, db_connection) -> list:
    """
    Replace Gemini's estimated prices with real vendor prices from the catalog DB.
    If a material has no catalog match, fill in fallback prices and vendor names.

    Works with or without a live DB — falls back gracefully.
    """
    for plan in finishing_plans:
        for material in plan.get("materials", []):
            category  = material.get("category", "other")
            mat_name  = material.get("name", "")
            quantity  = material.get("quantity", 0)

            matched_vendors = []

            if db_connection is not None:
                try:
                    rows = db_connection.execute("""
                        SELECT vendor_name, product_name, price_per_unit, unit, vendor_url
                        FROM vendor_catalog
                        WHERE category = ?
                          AND LOWER(product_name) LIKE ?
                        ORDER BY price_per_unit ASC
                        LIMIT 3
                    """, [
                        category,
                        f"%{mat_name.split()[0].lower()}%",
                    ]).fetchall()

                    if rows:
                        material["unit_price_egp"] = rows[0]["price_per_unit"]
                        material["total_egp"]       = round(quantity * rows[0]["price_per_unit"], 0)
                        matched_vendors = [
                            {
                                "name":    r["vendor_name"],
                                "product": r["product_name"],
                                "price":   r["price_per_unit"],
                                "url":     r["vendor_url"],
                            }
                            for r in rows
                        ]
                except Exception:
                    pass

            # No DB match — use fallback pricing and vendor suggestions
            if not matched_vendors:
                fallback_price = _lookup_fallback_price(category, mat_name)
                if not material.get("unit_price_egp"):
                    material["unit_price_egp"] = fallback_price
                    material["total_egp"]       = round(quantity * fallback_price, 0)
                matched_vendors = [
                    {"name": v, "product": mat_name, "price": material["unit_price_egp"], "url": ""}
                    for v in _get_vendor_suggestions(category, mat_name)
                ]

            material["vendors"] = matched_vendors

        # Recalculate plan subtotals from enriched material prices
        materials_total = sum(m.get("total_egp", 0) for m in plan.get("materials", []))
        labor_total     = sum(l.get("total_egp", 0) for l in plan.get("labor", []))
        plan["materials_subtotal_egp"] = materials_total
        plan["labor_subtotal_egp"]     = labor_total
        plan["total_cost_egp"]         = materials_total + labor_total

    return finishing_plans
