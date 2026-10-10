# OpenList IPA Bridge V1

This is a standalone, non-invasive, **read-only** integration with the installed official OpenList v4.2.6 and IPA Manager v0.2. It does not change the OpenList binary, database, or configuration.

Endpoints: `POST /bridge/list` to browse IPA filenames, `POST /bridge/inspect` to copy an IPA from an approved HTTPS OpenList raw-download host into IPA Manager's temporary inspection job. Requests use an independent `X-Bridge-Token` credential.

Required variables: `OPENLIST_URL`, `OPENLIST_TOKEN` (dedicated read-only API credential), `BRIDGE_TOKEN`, `IPA_MANAGER_URL`, `IPA_TOKEN`, `DOWNLOAD_HOSTS` (explicit HTTPS download host allowlist). Run the service on loopback only behind admin authentication.

Known limitations: the inspection endpoint buffers input in memory, maximum 1GiB; remote storage and the end-to-end service have NOT been validated. Deep removal and writing output back to OpenList are disabled until individual Mach-O dependency validation is implemented. Prefer more restrictive 100MiB input operational limits and a private environment for this prototype.

A local source ZIP with implementation and Python syntax verification is available from the project conversation. The source will be promoted into the GitHub repository after integration security review.
