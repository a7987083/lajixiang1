#include "XRITrace.h"
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <atomic>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

namespace {
using LuaState = void;
using DobbyHookFn = int (*)(void *, void *, void **);
using NewStateFn = LuaState *(*)(void);
using CloseFn = void (*)(LuaState *);
using XLuaLoadFn = int (*)(LuaState *, const char *, int, const char *);
using LuaLoadFn = int (*)(LuaState *, const char *, size_t, const char *, const char *);

struct StateEvent {
    uintptr_t value;
    std::string action;
    uint64_t sequence;
};
struct ChunkEvent {
    uintptr_t state;
    std::string source;
    std::string name;
    uint64_t size;
    uint64_t digest;
    int result;
    uint64_t sequence;
    bool hashTruncated;
};
struct HookEntry {
    const char *name;
    void *address;
    bool installed;
    int error;
};
constexpr size_t kMaxChunks = 256;
constexpr size_t kMaxStates = 128;
constexpr size_t kMaxHashBytes = 1024 * 1024;
std::mutex g_mu;
std::atomic<bool> g_active{false};
std::atomic<bool> g_installed{false};
std::atomic<uint64_t> g_seq{0};
std::vector<StateEvent> g_states;
std::vector<ChunkEvent> g_chunks;
std::vector<HookEntry> g_hooks;
std::string g_reason = "not started";
thread_local unsigned g_loadingDepth = 0;

NewStateFn origNewState = nullptr;
CloseFn origClose = nullptr;
XLuaLoadFn origXLuaLoad = nullptr;
LuaLoadFn origLuaLoad = nullptr;

uint64_t hashPrefix(const char *data, size_t length) {
    uint64_t value = UINT64_C(14695981039346656037);
    const size_t n = length < kMaxHashBytes ? length : kMaxHashBytes;
    for (size_t i = 0; i < n; ++i) {
        value ^= static_cast<unsigned char>(data[i]);
        value *= UINT64_C(1099511628211);
    }
    return value;
}

std::string escape(const std::string &input) {
    static const char h[] = "0123456789ABCDEF";
    std::string s;
    for (unsigned char c : input) {
        if (c == '"') s += "\\\"";
        else if (c == '\\') s += "\\\\";
        else if (c < 0x20) {
            s += "\\u00"; s += h[c >> 4]; s += h[c & 15];
        } else s += static_cast<char>(c);
    }
    return s;
}
std::string hex(uintptr_t value) {
    char out[32];
    std::snprintf(out, sizeof(out), "0x%llx", (unsigned long long)value);
    return out;
}
std::string digestHex(uint64_t value) {
    char out[17];
    std::snprintf(out, sizeof(out), "%016llx", (unsigned long long)value);
    return out;
}
void recordState(LuaState *state, const char *action) {
    if (!g_active.load(std::memory_order_relaxed) || !state) return;
    std::lock_guard<std::mutex> lock(g_mu);
    if (g_states.size() >= kMaxStates) g_states.erase(g_states.begin());
    g_states.push_back({reinterpret_cast<uintptr_t>(state), action, ++g_seq});
}
void recordChunk(LuaState *state, size_t size, uint64_t digest,
                 const char *name, int status, const char *api) {
    if (!g_active.load(std::memory_order_relaxed) || !state) return;
    // Bytes are hashed before invoking the original Lua loader; no buffer is retained.
    std::string chunkName = name ? std::string(name, strnlen(name, 512)) : "(unnamed)";
    std::lock_guard<std::mutex> lock(g_mu);
    if (g_chunks.size() >= kMaxChunks) g_chunks.erase(g_chunks.begin());
    g_chunks.push_back({reinterpret_cast<uintptr_t>(state), api, chunkName,
                        static_cast<uint64_t>(size), digest, status, ++g_seq,
                        size > kMaxHashBytes});
}

LuaState *newStateHook() {
    LuaState *L = origNewState ? origNewState() : nullptr;
    recordState(L, "created");
    return L;
}
void closeHook(LuaState *L) {
    // Record before close so an identical pointer reused later is distinguishable.
    recordState(L, "closing");
    if (origClose) origClose(L);
}
int xluaLoadHook(LuaState *L, const char *b, int sz, const char *n) {
    ++g_loadingDepth;
    const uint64_t digest = g_loadingDepth == 1 && b && sz > 0 ? hashPrefix(b, static_cast<size_t>(sz)) : 0;
    int result = origXLuaLoad ? origXLuaLoad(L, b, sz, n) : -1;
    if (g_loadingDepth == 1 && sz >= 0)
        recordChunk(L, static_cast<size_t>(sz), digest, n, result, "xluaL_loadbuffer");
    --g_loadingDepth;
    return result;
}
int luaLoadHook(LuaState *L, const char *b, size_t sz, const char *n, const char *mode) {
    ++g_loadingDepth;
    const uint64_t digest = g_loadingDepth == 1 && b && sz > 0 ? hashPrefix(b, sz) : 0;
    int result = origLuaLoad ? origLuaLoad(L, b, sz, n, mode) : -1;
    if (g_loadingDepth == 1)
        recordChunk(L, sz, digest, n, result, "luaL_loadbufferx");
    --g_loadingDepth;
    return result;
}

// Only resolve exact exports in their owning loaded image, never inferred offsets.
// A hook is never installed unless the original trampoline is provided.
void *resolve(const char *name) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; ++i) {
        const char *path = _dyld_get_image_name(i);
        const mach_header *mh = _dyld_get_image_header(i);
        if (!path || !mh || (!std::strstr(path,"UnityFramework") &&
            !std::strstr(path,"xlua") && !std::strstr(path,"XLua") &&
            !std::strstr(path,"liblua") && !std::strstr(path,"Lua"))) continue;
        void *handle = dlopen(path, RTLD_NOW | RTLD_NOLOAD);
        if (!handle) continue;
        void *value = dlsym(handle, name);
        Dl_info info = {};
        bool owned = value && dladdr(value, &info) && info.dli_fbase == mh;
        dlclose(handle);
        if (owned) return value;
    }
    return nullptr;
}
std::string jsonSnapshot() {
    std::lock_guard<std::mutex> lock(g_mu);
    std::string result = R"({"schemaVersion":1,"module":"XRITrace","mode":"read-only",)";
    result += "\"recording\":" + std::string(g_active ? "true" : "false");
    result += ",\"hooksInstalled\":" + std::string(g_installed ? "true" : "false");
    result += ",\"reason\":\"" + escape(g_reason) + "\",\"hooks\":[";
    for (size_t i=0; i<g_hooks.size(); ++i) {
        if (i) result += ",";
        const auto &h=g_hooks[i];
        result += "{\"name\":\"" + std::string(h.name) + "\",\"installed\":" +
                  (h.installed ? "true" : "false") + ",\"error\":" + std::to_string(h.error) + "}";
    }
    result += "],\"states\":[";
    for (size_t i=0; i<g_states.size(); ++i) {
        if (i) result += ",";
        const auto &e=g_states[i];
        result += "{\"state\":\"" + hex(e.value) + "\",\"action\":\"" + e.action +
                  "\",\"sequence\":" + std::to_string(e.sequence) + "}";
    }
    result += "],\"chunks\":[";
    for (size_t i=0; i<g_chunks.size(); ++i) {
        if (i) result += ",";
        const auto &e=g_chunks[i];
        result += "{\"state\":\"" + hex(e.state) + "\",\"source\":\"" + e.source +
                  "\",\"name\":\"" + escape(e.name) + "\",\"size\":" +
                  std::to_string(e.size) + ",\"prefixFNV64\":\"" +
                  digestHex(e.digest) + "\",\"hashTruncated\":" +
                  (e.hashTruncated?"true":"false") + ",\"result\":" +
                  std::to_string(e.result) + ",\"sequence\":" +
                  std::to_string(e.sequence) + "}";
    }
    result += "]}";
    return result;
}
} // namespace

