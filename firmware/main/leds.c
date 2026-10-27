// ABOUTME: Drives the WS2811 LED string and exposes it to Lua as the "leds" module.
// ABOUTME: Uses the led_strip RMT driver; changes only reach the string on show().

#include "leds.h"

#include <stdio.h>

#include "led_strip.h"

#include "lauxlib.h"

// 10 MHz: 0.1 us per tick, fine enough for WS2811 timings.
#define RMT_RESOLUTION_HZ (10 * 1000 * 1000)

static led_strip_handle_t strip = NULL;

esp_err_t leds_init(void)
{
    led_strip_config_t strip_config = {
        .strip_gpio_num = CONFIG_SENDO_LED_GPIO,
        .max_leds = CONFIG_SENDO_LED_COUNT,
        .led_model = LED_MODEL_WS2811,
#if CONFIG_SENDO_LED_ORDER_GRB
        .color_component_format = LED_STRIP_COLOR_COMPONENT_FMT_GRB,
#else
        .color_component_format = LED_STRIP_COLOR_COMPONENT_FMT_RGB,
#endif
    };
    led_strip_rmt_config_t rmt_config = {
        .clk_src = RMT_CLK_SRC_DEFAULT,
        .resolution_hz = RMT_RESOLUTION_HZ,
    };
    esp_err_t err = led_strip_new_rmt_device(&strip_config, &rmt_config, &strip);
    if (err != ESP_OK) {
        printf("leds-error step=init err=%s\n", esp_err_to_name(err));
        return err;
    }
    // Sends an all-off frame, so the string doesn't keep a stale picture after a reset.
    return led_strip_clear(strip);
}

static int push_result(lua_State *L, esp_err_t err)
{
    if (err != ESP_OK) {
        lua_pushboolean(L, false);
        lua_pushstring(L, esp_err_to_name(err));
        return 2;
    }
    lua_pushboolean(L, true);
    return 1;
}

static uint32_t check_channel(lua_State *L, int arg)
{
    lua_Integer value = luaL_checkinteger(L, arg);
    luaL_argcheck(L, value >= 0 && value <= 255, arg, "expected 0..255");
    return (uint32_t)value;
}

static int l_clear(lua_State *L)
{
    for (uint32_t i = 0; i < CONFIG_SENDO_LED_COUNT; i++) {
        esp_err_t err = led_strip_set_pixel(strip, i, 0, 0, 0);
        if (err != ESP_OK) {
            return push_result(L, err);
        }
    }
    return push_result(L, ESP_OK);
}

static int l_set(lua_State *L)
{
    lua_Integer index = luaL_checkinteger(L, 1);
    luaL_argcheck(L, index >= 0 && index < CONFIG_SENDO_LED_COUNT, 1, "LED index out of range");
    uint32_t red = check_channel(L, 2);
    uint32_t green = check_channel(L, 3);
    uint32_t blue = check_channel(L, 4);
    return push_result(L, led_strip_set_pixel(strip, (uint32_t)index, red, green, blue));
}

static int l_show(lua_State *L)
{
    return push_result(L, led_strip_refresh(strip));
}

static int open_leds(lua_State *L)
{
    static const luaL_Reg funcs[] = {
        {"clear", l_clear},
        {"set", l_set},
        {"show", l_show},
        {NULL, NULL},
    };
    luaL_newlib(L, funcs);
    lua_pushinteger(L, CONFIG_SENDO_LED_COUNT);
    lua_setfield(L, -2, "count");
    return 1;
}

void leds_register(lua_State *L)
{
    luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
    lua_pushcfunction(L, open_leds);
    lua_setfield(L, -2, "leds");
    lua_pop(L, 1);
}
