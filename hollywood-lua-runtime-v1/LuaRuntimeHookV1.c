// Read-only Lua runtime probe. No game currency or energy mutation.
#include <dlfcn.h>
#include <pthread.h>
#include <stddef.h>
#include <stdio.h>

typedef struct lua_State lua_State;
typedef int (*pcall_t)(lua_State*,int,int,int);
typedef int (*load_t)(lua_State*,const char*,size_t,const char*);
typedef int (*gettop_t)(lua_State*);
typedef void (*settop_t)(lua_State*,int);
typedef const char* (*tolstring_t)(lua_State*,int,size_t*);
typedef void (*substrate_t)(void*,void*,void**);
typedef int (*dobby_t)(void*,void*,void**);

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
        fprintf(stderr,"[LuaHookV1] probe failed: %d %s\n",rc,error?error:"(none)");
    } else fprintf(stderr,"[LuaHookV1] read-only probe executed\n");
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

static void *get_symbol(void *h,const char *symbol) {
    void *p=h?dlsym(h,symbol):NULL;
    return p?p:dlsym(RTLD_DEFAULT,symbol);
}

__attribute__((visibility("default"))) int LuaHookV1_RetryInstall(void) {
    pthread_mutex_lock(&install_lock);
    if(installed) {pthread_mutex_unlock(&install_lock); return 1;}
    void *unity=dlopen("@rpath/UnityFramework.framework/UnityFramework",RTLD_NOW|RTLD_NOLOAD);
    void *target=get_symbol(unity,"lua_pcall");
    lua_loadbuffer=(load_t)get_symbol(unity,"luaL_loadbuffer");
    lua_gettop=(gettop_t)get_symbol(unity,"lua_gettop");
    lua_settop=(settop_t)get_symbol(unity,"lua_settop");
    lua_tolstring=(tolstring_t)get_symbol(unity,"lua_tolstring");
    if(!target||!lua_loadbuffer||!lua_gettop||!lua_settop) {
        fprintf(stderr,"[LuaHookV1] Lua API unavailable\n");
        pthread_mutex_unlock(&install_lock); return 0;
    }
    substrate_t substrate=(substrate_t)dlsym(RTLD_DEFAULT,"MSHookFunction");
    dobby_t dobby=(dobby_t)dlsym(RTLD_DEFAULT,"DobbyHook");
    if(!substrate&&!dobby) {
        fprintf(stderr,"[LuaHookV1] no supported inline hook runtime\n");
        pthread_mutex_unlock(&install_lock); return 0;
    }
    int result=0;
    if(substrate) substrate(target,(void*)hooked_pcall,(void**)&original_pcall);
    else result=dobby(target,(void*)hooked_pcall,(void**)&original_pcall);
    if(result!=0 || !original_pcall) {
        fprintf(stderr,"[LuaHookV1] install failed\n");
        pthread_mutex_unlock(&install_lock); return 0;
    }
    installed=1;
    fprintf(stderr,"[LuaHookV1] installed pcall=%p original=%p\n",target,(void*)original_pcall);
    pthread_mutex_unlock(&install_lock); return 1;
}

__attribute__((visibility("default"))) int LuaHookV1_IsInstalled(void) {
    return __atomic_load_n(&installed,__ATOMIC_RELAXED);
}
__attribute__((constructor)) static void init(void) {
    fprintf(stderr,"[LuaHookV1] loaded, diagnostic only\n");
    (void)LuaHookV1_RetryInstall();
}
