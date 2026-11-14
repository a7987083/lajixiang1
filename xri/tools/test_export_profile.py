import unittest
from export_profile import build_profile, classify_user_observations

class ProfileTests(unittest.TestCase):
    def test_no_candidates_is_non_executable(self):
        result = build_profile({"hooks":[],"resourceProbes":[],"bridges":[]})
        self.assertEqual(result["verifiedResourceModifierCount"], 0)
        self.assertEqual(result["P6"]["profiles"], [])
        self.assertEqual(result["mode"], "read_only_non_executable")

    def test_manual_values_never_independently_verified(self):
        result = classify_user_observations([
            {"kind":"energy","before":10,"after":9,"afterRestart":9}])[0]
        self.assertEqual(result["delta"], "-1")
        self.assertTrue(result["persistenceAccordingToUser"])
        self.assertFalse(result["causallyLinkedToCallback"])
        self.assertFalse(result["serverPersistenceVerified"])

    def test_non_numeric_is_not_accepted_as_value(self):
        result = classify_user_observations([
            {"kind":"gold","before":"NaN","after":"100"}])[0]
        self.assertIsNone(result["delta"])

    def test_candidate_disables_invocation(self):
        trace = {
            "internalVmAdapter":"export-api-only",
            "hooks":[{"name":"luaD_precall","installed":False}],
            "resourceProbes":[
                {"kind":"other","callbackCounts":[
                    {"callback":"0xabc","count":2},{"callback":"0xdef","count":8}]},
                {"kind":"custom_reward","callbackCounts":[
                    {"callback":"0xabc","count":8},{"callback":"0xdef","count":2}]}
            ],
            "cFunctionExecutions":[{"callback":"0xabc",
                "ownerImage":"/X/UnityFramework.framework/UnityFramework",
                "ownerImageOffset":"0x1234"}],
            "bridges":[{"nativeCallback":"0xabc","className":"SomeClass",
                "namespace":"Game","methodName":"Unknown"}]
        }
        p = build_profile(trace)
        self.assertEqual(p["P6"]["profiles"][0]["imageRelativeOffset"],"0x1234")
        self.assertEqual(p["P6"]["profiles"][0]["methodCandidates"][0]["method"],
                         "Game.SomeClass.Unknown")
        self.assertFalse(p["P6"]["profiles"][0]["action"]["enabled"])
        self.assertEqual(p["P6"]["profiles"][0]["verification"]["argumentABI"],
                         "NOT_VERIFIED")

if __name__ == "__main__":
    unittest.main()
