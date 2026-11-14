#include "PetsResourceMenu.h"
#include "ResourceOperation.h"
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <limits.h>
#include <time.h>
#include <unistd.h>

extern int DobbyHook(void *, void *, void **);
typedef struct MethodInfo MethodInfo;
typedef void (*tick_fn)(void *, const MethodInfo *);
typedef struct { void *klass, *monitor, *bounds; uintptr_t length; void *items[]; } ObjectArray;
// IL2CPP public exports. All pointers are resolved by name from the loaded runtime.
static void *(*domain_get)(void);
static const void **(*domain_assemblies)(const void *, size_t *);
static const void *(*assembly_image)(const void *);
static void *(*class_from_name)(const void *, const char *, const char *);
static const MethodInfo *(*class_methods)(void *, void **);
static const char *(*method_name)(const MethodInfo *);
static uint32_t (*method_param_count)(const MethodInfo *);
static const void *(*method_param)(const MethodInfo *, uint32_t);
static char *(*type_name)(const void *);
static void (*runtime_free)(void *);
static void *(*runtime_invoke)(const MethodInfo *, void *, void **, void **);
static void *(*string_new)(const char *);
static const uint16_t *(*string_chars)(void *);
static int32_t (*string_length)(void *);
static uintptr_t (*array_length)(void *);
static void *(*thread_attach)(void *);
static void (*thread_detach)(void *);
static void (*format_exception)(void *, char *, int);
static const void *(*get_corlib)(void);
static void *(*object_class)(void *);
static void *string_class;
static const MethodInfo *do_string_method;
static tick_fn original_tick;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static int installed, enabled = 1, pending, resource_id, quantity;
static uint64_t pending_at, next_probe;
static char status_text[768] = "等待 IL2CPP 初始化";
static __thread int servicing;

