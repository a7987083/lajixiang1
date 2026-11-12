// V3 controlled Lua runtime test: no resource changes until explicitly requested.
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
#include "LuaBootstrapV3.h"

typedef struct lua_State lua_State;
typedef int (*pcall_t)(lua_State*,int,int,int);
typedef int (*load_t)(lua_State*,const char*,size_t,const char*);
typedef int (*gettop_t)(lua_State*);
typedef void (*settop_t)(lua_State*,int);
typedef const char* (*tolstring_t)(lua_State*,int,size_t*);
typedef void (*substrate_t)(void*,void*,void**);
typedef int (*dobby_t)(void*,void*,void**);

// Append one complete line to the app sandbox; no absolute container path is hardcoded.
// Expected location: <AppDataContainer>/Documents/LuaHookV3.log
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
        int len = snprintf(path, sizeof(path), "%s/Documents/LuaHookV3.log", home);
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
                int total = snprintf(record, sizeof(record), "[%s] [LuaHookV3] %s\n", stamp, message);
                if (total > 0) {
                    size_t bytes = (size_t)total < sizeof(record) ? (size_t)total : sizeof(record) - 1;
                    (void)write(fd, record, bytes);
                }
                close(fd);
            }
        }
    }
    fprintf(stderr, "[LuaHookV3] %s\n", message);
}

static pcall_t original_pcall;
static load_t lua_loadbuffer;
static gettop_t lua_gettop;
static settop_t lua_settop;
static tolstring_t lua_tolstring;
static pthread_mutex_t install_lock=PTHREAD_MUTEX_INITIALIZER;
static int installed=0;
static int pending_action=0; // 0 none, 1 gold, 2 gem, 3 energy on, 4 energy off
static pthread_mutex_t action_lock=PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t probe_lock=PTHREAD_MUTEX_INITIALIZER;
static unsigned long long next_poll_ns=0;
static unsigned long long next_preflight_ns=0;
static int last_mod_state=-1;
static lua_State *bound_mod_state=NULL;
static unsigned long long next_mod_tick_ns=0;
// 0 unknown, 1 _MOD absent, 2 _MOD available; atomic status shared with UIKit.
static int mod_status=0;
static __thread int in_probe=0;


static unsigned long long monotonic_ns(void) {
    struct timespec t;
    if (clock_gettime(CLOCK_MONOTONIC,&t)!=0) return 0;
    return (unsigned long long)t.tv_sec*1000000000ULL+(unsigned long long)t.tv_nsec;
}
static const char *action_name(int action) {
    switch(action) { case 1:return "gold"; case 2:return "gem"; case 3:return "energy_on"; case 4:return "energy_off"; default:return "unknown"; }
}
static int queue_action(int action) {
    if (action<1 || action>4) return 0;
    if (!__atomic_load_n(&installed,__ATOMIC_ACQUIRE)) { lua_hook_log("rejected action=%s: hook not installed",action_name(action)); return 0; }
    int mod=__atomic_load_n(&mod_status,__ATOMIC_ACQUIRE);
    if(mod==1) { lua_hook_log("rejected action=%s: _MOD not available in observed Lua state",action_name(action)); return 0; }
    pthread_mutex_lock(&action_lock);
    int ok=0;
    if (pending_action==0) { pending_action=action; ok=1; }
    pthread_mutex_unlock(&action_lock);
    if (ok) lua_hook_log("queued action=%s; awaiting Lua pcall",action_name(action));
    else lua_hook_log("rejected action=%s; pending action already exists",action_name(action));
    return ok;
}
// Exported status for the UI: 0 unknown, 1 absent, 2 ready.
__attribute__((visibility("default"))) int LuaHookV3_ModStatus(void) { return __atomic_load_n(&mod_status,__ATOMIC_ACQUIRE); }
// Exported explicit triggers; callable from an external debugging UI or dlsym.
__attribute__((visibility("default"))) int LuaHookV3_RequestGold(void) { return queue_action(1); }
__attribute__((visibility("default"))) int LuaHookV3_RequestGem(void) { return queue_action(2); }
__attribute__((visibility("default"))) int LuaHookV3_RequestEnergy(int enabled) { return queue_action(enabled?3:4); }

