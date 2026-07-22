#!/usr/bin/env python3
"""
Generates reports/<customer>/deployment-log.md from git history, proving
what content was deployed and when for compliance/SLA evidence.

Usage: generate-deployment-report.py [--customer contoso]  (default: all)
"""
import argparse
import subprocess
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent
CUSTOMERS_DIR = ROOT / "customers"
REPORTS_DIR = ROOT / "reports"


def git_log_for_path(path: str):
    result = subprocess.run(
        ["git", "log", "--follow", "--date=iso-strict",
         "--pretty=format:%H|%ad|%an|%s", "--", path],
        cwd=ROOT, capture_output=True, text=True, check=True
    )
    entries = []
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        commit, date, author, subject = line.split("|", 3)
        entries.append({"commit": commit, "date": date, "author": author, "subject": subject})
    return entries


def generate_for_customer(customer: str):
    customer_dir = CUSTOMERS_DIR / customer
    if not customer_dir.exists():
        print(f"::warning::No such customer '{customer}', skipping")
        return

    out_dir = REPORTS_DIR / customer
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / "deployment-log.md"

    lines = [
        f"# Deployment Log - {customer}",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        "",
        "This log is derived from Git history and reflects every commit that",
        "touched this customer's Sentinel content. Each entry corresponds to a",
        "GitHub Actions deployment run gated by that customer's Environment.",
        "",
    ]

    for content_type_dir in sorted(customer_dir.iterdir()):
        if not content_type_dir.is_dir() or content_type_dir.name.startswith("."):
            continue
        rel = content_type_dir.relative_to(ROOT)
        entries = git_log_for_path(str(rel))
        if not entries:
            continue
        lines.append(f"## {content_type_dir.name}")
        lines.append("")
        lines.append("| Date | Commit | Author | Change |")
        lines.append("|------|--------|--------|--------|")
        for e in entries:
            lines.append(f"| {e['date']} | `{e['commit'][:8]}` | {e['author']} | {e['subject']} |")
        lines.append("")

    out_file.write_text("\n".join(lines))
    print(f"Wrote {out_file}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--customer")
    args = parser.parse_args()

    if args.customer:
        generate_for_customer(args.customer)
    else:
        for d in CUSTOMERS_DIR.iterdir():
            if d.is_dir() and not d.name.startswith("_"):
                generate_for_customer(d.name)


if __name__ == "__main__":
    main()
