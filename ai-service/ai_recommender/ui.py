import os
import subprocess
import sys
import time

import gradio as gr
import requests

API_URL = "http://localhost:8001/recommend"
API_ROOT = "http://localhost:8001/"

SERVICE_ICON = {
    "Plumbing": "&#128167;",
    "Electrical": "&#9889;",
    "A/C": "&#10052;",
    "Carpentry": "&#128736;",
    "Cleaning": "&#129533;",
    "Painting": "&#128396;",
    "Appliance Repair": "&#128295;",
    "Handyman": "&#128296;",
}

URGENCY_BADGE = {
    "urgent": ("&#128308;", "#ef4444"),
    "same_day": ("&#128308;", "#b91c1c"),
    "high": ("&#128992;", "#f97316"),
    "low": ("&#128994;", "#22c55e"),
}

MOCK_TECHNICIANS = {
    "Plumbing": {
        "name": "Omar Tarek",
        "role": "Master Plumber",
        "exp": "12 yrs",
        "rating": "4.9",
        "avail": "Within 45 mins",
        "rate": "100 EGP flat repair",
        "tags": ["Verified Emergency", "Leak Specialist"],
        "avatar": "https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=80&h=80&fit=crop",
    },
    "Electrical": {
        "name": "Khaled Mostafa",
        "role": "Certified Electrician",
        "exp": "9 yrs",
        "rating": "4.8",
        "avail": "Same Day",
        "rate": "120 EGP/hr",
        "tags": ["Verified", "Panel & Wiring Expert"],
        "avatar": "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=80&h=80&fit=crop",
    },
    "A/C": {
        "name": "Mahmoud Hassan",
        "role": "A/C & HVAC Specialist",
        "exp": "10 yrs",
        "rating": "4.7",
        "avail": "Today",
        "rate": "150 EGP service call",
        "tags": ["Verified", "All Brands"],
        "avatar": "https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?w=80&h=80&fit=crop",
    },
    "Carpentry": {
        "name": "Tarek Ibrahim",
        "role": "Master Carpenter",
        "exp": "15 yrs",
        "rating": "4.6",
        "avail": "This Week",
        "rate": "200 EGP/day",
        "tags": ["Verified", "Doors & Furniture"],
        "avatar": "https://images.unsplash.com/photo-1581092335397-9583eb92d232?w=80&h=80&fit=crop",
    },
    "Cleaning": {
        "name": "Aisha Mahmoud",
        "role": "Deep Cleaning Expert",
        "exp": "6 yrs",
        "rating": "4.9",
        "avail": "Tomorrow",
        "rate": "350 EGP full apt",
        "tags": ["Verified", "Deep & Carpet Clean"],
        "avatar": "https://images.unsplash.com/photo-1607746882042-944635dfe10e?w=80&h=80&fit=crop",
    },
    "Painting": {
        "name": "Youssef Ali",
        "role": "Interior Painter",
        "exp": "8 yrs",
        "rating": "4.7",
        "avail": "Next Week",
        "rate": "250 EGP/day",
        "tags": ["Verified", "Interior Specialist"],
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&h=80&fit=crop",
    },
    "Appliance Repair": {
        "name": "Hassan El-Sayed",
        "role": "Appliance Technician",
        "exp": "11 yrs",
        "rating": "4.8",
        "avail": "Today",
        "rate": "130 EGP/hr",
        "tags": ["Verified", "Multi-Brand Repair"],
        "avatar": "https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=80&h=80&fit=crop",
    },
    "Handyman": {
        "name": "Amr Walid",
        "role": "General Handyman",
        "exp": "7 yrs",
        "rating": "4.6",
        "avail": "Today",
        "rate": "90 EGP/hr",
        "tags": ["Verified", "Quick Fix"],
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80&h=80&fit=crop",
    },
}

CSS = """
.gradio-container { max-width: 860px !important; margin: 0 auto !important; }
.submit-row button { height: 52px !important; font-size: 16px !important; font-weight: 700 !important; }
footer { display: none !important; }
"""


def check_api_status():
    try:
        response = requests.get(API_ROOT, timeout=2)
        if response.status_code == 200:
            return (
                '<div style="background:#22c55e;color:white;padding:8px 18px;border-radius:8px;'
                'font-weight:700;font-size:14px;display:inline-block">API Online</div>'
            )
    except Exception:
        pass

    return (
        '<div style="background:#ef4444;color:white;padding:8px 18px;border-radius:8px;'
        'font-weight:700;font-size:14px;display:inline-block">API Offline</div>'
    )


