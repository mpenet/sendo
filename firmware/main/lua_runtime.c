// ABOUTME: Starts the Lua runtime that runs the Fennel-compiled firmware logic.
// ABOUTME: Mounts the "assets" LittleFS partition and loads modules from it with require().

#include "lua_runtime.h"

#include <stdbool.h>
#include <stdio.h>

#include "esp_heap_caps.h"
#include "esp_littlefs.h"

#include "lauxlib.h"
#include "lualib.h"

#define ASSETS_PATH "/assets"

static bool mount_assets(void)
{
    esp_vfs_littlefs_conf_t conf = {
        .base_path = ASSETS_PATH,
        .partition_label = "assets",
        // The image is flashed with the firmware: formatting would wipe the Lua bundle.
        .format_if_mount_failed = false,
    };
    esp_err_t err = esp_vfs_littlefs_register(&conf);
    if (err != ESP_OK) {
        printf("lua-error step=mount err=%s\n", esp_err_to_name(err));
        return false;
    }
    return true;
}

// Opens only the libraries the bundle uses, matching `make bundle-check`.
static void open_libs(lua_State *L)
{
    static const luaL_Reg libs[] = {
        {LUA_GNAME, luaopen_base},
        {LUA_LOADLIBNAME, luaopen_package},
        {LUA_MATHLIBNAME, luaopen_math},
        {LUA_STRLIBNAME, luaopen_string},
        {LUA_TABLIBNAME, luaopen_table},
        {NULL, NULL},
    };
    for (const luaL_Reg *lib = libs; lib->func != NULL; lib++) {
        luaL_requiref(L, lib->name, lib->func, 1);
        lua_pop(L, 1);
    }
}

static void set_search_path(lua_State *L)
{
    lua_getglobal(L, "package");
    lua_pushstring(L, ASSETS_PATH "/?.lua");
    lua_setfield(L, -2, "path");
    lua_pop(L, 1);
}

lua_State *lua_runtime_start(void)
{
    if (!mount_assets()) {
        return NULL;
    }
    lua_State *L = luaL_newstate();
    if (L == NULL) {
        printf("lua-error step=newstate\n");
        return NULL;
    }
    open_libs(L);
    set_search_path(L);
    return L;
}

bool lua_runtime_selfcheck(lua_State *L)
{
    int rc = luaL_dostring(L, "return require('sendo.selfcheck').run()");
    if (rc != LUA_OK) {
        const char *message = lua_tostring(L, -1);
        printf("lua-error step=selfcheck message=\"%s\"\n", message != NULL ? message : "(non-string error)");
        lua_settop(L, 0);
        return false;
    }
    printf("%s free-heap=%u\n", lua_tostring(L, -1),
           (unsigned)heap_caps_get_free_size(MALLOC_CAP_DEFAULT));
    lua_settop(L, 0);
    return true;
}