// Non-executable, whitelisted command file for manual testing using the app Documents directory.
// Create Documents/LuaHookV3.command with exactly "gold", "gem", "energy_on", or "energy_off".
// Polling is bounded to once per second on observed Lua calls, and files are opened with O_NOFOLLOW.
static void poll_command_file(unsigned long long now) {
    unsigned long long deadline=__atomic_load_n(&next_poll_ns,__ATOMIC_RELAXED);
    if(now<deadline) return;
    if(!__atomic_compare_exchange_n(&next_poll_ns,&deadline,now+1000000000ULL,0,__ATOMIC_ACQ_REL,__ATOMIC_RELAXED)) return;
    const char *home=getenv("HOME");
    if(!home || home[0]!='/') return;
    char path[PATH_MAX];
    int n=snprintf(path,sizeof(path),"%s/Documents/LuaHookV3.command",home);
    if(n<=0 || (size_t)n>=sizeof(path)) return;
    int fd=open(path,O_RDONLY|O_CLOEXEC|O_NOFOLLOW);
    if(fd<0) return;
    char buf[64]={0};
    ssize_t got=read(fd,buf,sizeof(buf)-1);
    close(fd);
    if(got<=0) { lua_hook_log("empty command file"); (void)unlink(path); return; }
    // Read only strict single command. File is consumed once, whether valid or not.
    buf[got]=0;
    char *e=buf;
    while(*e && *e!='\n' && *e!='\r' && *e!=' ' && *e!='\t') e++;
    *e=0;
    int action=0;
    if(strcmp(buf,"gold")==0) action=1;
    else if(strcmp(buf,"gem")==0) action=2;
    else if(strcmp(buf,"energy_on")==0) action=3;
    else if(strcmp(buf,"energy_off")==0) action=4;
    if(action) {
        if(queue_action(action)) (void)unlink(path);
        // When busy, leave the file in place for the next poll.
    } else {
        lua_hook_log("invalid command file; valid values: gold gem energy_on energy_off");
        (void)unlink(path);
    }
}

static int run_lua(lua_State *L,const char *script,const char *tag,char *result,size_t result_size) {
    int top=lua_gettop(L);
    int rc=lua_loadbuffer(L,script,strlen(script),tag);
    if(rc==0) rc=original_pcall(L,0,1,0);
    const char *value=lua_tolstring(L,-1,NULL);
    if(result && result_size) snprintf(result,result_size,"%s",value?value:"(no string result)");
    lua_settop(L,top);
    return rc;
}

