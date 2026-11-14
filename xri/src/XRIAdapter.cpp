#include "XRIAdapter.h"
#include <cstdint>
#include <cstring>
#include <dlfcn.h>
#include <mach-o/loader.h>
namespace {
// Exact target ABI only: Taylor Secret 1.8.9 UUID CC89F3E2-E288-3FBF-AB96-1FD4E58F047A.
bool verifiedTaylorPrecall(void *address) {
    Dl_info info={};
    if (!address || !dladdr(address,&info) || !info.dli_fbase || !info.dli_fname ||
        !std::strstr(info.dli_fname,"/UnityFramework.framework/UnityFramework")) return false;
    const auto *h = reinterpret_cast<const mach_header_64 *>(info.dli_fbase);
    if(h->magic != MH_MAGIC_64 || h->ncmds > 1024) return false;
    const uint8_t expected[16]={0xCC,0x89,0xF3,0xE2,0xE2,0x88,0x3F,0xBF,
                                0xAB,0x96,0x1F,0xD4,0xE5,0x8F,0x04,0x7A};
    const auto *p=reinterpret_cast<const uint8_t *>(h+1);
    bool match=false;
    for(uint32_t i=0;i<h->ncmds;++i){
        const auto *lc=reinterpret_cast<const load_command *>(p);
        if(lc->cmdsize<sizeof(load_command)||lc->cmdsize>65536)return false;
        if(lc->cmd==LC_UUID && lc->cmdsize>=sizeof(uuid_command)){
            match=std::memcmp(reinterpret_cast<const uuid_command *>(p)->uuid,expected,16)==0;
            break;
        }
        p+=lc->cmdsize;
    }
    if(!match || reinterpret_cast<uintptr_t>(address)-reinterpret_cast<uintptr_t>(h)
           != UINT64_C(0x032534D8)) return false;
    uint32_t opcode=0;
    std::memcpy(&opcode,reinterpret_cast<const uint8_t *>(h)+UINT64_C(0x032537AC),4);
    return opcode==UINT32_C(0xD63F02E0);
}

}
const char *xri_internal_adapter_for_precall(void *address) {
    // Extend only with independently verified exact binary adapters.
    return verifiedTaylorPrecall(address) ? "taylorsecret-xlua-1.8.9" : nullptr;
}
