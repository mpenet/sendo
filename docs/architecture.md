# Architecture

How sendo is put together, why, and where it stands.

## Overview

The official MoonBoard app connects to the board over Bluetooth Low Energy
and writes a short ASCII message describing a problem. sendo receives those
writes on an ESP32-S3, works out which holds to light and in which colour, and
drives a string of WS2811 LEDs.

```
 MoonBoard app ──BLE writes──▶ ESP32-S3
                               ┌──────────────────────────── C (ESP-IDF) ─┐
                               │ NimBLE: Nordic UART Service              │
                               │ LittleFS "assets" partition              │
                               │ Lua 5.5 runtime                          │
                               │   ┌──────── Lua compiled from Fennel ─┐  │
                               │   │ stream → problem → app → render   │  │
                               │   └───────────────────────────────────┘  │
                               │ RMT LED driver (planned)                 │
                               └──────────────────────────────────────────┘
                                          │
                                          ▼
                                 WS2811 LED strings
```

The split:

- **C** owns the hardware: Bluetooth, flash, the LED driver, tasks and memory.
  It doesn't know the protocol.
- **Fennel** owns the logic: parsing the app's messages, mapping holds to LEDs,
  colours, power limits. It doesn't know the hardware.

The Fennel is compiled to plain Lua on the developer's machine. The device only
runs standard Lua; there is no Fennel compiler or runtime on it.

## The protocol core

Five modules in `fnl/sendo/`, each a small set of pure functions over plain
data. `stream` is the one exception: it keeps per-connection parser state.

| Module | Input | Output |
|---|---|---|
| `stream` | bytes from BLE writes, split anywhere | frames: `{:options "D,M"}`, `{:holds "S5,E18"}` |
| `problem` | frame bodies | `{:lights-above true}`, `[{:role :start :index 5} …]` |
| `grid` | hold index | cell `{:col 1 :row 1}` and name `"A1"`, and back |
| `render` | holds, options, config | lit LEDs: `{led-index [r g b]}` |
| `app` | events `{:type :received :conn 1 :bytes "…"}` | effects `[{:leds {…}}]` |

Data flow for one write:

```
event ─▶ app.handle
           ├─ per-connection stream.feed ─▶ frames
           │    options frame ─▶ problem.parse-options ─▶ pending options (or clear on Z)
           │    holds frame   ─▶ problem.parse-holds ─▶ render.render ─▶ {:leds …}
           └─ returns effects in order
```

`app.handle` returns effects rather than performing them. The caller decides
what an effect means: the firmware will write the LEDs, the simulator draws a
board, the tests compare values. The same events always produce the same
effects, so a recorded log of events replays exactly.

`sendo.selfcheck` runs a fixed message through `app` and summarises the
result. The firmware prints it at boot so the whole chain is verified on the
device.

## Build pipeline

```
fnl/sendo/*.fnl ──fennel --compile──▶ firmware/assets/sendo/*.lua
                                             │ (make bundle, run by idf.py build)
                                             ▼
                         littlefs image "assets" (build/assets.bin)
                                             │ idf.py flash
                                             ▼
                         device: require("sendo.app") from /assets
```

- `idf.py build` runs `make bundle` before building the LittleFS image, so
  the image never holds stale Lua.
- The device loads Lua **source**, not bytecode. The device's Lua uses 32-bit
  numbers (see below), so bytecode from a normal desktop `luac` won't load.
  Parsing about 11 KB of source at boot takes milliseconds. Bytecode remains an
  option: `build/lua32/` has a matching 32-bit `luac`.

## Number model

The `espressif/lua` component builds Lua with `LUA_32BITS`: integers are 32-bit
and floats are single precision. Desktop Lua uses 64-bit integers and doubles.

Consequences the code relies on:

- Hold indices, LED indices and colour channels are small integers.
- Brightness uses integer division (`//`), so colours stay integers.
  `table.concat` would print a float as `32.0`, which the self-check test
  would catch.
- A hold number too big for 32 bits parses as a float on the device. `grid`
  rejects non-integers, so such holds are skipped on both platforms (tested).

`make test32` runs the whole suite on a Lua built the same way, and
`make bundle-check` runs the compiled bundle on it with only the libraries the
firmware opens.

## Threading model

Lua is not thread-safe: one `lua_State` must only ever be used by one task.

- **Now:** the main task creates the state and runs the self-check before
  Bluetooth starts. BLE callbacks run on NimBLE's host task and only log.
- **Next step:** BLE callbacks copy each write into a FreeRTOS queue. A
  dedicated Lua task owns the state, drains the queue, calls `app.handle` and
  applies the effects. Calling Lua directly from a BLE callback would be a bug.

## Testing strategy

| Layer | How | Command |
|---|---|---|
| Protocol core | Example tests per module | `make test` |
| Parser robustness | Property tests: random chunking, random garbage, resync; 500 runs each, fixed seeds. Checked against deliberately broken parsers to prove they catch bugs. | `make test` |
| Device number model | Whole suite on 32-bit Lua | `make test32` |
| Compiled bundle | Lua output run without Fennel, device libraries only | `make bundle-check` |
| Firmware C | Host tests with AddressSanitizer and UBSan | `make firmware-test` |
| Firmware build | 0 compiler warnings | `idf.py build` |
| On hardware | Self-check line at boot; captures from the real app | see [firmware.md](firmware.md) |

New behaviour is written test-first: a failing test, then the code.

## Decisions

| Decision | Why |
|---|---|
| ESP32-S3 (N8R8), not S31 | Mature BLE stack and examples; PSRAM for an optional on-device REPL. The S31's ESP-IDF support is still young. |
| Logic in Fennel, compiled to Lua at build time | Expressive, testable on the laptop, no compiler on the device. |
| Lua source on the device, not bytecode | Bytecode must match the device's 32-bit number model; source is simple and readable in error messages. |
| Pure core returning effects | Same code on host and device; exact replay of event logs. |
| Per-connection parser state and options | The app supports several users at once; interleaved writes must not mix. |
| Options apply to the next problem only | Matches every firmware known to work with the app. |
| Light above bottom-row holds too | Community firmwares skip it without reason; on the board, row 2's LED sits just above a row-1 hold. |
| Bonds persisted in NVS | A board that forgets bonds breaks reconnects from phones that kept them. |

## Status

| # | Milestone | Status |
|---|---|---|
| 1 | Sniffer firmware: log every write from the app | Built; waiting for hardware |
| 2 | Protocol spec | Written from community firmwares; captures still to confirm |
| 3 | Protocol core in Fennel | Done |
| 4 | Simulator | Terminal simulator done; live bridge from the board not started |
| 5 | Lua on the device | Built with a boot self-check; waiting for hardware |
| 6 | LEDs on the bench | Not started: RMT driver and Lua task |
| 7 | Installed on the wall | Not started |
| 8 | Hardening: watchdog, A/B bundle with rollback, config in NVS | Not started |
| 9 | CI and hardware-in-the-loop tests | Not started |
