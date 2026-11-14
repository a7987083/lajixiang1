#include "XRITrace.h"
#include <dlfcn.h>
#include <dispatch/dispatch.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach_time.h>
#include <pthread.h>
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
#ifdef XRI_BUNDLED_DOBBY
extern "C" int DobbyHook(void *, void *, void **);
#endif
using NewStateFn = LuaState *(*)(void);
using CloseFn = void (*)(LuaState *);
using XLuaLoadFn = int (*)(LuaState *, const char *, int, const char *);
using LuaLoadFn = int (*)(LuaState *, const char *, size_t, const char *, const char *);
using LuaKFunction = int (*)(LuaState *, int, intptr_t);
using LuaPCallFn = int (*)(LuaState *, int, int, int, intptr_t, LuaKFunction);
// Opaque IL2CPP types: method metadata is accessed only via public runtime APIs.
using RuntimeInvokeFn = void *(*)(const void *, void *, void **, void **);
using MethodNameFn = const char *(*)(const void *);
using MethodClassFn = void *(*)(const void *);
using ClassNameFn = const char *(*)(void *);
using ClassNamespaceFn = const char *(*)(void *);

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
struct ExecutionEvent {
    uintptr_t state;
    uint64_t thread;
    uint64_t callId;
    int nargs;
    int nresults;
    int errfunc;
    int status;
    uint64_t durationNs;
    uint64_t sequence;
};
struct BridgeEvent {
    uintptr_t method;
    uint64_t thread;
    uint64_t callId;
    uint64_t durationNs;
    bool exception;
    uint64_t sequence;
    std::string methodName;
    std::string className;
    std::string namespaceName;
};
struct HookEntry {
    const char *name;
    void *address;
    bool installed;
    int error;
};
constexpr size_t kMaxBridges = 256;
constexpr size_t kMaxExecutions = 512;
constexpr size_t kMaxChunks = 256;
constexpr size_t kMaxStates = 128;
constexpr size_t kMaxHashBytes = 1024 * 1024;
std::mutex g_mu;
std::atomic<bool> g_active{false};
std::atomic<bool> g_installed{false};
std::atomic<bool> g_autoStarted{false};
std::atomic<bool> g_schedulePending{false};
dispatch_queue_t g_installQueue = nullptr;
std::once_flag g_once;
std::atomic<uint64_t> g_seq{0};
std::vector<StateEvent> g_states;
std::vector<ChunkEvent> g_chunks;
std::vector<ExecutionEvent> g_executions;
std::vector<BridgeEvent> g_bridges;
std::atomic<uint64_t> g_bridgeTotal{0};
std::atomic<uint64_t> g_bridgeDropped{0};
std::atomic<uint64_t> g_callIds{0};
std::atomic<uint64_t> g_executionTotal{0};
std::atomic<uint64_t> g_executionDropped{0};
std::vector<HookEntry> g_hooks;
std::string g_reason = "not started";
thread_local unsigned g_loadingDepth = 0;

