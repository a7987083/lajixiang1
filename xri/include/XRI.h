#pragma once
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif

// ABI v1. Read-only; no Lua stack manipulation, patching, or hooks.
// Returns required bytes including trailing NUL. If capacity is too small,
// output is not written. Passing (NULL, 0) queries the required size.
size_t xri_snapshot_json(char *output, size_t capacity);

// Stable version identifier for consumers of the exported ABI.
const char *xri_version(void);

#ifdef __cplusplus
}
#endif