def start_api():
    try:
        response = requests.get(API_ROOT, timeout=1)
        if response.status_code == 200:
            return check_api_status()
    except Exception:
        pass

    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "api:app", "--port", "8001"],
            cwd=script_dir,
            creationflags=flags,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(4)
    except Exception as exc:
        return (
            '<div style="background:#ef4444;color:white;padding:8px 18px;border-radius:8px;'
            f'font-weight:700">Failed: {exc}</div>'
        )

    return check_api_status()


def card(service: str, location: str = None, budget: str = None) -> str:
    technician = MOCK_TECHNICIANS.get(service) or MOCK_TECHNICIANS["Handyman"]
    icon = SERVICE_ICON.get(service, "&#128295;")
    loc = location or "Your Area"
    tags = " ".join(
        f'<span style="background:#f0f4ff;color:#4338ca;font-size:12px;font-weight:600;'
        f'padding:3px 10px;border-radius:20px">{tag}</span>'
        for tag in technician["tags"]
    )
    budget_line = (
        f'<span style="color:#64748b;font-size:14px">Budget: <b>{budget}</b></span><br>'
        if budget
        else ""
    )

    return f"""
<div style="font-family:'Segoe UI',system-ui,sans-serif;border-radius:16px;overflow:hidden;
            box-shadow:0 4px 24px rgba(0,0,0,0.12);border:1px solid #e2e8f0">
  <div style="background:linear-gradient(135deg,#4f46e5,#7c3aed);color:white;padding:18px 22px;
              display:flex;align-items:center;gap:14px">
    <span style="font-size:32px;line-height:1">{icon}</span>
    <div style="flex:1">
      <div style="font-size:11px;font-weight:800;letter-spacing:1.5px;opacity:.8;margin-bottom:3px">RECOMMENDED TECHNICIAN</div>
      <div style="font-size:18px;font-weight:800">{service} · {loc}</div>
    </div>
    <div style="background:#22c55e;color:white;font-size:12px;font-weight:800;
                padding:5px 14px;border-radius:20px;white-space:nowrap">98% Match</div>
  </div>

  <div style="background:#fff;padding:20px 22px">
    <div style="display:flex;align-items:center;gap:16px;padding-bottom:16px;
                border-bottom:1px solid #f1f5f9;margin-bottom:16px">
      <img src="{technician['avatar']}" width="64" height="64"
           style="border-radius:50%;object-fit:cover;border:3px solid #e0e7ff"
           onerror="this.style.display='none'" />
      <div style="flex:1">
        <div style="font-size:20px;font-weight:800;color:#0f172a">{technician['name']}</div>
        <div style="font-size:14px;color:#64748b;margin-top:2px">{technician['role']} &nbsp;·&nbsp; {technician['exp']} exp.</div>
      </div>
      <div style="background:#fef9c3;color:#713f12;font-size:18px;font-weight:800;
                  padding:6px 14px;border-radius:10px">★ {technician['rating']}</div>
    </div>

    <div style="margin-bottom:14px;line-height:2">
      <span style="color:#64748b;font-size:14px">Location: <b>{loc}</b></span><br>
      <span style="color:#16a34a;font-size:14px;font-weight:700">Availability: {technician['avail']}</span><br>
      <span style="color:#64748b;font-size:14px">Rate: <b>{technician['rate']}</b></span><br>
      {budget_line}
    </div>

    <div style="margin-bottom:18px">{tags}</div>

    <a href="../html/booking.html"
       style="display:block;text-align:center;background:linear-gradient(135deg,#4f46e5,#7c3aed);
              color:white;font-size:16px;font-weight:800;padding:14px;border-radius:10px;
              text-decoration:none;letter-spacing:.3px">
      Accept &amp; Book Now →
    </a>
  </div>
</div>"""


