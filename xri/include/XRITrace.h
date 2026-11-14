#pragma once
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif

// P2 read-only tracer. An active inline hook provider with the DobbyHook ABI
// must already be loaded. Never changes Lua arguments, return values or stack.
// start: 1 started, 0 inactive/unavailable, -1 invalid/incompatible target.
// stop: disables recording; already installed inline hooks remain as transparent
// pass-through because removing them without owner coordination is unsafe.
int xri_trace_start(void);
void xri_trace_stop(void);
void xri_trace_clear(void);
// JSON retrieval uses the same size-query convention as xri_snapshot_json.
size_t xri_trace_snapshot_json(char *output, size_t capacity);

#ifdef __cplusplus
}
#endif
