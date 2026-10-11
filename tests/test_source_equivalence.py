#!/usr/bin/env python3
"""Check extraction preserved the Screen implementation against the stable baseline."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
base=subprocess.check_output(["git","show","d265c98942454587e4cd42deec929f5c6fa7af10:ios-ui/main.m"],cwd=root).decode()
def expand(source):
    for name in ("TSComponents.inc","TSSearch.inc","TSPages.inc"):
        marker='#include "'+name+'"\n'
        assert source.count(marker)==1,name
        source=source.replace(marker,(root/"ios-ui"/name).read_text())
    return source
old=expand(base)
new=expand((root/"ios-ui/TrollSkinUI.m").read_text())
start_old=old.index("- (void)demo ")
end_old=old.index("\n@end\n@interface SkinDelegate",start_old)
start_new=new.index("- (void)demo ")
end_new=new.index("\n@end\n",start_new)
original=old[start_old:end_old]
refactored=new[start_new:end_new].replace("[TSSkinScreen new]","[Screen new]")
assert original==refactored,"Screen implementation changed relative to stable baseline"
main=(root/"ios-ui/main.m").read_text()
header=(root/"ios-ui/TrollSkinUI.h").read_text()
assert "UIApplicationMain" not in new
assert "UIApplicationMain" in main
assert "[TrollSkinUI createRootViewController]" in main
assert "+ (UIViewController *)createRootViewController" in header
assert "self.scroll.contentInset=UIEdgeInsetsMake(0,0,100,0)" in new
print("PASS: original Screen method bodies preserved; demo entry isolated; public factory present")