static uint64_t now_ns(void) {
  struct timespec t;
  if (clock_gettime(CLOCK_MONOTONIC, &t)) return 0;
  return (uint64_t)t.tv_sec*1000000000ULL+(uint64_t)t.tv_nsec;
}
static void log_line(const char *s) {
  const char *home=getenv("HOME");
  if (!home || home[0]!='/') return;
  char path[PATH_MAX];
  int n=snprintf(path,sizeof(path),"%s/Documents/PetsResourceMenu.log",home);
  if (n<=0 || (size_t)n>=sizeof(path)) return;
  int fd=open(path,O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC|O_NOFOLLOW,0600);
  if (fd<0) return;
  (void)write(fd,s,strlen(s)); (void)write(fd,"\n",1); close(fd);
}
static void report(const char *s, int record) {
  pthread_mutex_lock(&lock);
  int changed=strcmp(status_text,s)!=0;
  snprintf(status_text,sizeof(status_text),"%s",s);
  if (record && changed) log_line(s);
  pthread_mutex_unlock(&lock);
}
int PetsResourceRequest(int id,int amount) {
  pthread_mutex_lock(&lock);
  int ok=installed && enabled && !pending && id>=0 && id<=3
      && ((id==0 && amount==0) || (id>0 && amount>=1 && amount<=100));
  if (ok) {
    pending=1; resource_id=id; quantity=amount; pending_at=now_ns();
    snprintf(status_text,sizeof(status_text),"已排队，等待游戏 Lua Tick");
  }
  pthread_mutex_unlock(&lock); return ok;
}
void PetsResourceStatus(char *out,size_t cap) {
  if (!out || !cap) return;
  pthread_mutex_lock(&lock);
  if (pending && now_ns()-pending_at>10000000000ULL) {
    pending=0; snprintf(status_text,sizeof(status_text),"请求超时并已取消，请进入游戏后重试");
    log_line(status_text);
  }
  snprintf(out,cap,"%s",status_text);
  pthread_mutex_unlock(&lock);
}
static void copy_string(void *s,char *out,size_t cap) {
  if (!cap) return;
  out[0]=0;
  const uint16_t *chars=string_chars(s);
  int32_t count=string_length(s); size_t pos=0;
  for (int32_t i=0; i<count; i++) {
    uint32_t c=chars[i];
    if (c>=0xD800 && c<=0xDBFF && i+1<count && chars[i+1]>=0xDC00 && chars[i+1]<=0xDFFF)
      c=0x10000+((c-0xD800)<<10)+(chars[++i]-0xDC00);
    else if (c>=0xD800 && c<=0xDFFF) c=0xFFFD;
    unsigned char bytes[4]; size_t n;
    if (c<0x80) { bytes[0]=(unsigned char)c; n=1; }
    else if (c<0x800) { bytes[0]=0xC0|(c>>6); bytes[1]=0x80|(c&63); n=2; }
    else if (c<0x10000) { bytes[0]=0xE0|(c>>12); bytes[1]=0x80|((c>>6)&63); bytes[2]=0x80|(c&63); n=3; }
    else { bytes[0]=0xF0|(c>>18); bytes[1]=0x80|((c>>12)&63); bytes[2]=0x80|((c>>6)&63); bytes[3]=0x80|(c&63); n=4; }
    if (pos+n>=cap) break;
    memcpy(out+pos,bytes,n); pos+=n;
  }
  out[pos]=0;
}
static int run_operation(void *env,int id,int amount,char *out,size_t cap) {
  char script[8192];
  int n=snprintf(script,sizeof(script),kResourceOperation,id,amount);
  if (n<0 || (size_t)n>=sizeof(script)) { snprintf(out,cap,"ERROR|脚本长度错误"); return -1; }
  // Reference-type arguments are object pointers, not pointers to stack slots.
  // Use managed DoString so the host owns locking, error handling and stack restoration.
  void *args[3]={string_new(script),string_new("@PetsResourceMenuV1"),NULL};
  void *exception=NULL;
  ObjectArray *result=(ObjectArray *)runtime_invoke(do_string_method,env,args,&exception);
  if (exception) {
    char detail[512]={0}; format_exception(exception,detail,(int)sizeof(detail));
    snprintf(out,cap,"ERROR|%.500s",detail); return -1;
  }
  if (!result || array_length(result)<1 || !result->items[0] || object_class(result->items[0])!=string_class) {
    snprintf(out,cap,"ERROR|Lua 未返回状态文本"); return -1;
  }
  copy_string(result->items[0],out,cap); return 0;
}
static void hooked_tick(void *self,const MethodInfo *method) {
  if (!original_tick) return;
  original_tick(self,method);
  if (!self || servicing || !pthread_main_np()) return;
  uint64_t now=now_ns();
  pthread_mutex_lock(&lock);
  if (!installed || !enabled || (now<next_probe && !pending)) { pthread_mutex_unlock(&lock); return; }
  if (pending && now-pending_at>10000000000ULL) {
    pending=0; snprintf(status_text,sizeof(status_text),"请求超时并已取消");
  }
  int requested=pending, id=requested?resource_id:0, amount=requested?quantity:0;
  uint64_t request_at=pending_at;
  next_probe=now+1000000000ULL; pthread_mutex_unlock(&lock);
  servicing=1;
  char reply[768];
  int rc=run_operation(self,0,0,reply,sizeof(reply));
  if (!rc && !strncmp(reply,"READY|",6) && requested) {
    pthread_mutex_lock(&lock);
    int execute=pending && enabled && pending_at==request_at && resource_id==id && quantity==amount
               && now_ns()-pending_at<=10000000000ULL;
    if (execute) pending=0;
    pthread_mutex_unlock(&lock);
    if (execute) { (void)run_operation(self,id,amount,reply,sizeof(reply)); report(reply,1); }
  } else if (!requested) {
    pthread_mutex_lock(&lock); int show=now>=pending_at+5000000000ULL; pthread_mutex_unlock(&lock);
    if (show) report(reply,0);
  } else if (rc) {
    pthread_mutex_lock(&lock);
    if (pending_at==request_at) pending=0;
    pthread_mutex_unlock(&lock);
    report(reply,1);
  }
  servicing=0;
}
static int resolve_exports(void *handle) {
#define API(variable,name) do { *(void **)(&variable)=dlsym(handle,name); if (!(variable)) return 0; } while(0)
  API(domain_get,"il2cpp_domain_get"); API(domain_assemblies,"il2cpp_domain_get_assemblies");
  API(assembly_image,"il2cpp_assembly_get_image"); API(class_from_name,"il2cpp_class_from_name");
  API(class_methods,"il2cpp_class_get_methods"); API(method_name,"il2cpp_method_get_name");
  API(method_param_count,"il2cpp_method_get_param_count"); API(method_param,"il2cpp_method_get_param");
  API(type_name,"il2cpp_type_get_name"); API(runtime_free,"il2cpp_free");
  API(runtime_invoke,"il2cpp_runtime_invoke"); API(string_new,"il2cpp_string_new");
  API(string_chars,"il2cpp_string_chars"); API(string_length,"il2cpp_string_length");
  API(array_length,"il2cpp_array_length"); API(thread_attach,"il2cpp_thread_attach");
  API(thread_detach,"il2cpp_thread_detach"); API(format_exception,"il2cpp_format_exception");
  API(get_corlib,"il2cpp_get_corlib"); API(object_class,"il2cpp_object_get_class");
#undef API
  return 1;
}
static int locate_and_hook(void *domain) {
  size_t count=0;
  const void **assemblies=domain_assemblies(domain,&count);
  void *lua_env_class=NULL;
  for (size_t i=0; i<count && !lua_env_class; i++)
    lua_env_class=class_from_name(assembly_image(assemblies[i]),"XLua","LuaEnv");
  if (!lua_env_class) return 0;
  string_class=class_from_name(get_corlib(),"System","String");
  if (!string_class) return 0;
  void *iter=NULL;
  const MethodInfo *m, *tick_method=NULL;
  while ((m=class_methods(lua_env_class,&iter))) {
    const char *name=method_name(m); uint32_t params=method_param_count(m);
    if (!strcmp(name,"Tick") && params==0) tick_method=m;
    if (!strcmp(name,"DoString") && params==3) {
      char *name0=type_name(method_param(m,0));
      if (name0 && !strcmp(name0,"System.String")) do_string_method=m;
      if (name0) runtime_free(name0);
    }
  }
  if (!tick_method || !do_string_method) return 0;
  // Target IL2CPP MethodInfo begins with methodPointer; no version/identity offset table.
  void *entry=*(void * const *)tick_method;
  if (!entry) return 0;
  int rc=DobbyHook(entry,(void *)hooked_tick,(void **)&original_tick);
  if (rc || !original_tick) { report("Hook 安装失败，查看 PetsResourceMenu.log",1); return -1; }
  pthread_mutex_lock(&lock); installed=1; pthread_mutex_unlock(&lock);
  report("已接入 LuaEnv，等待游戏资源初始化",1); return 1;
}
static void *install_worker(void *unused) {
  (void)unused;
  void *runtime_handle=NULL;
  for (unsigned attempt=0; attempt<240; attempt++) {
    if (!runtime_handle) {
      for (uint32_t i=0; i<_dyld_image_count(); i++) {
        const char *path=_dyld_get_image_name(i);
        if (!path) continue;
        void *candidate=dlopen(path,RTLD_LAZY|RTLD_NOLOAD);
        if (candidate && resolve_exports(candidate)) { runtime_handle=candidate; break; }
        if (candidate) dlclose(candidate);
      }
    }
    if (runtime_handle) {
      void *domain=domain_get();
      if (domain) {
        void *thread=thread_attach(domain);
        if (thread) {
          int rc=locate_and_hook(domain);
          thread_detach(thread);
          if (rc) return NULL;
        }
      }
    }
    const struct timespec t={0,500000000L}; nanosleep(&t,NULL);
  }
  report("等待 IL2CPP / LuaEnv 超时，可重启游戏后重试",1); return NULL;
}
__attribute__((visibility("default"))) void PetsResourceDisable(void) {
  pthread_mutex_lock(&lock); enabled=0; pending=0; pthread_mutex_unlock(&lock);
  report("资源菜单已停用，重启游戏可恢复",1);
}
__attribute__((constructor)) static void start_runtime(void) {
  pthread_t tid;
  if (!pthread_create(&tid,NULL,install_worker,NULL)) pthread_detach(tid);
  else report("初始化线程创建失败",1);
}
