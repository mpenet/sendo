-- ABOUTME: Runs the compiled Lua bundle the way the firmware does, without Fennel.
-- ABOUTME: Mirrors lua_runtime.c: device libraries only, a fake "leds" C module, the same require calls.

local bundle_dir = arg[1]

-- The firmware opens only base, package, math, string and table.
io_write = io.write
io, os, debug, utf8, coroutine = nil, nil, nil, nil, nil
package.path = bundle_dir .. "/?.lua"

local failures = 0
local function check(name, expected, actual)
  if expected ~= actual then
    failures = failures + 1
    io_write("FAIL ", name, "\n  expected: ", expected, "\n  actual:   ", actual, "\n")
  end
end

-- Same interface as leds.c: count, clear, set, show. show records the frame.
local shown = {}
local frame = {}
package.preload.leds = function()
  return {
    count = 150,
    clear = function() frame = {} return true end,
    set = function(i, r, g, b)
      assert(math.type(i) == "integer" and i >= 0 and i < 150, "LED index out of range")
      for _, c in ipairs({r, g, b}) do
        assert(math.type(c) == "integer" and c >= 0 and c <= 255, "expected 0..255")
      end
      frame[#frame + 1] = i .. ":" .. r .. "," .. g .. "," .. b
      return true
    end,
    show = function()
      table.sort(frame)
      shown[#shown + 1] = table.concat(frame, " ")
      return true
    end,
  }
end

local selfcheck = require("sendo.selfcheck").run()
io_write(selfcheck, "\n")
check("selfcheck", "selfcheck leds=5 0:0,255,0 1:32,32,0 5:0,0,255 6:32,32,0 131:255,0,0", selfcheck)

-- The call lua_runtime.c makes, then events split across writes like the app sends them.
-- require returns the module and its loader data: keep only the module.
local leds = require("leds")
local firmware = require("sendo.firmware").start(leds)
firmware.received(1, "~D*l#S0,")
firmware.received(1, "P5,E131#")
firmware.received(2, "l#E7")
firmware.disconnected(2)
firmware.received(1, "~Z*")

check("frames", 2, #shown)
check("problem frame", "0:0,255,0 131:255,0,0 1:32,32,0 5:0,0,255 6:32,32,0", shown[1])
check("clear frame", "", shown[2])

io_write("bundle-check: ", failures, " failures\n")
if failures > 0 then error("bundle-check failed") end