def plan_card(data: dict, highlighted: str = None) -> str:
    steps = data.get("steps", [])
    advisor_message = data.get("advisor_message", "")
    extracted = data.get("extracted", {})

    parts = [f"{len(steps)} services detected"]
    if extracted.get("location"):
        parts.append(extracted["location"])
    if extracted.get("budget"):
        parts.append(f"Budget {extracted['budget']}")
    subtitle = " · ".join(parts)

    rows = ""
    for step in steps:
        dot, color = URGENCY_BADGE.get(step.get("urgency", "low"), ("&#128994;", "#22c55e"))
        service = step.get("service", "")
        is_highlighted = highlighted and service == highlighted
        background = "rgba(79,70,229,.07)" if is_highlighted else "#fff"
        border = "3px solid #4f46e5" if is_highlighted else "3px solid transparent"
        pick_badge = (
            '<span style="background:#4f46e5;color:#fff;font-size:10px;font-weight:700;'
            'padding:2px 8px;border-radius:20px;margin-left:8px">YOUR PICK</span>'
            if is_highlighted
            else ""
        )

        rows += (
            f'<div style="display:flex;align-items:center;padding:10px 14px;'
            f'background:{background};border-left:{border};border-bottom:1px solid #f1f5f9">'
            f'<span style="color:#94a3b8;font-size:11px;font-weight:700;width:52px">STEP {step.get("step", "")}</span>'
            f'<span style="font-size:16px;margin-right:8px">{SERVICE_ICON.get(service, "&#128295;")}</span>'
            f'<span style="font-weight:700;font-size:15px;flex:1;color:#0f172a">{service}{pick_badge}</span>'
            f'<span style="background:{color};color:#fff;font-size:11px;font-weight:700;'
            f'padding:3px 11px;border-radius:20px">{dot} {step.get("urgency_label", "Can Wait")}</span>'
            f'</div>'
        )

    advisor = ""
    if advisor_message:
        advisor = (
            '<div style="padding:14px 16px 6px">'
            '<div style="font-size:11px;font-weight:800;color:#94a3b8;letter-spacing:1px;margin-bottom:6px">SERVIO ADVISOR</div>'
            f'<div style="font-size:14px;color:#334155;line-height:1.6;font-style:italic">&ldquo;{advisor_message}&rdquo;</div>'
            '</div>'
        )

    return (
        '<div style="font-family:\'Segoe UI\',system-ui,sans-serif;border-radius:14px;overflow:hidden;'
        'border:1px solid #e2e8f0;box-shadow:0 2px 12px rgba(0,0,0,.07)">'
        '<div style="background:#1e293b;color:#fff;padding:14px 18px">'
        '<div style="font-size:11px;font-weight:800;letter-spacing:1.5px;opacity:.7;margin-bottom:2px">YOUR HOME SERVICE PLAN</div>'
        f'<div style="font-size:14px;font-weight:600">{subtitle}</div>'
        '</div>'
        f'<div style="background:#fff">{rows}{advisor}</div>'
        '</div>'
    )


def _service_choice_label(service: str) -> str:
    return f"{service}"


def _service_from_choice(choice: str) -> str:
    return choice.strip()


def followup_intro(data: dict) -> str:
    message = data.get("follow_up_message") or "Add the missing details below to continue."
    return (
        '<div style="background:#fff7ed;border:1px solid #fdba74;border-radius:12px;'
        'padding:12px 14px;margin-bottom:12px">'
        '<div style="font-size:13px;font-weight:700;color:#9a3412;margin-bottom:4px">Before we match a technician</div>'
        f'<div style="font-size:13px;color:#7c2d12;line-height:1.5">{message}</div>'
        '</div>'
    )


def priority_intro(needs_follow_up: bool) -> str:
    body = (
        "Servio already ranked the issues above. Pick the one you care about most, then add the missing details below to unlock the technician match."
        if needs_follow_up
        else "Servio ranked them by urgency above. Pick the one you want to solve first and the technician card will update instantly."
    )
    return (
        '<div style="background:linear-gradient(135deg,#ede9fe,#f5f3ff);border:1px solid #c4b5fd;'
        'border-radius:12px;padding:14px 18px;margin:8px 0 4px">'
        '<b style="color:#4c1d95;font-size:15px">Multiple issues detected</b>'
        f'<p style="color:#5b21b6;font-size:13px;margin:4px 0 0">{body}</p></div>'
    )


