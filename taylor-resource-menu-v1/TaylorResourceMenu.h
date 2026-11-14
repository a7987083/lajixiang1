#pragma once
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
int TaylorResourceRequest(int resource_id, int amount);
void TaylorResourceStatus(char *out, size_t cap);
#ifdef __cplusplus
}
#endif