extern "C" __attribute__((visibility("default"))) int xri_trace_start(void) {
    std::lock_guard<std::mutex> lock(g_mu);
    if (g_installed) {
        g_active = true;
        g_reason = "recording";
        return 1;
    }
    // Optional inline-hook provider. No new library is loaded by this path.
    auto hook = reinterpret_cast<DobbyHookFn>(dlsym(RTLD_DEFAULT, "DobbyHook"));
    if (!hook) {
        g_reason = "DobbyHook provider not loaded; active capture unavailable";
        return 0;
    }
    struct Target {const char *name; void *replacement; void **original;};
    const Target targets[] = {
        {"luaL_newstate", reinterpret_cast<void *>(&newStateHook),
         reinterpret_cast<void **>(&origNewState)},
        {"lua_close", reinterpret_cast<void *>(&closeHook),
         reinterpret_cast<void **>(&origClose)},
        {"xluaL_loadbuffer", reinterpret_cast<void *>(&xluaLoadHook),
         reinterpret_cast<void **>(&origXLuaLoad)},
        {"luaL_loadbufferx", reinterpret_cast<void *>(&luaLoadHook),
         reinterpret_cast<void **>(&origLuaLoad)}
    };
    int installed = 0;
    for (const auto &t : targets) {
        void *addr = resolve(t.name);
        if (!addr) { g_hooks.push_back({t.name, nullptr, false, -2}); continue; }
        int error = hook(addr, t.replacement, t.original);
        bool ok = error == 0 && *t.original != nullptr;
        g_hooks.push_back({t.name, addr, ok, error});
        if (ok) ++installed;
        // We cannot safely revert unknown provider's partial hooks. Stop adding hooks
        // if it returns success without a valid original trampoline.
        if (error == 0 && !*t.original) {
            g_reason = "hook provider returned no original trampoline";
            return -1;
        }
    }
    g_installed = installed != 0;
    g_active = installed != 0;
    g_reason = installed ? "recording; pre-existing Lua states may be unobserved"
                         : "no supported exported hook target";
    return installed ? 1 : 0;
}
extern "C" __attribute__((visibility("default"))) void xri_trace_stop(void) {
    g_active = false;
    std::lock_guard<std::mutex> lock(g_mu);
    g_reason = "paused; installed hooks remain pass-through";
}
extern "C" __attribute__((visibility("default"))) void xri_trace_clear(void) {
    std::lock_guard<std::mutex> lock(g_mu);
    g_chunks.clear();
    g_states.clear();
}
extern "C" __attribute__((visibility("default")))
size_t xri_trace_snapshot_json(char *output, size_t capacity) {
    const std::string s = jsonSnapshot();
    size_t n = s.size() + 1;
    if (output && capacity >= n) std::memcpy(output, s.c_str(), n);
    return n;
}
