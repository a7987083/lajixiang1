#pragma once
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif

// P2 read-only tracer. An active inline hook provider with the DobbyHook ABI is linked
// into the official CI artifact. Other builds may use an existing provider. Never changes Lua arguments, return values or stack.
// start: 1 started, 0 inactive/unavailable, -1 invalid/incompatible target.
// stop: disables recording; already installed inline hooks remain as transparent
// pass-through because removing them without owner coordination is unsafe.
int xri_trace_start(void);
void xri_trace_stop(void);
void xri_trace_clear(void);
// P2.5 manually brackets a game operation. This records correlated Lua/IL2CPP
// events and counters; it does NOT read or assert currency/resource values.
// kind: "diamond", "gold", "energy", "other". 1 = success, 0 = inactive,
// -1 = invalid kind / no active probe / an existing probe is in progress.
int xri_resource_probe_begin(const char *kind);
int xri_resource_probe_end(void);
// JSON retrieval uses the same size-query convention as xri_snapshot_json.
size_t xri_trace_snapshot_json(char *output, size_t capacity);

#ifdef __cplusplus
}
#endif
