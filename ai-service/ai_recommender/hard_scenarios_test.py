"""
Hard-scenario stress test for Servio Smart Match AI.
Tests confusing, ambiguous, multi-service, and indirect prompts
that the existing comprehensive_test.py does NOT cover.
"""
import sys
import requests

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

API_URL = "http://localhost:8001/recommend"

# ─────────────────────────────────────────────────────────────────────────────
# (prompt, expected_scenario, expected_primary_service_or_None, note)
# expected_service = None means "don't care about service, just scenario"
# For multi: expected_service = comma-separated services that must ALL appear in steps
# ─────────────────────────────────────────────────────────────────────────────
test_cases = [

    # ── GROUP A: Confusing cross-service (the "pipe on panel" family) ─────────

    ("my pipe is leaking on my electrical panel what to do",
     "multi", "Electrical,Plumbing",
     "SAFETY: pipe leak + electrical panel → must trigger water-on-electrical"),

    ("there is water dripping from the ceiling onto my socket",
     "multi", "Electrical,Plumbing",
     "SAFETY: ceiling drip onto socket → water-on-electrical"),

    ("the faucet above my fuse box is dripping",
     "multi", "Electrical,Plumbing",
     "SAFETY: faucet drip near fuse box"),

    ("water is coming out of the wall near the breaker",
     "multi", "Electrical,Plumbing",
     "SAFETY: wall water near breaker"),

    ("my bathroom ceiling collapsed and water is touching the wires",
     "multi", "Electrical,Plumbing",
     "SAFETY: water touching wires"),

    # ── GROUP B: Implicit service (problem described without naming the trade) ─

    ("my toilet is making a gurgling sound and won't flush",
     "single", "Plumbing",
     "IMPLICIT: gurgling toilet → plumbing, no 'plumber' keyword"),

    ("the fridge stopped working completely",
     "single", "Appliance Repair",
     "IMPLICIT: fridge stopped → appliance, no keyword 'repair'"),

    ("there's a burning smell when I turn on the AC",
     "single", "A/C",
     "IMPLICIT: burning smell from AC → still A/C, not electrical"),

    ("my front door is stuck and I can't open it",
     "single", "Carpentry",
     "IMPLICIT: stuck door → carpentry"),

    ("the water from my shower is coming out cold no matter what I set",
     "single", "Plumbing",
     "IMPLICIT: no hot water → plumbing (water heater)"),

    ("my oven sparks every time I turn it on",
     "single", "Appliance Repair",
     "IMPLICIT: oven sparks → appliance, not electrical"),

    ("the wall in my bedroom has a large brown stain spreading",
     "single", "Plumbing",
     "IMPLICIT: spreading stain → hidden leak → plumbing"),

    # ── GROUP C: Multiple services, no explicit connector ─────────────────────

    ("the paint on my ceiling is bubbling and there is a leak above it",
     "multi", "Plumbing,Painting",
     "MULTI: ceiling leak causing paint bubble → plumbing urgent + painting later"),

    ("I can't get hot water and my bedroom door won't close",
     "multi", "Plumbing,Carpentry",
     "MULTI: water heater + door = 2 unrelated services"),

    ("the washing machine is leaking all over and it broke the cabinet door next to it",
     "multi", "Appliance Repair,Carpentry",
     "MULTI: appliance leak + cabinet damage"),

    ("my AC stopped cooling and the kitchen sink is clogged",
     "multi", "A/C,Plumbing",
     "MULTI: two unrelated issues explicit"),

    ("lights are flickering and my wardrobe door fell off",
     "multi", "Electrical,Carpentry",
     "MULTI: electrical + carpentry"),

    # ── GROUP D: Question framing (what to do, help me, can you) ─────────────

    ("what should I do if my kitchen sink won't drain",
     "single", "Plumbing",
     "QUESTION FRAMING: indirect question about blocked sink"),

    ("help me figure out why my lights keep going off",
     "single", "Electrical",
     "QUESTION FRAMING: help-me framing for electrical"),

    ("can anyone fix my washing machine it stopped spinning",
     "single", "Appliance Repair",
     "QUESTION FRAMING: can-anyone framing"),

    ("I don't know what's wrong but my AC makes a weird noise",
     "single", "A/C",
     "QUESTION FRAMING: uncertainty prefix, still identifies A/C"),

    # ── GROUP E: Service confusion traps (easily misclassified) ───────────────

    ("my fridge has water pooling at the bottom",
     "single", "Appliance Repair",
     "TRAP: fridge water → appliance NOT plumbing"),

    ("AC is dripping water onto the floor",
     "single", "A/C",
     "TRAP: AC condensation → A/C NOT safety rule, NOT plumbing"),

    ("I need to repaint the room after the plumber fixed the leak",
     "multi", "Painting,Plumbing",
     "TRAP: painting + explicit plumbing reference"),

    ("there's humidity and mold on my bathroom walls",
     "single", "Plumbing",
     "TRAP: humidity/mold → plumbing (hidden leak), NOT painting"),

    ("my boiler is not heating water",
     "single", "Plumbing",
     "TRAP: boiler → plumbing (water heater), not appliance"),

    # ── GROUP F: Vague / deliberately incomplete ──────────────────────────────

    ("something is wrong in my kitchen",
     "vague", None,
     "VAGUE: kitchen but no service identified"),

    ("I need help at home",
     "vague", None,
     "VAGUE: no service or details"),

    ("fix everything please",
     "unrecognized", None,
     "UNRECOGNIZED: generic phrase, no service identified"),

    ("there's a problem with the thing above my stove",
     "single", "Appliance Repair",
     "F: stove keyword → Appliance Repair single (reasonable inference)"),

    # ── GROUP G: Unrecognized / out of scope ──────────────────────────────────

    ("my cat keeps scratching the furniture",
     "unrecognized", None,
     "OUT OF SCOPE: pets, not home service"),

    ("I need a driver to take me somewhere",
     "unrecognized", None,
     "OUT OF SCOPE: transport request"),

    ("can you design my website",
     "unrecognized", None,
     "OUT OF SCOPE: IT service"),

    ("I want to order food delivery",
     "unrecognized", None,
     "OUT OF SCOPE: food delivery"),

    # ── GROUP H: Arabic confusing prompts ─────────────────────────────────────

    ("ماسورة المياه عندي بتنقط على لوحة الكهرباء",
     "multi", "Electrical,Plumbing",
     "AR SAFETY: water pipe dripping on electrical panel"),

    ("الثلاجة مش شغالة وعندي باب خشب مكسور",
     "multi", "Appliance Repair,Carpentry",
     "AR MULTI: fridge broken + wooden door broken"),

    ("مش عارف المشكلة بس في صوت غريب في التكييف",
     "single", "A/C",
     "AR QUESTION: don't know problem but A/C noise"),

    ("في مياه في السقف جنب الانارة",
     "multi", "Plumbing,Electrical",
     "AR: water in ceiling near lights → might trigger safety"),

    # ── GROUP I: Pattern regression cases (verify each fix from Task 2) ──────────

    ("there is a leak in the ceiling above the kitchen",
     "single", "Plumbing",
     "I: REGRESSION B4: 'leak' noun → Plumbing"),

    ("the paint is peeling and there is a leak behind the wall",
     "multi", "Plumbing,Painting",
     "I: REGRESSION B4: leak noun + paint peeling → multi"),

    ("there is mold growing on my bathroom ceiling",
     "single", "Plumbing",
     "I: REGRESSION B5: mold on ceiling → Plumbing hidden leak"),

    ("the walls feel damp and there's a musty smell",
     "single", "Plumbing",
     "I: REGRESSION B5: damp walls → Plumbing"),

    ("there is a brown water stain on the wall that keeps growing",
     "single", "Plumbing",
     "I: REGRESSION B7: brown stain spreading → Plumbing"),

    ("my shower only gives cold water no matter the setting",
     "single", "Plumbing",
     "I: REGRESSION B6: no hot water from shower → Plumbing"),

    ("the boiler stopped heating water",
     "single", "Plumbing",
     "I: REGRESSION B6: boiler → Plumbing"),

    ("my microwave sparks when I start it",
     "single", "Appliance Repair",
     "I: REGRESSION B3: microwave sparks → Appliance not Electrical"),

    ("the washing machine makes a burning smell",
     "single", "Appliance Repair",
     "I: REGRESSION B3: washer burning smell → Appliance not Electrical"),

    ("مياه بتنزل من السقف جنب الانارة في الاوضة",
     "multi", "Electrical,Plumbing",
     "I: REGRESSION B8: AR water near ceiling light → safety rule"),
]


