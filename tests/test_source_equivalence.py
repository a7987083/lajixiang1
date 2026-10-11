#!/usr/bin/env python3
"""Source-preservation regression: included component bodies must match stable baseline."""
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[1]
base = subprocess.check_output(
    ["git", "show", "d265c98942454587e4cd42deec929f5c6fa7af10:ios-ui/main.m"],
    cwd=root,
).decode("utf-8")
main = (root / "ios-ui/main.m").read_text()
for name in ("TSComponents.inc", "TSSearch.inc", "TSPages.inc"):
    marker = '#include "' + name + '"\n'
    assert main.count(marker) == 1, "Missing or duplicate component include: " + name
    main = main.replace(marker, (root / "ios-ui" / name).read_text())
if main != base:
    import difflib
    print("Behavior-preserving source equivalence FAILED")
    print("".join(difflib.unified_diff(base.splitlines(True),main.splitlines(True),fromfile="baseline",tofile="refactored"))[:6000])
    sys.exit(1)
assert "self.scroll.contentInset=UIEdgeInsetsMake(0,0,100,0)" in main
assert "searchBarSearchButtonClicked:" in main
assert "self.tab==3" in main
assert "self.dock=bar;" in main
print("PASS: expanded source is byte-for-byte identical to pre-refactor baseline; key UI contracts present")
