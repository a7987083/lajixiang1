#pragma once
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
// Internal activation, invoked only after the Dobby Hook passes verification.
void TaylorResourceMenuActivate(void);
int TaylorResourceRequest(int resource_id, int amount);
void TaylorResourceStatus(char *out, size_t cap);
#ifdef __cplusplus
}
#endif