static void probe(lua_State *L) {
    if (!L || in_probe || !original_pcall || !lua_loadbuffer || !lua_gettop || !lua_settop || !lua_tolstring) return;
    in_probe=1;
    pthread_mutex_lock(&probe_lock);
    unsigned long long now=monotonic_ns();
    lua_State *bound=__atomic_load_n(&bound_mod_state,__ATOMIC_ACQUIRE);
    if (bound && bound!=L) { pthread_mutex_unlock(&probe_lock); in_probe=0; return; }
    poll_command_file(now);
    int action=0;
    pthread_mutex_lock(&action_lock);
    action=pending_action;
    pthread_mutex_unlock(&action_lock);
    // Preflight only once every 5 seconds, or for a pending action; no unknown Lua methods executed.
    unsigned long long next=__atomic_load_n(&next_preflight_ns,__ATOMIC_RELAXED);
    if(action || now>=next) {
        __atomic_store_n(&next_preflight_ns,now+5000000000ULL,__ATOMIC_RELAXED);
        char status[256]={0};
        int rc=run_lua(L,"local m=_MOD\nif type(m)~=\"table\" then return \"ABSENT _MOD type=\"..type(m) end\nreturn \"READY addItem=\"..type(m.addItem)..\" tick=\"..type(m.tick)..\" infEnergy=\"..type(m.infEnergy)","=LuaHookV3Check",status,sizeof(status));
        int ready=(rc==0 && strncmp(status,"READY ",6)==0);
        if(!ready && !bound) {
            // Only initialize in a Lua VM that already exposes the game's xyd table.
            // Execute once per Lua state; never inject into an unrelated Lua VM.
            char context[128]={0};
            int context_rc=run_lua(L,"return type(xyd)", "=LuaHookV3Context",context,sizeof(context));
            if(context_rc==0 && strcmp(context,"table")==0) {
                char boot_result[512]={0};
                int boot_rc=run_lua(L,kLuaBootstrap,"=LuaHookV3Bootstrap",boot_result,sizeof(boot_result));
                lua_hook_log("bootstrap rc=%d result=%s",boot_rc,boot_result);
                if(boot_rc==0) {
                    char newstatus[256]={0};
                    int check_rc=run_lua(L,"local m=_MOD; if type(m)~='table' then return 'ABSENT' end; return 'READY addItem='..type(m.addItem)..' tick='..type(m.tick)..' infEnergy='..type(m.infEnergy)", "=LuaHookV3Recheck",newstatus,sizeof(newstatus));
                    if(check_rc==0 && strstr(newstatus,"addItem=function") && strstr(newstatus,"tick=function")) {
                        __atomic_store_n(&bound_mod_state,L,__ATOMIC_RELEASE);
                        ready=1;
                        snprintf(status,sizeof(status),"%s",newstatus);
                        lua_hook_log("bootstrap ready; bound Lua state=%p", (void*)L);
                    } else lua_hook_log("bootstrap did not expose required functions: rc=%d %s",check_rc,newstatus);
                }
            }
        }
        if(ready && __atomic_load_n(&bound_mod_state,__ATOMIC_ACQUIRE)==NULL)
            __atomic_store_n(&bound_mod_state,L,__ATOMIC_RELEASE);
        if(rc || last_mod_state!=(ready?1:0)) lua_hook_log("preflight rc=%d %s",rc,status);
        last_mod_state=ready?1:0;
        __atomic_store_n(&mod_status,ready?2:1,__ATOMIC_RELEASE);
        if(ready && (!next_mod_tick_ns || now>=next_mod_tick_ns)) {
            next_mod_tick_ns=now+10000000000ULL; // 10 seconds, on the Lua call thread
            char tick_result[256]={0};
            int tick_rc=run_lua(L,"if type(_MOD)=='table' and type(_MOD.tick)=='function' then _MOD.tick(); return 'OK' end return 'NOT_READY'", "=LuaHookV3Tick",tick_result,sizeof(tick_result));
            if(tick_rc) lua_hook_log("periodic tick failed: rc=%d %s",tick_rc,tick_result);
        }
        if(action) {
            int can_run=ready && ((action<=2 && strstr(status,"addItem=function")) || (action>=3 && strstr(status,"tick=function")));
            if (!can_run) {
                pthread_mutex_lock(&action_lock);
                if (pending_action==action) pending_action=0;
                pthread_mutex_unlock(&action_lock);
                lua_hook_log("action=%s cancelled: required _MOD function unavailable (%s)",action_name(action),status);
            }
            if(can_run) {
                // Take the queued command atomically. No execution before explicit request.
                pthread_mutex_lock(&action_lock);
                int claimed=pending_action==action;
                if(claimed) pending_action=0;
                pthread_mutex_unlock(&action_lock);
                if(claimed) {
                    const char *script=NULL;
                    switch(action) {
                        case 1:script="if type(_MOD)~=\"table\" or type(_MOD.addItem)~=\"function\" then return \"NOT_READY addItem\" end\n_MOD.addItem(\"gold\", 10)\nreturn \"EXECUTED addItem(gold,10)\"";break;
                        case 2:script="if type(_MOD)~=\"table\" or type(_MOD.addItem)~=\"function\" then return \"NOT_READY addItem\" end\n_MOD.addItem(\"gem\", 10)\nreturn \"EXECUTED addItem(gem,10)\"";break;
                        case 3:script="if type(_MOD)~=\"table\" or type(_MOD.tick)~=\"function\" then return \"NOT_READY tick\" end\n_MOD.infEnergy=true\n_MOD.tick()\nreturn \"EXECUTED infEnergy=true tick\"";break;
                        case 4:script="if type(_MOD)~=\"table\" or type(_MOD.tick)~=\"function\" then return \"NOT_READY tick\" end\n_MOD.infEnergy=false\n_MOD.tick()\nreturn \"EXECUTED infEnergy=false tick\"";break;
                    }
                    char response[512]={0};
                    int exec_rc=script?run_lua(L,script,"=LuaHookV3Action",response,sizeof(response)):-1;
                    lua_hook_log("action=%s lua_rc=%d result=%s",action_name(action),exec_rc,response);
                }
            }
        }
    }
    pthread_mutex_unlock(&probe_lock);
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

__attribute__((visibility("default"))) int LuaHookV3_RetryInstall(void) {
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

__attribute__((visibility("default"))) int LuaHookV3_IsInstalled(void) {
    return __atomic_load_n(&installed,__ATOMIC_RELAXED);
}
// Never attempt to patch executable code from the dyld image constructor.
// A bounded background retry covers UnityFramework/hook-runtime load ordering.
static void *install_worker(void *arg) {
    (void)arg;
    for (int attempt=1; attempt<=60; ++attempt) {
        if (LuaHookV3_RetryInstall()) {
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
    lua_hook_log("loaded, controlled V3; no automatic resource mutations");
    pthread_t worker;
    int err = pthread_create(&worker, NULL, install_worker, NULL);
    if (err == 0) pthread_detach(worker);
    else lua_hook_log("worker thread creation failed: %d", err);
}
