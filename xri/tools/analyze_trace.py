#!/usr/bin/env python3
"""XRI evidence report: read-only observations, never a resource mutation claim."""
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def integer(value):
    try:
        return int(value)
    except (ValueError, TypeError):
        return 0

def analyze(trace, snapshot=None, observations=None):
    hooks = {h.get("name"): h for h in trace.get("hooks", [])}
    c_hook = bool(hooks.get("luaD_precall", {}).get("installed"))
    executions = trace.get("cFunctionExecutions", [])
    registrations = {x.get("callback"): x for x in trace.get("cFunctionRegistrations", [])}
    bridges = trace.get("bridges", [])
    samples = trace.get("resourceProbes", [])
    callback_methods = defaultdict(Counter)
    for event in bridges:
        callback = event.get("nativeCallback")
        if callback in (None, "", "0x0"):
            continue
        name = ".".join(filter(None, (event.get("namespace"), event.get("className"),
                                      event.get("methodName"))))
        if name:
            callback_methods[callback][name] += 1

    sample_summary = []
    last_control = None
    last_control_overflow = False
    callback_scores = Counter()
    normalized_comparison_count = 0
    for probe in samples:
        current = {x.get("callback"): integer(x.get("count")) for x in probe.get("callbackCounts", [])
                   if x.get("callback")}
        entry = {
            "kind": probe.get("kind"),
            "startSequence": probe.get("startSequence"),
            "status": probe.get("status", "unknown"),
            "callbackDelta": integer(probe.get("callbackDelta")),
            "callbackAggregationOverflow": integer(probe.get("callbackAggregationOverflow")),
            "distinctCallbackCount": len(current),
            "controlAvailable": last_control is not None,
            "callbackPositiveDeltas": [],
            "resourceValueVerified": False,
        }
        if probe.get("kind") == "other":
            last_control = current
            last_control_overflow = bool(entry["callbackAggregationOverflow"])
        elif last_control is not None:
            # Counts are observational; compare with a manually marked control.
            control_total = sum(last_control.values())
            target_total = sum(current.values())
            entry["comparisonReady"] = bool(control_total and target_total and
                                            not entry["callbackAggregationOverflow"] and
                                            not last_control_overflow)
            if entry["comparisonReady"]:
                normalized_comparison_count += 1
                for key in sorted(set(current) | set(last_control)):
                    control_rate = 1000.0 * last_control.get(key, 0) / control_total
                    target_rate = 1000.0 * current.get(key, 0) / target_total
                    delta_rate = round(target_rate - control_rate, 5)
                    if delta_rate > 0:
                        entry["callbackPositiveDeltas"].append({
                            "callback": key, "deltaRatePer1kReturns": delta_rate,
                            "controlCount": last_control.get(key, 0),
                            "targetCount": current.get(key, 0),
                        })
                        callback_scores[key] += delta_rate
            entry["callbackPositiveDeltas"].sort(key=lambda x: -x["deltaRatePer1kReturns"])
        sample_summary.append(entry)

    candidates = []
    for cb, score in callback_scores.most_common():
        registration = registrations.get(cb, {})
        observed = next((x for x in reversed(executions) if x.get("callback") == cb), {})
        candidates.append({
            "callback": cb,
            "positiveRateDeltaPer1kReturns": round(score, 5),
            "registeredInRetainedBuffer": bool(registration),
            "ownerImage": observed.get("ownerImage", registration.get("ownerImage", "")),
            "ownerImageOffset": observed.get("ownerImageOffset", registration.get("ownerImageOffset", "")),
            "nestedManagedMethodCandidates": [
                {"method": name, "observedNestedCalls": count}
                for name, count in callback_methods.get(cb, Counter()).most_common(12)
            ],
            "causality": "NOT_ESTABLISHED",
            "resourceMutationEvidence": "NOT_VERIFIED",
        })

    images = []
    if snapshot:
        images = [
            {"path": im.get("path", ""), "uuid": str(im.get("uuid", "")).upper()}
            for im in snapshot.get("images", [])
            if isinstance(im, dict)
        ]
    adapter = trace.get("internalVmAdapter", "unreported")
    user_observations = []
    if observations:
        for ob in observations:
            user_observations.append({
                "kind": ob.get("kind", "unknown"),
                "before": ob.get("before"),
                "after": ob.get("after"),
                "afterRestart": ob.get("afterRestart"),
                "evidenceLevel": "USER_REPORTED_NOT_INDEPENDENTLY_VERIFIED",
            })

    return {
        "reportVersion": 1,
        "runtime": {
            "adapter": adapter,
            "images": images,
            "imageMetadataProvided": snapshot is not None,
            "abiSafety": "EXACT_ADAPTER_ONLY" if adapter not in ("unreported", "export-api-only")
                         else "EXPORTED_API_ONLY",
        },
        "nativeCallbackHookInstalled": c_hook,
        "nativeCallbacksReturnedTotal": integer(trace.get("cFunctionExecutionStats", {}).get("total")),
        "nativeCallbackEventsRetained": len(executions),
        "resourceWindows": sample_summary,
        "normalizedComparisonCount": normalized_comparison_count,
        "candidates": candidates,
        "userObservations": user_observations,
        "readOnly": True,
        "evidenceBoundary": (
            "Registration, normal callback return, nested invocation and manual-window "
            "correlation are observations only. No resource values, arguments, causal "
            "effects or server persistence are established by this trace."
        ),
        "P3_3": "OBSERVED_HOOK_INSTALLED_NOT_FUNCTION_COMPLETE" if c_hook else "INTERNAL_HOOK_UNAVAILABLE",
        "P3_4": "CANDIDATE_CORRELATION_ONLY",
        "P4": "RESOURCE_VALUES_NOT_INSTRUMENTED",
        "P5": "BLOCKED_UNTIL_VERIFIED_RESOURCE_API_AND_DEVICE_DATA",
    }

def main():
    parser = argparse.ArgumentParser(description="Analyze real XRI trace.json without claiming mutation")
    parser.add_argument("trace", type=Path)
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--observations", type=Path,
                        help="Optional user-entered values; always labeled unverified")
    parser.add_argument("--output", type=Path, default=Path("xri_evidence.json"))
    args = parser.parse_args()
    trace = load_json(args.trace)
    snapshot = load_json(args.snapshot) if args.snapshot else None
    observations = load_json(args.observations) if args.observations else None
    report = analyze(trace, snapshot, observations)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print(f"Saved {args.output}: {len(report['candidates'])} observational candidates")

if __name__ == "__main__":
    main()