def vague_card(data: dict) -> str:
    missing_fields = data.get("missing_field_labels", [])
    confidence = data.get("confidence")
    recommended = data.get("recommended_service")
    issue_mode = data.get("issue_mode", "single")
    follow_up_message = data.get("follow_up_message") or "Answer below to get your technician match."
    services = data.get("service_options") or [
        item.get("service")
        for item in data.get("top_3", [])
        if item.get("service") and item.get("confidence", 0) > 0
    ]

    items = "".join(
        f'<div style="display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:1px solid #fef3c7">'
        f'<span style="color:#f59e0b;font-size:16px">○</span>'
        f'<span style="font-size:14px;color:#92400e;font-weight:600">{field}</span></div>'
        for field in missing_fields
    )
    confidence_line = (
        f'<div style="font-size:13px;color:#b45309;margin-bottom:10px">AI confidence: <b>{confidence}%</b> and it needs a bit more detail</div>'
        if confidence is not None and confidence < 60
        else ""
    )
    title = (
        f"Multiple services found: {', '.join(services)}"
        if issue_mode == "multi" and services
        else f"Likely match so far: {recommended}"
        if recommended
        else "Need a bit more detail"
    )
    chips = "".join(
        f'<span style="background:#fff;color:#78350f;border:1px solid #fcd34d;font-size:12px;'
        f'font-weight:700;padding:4px 10px;border-radius:999px">{SERVICE_ICON.get(service, "&#128295;")} {service}</span>'
        for service in services[:3]
    )

    return (
        '<div style="font-family:\'Segoe UI\',system-ui,sans-serif;border-radius:14px;overflow:hidden;'
        'border:2px solid #fcd34d;box-shadow:0 2px 12px rgba(0,0,0,.07)">'
        '<div style="background:#fbbf24;padding:14px 18px">'
        '<div style="font-size:16px;font-weight:800;color:#1c1917">Need a bit more info</div>'
        f'<div style="font-size:13px;color:#44403c;margin-top:3px">{title}</div>'
        '</div>'
        f'<div style="background:#fffbeb;padding:14px 18px">{confidence_line}'
        f'<div style="font-size:13px;color:#92400e;line-height:1.5;margin-bottom:12px">{follow_up_message}</div>'
        f'<div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px">{chips}</div>{items}</div>'
        '</div>'
    )


def _call_api(prompt: str) -> dict:
    try:
        return requests.post(API_URL, json={"prompt": prompt}, timeout=10).json()
    except requests.exceptions.ConnectionError:
        return {"error": "API is offline - click Start API above."}
    except Exception as exc:
        return {"error": str(exc)}


def _radio_value(choices, selected_service):
    if not choices:
        return None
    if selected_service:
        return _service_choice_label(selected_service)
    return choices[0]


def _outputs(data):
    if "error" in data:
        error_html = (
            f'<p style="color:#ef4444;font-family:Segoe UI,sans-serif;padding:16px">{data["error"]}</p>'
        )
        return (
            error_html,
            gr.update(visible=False),
            "",
            gr.update(visible=False),
            "",
            gr.update(choices=[], value=None),
            gr.update(visible=False),
            "",
            data,
        )

    steps = data.get("steps", [])
    extracted = data.get("extracted", {})
    issue_mode = data.get("issue_mode") or ("multi" if len(steps) > 1 else "single")
    needs_follow_up = bool(data.get("needs_follow_up"))
    selected_service = data.get("selected_service") or data.get("recommended_service")
    choices = [_service_choice_label(step["service"]) for step in steps if step.get("service")]
    radio_value = _radio_value(choices, selected_service)

    if needs_follow_up and issue_mode == "multi" and len(steps) > 1:
        return (
            plan_card(data, highlighted=selected_service),
            gr.update(visible=True),
            followup_intro(data),
            gr.update(visible=True),
            priority_intro(True),
            gr.update(choices=choices, value=radio_value),
            gr.update(visible=False),
            "",
            data,
        )

    if needs_follow_up:
        return (
            vague_card(data),
            gr.update(visible=True),
            followup_intro(data),
            gr.update(visible=False),
            "",
            gr.update(choices=[], value=None),
            gr.update(visible=False),
            "",
            data,
        )

    if issue_mode == "single":
        technician_html = card(selected_service, extracted.get("location"), extracted.get("budget"))
        return (
            technician_html,
            gr.update(visible=False),
            "",
            gr.update(visible=False),
            "",
            gr.update(choices=[], value=None),
            gr.update(visible=False),
            "",
            data,
        )

    technician_html = card(selected_service, extracted.get("location"), extracted.get("budget"))
    return (
        plan_card(data, highlighted=selected_service),
        gr.update(visible=False),
        "",
        gr.update(visible=True),
        priority_intro(False),
        gr.update(choices=choices, value=radio_value),
        gr.update(visible=True),
        technician_html,
        data,
    )


_BLANK = (
    "",
    gr.update(visible=False),
    "",
    gr.update(visible=False),
    "",
    gr.update(choices=[], value=None),
    gr.update(visible=False),
    "",
    None,
)