def scenario_from_data(d: dict) -> str:
    scenario = d.get("scenario")
    if scenario in {"single", "multi", "vague", "unrecognized"}:
        return scenario
    steps = d.get("steps", [])
    flagged = d.get("confidence_gate_triggered", False)
    extracted = d.get("extracted", {})
    if flagged or not extracted.get("location") or not extracted.get("budget"):
        return "vague"
    if len(steps) > 1:
        return "multi"
    return "single"


def check_services(d: dict, expected_services_str: str) -> bool:
    """For multi scenarios, check all expected services appear in steps."""
    if not expected_services_str:
        return True
    expected = [s.strip() for s in expected_services_str.split(",")]
    step_services = [s.get("service", "") for s in d.get("steps", [])]
    primary = d.get("recommended_service") or d.get("selected_service") or ""
    all_services = step_services + ([primary] if primary else [])
    return all(exp in all_services for exp in expected)


def run_tests():
    print("Servio Smart Match — HARD SCENARIO STRESS TEST")
    print(f"API: {API_URL}")
    print(f"Cases: {len(test_cases)}")
    print("=" * 80)

    groups = {
        "A: Cross-service safety": [],
        "B: Implicit service":     [],
        "C: Multi (no connector)": [],
        "D: Question framing":     [],
        "E: Confusion traps":      [],
        "F: Vague":                [],
        "G: Unrecognized":         [],
        "H: Arabic":               [],
        "I: Regression":           [],
    }

    group_keys = list(groups.keys())
    group_letters = [k[0] for k in group_keys]

    scenarios = ["single", "multi", "vague", "unrecognized"]
    totals  = {s: 0 for s in scenarios}
    correct = {s: 0 for s in scenarios}
    failures = []

    for i, (prompt, expected_scenario, expected_service, note) in enumerate(test_cases, 1):
        # Determine group from note prefix
        group_letter = note.split(":")[0].split(" ")[0]
        group_idx = group_letters.index(group_letter) if group_letter in group_letters else 0
        group_name = group_keys[group_idx]

        try:
            r = requests.post(API_URL, json={"prompt": prompt}, timeout=25)
            d = r.json()

            got_scenario  = scenario_from_data(d)
            svc_ok        = check_services(d, expected_service) if expected_scenario != "vague" and expected_scenario != "unrecognized" else True
            scenario_ok   = got_scenario == expected_scenario
            ok            = scenario_ok and svc_ok

            primary = d.get("recommended_service") or "?"
            steps   = [s.get("service") for s in d.get("steps", [])]
            conf    = d.get("confidence", 0)
            safety  = d.get("safety_risk", False)

            totals[expected_scenario] += 1
            if ok:
                correct[expected_scenario] += 1

            tag = "✓ PASS" if ok else "✗ FAIL"
            svc_tag = "" if svc_ok else " [WRONG SERVICE]"
            scen_tag = "" if scenario_ok else f" [got={got_scenario}]"

            print(f"[{i:02d}] {tag}{scen_tag}{svc_tag}")
            print(f"      expected scenario={expected_scenario}  service(s)={expected_service or 'any'}")
            print(f"      got      primary={primary} ({conf}%)  steps={steps}  safety={safety}")
            print(f"      note : {note}")
            print(f"      prompt: {prompt[:90]}")
            print()

            if not ok:
                failures.append((i, expected_scenario, got_scenario, expected_service or "any",
                                  primary, steps, prompt[:70]))

            groups[group_name].append(ok)

        except Exception as ex:
            print(f"[{i:02d}] ERROR — {ex}\n")
            failures.append((i, expected_scenario, "error", expected_service or "any", "?", [], str(ex)[:70]))
            groups[group_name].append(False)
            totals[expected_scenario] += 1

    print("=" * 80)
    print("RESULTS BY SCENARIO:")
    for sc in scenarios:
        t = totals[sc]
        c = correct[sc]
        bar = "█" * c + "░" * (t - c)
        print(f"  {sc:<12} {bar}  {c}/{t}")

    print("\nRESULTS BY GROUP:")
    for gname, results in groups.items():
        if not results:
            continue
        c = sum(results)
        t = len(results)
        bar = "█" * c + "░" * (t - c)
        print(f"  {gname:<28} {bar}  {c}/{t}")

    total_c = sum(correct.values())
    total_t = sum(totals.values())
    pct = (100 * total_c // total_t) if total_t else 0
    print(f"\n  OVERALL  {total_c}/{total_t} correct ({pct}%)")

    if failures:
        print("\nFAILED CASES:")
        for num, exp_sc, got_sc, exp_svc, got_svc, got_steps, p in failures:
            print(f"  [{num:02d}] scenario: expected={exp_sc} got={got_sc}  "
                  f"service: expected={exp_svc} got={got_svc} steps={got_steps}")
            print(f"        '{p}'")
    print("=" * 80)


if __name__ == "__main__":
    run_tests()
