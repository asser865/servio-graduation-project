import os
import unittest

os.environ.setdefault("GROQ_API_KEY", "test-key")

from api import _normalize_model_result  # noqa: E402


class SmartMatchLogicTests(unittest.TestCase):
    def test_water_electrical_and_paint_damage_builds_three_step_plan(self):
        prompt = (
            "My bathroom ceiling has water dripping on the electrical panel and "
            "the paint is bubbling off the walls. Budget 800 EGP, today."
        )

        result = _normalize_model_result(
            prompt,
            {
                "service": "Electrical",
                "confidence": 92,
                "location": "bathroom",
                "budget": "800 EGP",
                "time_range": "today",
                "top_3": [],
                "steps": [],
            },
        )

        services = [step["service"] for step in result["steps"]]
        self.assertEqual(services, ["Electrical", "Plumbing", "Painting"])
        self.assertEqual(result["steps"][0]["urgency"], "urgent")
        self.assertEqual(result["steps"][1]["urgency"], "same_day")
        self.assertEqual(result["steps"][2]["urgency"], "low")
        self.assertIsNone(result["extracted"]["location"])
        self.assertTrue(result["safety_risk"])
        self.assertEqual(len(result["issues"]), 3)

    def test_room_only_location_is_not_extracted(self):
        result = _normalize_model_result(
            "Water is leaking in my bathroom. Budget 300 EGP today.",
            {
                "service": "Plumbing",
                "confidence": 85,
                "location": "bathroom",
                "budget": "300 EGP",
                "time_range": "today",
            },
        )

        self.assertIsNone(result["extracted"]["location"])

    def test_vague_non_service_prompt_stays_unrecognized(self):
        result = _normalize_model_result(
            "Something feels wrong at home but I do not know what",
            {"service": None, "confidence": 20, "location": None},
        )

        self.assertEqual(result["scenario"], "unrecognized")
        self.assertEqual(result["steps"], [])

    def test_hard_scenario_matrix_refines_expected_outputs(self):
        scenarios = [
            {
                "name": "explicit district beats saved-location fallback",
                "prompt": "I need a plumber in Maadi for a leaking sink, budget 500 EGP tomorrow",
                "raw": {"service": "Plumbing", "confidence": 90, "location": "Maadi"},
                "services": ["Plumbing"],
                "location": "Maadi",
                "scenario": "single",
            },
            {
                "name": "appliance water issue is not plumbing",
                "prompt": "My washing machine is leaking and makes a loud noise in Dokki",
                "raw": {"service": "Appliance Repair", "confidence": 82, "location": "Dokki"},
                "services": ["Appliance Repair"],
                "location": "Dokki",
                "scenario": "single",
            },
            {
                "name": "multi unrelated services stay selectable",
                "prompt": "Clean my apartment and repaint the bedroom in Nasr City next week",
                "raw": {"service": "Cleaning", "confidence": 76, "location": "Nasr City"},
                "services": ["Cleaning", "Painting"],
                "location": "Nasr City",
                "scenario": "multi",
            },
            {
                "name": "misspelled electrical still maps from raw model service",
                "prompt": "Need an elctrician for sparks from socket in Cairo today budget 300 EGP",
                "raw": {"service": "Electrical", "confidence": 74, "location": "Cairo"},
                "services": ["Electrical"],
                "location": "Cairo",
                "scenario": "single",
            },
        ]

        for case in scenarios:
            with self.subTest(case["name"]):
                result = _normalize_model_result(case["prompt"], case["raw"])
                self.assertEqual([step["service"] for step in result["steps"]], case["services"])
                self.assertEqual(result["extracted"]["location"], case["location"])
                self.assertEqual(result["scenario"], case["scenario"])


if __name__ == "__main__":
    unittest.main()
