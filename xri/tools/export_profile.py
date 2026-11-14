#!/usr/bin/env python3
"""P5/P6 read-only evidence validation and non-executable profile export.

Nothing here may invoke a game method, infer argument ABI or assert causal
resource mutation from trace frequency alone.
"""
import argparse
import json
from decimal import Decimal, InvalidOperation
from pathlib import Path

from analyze_trace import analyze, load_json

def numeric(value):
    if value is None or isinstance(value, bool):
        return None
    try:
        result = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        return None
    return str(result) if result.is_finite() else None

def classify_user_observations(observations):
    result = []
    for row in (observations or []):
        if not isinstance(row, dict):
            continue
        before, after, restarted = (
            numeric(row.get("before")), numeric(row.get("after")),
            numeric(row.get("afterRestart"))
        )
        delta = None
        if before is not None and after is not None:
            delta = str(Decimal(after) - Decimal(before))
        result.append({
            "kind": str(row.get("kind", "other"))[:24],
            "source": "USER_SUPPLIED_MANUAL_OBSERVATION",
            "before": before, "after": after, "afterRestart": restarted,
            "delta": delta,
            "changedAccordingToUser": delta not in (None, "0"),
            "persistenceAccordingToUser": (
                restarted is not None and after is not None and restarted == after
            ),
            "independentlyMeasured": False,
            "serverPersistenceVerified": False,
            "causallyLinkedToCallback": False,
        })
    return result

def build_profile(trace, snapshot=None, observations=None):
    evidence = analyze(trace, snapshot=snapshot, observations=observations)
    manual = classify_user_observations(observations)
    image_uuid_by_name = {}
    for row in evidence["runtime"]["images"]:
        name = Path(row.get("path", "")).name
        if name:
            image_uuid_by_name[name] = row.get("uuid", "")

    profiles = []
    for index, candidate in enumerate(evidence["candidates"]):
        image = Path(candidate.get("ownerImage") or "").name
        methods = candidate.get("nestedManagedMethodCandidates") or []
        profiles.append({
            "id": "candidate-%04d" % (index + 1),
            "runtime": "lua-native-callback",
            "imageName": image,
            "imageUuid": image_uuid_by_name.get(image, ""),
            "imageRelativeOffset": candidate.get("ownerImageOffset", ""),
            "observedNativeCallback": candidate["callback"],
            "methodCandidates": methods,
            "evidence": {
                "positiveNormalizedRateDelta": candidate.get("positiveRateDeltaPer1kReturns", 0),
                "correlation": "manual_window_same_thread_nested",
                "causality": "NOT_ESTABLISHED",
            },
            "verification": {
                "functionSignature": "NOT_VERIFIED",
                "instance": "NOT_VERIFIED",
                "argumentABI": "NOT_VERIFIED",
                "returnABI": "NOT_VERIFIED",
                "resourceValueMutation": "NOT_VERIFIED",
                "persistence": "NOT_VERIFIED",
            },
            "action": {
                "enabled": False,
                "mode": "metadata_only",
                "invocation": None,
                "arguments": [],
            },
        })

    return {
        "schemaVersion": 1,
        "module": "XRIUniversalEvidenceProfile",
        "phase": "P6",
        "mode": "read_only_non_executable",
        "verifiedResourceModifierCount": 0,
        "runtime": evidence["runtime"],
        "P3_6": "PARTIAL_BOUNDARY_TRACE_NOT_FULL_FUNCTION_TRACER",
        "P4": "OBSERVATIONAL_CANDIDATES_ONLY",
        "P5": {
            "status": "MANUAL_EVIDENCE_INGESTION_ONLY",
            "readOnly": True,
            "manualResourceObservations": manual,
            "independentVerification": False,
        },
        "P6": {
            "exportStatus": "CANDIDATES_EXPORTED_NOT_EXECUTABLE",
            "profiles": profiles,
        },
        "warning": (
            "Candidate callbacks are not proven business methods. Never turn "
            "them into executable hooks or patches without target-specific "
            "ABI, actual data-flow and independent device verification."
        ),
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--observations", type=Path,
                        help="JSON array of manual before/after/afterRestart values")
    parser.add_argument("--output", type=Path, default=Path("xri_profile.json"))
    args = parser.parse_args()
    profile = build_profile(
        load_json(args.trace),
        load_json(args.snapshot) if args.snapshot else None,
        load_json(args.observations) if args.observations else None,
    )
    args.output.write_text(json.dumps(profile, ensure_ascii=False, indent=2)+"\n",
                           encoding="utf-8")
    print("Exported %d non-executable candidates to %s" %
          (len(profile["P6"]["profiles"]), args.output))

if __name__ == "__main__":
    main()
