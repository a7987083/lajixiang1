// Read-only Lua runtime probe. No game currency or energy mutation.
#include <dlfcn.h>
#include <pthread.h>
#include <stddef.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>
#include <time.h>
#include <mach-o/dyld.h>

typedef struct lua_State lua_State;
typedef int (*pcall_t)(lua_State*,int,int,int);
typedef int (*load_t)(lua_State*,const char*,size_t,const char*);
typedef int (*gettop_t)(lua_State*);
typedef void (*settop_t)(lua_State*,int);
typedef const char* (*tolstring_t)(lua_State*,int,size_t*);
typedef void (*substrate_t)(void*,void*,void**);
typedef int (*dobby_t)(void*,void*,void**);

// Append one complete line to the app sandbox; no absolute container path is hardcoded.
// Expected location: <AppDataContainer>/Documents/LuaHookV1.log
static void lua_hook_log(const char *fmt, ...) {
    char message[1024];
    va_list args;
    va_start(args, fmt);
    int n = vsnprintf(message, sizeof(message), fmt, args);
    va_end(args);
    if (n < 0) return;
    const char *home = getenv("HOME");
    if (home && home[0] == '/') {
        char path[PATH_MAX];
        int len = snprintf(path, sizeof(path), "%s/Documents/LuaHookV1.log", home);
        if (len > 0 && (size_t)len < sizeof(path)) {
            int fd = open(path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC | O_NOFOLLOW, 0600);
            if (fd >= 0) {
                char record[1200];
                time_t now = time(NULL);
                struct tm tm_value;
                char stamp[32] = "";
                if (localtime_r(&now, &tm_value)) {
                    strftime(stamp, sizeof(stamp), "%Y-%m-%d %H:%M:%S", &tm_value);
                }
                int total = snprintf(record, sizeof(record), "[%s] [LuaHookV1] %s\n", stamp, message);
                if (total > 0) {
                    size_t bytes = (size_t)total < sizeof(record) ? (size_t)total : sizeof(record) - 1;
                    (void)write(fd, record, bytes);
                }
                close(fd);
            }
        }
    }
    fprintf(stderr, "[LuaHookV1] %s\n", message);
}

static pcall_t original_pcall;
static load_t lua_loadbuffer;
static gettop_t lua_gettop;
static settop_t lua_settop;
static tolstring_t lua_tolstring;
static pthread_mutex_t install_lock=PTHREAD_MUTEX_INITIALIZER;
static int installed=0, pending=1;
static __thread int in_probe=0;

static void probe(lua_State *L) {
    if (!L || in_probe || !original_pcall || !lua_loadbuffer || !lua_gettop || !lua_settop) return;
    if (__sync_lock_test_and_set(&pending,0)==0) return;
    in_probe=1;
    int top=lua_gettop(L);
    const char script[]="return 1 + 1";
    int rc=lua_loadbuffer(L,script,sizeof(script)-1,"=LuaHookV1");
    if (rc==0) rc=original_pcall(L,0,1,0);
    if (rc) {
        const char *error=lua_tolstring ? lua_tolstring(L,-1,NULL) : NULL;
        lua_hook_log("probe failed: %d %s",rc,error?error:"(none)");
    } else lua_hook_log("read-only probe executed");
    lua_settop(L,top);
    in_probe=0;
}

static int hooked_pcall(lua_State *L,int nargs,int nresults,int errfunc) {
    pcall_t fn=original_pcall;
    if (!fn) return 1;
    int result=fn(L,nargs,nresults,errfunc);
    if (!in_probe) probe(L);
    return result;
}

static void *find_unity_handle(void) {
    // Derive exact loaded-image path; do not assume @rpath is resolvable via dlopen.
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; ++i) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "/UnityFramework.framework/UnityFramework")) {
            return dlopen(name, RTLD_NOW | RTLD_NOLOAD);
        }
    }
    return NULL;
}

static void *get_symbol(void *h,const char *symbol) {
    void *p=h?dlsym(h,symbol):NULL;
    return p?p:dlsym(RTLD_DEFAULT,symbol);
}

__attribute__((visibility("default"))) int LuaHookV1_RetryInstall(void) {
    pthread_mutex_lock(&install_lock);
    if(installed) {pthread_mutex_unlock(&install_lock); return 1;}
    void *unity=find_unity_handle();
    void *target=get_symbol(unity,"lua_pcall");
    lua_loadbuffer=(load_t)get_symbol(unity,"luaL_loadbuffer");
    lua_gettop=(gettop_t)get_symbol(unity,"lua_gettop");
    lua_settop=(settop_t)get_symbol(unity,"lua_settop");
    lua_tolstring=(tolstring_t)get_symbol(unity,"lua_tolstring");
    if(!target||!lua_loadbuffer||!lua_gettop||!lua_settop) {
        lua_hook_log("Lua API unavailable: unity=%p pcall=%p loadbuffer=%p gettop=%p settop=%p tolstring=%p images=%u", unity, target, (void*)lua_loadbuffer, (void*)lua_gettop, (void*)lua_settop, (void*)lua_tolstring, (unsigned)_dyld_image_count());
        if (unity) dlclose(unity);
        pthread_mutex_unlock(&install_lock); return 0;
    }
    substrate_t substrate=(substrate_t)dlsym(RTLD_DEFAULT,"MSHookFunction");
    dobby_t dobby=(dobby_t)dlsym(RTLD_DEFAULT,"DobbyHook");
    if(!substrate&&!dobby) {
        lua_hook_log("no supported inline hook runtime (MSHookFunction=%p DobbyHook=%p)", (void*)substrate, (void*)dobby);
        if (unity) dlclose(unity);
        pthread_mutex_unlock(&install_lock); return 0;
    }
    int result=0;
    if(substrate) substrate(target,(void*)hooked_pcall,(void**)&original_pcall);
    else result=dobby(target,(void*)hooked_pcall,(void**)&original_pcall);
    if(result!=0 || !original_pcall) {
        lua_hook_log("install failed");
        if (unity) dlclose(unity);
        pthread_mutex_unlock(&install_lock); return 0;
    }
    installed=1;
    if (unity) dlclose(unity);
    lua_hook_log("installed pcall=%p original=%p",target,(void*)original_pcall);
    pthread_mutex_unlock(&install_lock); return 1;
}

__attribute__((visibility("default"))) int LuaHookV1_IsInstalled(void) {
    return __atomic_load_n(&installed,__ATOMIC_RELAXED);
}
// Never attempt to patch executable code from the dyld image constructor.
// A bounded background retry covers UnityFramework/hook-runtime load ordering.
static void *install_worker(void *arg) {
    (void)arg;
    for (int attempt=1; attempt<=60; ++attempt) {
        if (LuaHookV1_RetryInstall()) {
            lua_hook_log("hook ready on attempt %d", attempt);
            return NULL;
        }
        if (attempt == 1 || attempt % 10 == 0)
            lua_hook_log("retry attempt %d/60 (waiting for Lua API and hook framework)", attempt);
        struct timespec interval = { .tv_sec=0, .tv_nsec=500000000L };
        nanosleep(&interval, NULL);
    }
    lua_hook_log("retry exhausted after 30s; no hook installed");
    return NULL;
}

__attribute__((constructor)) static void init(void) {
    lua_hook_log("loaded, diagnostic only; async startup retry");
    pthread_t worker;
    int err = pthread_create(&worker, NULL, install_worker, NULL);
    if (err == 0) pthread_detach(worker);
    else lua_hook_log("worker thread creation failed: %d", err);
}
