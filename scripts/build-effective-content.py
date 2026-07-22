#!/usr/bin/env python3
"""
Build 'effective' content for every customer by merging shared/<ContentType>/*.json
(baseline, keyed by contentId) with each customer's subscriptions.json (inherit / override).

Outputs to customers/<customer>/.effective/<ContentType>/<contentId>.json - these are
what actually get deployed for shared content, alongside the customer's own native files.

Also supports --changed-shared-file to answer "which customers does this shared file
change affect", used by the deploy workflow to fan out shared-content changes correctly.

Usage:
  build-effective-content.py --all
  build-effective-content.py --customer contoso
  build-effective-content.py --changed-shared-file shared/AnalyticsRules/baseline-mass-account-deletion.json
"""
import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CUSTOMERS_DIR = ROOT / "customers"
SHARED_DIR = ROOT / "shared"


def deep_merge(base: dict, override: dict) -> dict:
    result = dict(base)
    for k, v in override.items():
        if k in ("contentId",):
            continue
        if isinstance(v, dict) and isinstance(result.get(k), dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result


def load_shared_baselines():
    baselines = {}
    for content_type_dir in SHARED_DIR.iterdir():
        if not content_type_dir.is_dir():
            continue
        content_type = content_type_dir.name
        for f in content_type_dir.glob("*.json"):
            data = json.loads(f.read_text())
            content_id = data.get("contentId")
            if not content_id:
                print(f"::warning::{f} has no contentId, skipping from overlay model")
                continue
            baselines.setdefault(content_type, {})[content_id] = data
    return baselines


def build_for_customer(customer_dir: Path, baselines: dict):
    sub_file = customer_dir / "subscriptions.json"
    if not sub_file.exists():
        return []
    subs = json.loads(sub_file.read_text())
    written = []
    for content_type, entries in subs.items():
        if content_type == "comment":
            continue
        out_dir = customer_dir / ".effective" / content_type
        out_dir.mkdir(parents=True, exist_ok=True)
        for entry in entries:
            content_id = entry["contentId"]
            mode = entry.get("mode", "inherit")
            baseline = baselines.get(content_type, {}).get(content_id)
            if not baseline:
                print(f"::error::{customer_dir.name} subscribes to unknown {content_type} contentId '{content_id}'")
                sys.exit(1)
            effective = baseline
            if mode == "override":
                override_path = ROOT / entry["overridePath"]
                override_data = json.loads(override_path.read_text())
                effective = deep_merge(baseline, override_data)
            out_file = out_dir / f"{content_id}.json"
            out_file.write_text(json.dumps(effective, indent=2))
            written.append(str(out_file.relative_to(ROOT)))
    return written


def customers_subscribed_to(content_type: str, content_id: str):
    affected = []
    for customer_dir in CUSTOMERS_DIR.iterdir():
        if not customer_dir.is_dir() or customer_dir.name == "_template":
            continue
        sub_file = customer_dir / "subscriptions.json"
        if not sub_file.exists():
            continue
        subs = json.loads(sub_file.read_text())
        for entry in subs.get(content_type, []):
            if entry["contentId"] == content_id:
                affected.append(customer_dir.name)
    return affected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--customer")
    parser.add_argument("--changed-shared-file")
    args = parser.parse_args()

    baselines = load_shared_baselines()

    if args.changed_shared_file:
        parts = Path(args.changed_shared_file).parts
        content_type = parts[1]
        data = json.loads((ROOT / args.changed_shared_file).read_text())
        content_id = data.get("contentId")
        affected = customers_subscribed_to(content_type, content_id)
        print(json.dumps({"contentType": content_type, "contentId": content_id, "affectedCustomers": affected}))
        return

    targets = [CUSTOMERS_DIR / args.customer] if args.customer else [
        d for d in CUSTOMERS_DIR.iterdir() if d.is_dir() and d.name != "_template"
    ]
    for customer_dir in targets:
        written = build_for_customer(customer_dir, baselines)
        for f in written:
            print(f"Built: {f}")


if __name__ == "__main__":
    main()
