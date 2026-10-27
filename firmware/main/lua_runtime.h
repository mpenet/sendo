// ABOUTME: Starts the Lua runtime that runs the Fennel-compiled firmware logic.
// ABOUTME: Mounts the "assets" LittleFS partition and loads modules from it with require().

#pragma once

#include <stdbool.h>

#include "lua.h"

// Mounts the assets partition and returns a Lua state with the base, package,
// math, string and table libraries open and package.path pointing at the
// assets. Returns NULL (after logging why) if any step fails.
lua_State *lua_runtime_start(void);

// Runs sendo.selfcheck and prints its summary line. Returns true on success.
bool lua_runtime_selfcheck(lua_State *L);
