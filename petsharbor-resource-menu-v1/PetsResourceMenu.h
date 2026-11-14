#pragma once
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
int PetsResourceRequest(int resource_id, int amount);
void PetsResourceStatus(char *out, size_t cap);
#ifdef __cplusplus
}
#endif
