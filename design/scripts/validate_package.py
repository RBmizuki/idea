#!/usr/bin/env python3
"""Validate Demand Foundry design package fixtures and required artifact inventory."""
from __future__ import annotations

from pathlib import Path
import hashlib
import json
import sys

import yaml
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "run-2026-09-04-01"
REQUIRED_DOCS = [
    "VISION.md", "PRD.md", "ARCHITECTURE.md", "AGENTS.md", "PIPELINE.md",
    "EVIDENCE.md", "EVALUATION.md", "DATA_MODEL.md", "API_SPEC.md", "UI_UX.md",
    "VALIDATION_SYSTEM.md", "SECURITY_AND_RISK.md", "MVP_PLAN.md", "BACKLOG.md",
    "DECISIONS.md", "STATE.md",
]
REQUIRED_RUN = [
    "brief.snapshot.yaml", "rubric.snapshot.yaml", "sources.jsonl", "evidence.jsonl",
    "signals.jsonl", "problems.jsonl", "opportunities.jsonl", "ideas.jsonl",
    "evaluations.jsonl", "red-team.jsonl", "validation-plans.jsonl", "decisions.jsonl",
    "costs.json", "STATE.md", "FINAL.md",
]
REQUIRED_IDEA_KEYS = set(
    "idea_id title one_liner origin change problem why_now customer trigger_event "
    "current_workflow current_alternative current_cost cost_of_inaction solution "
    "value_proposition before_after unique_mechanism business_model market go_to_market "
    "technology competition risk validation mvp economics classification scores decision".split()
)
PROVENANCE = set(
    "run_id prompt_version rubric_version model model_version generation_parameters random_seed "
    "source_snapshot generated_at token_usage estimated_cost".split()
)


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_jsonl(path: Path) -> list[dict]:
    records: list[dict] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except Exception as exc:
            fail(f"{path}:{line_number}: {exc}")
        if not isinstance(value, dict):
            fail(f"{path}:{line_number}: JSONL record must be an object")
        records.append(value)
    return records


def validate_jsonl_schema(schema_path: Path, data_path: Path) -> int:
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    count = 0
    for count, record in enumerate(read_jsonl(data_path), 1):
        errors = sorted(validator.iter_errors(record), key=lambda e: list(e.path))
        if errors:
            error = errors[0]
            location = ".".join(str(p) for p in error.path) or "<root>"
            fail(f"{data_path}:{count}:{location}: {error.message}")
    return count


def verify_manifest(path: Path, base: Path) -> None:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    for item in manifest.get("files", []):
        target = base / item["path"]
        if not target.is_file():
            fail(f"manifest target missing: {target}")
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if digest != item["sha256"]:
            fail(f"manifest hash mismatch: {target}")
        if target.stat().st_size != item["bytes"]:
            fail(f"manifest byte count mismatch: {target}")


for name in REQUIRED_DOCS:
    if not (ROOT / "docs" / name).is_file():
        fail(f"missing docs/{name}")
for name in REQUIRED_RUN:
    if not (RUN / name).is_file():
        fail(f"missing sample run file {name}")

for path in ROOT.rglob("*.json"):
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{path}: {exc}")
for path in ROOT.rglob("*.jsonl"):
    read_jsonl(path)
for path in ROOT.rglob("*.yaml"):
    try:
        yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{path}: {exc}")

ideas = read_jsonl(RUN / "ideas.jsonl")
if len(ideas) < 20:
    fail(f"expected >=20 ideas, got {len(ideas)}")
for index, idea in enumerate(ideas, 1):
    missing = (REQUIRED_IDEA_KEYS | PROVENANCE) - idea.keys()
    if missing:
        fail(f"idea record {index} missing {sorted(missing)}")
    classification = idea.get("classification", {})
    class_missing = {"facts", "estimates", "assumptions", "hypotheses", "unknowns"} - classification.keys()
    if class_missing:
        fail(f"idea {idea.get('idea_id')} incomplete classification: {sorted(class_missing)}")
    if not idea.get("current_alternative"):
        fail(f"idea {idea.get('idea_id')} missing current alternative")
    if not idea.get("validation", {}).get("kill_metric"):
        fail(f"idea {idea.get('idea_id')} missing kill metric")

validation_plans = read_jsonl(RUN / "validation-plans.jsonl")
if len(validation_plans) < 3:
    fail(f"expected >=3 validation plans, got {len(validation_plans)}")
for plan in validation_plans:
    if not 1 <= plan["duration_days"] <= 30:
        fail(f"validation {plan['validation_id']} exceeds 30 days")
    if not plan["success_metric"] or not plan["hold_metric"] or not plan["kill_metric"]:
        fail(f"validation {plan['validation_id']} lacks success/hold/kill thresholds")

evaluations = read_jsonl(RUN / "evaluations.jsonl")
hard_gates = [record for record in evaluations if record.get("record_type") == "hard_gate"]
if len(hard_gates) != len(ideas):
    fail(f"hard-gate records {len(hard_gates)} != ideas {len(ideas)}")
results = {record["overall_result"] for record in hard_gates}
if not {"PASS", "HOLD", "FAIL"}.issubset(results):
    fail(f"sample must demonstrate PASS/HOLD/FAIL, got {results}")

rubric = yaml.safe_load((RUN / "rubric.snapshot.yaml").read_text(encoding="utf-8"))
weights = rubric.get("weights") or rubric.get("criteria") or {}
weight_total = sum(float(value) for value in weights.values())
if round(weight_total, 8) != 100:
    fail(f"rubric weights sum to {weight_total}, not 100")

schema_counts = {
    "ideas": validate_jsonl_schema(ROOT / "schemas" / "idea-card.schema.json", RUN / "ideas.jsonl"),
    "evidence": validate_jsonl_schema(ROOT / "schemas" / "evidence-item.schema.json", RUN / "evidence.jsonl"),
    "validation_plans": validate_jsonl_schema(
        ROOT / "schemas" / "validation-plan.schema.json", RUN / "validation-plans.jsonl"
    ),
}

run_manifest = RUN / "manifest.json"
if run_manifest.exists():
    verify_manifest(run_manifest, RUN)
package_manifest = ROOT / "PACKAGE_MANIFEST.json"
if package_manifest.exists():
    verify_manifest(package_manifest, ROOT)

print(json.dumps({
    "status": "PASS",
    "required_docs": len(REQUIRED_DOCS),
    "sample_ideas": len(ideas),
    "hard_gates": len(hard_gates),
    "validation_plans": len(validation_plans),
    "rubric_weight_total": weight_total,
    "json_schema_records": schema_counts,
    "manifests_verified": {
        "run": run_manifest.exists(),
        "package": package_manifest.exists(),
    },
}, ensure_ascii=False, indent=2))