def handle_submit(prompt):
    if not prompt.strip():
        return _BLANK
    return _outputs(_call_api(prompt))


def handle_refine(original, f_loc, f_bud, f_time, f_note, priority_choice, _state):
    parts = []
    if f_loc and f_loc.strip():
        parts.append(f"location: {f_loc.strip()}")
    if f_bud and f_bud.strip():
        parts.append(f"budget: {f_bud.strip()} EGP")
    if f_time and f_time.strip():
        parts.append(f"when: {f_time.strip()}")
    if f_note and f_note.strip():
        parts.append(f_note.strip())
    if priority_choice:
        parts.append(f"my top priority is {_service_from_choice(priority_choice)}")

    refined = original.strip() + (". " + ", ".join(parts) if parts else "")
    return _outputs(_call_api(refined))


def handle_priority(choice, api_state):
    if not choice or not api_state:
        return gr.update(), gr.update(visible=False), ""

    if api_state.get("issue_mode") != "multi":
        return gr.update(), gr.update(visible=False), ""

    service = _service_from_choice(choice)
    if api_state.get("needs_follow_up"):
        return plan_card(api_state, highlighted=service), gr.update(visible=False), ""

    extracted = api_state.get("extracted", {})
    return (
        plan_card(api_state, highlighted=service),
        gr.update(visible=True),
        card(service, extracted.get("location"), extracted.get("budget")),
    )


with gr.Blocks(title="Servio AI Recommender", theme=gr.themes.Soft(), css=CSS) as demo:
    state = gr.State(None)

    gr.Markdown("## Servio - AI Service Recommender")
    with gr.Row():
        api_html = gr.HTML(value=check_api_status())
        refresh_btn = gr.Button("Refresh", size="sm")
        start_btn = gr.Button("Start API", variant="primary", size="sm")

    gr.Markdown("---")

    prompt_box = gr.Textbox(
        label="Describe your issue",
        placeholder='e.g. "AC not cooling in Heliopolis, budget 500 EGP, this weekend"',
        lines=3,
    )
    with gr.Row(elem_classes="submit-row"):
        submit_btn = gr.Button("Find My Technician", variant="primary")

    top_output = gr.HTML()

    with gr.Group(visible=False) as followup_group:
        followup_html = gr.HTML()
        with gr.Row():
            f_loc = gr.Textbox(label="Location", placeholder="e.g. Madinaty, Nasr City")
            f_time = gr.Textbox(label="When?", placeholder="e.g. Today, ASAP, This weekend")
        f_bud = gr.Textbox(label="Budget (EGP)", placeholder="e.g. 300 or 500-800")
        f_note = gr.Textbox(label="Extra details", placeholder="Any other context", lines=2)
        refine_btn = gr.Button("Refine & Find Technician", variant="primary")

    with gr.Group(visible=False) as priority_group:
        priority_html = gr.HTML()
        priority_radio = gr.Radio(label="Your top priority:", choices=[], interactive=True)

    with gr.Group(visible=False) as tech_group:
        tech_html = gr.HTML()

    gr.Markdown("---")
    gr.Examples(
        examples=[
            ["AC not cooling the room in Heliopolis, budget 500 EGP, this weekend"],
            ["water leaking under my sink in Maadi Cairo, budget 200 EGP, need it fixed today"],
            ["hello i have a problem with my AC, my ac keeps turning on and off alone"],
            ["water is dripping directly onto the socket in my kitchen in Nasr City, urgent"],
        ],
        inputs=prompt_box,
        label="Try these:",
    )

    outputs = [
        top_output,
        followup_group,
        followup_html,
        priority_group,
        priority_html,
        priority_radio,
        tech_group,
        tech_html,
        state,
    ]

    refresh_btn.click(fn=check_api_status, outputs=api_html)
    start_btn.click(fn=start_api, outputs=api_html)
    submit_btn.click(fn=handle_submit, inputs=prompt_box, outputs=outputs)
    prompt_box.submit(fn=handle_submit, inputs=prompt_box, outputs=outputs)

    refine_btn.click(
        fn=handle_refine,
        inputs=[prompt_box, f_loc, f_bud, f_time, f_note, priority_radio, state],
        outputs=outputs,
    )

    priority_radio.change(
        fn=handle_priority,
        inputs=[priority_radio, state],
        outputs=[top_output, tech_group, tech_html],
    )

    demo.load(fn=check_api_status, outputs=api_html)

demo.launch(server_name="127.0.0.1", server_port=7860, show_error=True)
