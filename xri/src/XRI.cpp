#include "XRI.h"

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

namespace {
std::mutex g_snapshot_mutex;

struct Export {
    const char *name;
    bool found = false;
    std::string image;
    uintptr_t rva = 0;
};

struct Image {
    std::string path;
    std::string uuid;
    uintptr_t base = 0;
    intptr_t slide = 0;
};

constexpr const char *kExports[] = {
    "xluaL_loadbuffer", "luaL_loadbufferx", "luaL_loadbuffer",
    "lua_pcallk", "lua_pcall", "lua_newstate", "luaL_newstate",
    "lua_close", "il2cpp_domain_get", "il2cpp_thread_attach",
    "il2cpp_assembly_get_image", "il2cpp_class_from_name"
};

bool isCandidate(const char *path) {
    if (!path) return false;
    return std::strstr(path, "UnityFramework") ||
           std::strstr(path, "GameAssembly") ||
           std::strstr(path, "xlua") ||
           std::strstr(path, "XLua") ||
           std::strstr(path, "liblua") ||
           std::strstr(path, "Lua");
}

std::string uuidForImage(const mach_header *header) {
    if (!header || header->magic != MH_MAGIC_64) return {};
    const auto *mh = reinterpret_cast<const mach_header_64 *>(header);
    const auto *command = reinterpret_cast<const uint8_t *>(mh) + sizeof(mach_header_64);
    // The OS loader validated mapped commands; still reject malformed cmd sizes.
    size_t remaining = mh->sizeofcmds;
    for (uint32_t i = 0; i < mh->ncmds; ++i) {
        if (remaining < sizeof(load_command)) break;
        const auto *lc = reinterpret_cast<const load_command *>(command);
        if (lc->cmdsize < sizeof(load_command) || lc->cmdsize > remaining) break;
        if (lc->cmd == LC_UUID && lc->cmdsize >= sizeof(uuid_command)) {
            const auto *u = reinterpret_cast<const uuid_command *>(command);
            char buffer[37];
            std::snprintf(buffer, sizeof(buffer),
                "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                u->uuid[0],u->uuid[1],u->uuid[2],u->uuid[3],
                u->uuid[4],u->uuid[5],u->uuid[6],u->uuid[7],
                u->uuid[8],u->uuid[9],u->uuid[10],u->uuid[11],
                u->uuid[12],u->uuid[13],u->uuid[14],u->uuid[15]);
            return buffer;
        }
        command += lc->cmdsize;
        remaining -= lc->cmdsize;
    }
    return {};
}

std::string escape(const std::string &s) {
    static const char *hex = "0123456789ABCDEF";
    std::string result;
    result.reserve(s.size() + 8);
    for (unsigned char c : s) {
        switch (c) {
            case '"': result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case '\n': result += "\\n"; break;
            case '\r': result += "\\r"; break;
            case '\t': result += "\\t"; break;
            default:
                if (c < 0x20) {
                    result += "\\u00";
                    result += hex[c >> 4];
                    result += hex[c & 0xF];
                } else {
                    result += static_cast<char>(c);
                }
        }
    }
    return result;
}

std::string hexNumber(uintptr_t number) {
    char buf[2 + sizeof(uintptr_t) * 2 + 1];
    std::snprintf(buf, sizeof(buf), "0x%llx",
                  static_cast<unsigned long long>(number));
    return buf;
}

std::string capture() {
    std::vector<Image> images;
    std::vector<Export> exports;
    for (const char *name : kExports) exports.push_back({name, false, {}, 0});

    const uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; ++i) {
        const char *path = _dyld_get_image_name(i);
        const mach_header *mh = _dyld_get_image_header(i);
        if (!path || !mh || !isCandidate(path)) continue;

        Image image;
        image.path = path;
        image.uuid = uuidForImage(mh);
        image.base = reinterpret_cast<uintptr_t>(mh);
        image.slide = _dyld_get_image_vmaddr_slide(i);
        images.push_back(image);

        // RTLD_NOLOAD never loads a new library just to inspect it.
        void *handle = dlopen(path, RTLD_NOW | RTLD_NOLOAD);
        if (!handle) continue;
        for (auto &symbol : exports) {
            if (symbol.found) continue;
            void *addr = dlsym(handle, symbol.name);
            if (!addr) continue;
            Dl_info info = {};
            // dlsym can resolve symbols from dependencies. Require same image.
            if (!dladdr(addr, &info) || info.dli_fbase != mh) continue;
            symbol.found = true;
            symbol.image = image.path;
            symbol.rva = reinterpret_cast<uintptr_t>(addr) - image.base;
        }
        dlclose(handle);
    }

    bool lua = false, xlua = false, il2cpp = false;
    for (const auto &symbol : exports) {
        if (!symbol.found) continue;
        if (std::strncmp(symbol.name, "lua", 3) == 0) lua = true;
        if (std::strncmp(symbol.name, "xlua", 4) == 0) xlua = true;
        if (std::strncmp(symbol.name, "il2cpp_", 7) == 0) il2cpp = true;
    }

    std::string out = R"({"schemaVersion":1,"module":"XRI","version":"0.1.0-p1",)";
    out += R"("mode":"read-only","capabilities":{"imageScan":true,"exportResolution":true,"luaVmTracking":false,"hookInstallation":false},)";
    out += "\"detected\":{\"lua\":" + std::string(lua ? "true" : "false") +
           ",\"xlua\":" + (xlua ? "true" : "false") +
           ",\"il2cpp\":" + (il2cpp ? "true" : "false") + "},";
    out += "\"images\":[";
    for (size_t i = 0; i < images.size(); ++i) {
        if (i) out += ",";
        const auto &im = images[i];
        out += "{\"path\":\"" + escape(im.path) + "\",\"uuid\":\"" + escape(im.uuid) +
               "\",\"loadAddress\":\"" + hexNumber(im.base) +
               "\",\"slide\":\"" + hexNumber(static_cast<uintptr_t>(im.slide)) + "\"}";
    }
    out += "],\"exports\":[";
    for (size_t i = 0; i < exports.size(); ++i) {
        if (i) out += ",";
        const auto &symbol = exports[i];
        out += "{\"name\":\"" + std::string(symbol.name) +
               "\",\"found\":" + (symbol.found ? "true" : "false");
        if (symbol.found) {
            out += ",\"image\":\"" + escape(symbol.image) +
                   "\",\"loadRelativeOffset\":\"" + hexNumber(symbol.rva) + "\"";
        }
        out += "}";
    }
    out += "]}";
    return out;
}
}  // namespace

extern "C" __attribute__((visibility("default")))
const char *xri_version(void) {
    return "0.1.0-p1";
}

extern "C" __attribute__((visibility("default")))
size_t xri_snapshot_json(char *output, size_t capacity) {
    std::lock_guard<std::mutex> lock(g_snapshot_mutex);
    const std::string result = capture();
    const size_t required = result.size() + 1;
    if (output && capacity >= required) {
        std::memcpy(output, result.c_str(), required);
    }
    return required;
}