NewStateFn origNewState = nullptr;
CloseFn origClose = nullptr;
XLuaLoadFn origXLuaLoad = nullptr;
LuaLoadFn origLuaLoad = nullptr;
LuaPCallFn origPCall = nullptr;
RuntimeInvokeFn origRuntimeInvoke = nullptr;
MethodNameFn methodGetName = nullptr;
MethodClassFn methodGetClass = nullptr;
ClassNameFn classGetName = nullptr;
ClassNamespaceFn classGetNamespace = nullptr;
thread_local uint64_t g_currentCallId = 0;
thread_local unsigned g_executionDepth = 0;

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
                 const std::string &name, int status, const char *api) {
    if (!g_active.load(std::memory_order_relaxed) || !state) return;
    // Bytes are hashed before invoking the original Lua loader; no buffer is retained.
    std::lock_guard<std::mutex> lock(g_mu);
    if (g_chunks.size() >= kMaxChunks) g_chunks.erase(g_chunks.begin());
    g_chunks.push_back({reinterpret_cast<uintptr_t>(state), api, name,
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
    const std::string safeName = g_loadingDepth == 1 && n ? std::string(n, strnlen(n, 512)) : "(unnamed)";
    int result = origXLuaLoad ? origXLuaLoad(L, b, sz, n) : -1;
    if (g_loadingDepth == 1 && sz >= 0)
        recordChunk(L, static_cast<size_t>(sz), digest, safeName, result, "xluaL_loadbuffer");
    --g_loadingDepth;
    return result;
}
int luaLoadHook(LuaState *L, const char *b, size_t sz, const char *n, const char *mode) {
    ++g_loadingDepth;
    const uint64_t digest = g_loadingDepth == 1 && b && sz > 0 ? hashPrefix(b, sz) : 0;
    const std::string safeName = g_loadingDepth == 1 && n ? std::string(n, strnlen(n, 512)) : "(unnamed)";
    int result = origLuaLoad ? origLuaLoad(L, b, sz, n, mode) : -1;
    if (g_loadingDepth == 1)
        recordChunk(L, sz, digest, safeName, result, "luaL_loadbufferx");
    --g_loadingDepth;
    return result;
}


// Observe protected call *boundaries*, not individual Lua bytecode functions.
// No Lua C API inspection or stack mutation is performed inside the hook.
int pcallHook(LuaState *L, int nargs, int nresults, int errfunc,
              intptr_t context, LuaKFunction continuation) {
    ++g_executionDepth;
    const bool capture = g_executionDepth == 1 && L &&
                         g_active.load(std::memory_order_relaxed);
    const uint64_t start = capture ? mach_absolute_time() : 0;
    const uint64_t previousCallId = g_currentCallId;
    const uint64_t callId = capture ? ++g_callIds : previousCallId;
    if (capture) g_currentCallId = callId;
    const int status = origPCall
        ? origPCall(L, nargs, nresults, errfunc, context, continuation) : -1;
    if (capture) {
        const uint64_t end = mach_absolute_time();
        static mach_timebase_info_data_t timebase = [] {
            mach_timebase_info_data_t info = {};
            mach_timebase_info(&info);
            return info;
        }();
        const uint64_t delta = end - start;
        const uint64_t elapsedNs = timebase.denom ?
            static_cast<uint64_t>((static_cast<long double>(delta) *
                timebase.numer) / timebase.denom) : 0;
        uint64_t tid = 0;
        pthread_threadid_np(nullptr, &tid);
        g_executionTotal.fetch_add(1, std::memory_order_relaxed);
        std::lock_guard<std::mutex> lock(g_mu);
        if (g_executions.size() >= kMaxExecutions) {
            g_executions.erase(g_executions.begin());
            g_executionDropped.fetch_add(1, std::memory_order_relaxed);
        }
        g_executions.push_back({
            reinterpret_cast<uintptr_t>(L), tid, callId, nargs, nresults,
            errfunc, status, elapsedNs, ++g_seq
        });
    }
    if (capture) g_currentCallId = previousCallId;
    --g_executionDepth;
    return status;
}


std::string boundedMetadata(const char *text) {
    return text ? std::string(text, strnlen(text, 192)) : std::string();
}

// A same-thread, dynamically nested invocation is evidence of an execution
// relationship only. Generated xLua wrappers can call C# directly and bypass
// il2cpp_runtime_invoke entirely. We never claim all Lua->C# calls are covered.
void *runtimeInvokeHook(const void *method, void *object,
                        void **args, void **exception) {
    const uint64_t callId = g_currentCallId;
    const bool observe = callId != 0 && method &&
                         g_active.load(std::memory_order_relaxed);
    const uint64_t start = observe ? mach_absolute_time() : 0;
    void *result = origRuntimeInvoke
        ? origRuntimeInvoke(method, object, args, exception) : nullptr;
    if (!observe) return result;

    const uint64_t elapsedTicks = mach_absolute_time() - start;
    static mach_timebase_info_data_t timebase = [] {
        mach_timebase_info_data_t info = {};
        mach_timebase_info(&info);
        return info;
    }();
    const uint64_t elapsedNs = timebase.denom ?
        static_cast<uint64_t>((static_cast<long double>(elapsedTicks) *
            timebase.numer) / timebase.denom) : 0;

    // Use exports from the same already-loaded runtime image only; never
    // inspect opaque MethodInfo, Il2CppClass, or argument memory layouts.
    std::string methodName = boundedMetadata(methodGetName ? methodGetName(method) : nullptr);
    void *klass = methodGetClass ? methodGetClass(method) : nullptr;
    std::string className = boundedMetadata(klass && classGetName ? classGetName(klass) : nullptr);
    std::string namespaceName = boundedMetadata(klass && classGetNamespace ?
        classGetNamespace(klass) : nullptr);
    uint64_t tid = 0;
    pthread_threadid_np(nullptr, &tid);
    g_bridgeTotal.fetch_add(1, std::memory_order_relaxed);

    std::lock_guard<std::mutex> lock(g_mu);
    if (g_bridges.size() >= kMaxBridges) {
        g_bridges.erase(g_bridges.begin());
        g_bridgeDropped.fetch_add(1, std::memory_order_relaxed);
    }
    g_bridges.push_back({reinterpret_cast<uintptr_t>(method), tid, callId,
                         elapsedNs, exception && *exception != nullptr, ++g_seq,
                         std::move(methodName), std::move(className),
                         std::move(namespaceName)});
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
            !std::strstr(path,"GameAssembly") &&
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
    result += ",\"autoStart\":" + std::string(g_autoStarted ? "true" : "false");
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
    result += "],\"executions\":[";
    for (size_t i = 0; i < g_executions.size(); ++i) {
        if (i) result += ",";
        const auto &e = g_executions[i];
        result += "{\"api\":\"lua_pcallk\",\"state\":\"" + hex(e.state) +
                  "\",\"threadId\":" + std::to_string(e.thread) +
                  ",\"callId\":" + std::to_string(e.callId) +
                  ",\"nargs\":" + std::to_string(e.nargs) +
                  ",\"nresults\":" + std::to_string(e.nresults) +
                  ",\"errfunc\":" + std::to_string(e.errfunc) +
                  ",\"status\":" + std::to_string(e.status) +
                  ",\"durationNs\":" + std::to_string(e.durationNs) +
                  ",\"sequence\":" + std::to_string(e.sequence) + "}";
    }
    result += "],\"bridges\":[";
    for (size_t i = 0; i < g_bridges.size(); ++i) {
        if (i) result += ",";
        const auto &e = g_bridges[i];
        result += "{\"api\":\"il2cpp_runtime_invoke\",\"evidence\":\"same_thread_nested\"," +
                  std::string("\"method\":\"") + hex(e.method) +
                  "\",\"methodName\":\"" + escape(e.methodName) +
                  "\",\"className\":\"" + escape(e.className) +
                  "\",\"namespace\":\"" + escape(e.namespaceName) +
                  "\",\"threadId\":" + std::to_string(e.thread) +
                  ",\"protectedCallId\":" + std::to_string(e.callId) +
                  ",\"durationNs\":" + std::to_string(e.durationNs) +
                  ",\"exception\":" + (e.exception ? "true" : "false") +
                  ",\"sequence\":" + std::to_string(e.sequence) + "}";
    }
    result += "],\"bridgeStats\":{\"total\":" +
              std::to_string(g_bridgeTotal.load(std::memory_order_relaxed)) +
              ",\"dropped\":" + std::to_string(g_bridgeDropped.load(std::memory_order_relaxed)) +
              ",\"scope\":\"il2cpp_runtime_invoke_within_lua_pcallk_same_thread\"}";
    result += ",\"executionStats\":{\"total\":" +
              std::to_string(g_executionTotal.load(std::memory_order_relaxed)) +
              ",\"dropped\":" +
              std::to_string(g_executionDropped.load(std::memory_order_relaxed)) +
              ",\"scope\":\"protected_call_boundaries_only\"},\"chunks\":[";
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

void installAvailable() {
#ifdef XRI_BUNDLED_DOBBY
    const DobbyHookFn hook = &DobbyHook;
#else
    const DobbyHookFn hook = reinterpret_cast<DobbyHookFn>(dlsym(RTLD_DEFAULT, "DobbyHook"));
#endif
    if (!hook) {
        std::lock_guard<std::mutex> lock(g_mu);
        g_reason = "Hook provider unavailable";
        return;
    }

    // Do not install IL2CPP hook unless the metadata ABI is fully available
    // from the same loaded runtime module. No guessed offsets or structures.
    void *invokeAddress = resolve("il2cpp_runtime_invoke");
    void *getName = resolve("il2cpp_method_get_name");
    void *getClass = resolve("il2cpp_method_get_class");
    void *getClassName = resolve("il2cpp_class_get_name");
    void *getNamespace = resolve("il2cpp_class_get_namespace");
    const bool bridgeReady = invokeAddress && getName && getClass &&
        getClassName && getNamespace;
    if (bridgeReady) {
        Dl_info info = {};
        Dl_info a = {}, b = {}, c = {}, d = {};
        if (!dladdr(invokeAddress, &info) || !dladdr(getName, &a) ||
            !dladdr(getClass, &b) || !dladdr(getClassName, &c) ||
            !dladdr(getNamespace, &d) ||
            info.dli_fbase != a.dli_fbase || info.dli_fbase != b.dli_fbase ||
            info.dli_fbase != c.dli_fbase || info.dli_fbase != d.dli_fbase) {
            invokeAddress = nullptr;
        } else {
            methodGetName = reinterpret_cast<MethodNameFn>(getName);
            methodGetClass = reinterpret_cast<MethodClassFn>(getClass);
            classGetName = reinterpret_cast<ClassNameFn>(getClassName);
            classGetNamespace = reinterpret_cast<ClassNamespaceFn>(getNamespace);
        }
    } else {
        invokeAddress = nullptr;
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
         reinterpret_cast<void **>(&origLuaLoad)},
        {"lua_pcallk", reinterpret_cast<void *>(&pcallHook),
         reinterpret_cast<void **>(&origPCall)},
        {"il2cpp_runtime_invoke", reinterpret_cast<void *>(&runtimeInvokeHook),
         reinterpret_cast<void **>(&origRuntimeInvoke)}
    };
    for (const auto &t : targets) {
        bool processed = false;
        {
            std::lock_guard<std::mutex> lock(g_mu);
            for (const auto &h : g_hooks) {
                if (std::strcmp(h.name, t.name) == 0) { processed = true; break; }
            }
        }
        if (processed) continue;
        void *addr = std::strcmp(t.name, "il2cpp_runtime_invoke") == 0 ?
            invokeAddress : resolve(t.name);
        if (!addr) continue; // Not yet loaded. Try again after next dyld image notification.

        // DobbyHook can suspend threads and install executable memory.
        // Never perform it under the dyld callback or our event mutex.
        const int error = hook(addr, t.replacement, t.original);
        const bool ok = error == 0 && *t.original != nullptr;
        {
            std::lock_guard<std::mutex> lock(g_mu);
            g_hooks.push_back({t.name, addr, ok, error ? error : (ok ? 0 : -3)});
            if (ok) {
                g_installed = true;
                g_active = true;
            }
        }
    }

    std::lock_guard<std::mutex> lock(g_mu);
    if (!g_installed) {
        g_reason = g_hooks.empty() ? "Waiting for exported Lua entry points"
                                   : "Hook installation failed; see hooks";
    } else {
        unsigned count = 0;
        for (const auto &h : g_hooks) if (h.installed) ++count;
        g_reason = count == 6 ? "Recording (6/6 hooks)"
                              : "Recording (partial hooks; earlier events not recoverable)";
    }
}

void installWorker(void *) {
    // The serial queue isolates installation from dyld's image-add callback.
    // Recheck the generation flag so newly added images are not lost.
    do {
        g_schedulePending = false;
        installAvailable();
    } while (g_schedulePending.exchange(false));
}

void scheduleInstall() {
    if (g_installQueue && !g_schedulePending.exchange(true)) {
        dispatch_async_f(g_installQueue, nullptr, installWorker);
    }
}

void imageAdded(const mach_header *, intptr_t) {
    // Never inspect symbols or patch instructions while dyld holds its loader lock.
    scheduleInstall();
}
} // namespace

extern "C" __attribute__((visibility("default"))) void xri_trace_initialize(void) {
    std::call_once(g_once, [] {
        g_autoStarted = true;
        g_installQueue = dispatch_queue_create("com.xri.hooks.install", DISPATCH_QUEUE_SERIAL);
        _dyld_register_func_for_add_image(imageAdded);
        scheduleInstall(); // Also handles images already present before injection.
    });
}

__attribute__((constructor)) static void xri_auto_initialize(void) {
    xri_trace_initialize();
}

// ABI-compatible entry point: idempotent request, no longer required from UI.
extern "C" __attribute__((visibility("default"))) int xri_trace_start(void) {
    xri_trace_initialize();
    if (g_installed) {
        g_active = true;
        return 1;
    }
    scheduleInstall();
    return 0; // Pending is not a successful hook installation.
}
extern "C" __attribute__((visibility("default"))) void xri_trace_stop(void) {
    g_active = false;
    std::lock_guard<std::mutex> lock(g_mu);
    g_reason = "Recording paused by API; hooks retained for safe pass-through";
}
extern "C" __attribute__((visibility("default"))) void xri_trace_clear(void) {
    std::lock_guard<std::mutex> lock(g_mu);
    g_chunks.clear();
    g_states.clear();
    g_executions.clear();
    g_bridges.clear();
    g_bridgeTotal = 0;
    g_bridgeDropped = 0;
    g_executionTotal = 0;
    g_executionDropped = 0;
}
extern "C" __attribute__((visibility("default")))
size_t xri_trace_snapshot_json(char *output, size_t capacity) {
    const std::string s = jsonSnapshot();
    size_t n = s.size() + 1;
    if (output && capacity >= n) std::memcpy(output, s.c_str(), n);
    return n;
}
