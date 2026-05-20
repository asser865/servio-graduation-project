from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

router = APIRouter()


class RoomDimensions(BaseModel):
    length_m:     float
    width_m:      float
    height_m:     float
    room_type:    str = "bedroom"
    quality_tier: str = "standard"    # economy | standard | premium
    num_windows:  int = 1
    num_doors:    int = 1


# Egyptian market price table (EGP per unit) — update periodically
PRICE_TABLE = {
    "economy": {
        "floor_tiles_per_m2":        175,
        "wall_paint_per_m2":          35,
        "ceiling_paint_per_m2":       30,
        "plaster_per_m2":             85,
        "door_per_unit":            3500,
        "window_per_unit":          2800,
        "electrical_per_m2":         120,
        "labor_tiler_per_day":       700,
        "labor_painter_per_day":     600,
        "labor_plasterer_per_day":   650,
    },
    "standard": {
        "floor_tiles_per_m2":        280,
        "wall_paint_per_m2":          55,
        "ceiling_paint_per_m2":       45,
        "plaster_per_m2":            110,
        "door_per_unit":            5500,
        "window_per_unit":          4200,
        "electrical_per_m2":         180,
        "labor_tiler_per_day":       900,
        "labor_painter_per_day":     750,
        "labor_plasterer_per_day":   800,
    },
    "premium": {
        "floor_tiles_per_m2":        550,
        "wall_paint_per_m2":          90,
        "ceiling_paint_per_m2":       75,
        "plaster_per_m2":            160,
        "door_per_unit":            9500,
        "window_per_unit":          7000,
        "electrical_per_m2":         280,
        "labor_tiler_per_day":      1200,
        "labor_painter_per_day":    1000,
        "labor_plasterer_per_day":  1100,
    }
}


@router.post("/ai/estimate-cost")
async def estimate_cost(dims: RoomDimensions):
    try:
        prices = PRICE_TABLE.get(dims.quality_tier, PRICE_TABLE["standard"])

        floor_area  = round(dims.length_m * dims.width_m, 2)
        wall_area   = round(2 * (dims.length_m + dims.width_m) * dims.height_m, 2)
        window_area = dims.num_windows * 1.5   # avg window 1.5 m²
        door_area   = dims.num_doors * 2.0     # avg door 2.0 m²
        net_wall    = max(wall_area - window_area - door_area, 0)
        ceiling     = floor_area

        waste = 1.10
        materials = [
            {"name": "Floor tiles",     "qty": round(floor_area * waste, 1), "unit": "m2", "price": prices["floor_tiles_per_m2"]},
            {"name": "Wall plaster",    "qty": round(net_wall * waste, 1),   "unit": "m2", "price": prices["plaster_per_m2"]},
            {"name": "Wall paint",      "qty": round(net_wall * waste, 1),   "unit": "m2", "price": prices["wall_paint_per_m2"]},
            {"name": "Ceiling paint",   "qty": round(ceiling * waste, 1),    "unit": "m2", "price": prices["ceiling_paint_per_m2"]},
            {"name": "Doors",           "qty": dims.num_doors,               "unit": "pc", "price": prices["door_per_unit"]},
            {"name": "Windows",         "qty": dims.num_windows,             "unit": "pc", "price": prices["window_per_unit"]},
            {"name": "Electrical work", "qty": round(floor_area, 1),         "unit": "m2", "price": prices["electrical_per_m2"]},
        ]

        for m in materials:
            m["total_egp"] = round(m["qty"] * m["price"], 0)

        materials_total = sum(m["total_egp"] for m in materials)

        tiling_days     = max(2, round(floor_area / 12))
        painting_days   = max(2, round((net_wall + ceiling) / 30))
        plastering_days = max(1, round(net_wall / 25))

        labor = [
            {"trade": "Tiler",     "days": tiling_days,     "rate": prices["labor_tiler_per_day"],     "total_egp": tiling_days * prices["labor_tiler_per_day"]},
            {"trade": "Painter",   "days": painting_days,   "rate": prices["labor_painter_per_day"],   "total_egp": painting_days * prices["labor_painter_per_day"]},
            {"trade": "Plasterer", "days": plastering_days, "rate": prices["labor_plasterer_per_day"], "total_egp": plastering_days * prices["labor_plasterer_per_day"]},
        ]

        labor_total = sum(l["total_egp"] for l in labor)
        grand_total = materials_total + labor_total

        return JSONResponse(content={
            "status": "success",
            "data": {
                "room_type":       dims.room_type,
                "quality_tier":    dims.quality_tier,
                "floor_area_m2":   floor_area,
                "wall_area_m2":    net_wall,
                "materials":       materials,
                "labor":           labor,
                "materials_total": materials_total,
                "labor_total":     labor_total,
                "grand_total_egp": grand_total,
                "timeline_days":   tiling_days + painting_days + plastering_days + 2
            }
        })

    except Exception as e:
        raise HTTPException(500, str(e))
