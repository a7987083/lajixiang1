// Read-only Lua runtime inventory. No game currency or energy mutation.
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
// Expected location: <AppDataContainer>/Documents/LuaHookV2.log
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
        int len = snprintf(path, sizeof(path), "%s/Documents/LuaHookV2.log", home);
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
                int total = snprintf(record, sizeof(record), "[%s] [LuaHookV2] %s\n", stamp, message);
                if (total > 0) {
                    size_t bytes = (size_t)total < sizeof(record) ? (size_t)total : sizeof(record) - 1;
                    (void)write(fd, record, bytes);
                }
                close(fd);
            }
        }
    }
    fprintf(stderr, "[LuaHookV2] %s\n", message);
}

static pcall_t original_pcall;
static load_t lua_loadbuffer;
static gettop_t lua_gettop;
static settop_t lua_settop;
static tolstring_t lua_tolstring;
static pthread_mutex_t install_lock=PTHREAD_MUTEX_INITIALIZER;
static int installed=0;
static int scan_phase=0;
static unsigned long long first_scan_ns=0;
static const unsigned scan_delays_seconds[4]={0,5,15,30};
static __thread int in_probe=0;

static void probe(lua_State *L, int phase) {
    if (!L || in_probe || !original_pcall || !lua_loadbuffer || !lua_gettop || !lua_settop || !lua_tolstring) return;
    lua_hook_log("begin inventory snapshot=%d delay=%us",phase+1,scan_delays_seconds[phase]);
    in_probe=1;
    int top=lua_gettop(L);
    const char script[]="local out, matches, limit = {}, 0, 100\nlocal package_name, package_count, global_count, preload_count = \"absent\", 0, 0, 0\nlocal function relevant(s)\n  s = string.lower(s)\n  local words = {\"gold\",\"gem\",\"diamond\",\"energy\",\"player\",\"reward\",\"award\",\"currency\",\"userdata\",\"coin\",\"stamina\",\"power\"}\n  for i = 1, #words do\n    if string.find(s, words[i], 1, true) then return true end\n  end\n  return false\nend\nlocal function scan(scope, t)\n  if type(t) ~= \"table\" then return 0 end\n  local seen, k = 0, next(t)\n  while k ~= nil and seen < 10000 do\n    seen = seen + 1\n    local v = rawget(t,k)\n    if type(k) == \"string\" and matches < limit and relevant(k) then\n      matches = matches + 1\n      local key = string.sub(k,1,100)\n      out[#out+1] = scope .. \".\" .. key .. \" [\" .. type(v) .. \"]\"\n      if type(v) == \"table\" then\n        local n, subkey = 0, next(v)\n        while subkey ~= nil and n < 200 and matches < limit do\n          n = n + 1\n          local subvalue = rawget(v,subkey)\n          if type(subkey) == \"string\" and relevant(subkey) then\n            matches = matches + 1\n            out[#out+1] = scope .. \".\" .. key .. \".\" .. string.sub(subkey,1,100) .. \" [\" .. type(subvalue) .. \"]\"\n          end\n          subkey = next(v,subkey)\n        end\n      end\n    end\n    k = next(t,k)\n  end\n  return seen\nend\nlocal pkg = rawget(_G,\"package\")\nif type(pkg) == \"table\" then\n  package_name = \"table\"\n  package_count = scan(\"package.loaded\",rawget(pkg,\"loaded\"))\n  preload_count = scan(\"package.preload\",rawget(pkg,\"preload\"))\nelse\n  package_name = type(pkg)\nend\nglobal_count = scan(\"_G\",_G)\nreturn \"scan_count=\"..matches..\" package_type=\"..package_name..\n  \" package_loaded_keys=\"..package_count..\" package_preload_keys=\"..preload_count..\n  \" global_keys=\"..global_count..\"\\n\"..table.concat(out,\"\\n\")";
    int rc=lua_loadbuffer(L,script,sizeof(script)-1,"=LuaHookV2");
    if (rc==0) rc=original_pcall(L,0,1,0);
    if (rc) {
        const char *error=lua_tolstring ? lua_tolstring(L,-1,NULL) : NULL;
        lua_hook_log("probe failed: %d %s",rc,error?error:"(none)");
    } else {
        size_t length=0;
        const char *inventory=lua_tolstring(L,-1,&length);
        if (inventory) {
            // Split into bounded lines so that each line fits the existing log record.
            size_t begin=0;
            size_t printed=0;
            while (begin<length && printed<7000) {
                size_t end=begin;
                while (end<length && inventory[end]!='\n' && end-begin<700) end++;
                lua_hook_log("inventory: %.*s",(int)(end-begin),inventory+begin);
                printed+=end-begin;
                begin=end<length && inventory[end]=='\n' ? end+1 : end;
            }
        }
        lua_hook_log("read-only Lua module inventory completed snapshot=%d",phase+1);
    }
    lua_settop(L,top);
    in_probe=0;
}

static int hooked_pcall(lua_State *L,int nargs,int nresults,int errfunc) {
    pcall_t fn=original_pcall;
    if (!fn) return 1;
    int result=fn(L,nargs,nresults,errfunc);
    if (!in_probe) {
        struct timespec now;
        if (clock_gettime(CLOCK_MONOTONIC, &now)==0) {
            unsigned long long t=(unsigned long long)now.tv_sec*1000000000ULL+(unsigned long long)now.tv_nsec;
            unsigned long long start=__atomic_load_n(&first_scan_ns,__ATOMIC_ACQUIRE);
            if (start==0) {
                unsigned long long zero=0;
                (void)__atomic_compare_exchange_n(&first_scan_ns,&zero,t,0,__ATOMIC_ACQ_REL,__ATOMIC_ACQUIRE);
                start=__atomic_load_n(&first_scan_ns,__ATOMIC_ACQUIRE);
            }
            int phase=__atomic_load_n(&scan_phase,__ATOMIC_ACQUIRE);
            if (phase<4 && t>=start && (t-start)/1000000000ULL>=scan_delays_seconds[phase]) {
                int expected=phase;
                if (__atomic_compare_exchange_n(&scan_phase,&expected,phase+1,0,__ATOMIC_ACQ_REL,__ATOMIC_ACQUIRE))
                    probe(L,phase);
            }
        }
    }
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

__attribute__((visibility("default"))) int LuaHookV2_RetryInstall(void) {
    pthread_mutex_lock(&install_lock);
    if(installed) {pthread_mutex_unlock(&install_lock); return 1;}
    void *unity=find_unity_handle();
    void *target=get_symbol(unity,"lua_pcall");
    lua_loadbuffer=(load_t)get_symbol(unity,"luaL_loadbuffer");
    lua_gettop=(gettop_t)get_symbol(unity,"lua_gettop");
    lua_settop=(settop_t)get_symbol(unity,"lua_settop");
    lua_tolstring=(tolstring_t)get_symbol(unity,"lua_tolstring");
    if(!target||!lua_loadbuffer||!lua_gettop||!lua_settop||!lua_tolstring) {
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

__attribute__((visibility("default"))) int LuaHookV2_IsInstalled(void) {
    return __atomic_load_n(&installed,__ATOMIC_RELAXED);
}
// Never attempt to patch executable code from the dyld image constructor.
// A bounded background retry covers UnityFramework/hook-runtime load ordering.
static void *install_worker(void *arg) {
    (void)arg;
    for (int attempt=1; attempt<=60; ++attempt) {
        if (LuaHookV2_RetryInstall()) {
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
