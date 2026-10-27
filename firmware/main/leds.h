// ABOUTME: Drives the WS2811 LED string and exposes it to Lua as the "leds" module.
// ABOUTME: Pin, length and colour order come from menuconfig (see Kconfig.projbuild).

#pragma once

#include "esp_err.h"
#include "lua.h"

// Creates the LED driver and turns every LED off.
esp_err_t leds_init(void);

// Makes require("leds") return the module in L. Call after leds_init succeeded.
//   leds.count            number of LEDs on the string
//   leds.clear()          zero every LED in the buffer, without sending it
//   leds.set(i, r, g, b)  set LED i (0-based) in the buffer; channels 0..255
//   leds.show()           send the buffer to the string; false, error on failure
void leds_register(lua_State *L);
