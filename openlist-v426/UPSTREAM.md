# OpenList v4.2.6 pinned baseline

This branch is independent of the existing `main` project. The workflow checks out the exact upstream frontend and backend commits and builds a Linux amd64 binary on Ubuntu 24.04.

- Backend: OpenListTeam/OpenList v4.2.6, `2bdf16d5967d0a403f67d809efd5a418b8f5bd30`
- Frontend: OpenListTeam/OpenList-Frontend v4.2.6, `0725e589bb7f0e734a7446f427eed2175f26c15c`
- Target: Linux x86_64, Ubuntu 24.04
- Output: `openlist-linux-amd64` plus SHA256SUMS
- Status: **upstream baseline only**. The requested IPA context menu, deep dylib removal, Mach-O load-command editing and signing integration have NOT yet been implemented.

Do not replace the production OpenList binary until the baseline and all existing storage drivers are tested. Keep the old binary and entire OpenList data directory/database backed up.

The planned feature layer uses an explicitly authenticated service boundary to IPA Manager. Avoid embedding signing keys or IPA Manager tokens in JavaScript bundles. Opening the IPA action must enforce the same read/write permissions as OpenList file operations; always create `_clean.ipa` rather than overwrite the source.

Do not update the upstream pinned commits without a separate reviewed change.
