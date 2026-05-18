import sys
import requests

# Force UTF-8 stdout on Windows so Arabic prompts don't crash the printer
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

API_URL = "http://localhost:8001/recommend"

# ─────────────────────────────────────────────────────────────────────────────
# Each case: (prompt, expected_scenario, note)
#   scenario: "single" | "multi" | "vague" | "unrecognized"
# ─────────────────────────────────────────────────────────────────────────────
test_cases = [

    # ── SCENARIO 1: Single service — clear, complete prompts ─────────────────
    # Expected UI: technician card shown directly (no plan, no priority radio)

    ("AC not cooling the room in Heliopolis, budget 500 EGP, this weekend",
     "single", "A/C only"),

    ("lights keep flickering in Dokki Giza, budget 300 EGP, tomorrow",
     "single", "Electrical only"),

    ("water leaking under my sink in Maadi Cairo, budget 200 EGP, today",
     "single", "Plumbing only — no electrical near"),

    ("washing machine not spinning in Zamalek, budget 300 EGP, tomorrow evening",
     "single", "Appliance Repair"),

    ("need TV mounted on the wall in New Cairo, budget 150 EGP, weekend",
     "single", "Handyman"),

    ("door won't close properly in Alexandria, budget 150 EGP, this week",
     "single", "Carpentry"),

    ("need deep cleaning for my apartment in Nasr City, budget 600 EGP, flexible",
     "single", "Cleaning"),

    ("wall paint peeling off in 6th October, budget 400 EGP, next week",
     "single", "Painting"),

    ("sparks coming from the socket in Haram Giza, budget 250 EGP, asap",
     "single", "Electrical — sparks alone"),

    ("toilet is overflowing in Shubra Cairo, budget 200 EGP, urgent",
     "single", "Plumbing"),

    ("fridge not cooling in Mohandessin, budget 350 EGP, today",
     "single", "Appliance Repair (not AC)"),

    ("my AC is making a loud noise in Madinaty, budget 400 EGP, this week",
     "single", "A/C only"),

    # ── SCENARIO 2: Vague — service identified, location/budget now advisory ───
    # Advisory chips shown but service match proceeds (blocking only = unknown service)

    ("i need a plumber",
     "single", "service clear (Plumbing); location/budget advisory"),

    ("something is wrong with the electricity",
     "single", "service clear (Electrical); location/budget advisory"),

    ("clean my house",
     "single", "service clear (Cleaning); location/budget advisory"),

    ("hello i have a problem with my AC, my ac keeps turning on and off alone and sometimes gives hot air",
     "single", "service clear (A/C); location/budget advisory"),

    ("need someone to fix my door",
     "single", "service clear (Carpentry); location/budget advisory"),

    ("my sink is leaking",
     "single", "service clear (Plumbing); location/budget advisory"),

    ("the lights in my room keep going off",
     "single", "service clear (Electrical); location/budget advisory"),

    # ── SCENARIO 3: Multiple services — user EXPLICITLY mentions 2+ problems ─
    # Expected UI: plan card + priority radio + technician card

    ("water is dripping directly onto the socket in my kitchen in Nasr City, budget 400 EGP, urgent",
     "multi", "Plumbing + Electrical (safety rule)"),

    ("my sink is leaking and it's dripping on the electrical panel in Maadi, budget 500 EGP, today",
     "multi", "Plumbing + Electrical"),

    ("I need my apartment painted and the wooden shelves fixed in Zamalek, budget 1200 EGP, next week",
     "multi", "Painting + Carpentry"),

    ("the AC is broken and my fridge is also not cooling in Heliopolis, budget 700 EGP, this week",
     "multi", "A/C + Appliance Repair"),

    ("need deep cleaning and the bathroom pipes are blocked in Mohandessin, budget 800 EGP, weekend",
     "multi", "Cleaning + Plumbing"),

    ("my washing machine is leaking on the floor and I also need the wooden cabinet next to it repaired, Madinaty, budget 600 EGP, today",
     "multi", "Appliance + Carpentry"),

    # ── SCENARIO 4: Edge cases — should NOT become multi ─────────────────────

    ("AC is dripping a little water from the unit in Sheikh Zayed, budget 300 EGP, today",
     "single", "AC condensation = still just A/C"),

    ("AC not cooling and the room is humid in Rehab City, budget 450 EGP, weekend",
     "single", "AC humidity = still just A/C"),

    ("my fridge has water pooling inside in New Cairo, budget 250 EGP, today",
     "single", "Water inside appliance = Appliance Repair"),

    # ── SCENARIO 5: Arabic / mixed language ───────────────────────────────────

    ("عندي مشكلة في التكييف مش بيبرد في مدينتي، الميزانية 500 جنيه، النهارده",
     "single", "AR: A/C not cooling, Madinaty"),

    ("محتاج سباك في المعادي، الميزانية 300 جنيه",
     "single", "AR: plumber, has location+budget, time advisory"),

    ("في تسريب مياه على اللوحة الكهربائية في الزمالك، الميزانية 600 جنيه، عاجل",
     "multi", "AR: water on electrical panel"),

    # ── SCENARIO 6: Unrecognized / unrelated input ───────────────────────────

    ("hello",
     "unrecognized", "Greeting only"),

    ("asdf qwer zxcv",
     "unrecognized", "Nonsense input"),

    ("I want pizza tonight",
     "unrecognized", "Unrelated to home services"),

    ("can you book me a doctor?",
     "unrecognized", "Medical request outside Servio scope"),
]


