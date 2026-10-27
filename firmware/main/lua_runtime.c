// ABOUTME: The Lua task: runs the Fennel-compiled firmware logic on queued Bluetooth events.
// ABOUTME: Mounts the "assets" LittleFS partition and loads modules from it with require().

#include "lua_runtime.h"

#include <stdbool.h>
#include <stdio.h>

#include "esp_heap_caps.h"
#include "esp_littlefs.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"

#include "lauxlib.h"
#include "lualib.h"

#include "events.h"
#include "leds.h"

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

// Prints the error on top of the stack and clears the stack.
static void report_error(lua_State *L, const char *step)
{
    const char *message = lua_tostring(L, -1);
    printf("lua-error step=%s message=\"%s\"\n", step,
           message != NULL ? message : "(non-string error)");
    lua_settop(L, 0);
}

static lua_State *start(void)
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

static void selfcheck(lua_State *L)
{
    if (luaL_dostring(L, "return require('sendo.selfcheck').run()") != LUA_OK) {
        report_error(L, "selfcheck");
        return;
    }
    printf("%s free-heap=%u\n", lua_tostring(L, -1),
           (unsigned)heap_caps_get_free_size(MALLOC_CAP_DEFAULT));
    lua_settop(L, 0);
}

// Returns a registry reference to the callbacks table of sendo.firmware, or LUA_NOREF.
static int load_firmware(lua_State *L)
{
    // require returns the module and its loader data: keep only the module.
    if (luaL_dostring(L, "local leds = require('leds') "
                         "return require('sendo.firmware').start(leds)") != LUA_OK) {
        report_error(L, "firmware");
        return LUA_NOREF;
    }
    return luaL_ref(L, LUA_REGISTRYINDEX);
}

static void dispatch(lua_State *L, int firmware, const event_t *event)
{
    lua_rawgeti(L, LUA_REGISTRYINDEX, firmware);
    if (event->type == EVENT_RECEIVED) {
        lua_getfield(L, -1, "received");
        lua_pushinteger(L, event->conn);
        lua_pushlstring(L, (const char *)event->data, event->len);
        if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
            report_error(L, "received");
        }
    } else {
        lua_getfield(L, -1, "disconnected");
        lua_pushinteger(L, event->conn);
        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            report_error(L, "disconnected");
        }
    }
    lua_settop(L, 0);
}

void lua_runtime_task(void *queue)
{
    lua_State *L = start();
    if (L != NULL) {
        selfcheck(L);
    }
    int firmware = LUA_NOREF;
    if (L != NULL && leds_init() == ESP_OK) {
        leds_register(L);
        firmware = load_firmware(L);
    }
    printf("lua-ready firmware=%s stack-free=%u\n", firmware != LUA_NOREF ? "yes" : "no",
           (unsigned)uxTaskGetStackHighWaterMark(NULL));

    // Static: an event is over 512 bytes, too big for the task stack.
    static event_t event;
    for (;;) {
        if (xQueueReceive((QueueHandle_t)queue, &event, portMAX_DELAY) == pdTRUE
                && firmware != LUA_NOREF) {
            dispatch(L, firmware, &event);
        }
    }
}
