#include "TaylorResourceMenu.h"
#include "ResourceOperation.h"
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <limits.h>

extern int DobbyHook(void *, void *, void **);
typedef struct lua_State lua_State;
typedef void (*tick_fn)(void *, const void *);
typedef int (*load_fn)(lua_State *, const char *, int, const char *);
typedef int (*pcall_fn)(lua_State *, int, int, int);
typedef int (*top_fn)(lua_State *);
typedef void (*settop_fn)(lua_State *, int);
typedef const char *(*string_fn)(lua_State *, int, size_t *);
static tick_fn original_tick;
static load_fn load_buffer;
static pcall_fn protected_call;
static top_fn get_top;
static settop_fn set_top;
static string_fn to_string;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static char status_text[768] = "等待 UnityFramework";
static int installed, enabled = 1, pending, resource_id, quantity;
static uint64_t pending_at, next_probe;
static __thread int servicing;
static const uint8_t target_uuid[16] = {
  0xCC,0x89,0xF3,0xE2,0xE2,0x88,0x3F,0xBF,0xAB,0x96,0x1F,0xD4,0xE5,0x8F,0x04,0x7A
};
static uint64_t now_ns(void) {
  struct timespec t;
  if (clock_gettime(CLOCK_MONOTONIC, &t)) return 0;
  return (uint64_t)t.tv_sec * 1000000000ULL + (uint64_t)t.tv_nsec;
}
static void log_line(const char *s) {
  const char *home = getenv("HOME");
  if (!home || home[0] != '/') return;
  char path[PATH_MAX];
  int n = snprintf(path, sizeof(path), "%s/Documents/TaylorResourceMenu.log", home);
  if (n <= 0 || (size_t)n >= sizeof(path)) return;
  int fd = open(path, O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC|O_NOFOLLOW, 0600);
  if (fd < 0) return;
  (void)write(fd, s, strlen(s)); (void)write(fd, "\n", 1); close(fd);
}
static void report(const char *s, int record) {
  pthread_mutex_lock(&lock);
  int changed = strcmp(status_text, s) != 0;
  snprintf(status_text, sizeof(status_text), "%s", s);
  if (record && changed) log_line(s);
  pthread_mutex_unlock(&lock);
}
int TaylorResourceRequest(int id, int amount) {
  pthread_mutex_lock(&lock);
  int ok = installed && enabled && !pending && id >= 0 && id <= 3
        && ((id == 0 && amount == 0) || (id != 0 && amount >= 1 && amount <= 100));
  if (ok) {
    pending = 1; resource_id = id; quantity = amount; pending_at = now_ns();
    snprintf(status_text, sizeof(status_text), "已排队，等待游戏 Lua Tick");
  }
  pthread_mutex_unlock(&lock);
  return ok;
}
void TaylorResourceStatus(char *out, size_t cap) {
  if (!out || !cap) return;
  pthread_mutex_lock(&lock);
  if (pending && now_ns() - pending_at > 10000000000ULL) {
    pending = 0;
    snprintf(status_text, sizeof(status_text), "请求超时并已取消，请进入游戏后重试");
    log_line(status_text);
  }
  snprintf(out, cap, "%s", status_text);
  pthread_mutex_unlock(&lock);
}
static int run_operation(lua_State *L, int id, int amount, char *out, size_t cap) {
  // Every path restores the exact original stack height. No Lua object/state is retained.
  int top = get_top(L);
  char script[8192];
  int n = snprintf(script, sizeof(script), kResourceOperation, id, amount);
  if (n < 0 || (size_t)n >= sizeof(script)) {
    snprintf(out, cap, "ERROR|脚本长度错误"); return -1;
  }
  int rc = load_buffer(L, script, n, "@TaylorResourceMenuV1");
  if (!rc) rc = protected_call(L, 0, 1, 0);
  size_t length = 0;
  const char *value = to_string(L, -1, &length);
  if (value) snprintf(out, cap, "%.*s", (int)(length < cap-1 ? length : cap-1), value);
  else snprintf(out, cap, "ERROR|Lua 未返回状态文本（rc=%d）", rc);
  set_top(L, top);
  return rc;
}
static void hooked_tick(void *self, const void *method) {
  if (!original_tick) return;
  original_tick(self, method);
  // Capture nothing across calls. Tick is the host lifecycle boundary, after normal GC work.
  if (!self || servicing || !pthread_main_np()) return;
  uint64_t now = now_ns();
  pthread_mutex_lock(&lock);
  if (!enabled || !installed || (now < next_probe && !pending)) {
    pthread_mutex_unlock(&lock); return;
  }
  if (pending && now - pending_at > 10000000000ULL) {
    pending = 0;
    snprintf(status_text, sizeof(status_text), "请求超时并已取消");
  }
  int requested = pending;
  int id = requested ? resource_id : 0, amount = requested ? quantity : 0;
  uint64_t request_at = pending_at;
  next_probe = now + 1000000000ULL;
  pthread_mutex_unlock(&lock);
  lua_State *L = *(lua_State **)((uint8_t *)self + 0x10);
  if (!L) return;
  servicing = 1;
  char reply[768];
  // First check THIS environment; another LuaEnv cannot consume a resource request.
  int rc = run_operation(L, 0, 0, reply, sizeof(reply));
  int ready = !rc && !strncmp(reply, "READY|", 6);
  if (ready && requested) {
    pthread_mutex_lock(&lock);
    // A concurrent UI timeout/replacement cannot resurrect an expired command.
    int execute = pending && pending_at == request_at && resource_id == id && quantity == amount
               && now_ns() - pending_at <= 10000000000ULL;
    if (execute) pending = 0;
    pthread_mutex_unlock(&lock);
    if (execute) {
      rc = run_operation(L, id, amount, reply, sizeof(reply));
      report(reply, 1);
    }
  } else if (!requested) {
    // Keep action feedback visible for five seconds, then resume live balance polling.
    pthread_mutex_lock(&lock);
    int show = now >= pending_at + 5000000000ULL;
    pthread_mutex_unlock(&lock);
    if (show) report(reply, 0);
  } else if (!strncmp(reply, "BLOCKED|", 8)) {
    pthread_mutex_lock(&lock); pending = 0; pthread_mutex_unlock(&lock);
    report(reply, 1);
  }
  servicing = 0;
}
static int matching_image(const struct mach_header_64 *h) {
  if (!h || h->magic != MH_MAGIC_64 || h->cputype != CPU_TYPE_ARM64) return 0;
  const uint8_t *p = (const uint8_t *)(h+1), *end = p + h->sizeofcmds;
  for (uint32_t i=0; i<h->ncmds; i++) {
    if ((size_t)(end-p) < sizeof(struct load_command)) return 0;
    const struct load_command *c = (const struct load_command *)p;
    if (c->cmdsize < sizeof(*c) || c->cmdsize > (size_t)(end-p)) return 0;
    if (c->cmd == LC_UUID && c->cmdsize >= sizeof(struct uuid_command))
      return !memcmp(((const struct uuid_command *)c)->uuid, target_uuid, 16);
    p += c->cmdsize;
  }
  return 0;
}
static int install_once(void) {
  for (uint32_t i=0; i<_dyld_image_count(); i++) {
    const char *name = _dyld_get_image_name(i);
    if (!name || !strstr(name, "/UnityFramework.framework/UnityFramework")) continue;
    const struct mach_header_64 *h = (const struct mach_header_64 *)_dyld_get_image_header(i);
    if (!matching_image(h)) { report("版本不匹配，资源功能已停用", 1); return -1; }
    uintptr_t b = (uintptr_t)h;
    static const uint8_t signature[] = {0xff,0x03,0x02,0xd1,0xf6,0x57,0x05,0xa9,0xf4,0x4f,0x06,0xa9,0xfd,0x7b,0x07,0xa9};
    if (memcmp((void *)(b+0x3B65878), signature, sizeof(signature))) {
      report("Tick 指令不匹配，资源功能已停用", 1); return -1;
    }
    load_buffer = (load_fn)(b+0x328EF4C);
    protected_call = (pcall_fn)(b+0x328EE04);
    get_top = (top_fn)(b+0x3246608);
    set_top = (settop_fn)(b+0x3246624);
    to_string = (string_fn)(b+0x3247518);
    int rc = DobbyHook((void *)(b+0x3B65878), (void *)hooked_tick, (void **)&original_tick);
    if (rc || !original_tick) { report("Hook 安装失败，查看 TaylorResourceMenu.log", 1); return -1; }
    pthread_mutex_lock(&lock); installed = 1; pthread_mutex_unlock(&lock);
    report("已接入，等待游戏资源初始化", 1); return 1;
  }
  return 0;
}
static void *install_worker(void *unused) {
  (void)unused;
  for (int i=0; i<120; i++) {
    if (install_once()) return NULL;
    const struct timespec t = {0, 500000000L}; nanosleep(&t, NULL);
  }
  report("60秒内未发现目标 UnityFramework", 1); return NULL;
}
// Disable cancels pending requests; the inert trampoline remains until app exit.
__attribute__((visibility("default"))) void TaylorResourceDisable(void) {
  pthread_mutex_lock(&lock); enabled = 0; pending = 0; pthread_mutex_unlock(&lock);
  report("资源菜单已停用，重启游戏可恢复", 1);
}
__attribute__((constructor)) static void start_runtime(void) {
  pthread_t tid;
  if (!pthread_create(&tid, NULL, install_worker, NULL)) pthread_detach(tid);
  else report("初始化线程创建失败", 1);
}
