#!/usr/bin/env python3
"""Apply a minimal IPA preview extension to pinned OpenList-Frontend v4.2.6."""
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
index = root / "src/pages/home/previews/index.ts"
if not index.exists():
    raise SystemExit("Cannot locate upstream IPA preview registry")
source = index.read_text()
needle = '''  {
    key: "ipa",
    exts: ["ipa", "tipa"],
    component: lazy(() => import("./ipa")),
    prior: true,
  },'''
addition = needle + '''
  {
    key: "ipa_toolbox",
    exts: ["ipa"],
    component: lazy(() => import("./ipa-toolbox")),
    prior: true,
    availableInArchive: false,
  },'''
if source.count(needle) != 1:
    raise SystemExit("IPA preview anchor has changed; review upstream changes")
index.write_text(source.replace(needle, addition))
names = root / "src/lang/en/home.json"
import json
data = json.loads(names.read_text())
if "preview" not in data or "names" not in data["preview"]:
    raise SystemExit("Cannot locate upstream i18n preview names")
data["preview"]["names"]["ipa_toolbox"] = "IPA Toolbox"
names.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
zh_home = root / "src/lang/zh-CN/home.json"
zh_index = root / "src/lang/zh-CN/index.json"
if not zh_home.exists() or not zh_index.exists():
    raise SystemExit("Official v4.2.6 zh-CN translation is missing")
zh = json.loads(zh_home.read_text())
zh.setdefault("preview", {}).setdefault("names", {})["ipa_toolbox"] = "IPA 工具箱"
zh_home.write_text(json.dumps(zh, ensure_ascii=False, indent=2) + "\\n")

component = root / "src/pages/home/previews/ipa-toolbox.tsx"
if component.exists():
    raise SystemExit("IPA toolbox already exists")
component.write_text('''import { Heading, Text, VStack, Alert, AlertIcon } from "@hope-ui/solid"
import { FileInfo } from "./info"

/**
 * Read-only placeholder. No direct fetch of OpenList raw_url, no browser-held
 * signing tokens, no unauthenticated writes. Backend API comes in a later PR.
 */
const IpaToolbox = () => (
  <FileInfo>
    <VStack spacing="$3" px="$4" w="$full">
      <Heading size="md">IPA 工具箱</Heading>
      <Alert status="info">
        <AlertIcon />
        动态库扫描接口尚未接入，当前仅展示入口。
      </Alert>
      <Text fontSize="sm">完整移除、Ad-hoc 签名和写回操作尚未开放。</Text>
    </VStack>
  </FileInfo>
)

export default IpaToolbox
''')
print("IPA preview entry added; destructive actions remain disabled")
