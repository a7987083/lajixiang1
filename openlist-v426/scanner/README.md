# OpenList v4.2.6 — Mach-O scanner / IPA 工具箱

## Current state / 当前状态

This stage provides a standalone **read-only** Python scanner and restores the official OpenList-Frontend v4.2.6 Simplified Chinese translation package before building. The IPA toolbox UI preserves English switching and defaults to zh-CN for new browser sessions. The in-page scan API is NOT yet connected.

本阶段提供独立的**只读** Python Mach-O 扫描器；编译时引入官方 v4.2.6 简体中文语言包，新会话默认简体中文，仍可切换英文。目前网页工具箱的“扫描”尚未连接到后端，不应宣称已经能直接在网页扫描云端 IPA。

## Usage / 测试

```bash
python3 scan.py /path/to/test.ipa > scan.json
python3 -m unittest discover -s . -p 'test_*.py' -v
```

No extraction, patching, signing or write-back. Scans Mach-O load commands inside Payload/ and emits JSON with binary paths, architectures, dependent install names and rpaths. Rejects oversized entries, excessive archive records, and malformed command offsets. Errors are included in the JSON.

不会解包修改、打补丁、签名或写回。结果包含 Mach-O 路径、CPU 架构、动态库依赖、rpath；异常载入命令会记录错误。

## Safety and limitations

- Scan assumes a locally accessible IPA file, not an authenticated OpenList cloud object.
- Does NOT resolve actual dyld paths to on-disk dylib existence or cross-architecture matching.
- Nested IPA-in-IPA is not scanned.
- Maximum IPA compressed size is 1 GiB; maximum individual Mach-O uncompressed size 128 MiB; maximum ZIP entries 20,000.
- The UI cannot execute destructive operations, and file download from OpenList remains unimplemented.
- Full server E2E and browser checks have not yet been performed.
