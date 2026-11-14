#include <dlfcn.h>
#include <fcntl.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#define TARGET_RVA ((uintptr_t)0x3A195FC)
static const uint8_t uuid[16]={0xCC,0x89,0xF3,0xE2,0xE2,0x88,0x3F,0xBF,0xAB,0x96,0x1F,0xD4,0xE5,0x8F,0x04,0x7A};
typedef struct {void *klass,*monitor;int32_t length;uint16_t chars[];} IString;
typedef struct {void *klass,*monitor,*bounds;uintptr_t length;uint8_t data[];} IByteArray;
typedef IByteArray *(*loader_t)(void*,IString**,const void*);
typedef void (*substrate_t)(void*,void*,void**);
typedef int (*dobby_t)(void*,void*,void**);
static loader_t original;
static pthread_mutex_t loglock=PTHREAD_MUTEX_INITIALIZER;
static unsigned records;
static __thread int busy;
static void logmsg(const char *s) {
  const char *home=getenv("HOME");
  if(!home||*home!='/')return;
  char path[PATH_MAX];
  int n=snprintf(path,sizeof(path),"%s/Documents/TaylorLuaLoaderProbe.log",home);
  if(n<=0||(size_t)n>=sizeof(path))return;
  pthread_mutex_lock(&loglock);
  int fd=open(path,O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC|O_NOFOLLOW,0600);
  if(fd>=0){(void)write(fd,s,strlen(s));(void)write(fd,"\n",1);close(fd);}
  pthread_mutex_unlock(&loglock);
}
static void name_to_ascii(IString *s,char *dst,size_t cap) {
  if(!cap)return;
  dst[0]=0;
  if(!s){snprintf(dst,cap,"(null)");return;}
  if(s->length<0||s->length>32768){snprintf(dst,cap,"(invalid-length)");return;}
  size_t p=0;
  for(int32_t i=0;i<s->length&&p+3<cap;i++){
    uint16_t c=s->chars[i];
    dst[p++]=(c>=32&&c<=126)?(char)c:'?';
  }
  dst[p]=0;
}
static IByteArray *hook_loader(void *self,IString **name,const void *method) {
  if(!original)return NULL;
  if(busy)return original(self,name,method);
  busy=1;
  char before[192],after[192],msg[640],head[32]={0};
  name_to_ascii(name?*name:NULL,before,sizeof(before));
  IByteArray *ret=original(self,name,method);
  name_to_ascii(name?*name:NULL,after,sizeof(after));
  unsigned seq=__atomic_add_fetch(&records,1,__ATOMIC_RELAXED);
  if(seq<=3000){
    uintptr_t len=ret?ret->length:0;
    if(ret&&len<=128*1024*1024){
      size_t take=len<8?(size_t)len:8,off=0;
      for(size_t i=0;i<take;i++)
        off+=(size_t)snprintf(head+off,sizeof(head)-off,"%02x%s",ret->data[i],i+1==take?"":" ");
    }else if(ret)snprintf(head,sizeof(head),"invalid-length");
    snprintf(msg,sizeof(msg),"seq=%u name_before=%s name_after=%s result=%s bytes=%llu head=%s",
      seq,before,after,ret?"byte[]":"null",(unsigned long long)len,head);
    logmsg(msg);
  }
  busy=0;
  return ret;
}
static int uuid_ok(const struct mach_header_64 *hdr) {
  if(!hdr||hdr->magic!=MH_MAGIC_64)return 0;
  const uint8_t *p=(const uint8_t*)(hdr+1);
  for(uint32_t j=0;j<hdr->ncmds;j++){
    const struct load_command *lc=(const struct load_command*)p;
    if(lc->cmdsize<sizeof(*lc))return 0;
    if(lc->cmd==LC_UUID&&lc->cmdsize>=sizeof(struct uuid_command))
      return memcmp(((const struct uuid_command*)p)->uuid,uuid,16)==0;
    p+=lc->cmdsize;
  }
  return 0;
}
static int install(void) {
  for(uint32_t i=0;i<_dyld_image_count();i++){
    const char *path=_dyld_get_image_name(i);
    if(!path||!strstr(path,"/UnityFramework.framework/UnityFramework"))continue;
    const struct mach_header_64 *h=(const struct mach_header_64*)_dyld_get_image_header(i);
    if(!uuid_ok(h)){logmsg("disabled: UnityFramework UUID mismatch");return -1;}
    void *target=(void*)((uintptr_t)h+TARGET_RVA);
    substrate_t substrate=(substrate_t)dlsym(RTLD_DEFAULT,"MSHookFunction");
    dobby_t dobby=(dobby_t)dlsym(RTLD_DEFAULT,"DobbyHook");
    if(!substrate&&!dobby){logmsg("disabled: MSHookFunction/DobbyHook unavailable");return -1;}
    int rc=0;
    if(substrate)substrate(target,(void*)hook_loader,(void**)&original);
    else rc=dobby(target,(void*)hook_loader,(void**)&original);
    if(rc||!original){logmsg("disabled: install failed");return -1;}
    logmsg("installed CustomLuaLoader RVA=0x3A195FC, read-only");
    return 1;
  }
  return 0;
}
static void *worker(void *unused) {
  (void)unused;
  for(int i=0;i<60;i++){
    int rc=install();
    if(rc)return NULL;
    const struct timespec t={0,500000000L};
    nanosleep(&t,NULL);
  }
  logmsg("disabled: UnityFramework not loaded within 30 seconds");
  return NULL;
}
__attribute__((constructor)) static void init(void) {
  logmsg("loaded Taylor 1.8.9-69 read-only Lua loader observer");
  pthread_t tid;
  if(pthread_create(&tid,NULL,worker,NULL)==0)pthread_detach(tid);
  else logmsg("disabled: worker creation failed");
}
