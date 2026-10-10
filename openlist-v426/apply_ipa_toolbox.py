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
data["preview"]["names"]["ipa_toolbox"]  = "IPA Toolbox"
data["preview"]["ipa_toolbox_unavailable"] = "Mach-O scan service is not connected yet."
data["preview"]["ipa_scan"] = "Scan IPA (read-only)"
data["preview"]["ipa_scanning"] = "Scanning…"
data["preview"]["ipa_macho_count"] = "Mach-O files"
data["preview"]["ipa_toolbox_later"] = "Removal, signing and upload are not yet enabled."
names.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
zh_home = root / "src/lang/zh-CN/home.json"
zh_index = root / "src/lang/zh-CN/index.json"
if not zh_home.exists() or not zh_index.exists():
    raise SystemExit("Official v4.2.6 zh-CN translation is missing")
zh = json.loads(zh_home.read_text())
zh.setdefault("preview", {}).setdefault("names", {})["ipa_toolbox"]  = "IPA 工具箱"
zh["preview"]["ipa_toolbox_unavailable"] = "Mach-O 扫描服务尚未连接。"
zh["preview"]["ipa_scan"] = "扫描 IPA（只读）"
zh["preview"]["ipa_scanning"] = "正在扫描…"
zh["preview"]["ipa_macho_count"] = "Mach-O 文件数"
zh["preview"]["ipa_toolbox_later"] = "动态库移除、签名和写回尚未开放。"
zh_home.write_text(json.dumps(zh, ensure_ascii=False, indent=2) + "\n")

component = root / "src/pages/home/previews/ipa-toolbox.tsx"
if component.exists():
    raise SystemExit("IPA toolbox already exists")
component.write_text('''import { Button, Heading, Text, VStack, Alert, AlertIcon } from "@hope-ui/solid"
import { createSignal, For, Show } from "solid-js"
import { FileInfo } from "./info"
import { useT, useLink } from "~/hooks"
import { objStore } from "~/store"

type Dylib = {type: string; name: string}
type Arch = {arch: string; dependencies: Dylib[]; rpaths: string[]; id?: string | null}
type FileScan = {path: string; architectures: Arch[]}
type Scan = {mode: string; mach_o_count: number; files: FileScan[]; errors: {path: string; error: string}[]}
const IpaToolbox = () => {
  const t = useT()
  const { currentObjLink } = useLink()
  const [loading, setLoading] = createSignal(false)
  const [error, setError] = createSignal("")
  const [result, setResult] = createSignal<Scan | null>(null)
  const scan = async () => {
    if (loading()) return
    setLoading(true);setError("");setResult(null)
    try {
      if (objStore.obj.size > 128 * 1024 * 1024) throw new Error("IPA exceeds 128 MiB scan limit")
      const link = currentObjLink()
      const source = new URL(link, location.href)
      if (source.origin !== location.origin) throw new Error("IPA download is cross-origin; proxy through OpenList first")
      const downloaded = await fetch(source.href, { credentials: "same-origin" })
      if (!downloaded.ok) throw new Error("IPA download failed: " + downloaded.status)
      const ipa = await downloaded.blob()
      if (ipa.size > 128 * 1024 * 1024) throw new Error("IPA exceeds 128 MiB scan limit")
      const response = await fetch("/ipa-tools/scan", {method:"POST",headers:{"Content-Type":"application/octet-stream"},body:ipa,credentials:"same-origin"})
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || "Scan failed: " + response.status)
      setResult(data as Scan)
    } catch (e) { setError(e instanceof Error ? e.message : String(e)) }
    finally {setLoading(false)}
  }
  return (<FileInfo>
    <VStack spacing="$3" px="$4" w="$full">
      <Heading size="md">{t("home.preview.names.ipa_toolbox")}</Heading>
      <Button onClick={scan} disabled={loading()}>{loading() ? t("home.preview.ipa_scanning") : t("home.preview.ipa_scan")}</Button>
      <Show when={error()}><Alert status="error"><AlertIcon />{error()}</Alert></Show>
      <Show when={result()}>
        <Text>{t("home.preview.ipa_macho_count")}: {result()!.mach_o_count}</Text>
        <For each={result()!.files}>{(file) => <VStack spacing="$1" w="$full">
          <Text fontWeight="bold" style={{"overflow-wrap":"anywhere"}}>{file.path}</Text>
          <For each={file.architectures}>{(arch) => <VStack spacing="$1" w="$full">
            <Text>{arch.arch} · {arch.dependencies.length} dependencies</Text>
            <For each={arch.dependencies}>{(dep) => <Text fontSize="sm" style={{"overflow-wrap":"anywhere"}}>{dep.type}: {dep.name}</Text>}</For>
            <For each={arch.rpaths}>{(p) => <Text fontSize="sm">LC_RPATH: {p}</Text>}</For>
          </VStack>}</For>
        </VStack>}</For>
        <For each={result()!.errors}>{(e) => <Text color="red">{e.path}: {e.error}</Text>}</For>
      </Show>
      <Text fontSize="sm">{t("home.preview.ipa_toolbox_later")}</Text>
    </VStack>
  </FileInfo>)
}
export default IpaToolbox''')
# Keep the official locale selector and English fallback; change only first-run default.
i18n_path = root / "src/app/i18n.ts"
i18n_src = i18n_path.read_text()
default_line = 'export let initialLang = localStorage.getItem("lang") ?? defaultLang'
if i18n_src.count(default_line) != 1:
    raise SystemExit("Locale initialLang anchor changed")
i18n_src = i18n_src.replace(default_line, 'export let initialLang = localStorage.getItem("lang") ?? (languages.some((lang) => lang.code === "zh-CN") ? "zh-CN" : defaultLang)')
i18n_path.write_text(i18n_src)
print("IPA preview localized; official selector retained; zh-CN first-run default")
