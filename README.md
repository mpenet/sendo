# sendo

Firmware for a DIY MoonBoard Mini LED system on an ESP32-S3. The official
MoonBoard app connects to it over Bluetooth and lights the holds of the
selected problem.

The protocol and board logic is written in Fennel and compiled to plain Lua at
build time. The same code runs in the tests, in a terminal simulator and on the
device.

**Status:** the protocol core, simulator and firmware are written. The
firmware receives the app's Bluetooth writes, runs the core on them and drives
the LED string. None of it has run on a real board yet: waiting for hardware.
See [docs/architecture.md](docs/architecture.md#status).

## Documentation

| Document | Contents |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How it fits together, build pipeline, testing, decisions, status |
| [docs/protocol.md](docs/protocol.md) | What the MoonBoard app sends and how sendo interprets it |
| [docs/hardware.md](docs/hardware.md) | Parts, wiring, power, LED layout and hole geometry |
| [docs/firmware.md](docs/firmware.md) | Building, flashing, console output, capture sessions, troubleshooting |

## Layout

```
fnl/sendo/   firmware logic, compiled to Lua for the device
  firmware   what the device runs: BLE events in, calls to the LED module out
  app        BLE events -> LED effects, one input state per connection
  stream     splits BLE writes into options and holds frames
  problem    interprets options ("D", "Z") and holds ("S5" -> start at 5)
  grid       hold index <-> grid cell / name ("A1".."K12")
  render     holds -> lit LEDs: colours, mapping, lights above, power limit
  selfcheck  runs a fixed message through the core; printed at boot
sim/         terminal simulator drawing the board
test/        tests (*_test.fnl), runner and assertion helpers
firmware/    ESP-IDF project for the ESP32-S3 (C: Bluetooth, Lua task, LED driver)
docs/        documentation
```

## Development

Requires Fennel (1.6.1, installed as a Lua script), Lua 5.5 and a C compiler.

```sh
make test                    # run the test suite
make test32                  # same suite on Lua built like the firmware's (32-bit numbers)
make lint                    # run fennel-ls
make sim < sim/samples.txt   # one BLE write per line, draws each result
make bundle-check            # compile fnl/ to Lua and run it like the firmware does
make firmware-test           # host tests for the firmware's C code
```

`make test32` and `make bundle-check` download Lua 5.5.1 from lua.org once,
check its SHA-256 and build it in `build/`.

## Firmware

Install ESP-IDF v6.1 for the ESP32-S3 once:

```sh
git clone --depth 1 --branch v6.1 --recursive --shallow-submodules \
  https://github.com/espressif/esp-idf.git ~/esp/esp-idf
~/esp/esp-idf/install.sh esp32s3
```

Build and flash:

```sh
source ~/esp/esp-idf/export.fish   # once per shell (export.sh for bash/zsh)
cd firmware
idf.py build
idf.py -p <port> flash monitor
```

See [docs/firmware.md](docs/firmware.md) for the port, the console output and
troubleshooting.