def scenario_from_data(d: dict) -> str:
    scenario = d.get("scenario")
    if scenario in {"single", "multi", "vague", "unrecognized"}:
        return scenario

    steps       = d.get("steps", [])
    flagged     = d.get("confidence_gate_triggered", False)
    extracted   = d.get("extracted", {})
    missing_loc = not extracted.get("location")
    missing_bud = not extracted.get("budget")
    if flagged or missing_loc or missing_bud:
        return "vague"
    if len(steps) > 1:
        return "multi"
    return "single"


def run_tests():
    print("Servio AI Recommender -- Comprehensive Scenario Test")
    print(f"API: {API_URL}\n")
    print("=" * 72)

    scenarios = ["single", "multi", "vague", "unrecognized"]
    totals   = {scenario: 0 for scenario in scenarios}
    correct  = {scenario: 0 for scenario in scenarios}
    failures = []

    for i, (prompt, expected, note) in enumerate(test_cases, 1):
        try:
            r     = requests.post(API_URL, json={"prompt": prompt}, timeout=20)
            d     = r.json()
            got   = scenario_from_data(d)
            ok    = got == expected
            svc   = d.get("recommended_service", "?")
            conf  = d.get("confidence", 0)
            steps = [s.get("service") for s in d.get("steps", [])]

            totals[expected] += 1
            if ok:
                correct[expected] += 1

            tag = "PASS" if ok else "FAIL"
            print(f"[{i:02d}] {tag}  expected={expected:<6}  got={got:<6}  -> {svc} ({conf}%)")
            print(f"      steps: {steps}")
            print(f"      note : {note}")
            print(f"      prompt: {prompt[:75]}")
            print()

            if not ok:
                failures.append((i, expected, got, prompt[:60]))

        except Exception as ex:
            print(f"[{i:02d}] ERROR -- {ex}\n")
            failures.append((i, expected, "error", str(ex)[:60]))

    print("=" * 72)
    print("RESULTS BY SCENARIO:")
    for sc in scenarios:
        t   = totals[sc]
        c   = correct[sc]
        bar = "#" * c + "." * (t - c)
        print(f"  {sc:<8} {bar}  {c}/{t}")

    total_c = sum(correct.values())
    total_t = sum(totals.values())
    pct     = (100 * total_c // total_t) if total_t else 0
    print(f"\n  TOTAL   {total_c}/{total_t} correct ({pct}%)")

    if failures:
        print("\nFAILED CASES:")
        for num, exp, got, p in failures:
            print(f"  [{num:02d}] expected={exp} got={got}  '{p}'")
    print("=" * 72)


if __name__ == "__main__":
    run_tests()
