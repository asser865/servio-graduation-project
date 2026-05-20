"""
Intensive confusing test suite for Servio AI recommender.

Two layers:
1) LOCAL  — exercises _parse_when / _extract_time_range / _find_service_mentions
            / _normalize_arabic. Deterministic, no API. Always runnable.
2) REMOTE — hits POST /recommend (LLM in the loop). Skipped if SKIP_REMOTE=1
            or if uvicorn not running on http://localhost:8001.

Run:
    cd ai_recommender
    python test_intensive.py
    python test_intensive.py --only-local
    BASE_URL=http://localhost:8001 python test_intensive.py
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from zoneinfo import ZoneInfo
    _TZ = ZoneInfo("Africa/Cairo")
except Exception:
    _TZ = None

from api import (
    _parse_when,
    _normalize_arabic,
    _extract_explicit_services,
    _disambiguate_appliance_vs_electrical,
)


def _fixed_now() -> datetime:
    # Monday 2026-05-18 10:00 Cairo. Stable anchor for relative-date tests.
    if _TZ is not None:
        return datetime(2026, 5, 18, 10, 0, tzinfo=_TZ)
    return datetime(2026, 5, 18, 10, 0)


# ---------------------------------------------------------------------------
# LOCAL TIME TESTS — confusing/edge cases for _parse_when
# ---------------------------------------------------------------------------
# anchor: Monday 2026-05-18
TIME_CASES: List[Tuple[str, Dict[str, Any]]] = [
    # canonical
    ("today",                    {"bucket": "today",     "iso_date": "2026-05-18"}),
    ("i need it tomorrow",       {"bucket": "tomorrow",  "iso_date": "2026-05-19"}),
    ("tonight",                  {"bucket": "tonight",   "iso_date": "2026-05-18"}),
    ("this evening please",      {"bucket": "tonight",   "iso_date": "2026-05-18"}),
    # typos / abbreviations
    ("tommorrow morning",        {"bucket": "tomorrow",  "iso_date": "2026-05-19"}),
    ("tomoro",                   {"bucket": "tomorrow",  "iso_date": "2026-05-19"}),
    ("tmrw fine",                {"bucket": "tomorrow",  "iso_date": "2026-05-19"}),
    ("tmr if possible",          {"bucket": "tomorrow",  "iso_date": "2026-05-19"}),
    # weekday — "by friday" on a Monday → coming Friday
    ("can you come by friday?",  {"bucket": "this_week", "iso_date": "2026-05-22"}),
    ("before friday please",     {"bucket": "this_week", "iso_date": "2026-05-22"}),
    ("on saturday",              {"bucket": "this_week", "iso_date": "2026-05-23"}),
    ("next monday",              {"bucket": "this_week", "iso_date": "2026-05-25"}),
    ("next sun please",          {"bucket": "this_week", "iso_date": "2026-05-24"}),
    # relative
    ("in 3 days",                {"bucket": "this_week", "iso_date": "2026-05-21"}),
    ("in 10 days",               {"bucket": "next_week", "iso_date": "2026-05-28"}),
    ("in 2 hours",               {"bucket": "this_week"}),  # iso same day
    # bucket-only
    ("this weekend works",       {"bucket": "weekend",   "iso_date": "2026-05-23"}),
    ("any time, no rush",        {"bucket": "flexible"}),
    ("whenever",                 {"bucket": "flexible"}),
    ("emergency!! right now",    {"bucket": "asap"}),
    ("ASAP my pipe burst",       {"bucket": "asap"}),
    # Arabic colloquial
    ("بكرة لو سمحت",              {"bucket": "tomorrow",  "iso_date": "2026-05-19"}),
    ("بكره الصبح",               {"bucket": "tomorrow",  "iso_date": "2026-05-19"}),
    ("بكرا",                     {"bucket": "tomorrow",  "iso_date": "2026-05-19"}),
    ("النهاردة عاجل",             {"bucket": "asap"}),
    ("النهارده فقط",              {"bucket": "today",     "iso_date": "2026-05-18"}),
    ("بعد بكرة",                 {"bucket": "tomorrow",  "iso_date": "2026-05-20"}),
    ("يوم الجمعة من فضلك",        {"bucket": "this_week", "iso_date": "2026-05-22"}),
    ("الجمعه",                   {"bucket": "this_week", "iso_date": "2026-05-22"}),
    ("بعد ٣ ايام",                {"bucket": "this_week", "iso_date": "2026-05-21"}),  # Arabic-Indic digits
    ("بعد 3 ايام",                {"bucket": "this_week", "iso_date": "2026-05-21"}),
    ("الاسبوع الجاي",             {"bucket": "next_week"}),
    ("الاسبوع القادم",            {"bucket": "next_week"}),
    ("نهايه الاسبوع",             {"bucket": "weekend",   "iso_date": "2026-05-23"}),
    ("حالا",                     {"bucket": "asap"}),
    ("دلوقتي",                   {"bucket": "asap"}),
    # mixed-language / noisy
    ("plumber tmrw يا ريت",       {"bucket": "tomorrow"}),
    ("سباك by friday لو سمحت",     {"bucket": "this_week", "iso_date": "2026-05-22"}),
    # adversarial — should NOT find a time
    ("my sink is leaking",       None),
    ("الحنفية بتنقط",             None),
    ("budget 500 EGP",           None),
]


def assert_time(case: str, want: Optional[Dict[str, Any]]) -> Tuple[bool, str]:
    got = _parse_when(case, _fixed_now())
    if want is None:
        ok = not got
        return ok, f"expected no time, got {got}" if not ok else "ok"
    for key, val in want.items():
        if got.get(key) != val:
            return False, f"key={key} want={val!r} got={got.get(key)!r} full={got}"
    return True, "ok"


# ---------------------------------------------------------------------------
# LOCAL SERVICE TESTS — confusing / dialect / typo-laden / ambiguous
# ---------------------------------------------------------------------------
# format: (prompt, expected_top_service_or_None, must_NOT_contain_set)
SERVICE_CASES: List[Tuple[str, Optional[str], set]] = [
    # explicit English
    ("my sink is leaking in Maadi",                    "Plumbing", set()),
    ("the lights keep flickering",                     "Electrical", set()),
    ("AC not cooling at all",                          "A/C", set()),
    ("door wont close, hinge broken",                  "Carpentry", set()),
    ("need a maid for deep cleaning",                  "Cleaning", set()),
    ("repaint the bedroom walls",                      "Painting", set()),
    ("washing machine wont spin",                      "Appliance Repair", set()),
    ("mount my TV on the wall",                        "Handyman", set()),
    # English typos / slang
    ("my fridg is broken",                             "Appliance Repair", set()),
    ("electric​ity gone in living room",                "Electrical", set()),  # zero-width inside
    ("no cold air from the wall unit",                 "A/C", set()),
    ("water dripin from ceiling",                      "Plumbing", set()),
    # Arabic dialect — should match without exact ال prefix
    ("الغساله بايظه",                                  "Appliance Repair", set()),
    ("مفيش كهربا في الأوضة",                            "Electrical", set()),
    ("التكييف ما بيبردش",                              "A/C", set()),
    ("الحنفيه بتنقط في المطبخ",                        "Plumbing", set()),
    ("الحيطه محتاجه دهان",                             "Painting", set()),
    ("الباب مش بيقفل",                                 "Carpentry", set()),
    ("محتاج شغاله نظافه",                              "Cleaning", set()),
    # shelf install — genuinely ambiguous between Carpentry and Handyman.
    # Accept either: pass `None` for the second slot via the special "EITHER" sentinel below.
    ("تركيب رف على الحيط",                             "__EITHER__:Handyman,Carpentry", set()),
    # MSA Arabic
    ("لدي تسريب مياه في الحمام",                       "Plumbing", set()),
    ("مكيف الهواء لا يعمل",                            "A/C", set()),
    # adversarial appliance-vs-electrical disambiguation
    ("oven is sparking and burning smell",             "Appliance Repair", {"Electrical"}),
    ("sparks from the wall socket",                    "Electrical", {"Appliance Repair"}),
    # adversarial cleaning-vs-plumbing (hidden leak)
    ("brown stains on my ceiling spreading",           "Plumbing", {"Cleaning"}),
    ("mold on bathroom wall",                          "Plumbing", set()),
    # ambiguous but NOT a home service — should yield empty
    ("can you build me a website",                     None, set()),
    ("my dog scratched the sofa",                      None, set()),
    ("need food delivery",                             None, set()),
]


def assert_service(case: str, want: Optional[str], forbidden: set) -> Tuple[bool, str]:
    services = _extract_explicit_services(case)
    services = _disambiguate_appliance_vs_electrical(case, services)
    top = services[0] if services else None
    if want is None:
        ok = top is None
        return ok, ("ok" if ok else f"expected no service, got {services}")
    if isinstance(want, str) and want.startswith("__EITHER__:"):
        alternatives = want.split(":", 1)[1].split(",")
        if top in alternatives:
            return True, f"ok (matched {top} from {alternatives})"
        return False, f"want one of {alternatives} got={top!r} full={services}"
    if top != want:
        return False, f"want top={want!r} got={top!r} full={services}"
    for bad in forbidden:
        if bad in services:
            return False, f"forbidden {bad!r} present in {services}"
    return True, "ok"


# ---------------------------------------------------------------------------
# LOCAL NORMALIZATION SANITY
# ---------------------------------------------------------------------------
NORM_CASES: List[Tuple[str, str]] = [
    ("الحَنَفِيَّةُ", "الحنفيه"),  # tashkeel + ta-marbuta
    ("غَدًا",        "غدا"),
    ("١٢٣٤",        "1234"),       # Arabic-Indic digits
    ("إسماعيل",     "اسماعيل"),
    ("مُكَيِّف",     "مكيف"),
]


def assert_norm(case: str, want: str) -> Tuple[bool, str]:
    got = _normalize_arabic(case)
    return got == want, f"want={want!r} got={got!r}"


# ---------------------------------------------------------------------------
# REMOTE — exercises full /recommend endpoint (LLM round-trip)
# ---------------------------------------------------------------------------
REMOTE_CASES: List[Dict[str, Any]] = [
    {
        "name": "english + by-friday + budget + location",
        "prompt": "I need a plumber by friday in Maadi, budget 400 EGP, sink is leaking",
        "expect": {"recommended_service": "Plumbing", "time_iso_must_be": "2026-05-22"},
    },
    {
        "name": "typo tomorrow",
        "prompt": "fix my electricity tommorow in nasr city, 300 EGP",
        "expect": {"recommended_service": "Electrical", "time_iso_must_be": "2026-05-19"},
    },
    {
        "name": "arabic dialect plumbing + bukra",
        "prompt": "الحنفيه بتنقط في المطبخ بكره الصبح في مدينة نصر",
        "expect": {"recommended_service": "Plumbing", "time_iso_must_be": "2026-05-19"},
    },
    {
        "name": "arabic dialect AC + day name",
        "prompt": "التكييف ما بيبردش لو سمحت يوم الجمعه في الزمالك",
        "expect": {"recommended_service": "A/C", "time_iso_must_be": "2026-05-22"},
    },
    {
        "name": "arabic Indic digits + relative",
        "prompt": "الغساله بايظه واحتاج فني بعد ٢ ايام في 6 اكتوبر",
        "expect": {"recommended_service": "Appliance Repair", "time_iso_must_be": "2026-05-20"},
    },
    {
        "name": "ASAP overrides specific day",
        "prompt": "emergency!! water dripping on the electrical panel right now",
        "expect": {"recommended_service": "Electrical", "safety_risk": True},
    },
    {
        "name": "appliance-vs-electrical confusion",
        "prompt": "the oven is sparking and i smell burning",
        "expect": {"recommended_service": "Appliance Repair"},
    },
    {
        "name": "hidden leak masquerading as cleaning",
        "prompt": "brown stains keep spreading on my living room ceiling",
        "expect": {"recommended_service": "Plumbing"},
    },
    {
        "name": "next monday",
        "prompt": "ac installation next monday in heliopolis budget 800",
        "expect": {"recommended_service": "A/C", "time_iso_must_be": "2026-05-25"},
    },
    {
        "name": "Arabic colloquial — لا توجد كهرباء",
        "prompt": "مفيش كهربا خالص في الشقه دلوقتي",
        "expect": {"recommended_service": "Electrical"},
    },
    {
        "name": "non-home-service should be null",
        "prompt": "can you build me an e-commerce website",
        "expect": {"recommended_service": None},
    },
]


def _http_post(base: str, body: Dict[str, Any], timeout: float = 25.0) -> Optional[Dict[str, Any]]:
    import urllib.request
    req = urllib.request.Request(
        f"{base.rstrip('/')}/recommend",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        return {"_error": str(exc)}


def run_remote(base: str) -> Tuple[int, int]:
    passed = 0
    failed = 0
    print(f"\n=== REMOTE /recommend @ {base} ===")
    for case in REMOTE_CASES:
        result = _http_post(base, {"prompt": case["prompt"]})
        if not isinstance(result, dict) or "_error" in (result or {}):
            err = (result or {}).get("_error", "no response")
            print(f"  ✗ {case['name']}: transport — {err}")
            failed += 1
            continue
        ok, reasons = True, []
        expect = case["expect"]
        if "recommended_service" in expect:
            got = result.get("recommended_service")
            if got != expect["recommended_service"]:
                ok = False
                reasons.append(f"service: want={expect['recommended_service']!r} got={got!r}")
        if "time_iso_must_be" in expect:
            iso = (result.get("extracted") or {}).get("time_range_iso")
            if iso != expect["time_iso_must_be"]:
                ok = False
                reasons.append(f"time_iso: want={expect['time_iso_must_be']!r} got={iso!r}")
        if "safety_risk" in expect:
            if bool(result.get("safety_risk")) != bool(expect["safety_risk"]):
                ok = False
                reasons.append(f"safety_risk: want={expect['safety_risk']} got={result.get('safety_risk')}")
        if ok:
            passed += 1
            print(f"  ✓ {case['name']}")
        else:
            failed += 1
            print(f"  ✗ {case['name']}: {'; '.join(reasons)}")
        time.sleep(0.3)
    return passed, failed


# ---------------------------------------------------------------------------
# RUNNER
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only-local", action="store_true")
    parser.add_argument("--only-remote", action="store_true")
    parser.add_argument("--base", default=os.environ.get("BASE_URL", "http://localhost:8001"))
    args = parser.parse_args()

    total_pass = 0
    total_fail = 0

    if not args.only_remote:
        print("=== LOCAL TIME PARSER ===")
        for prompt, want in TIME_CASES:
            ok, msg = assert_time(prompt, want)
            mark = "✓" if ok else "✗"
            print(f"  {mark} {prompt!r:55} -> {msg}")
            total_pass += int(ok)
            total_fail += int(not ok)

        print("\n=== LOCAL SERVICE EXTRACTION ===")
        for prompt, want, forbidden in SERVICE_CASES:
            ok, msg = assert_service(prompt, want, forbidden)
            mark = "✓" if ok else "✗"
            print(f"  {mark} {prompt!r:60} -> {msg}")
            total_pass += int(ok)
            total_fail += int(not ok)

        print("\n=== LOCAL ARABIC NORMALIZATION ===")
        for prompt, want in NORM_CASES:
            ok, msg = assert_norm(prompt, want)
            mark = "✓" if ok else "✗"
            print(f"  {mark} {prompt!r:25} -> {msg}")
            total_pass += int(ok)
            total_fail += int(not ok)

    if not args.only_local and os.environ.get("SKIP_REMOTE") != "1":
        p, f = run_remote(args.base)
        total_pass += p
        total_fail += f

    print(f"\n=== SUMMARY: {total_pass} passed / {total_fail} failed ===")
    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
