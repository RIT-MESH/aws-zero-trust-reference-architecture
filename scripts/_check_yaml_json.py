#!/usr/bin/env python3
"""Check that all YAML and JSON files in the repo are well-formed."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

try:
    import yaml  # noqa: F401
    HAVE_YAML = True
except Exception:
    HAVE_YAML = False

errors = []

for p in ROOT.rglob("*.json"):
    if ".terraform" in p.parts or ".git" in p.parts:
        continue
    try:
        json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        errors.append(f"{p.relative_to(ROOT)}: {e}")

if HAVE_YAML:
    for p in list(ROOT.rglob("*.yml")) + list(ROOT.rglob("*.yaml")):
        if ".terraform" in p.parts or ".git" in p.parts:
            continue
        try:
            list(yaml.safe_load_all(p.read_text(encoding="utf-8")))
        except Exception as e:
            errors.append(f"{p.relative_to(ROOT)}: {e}")
else:
    print("PyYAML not installed; skipping YAML syntax checks (JSON only).")

if errors:
    for e in errors:
        print(f"  {e}")
    sys.exit(1)
print("All JSON/YAML files are well-formed.")
