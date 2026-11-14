#!/usr/bin/env python3
"""Synthetic unit fixture only, never real game evidence."""
import unittest
from analyze_trace import analyze

class EvidenceTests(unittest.TestCase):
    def test_empty_trace_not_proof(self):
        report = analyze({"hooks": [], "resourceProbes": [], "bridges": []})
        self.assertFalse(report["nativeCallbackHookInstalled"])
        self.assertEqual(report["P5"], "BLOCKED_UNTIL_VERIFIED_RESOURCE_API_AND_DEVICE_DATA")
        self.assertEqual(report["candidates"], [])

    def test_observation_only_and_normalized(self):
        trace = {
            "hooks": [{"name": "luaD_precall", "installed": True}],
            "resourceProbes": [
                {"kind": "other", "callbackDelta": 20,
                 "callbackCounts": [{"callback": "0xa", "count": 10},
                                    {"callback": "0xb", "count": 10}]},
                {"kind": "energy", "callbackDelta": 40,
                 "callbackCounts": [{"callback": "0xa", "count": 30},
                                    {"callback": "0xb", "count": 10}]},
            ],
            "bridges": [{
                "nativeCallback": "0xa", "namespace": "Example",
                "className": "Test", "methodName": "Method",
            }],
        }
        report = analyze(trace)
        self.assertEqual(report["normalizedComparisonCount"], 1)
        self.assertEqual(report["candidates"][0]["callback"], "0xa")
        self.assertEqual(report["candidates"][0]["causality"], "NOT_ESTABLISHED")
        self.assertEqual(report["candidates"][0]["nestedManagedMethodCandidates"][0]["method"],
                         "Example.Test.Method")
        self.assertFalse(report["resourceWindows"][1]["resourceValueVerified"])

    def test_overflow_rejects_comparison(self):
        trace = {"resourceProbes": [
            {"kind": "other", "callbackCounts": [{"callback": "0xa", "count": 2}]},
            {"kind": "gold", "callbackCounts": [{"callback": "0xa", "count": 3}],
             "callbackAggregationOverflow": 1},
        ]}
        report = analyze(trace)
        self.assertFalse(report["resourceWindows"][1]["comparisonReady"])
        self.assertEqual(report["candidates"], [])

if __name__ == "__main__":
    unittest.main()
