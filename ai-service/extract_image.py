"""Extract generated_room_image from JSON response and save as JPG."""
import json
import base64
import sys
from pathlib import Path

if len(sys.argv) < 2:
    print("Usage: python extract_image.py <path-to-response.json>")
    print("Example: python extract_image.py response_1779018944475.json")
    sys.exit(1)

input_path = Path(sys.argv[1])
if not input_path.exists():
    print(f"File not found: {input_path}")
    sys.exit(1)

with open(input_path, "r", encoding="utf-8") as f:
    data = json.load(f)

b64 = data.get("generated_room_image")
if not b64:
    print("No 'generated_room_image' field in JSON.")
    sys.exit(1)

output_path = input_path.with_suffix(".jpg")
with open(output_path, "wb") as f:
    f.write(base64.b64decode(b64))

print(f"Saved: {output_path.resolve()}")
print(f"Size: {output_path.stat().st_size / 1024:.1f} KB")
