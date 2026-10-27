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

## Installation

Everything needed to build lives in a Docker image: ESP-IDF v6.1, Lua 5.5.1
(standard and 32-bit), Fennel 1.6.1 and fennel-ls, all at pinned versions. The
host only needs Docker, to build, and esptool, to flash over USB.

1. Install [Docker](https://docs.docker.com/get-started/get-docker/)
   (Docker Desktop on macOS and Windows).
2. Install esptool 5 or later, with pyserial's serial monitor. Any one of:

   ```sh
   uv tool install --with-executables-from pyserial 'esptool>=5'
   pipx install --include-deps 'esptool>=5'
   python3 -m pip install --user 'esptool>=5'
   ```

   Check with `esptool version`. Without the version constraint, some
   installers pick esptool 4, which only provides `esptool.py`.

3. Clone the repository and build:

   ```sh
   git clone <repo-url> sendo && cd sendo
   scripts/in-docker make check firmware
   ```

   The first run builds the image: it downloads about 4 GB (13 GB on disk,
   mostly Espressif's toolchains) and takes a few minutes. Later runs start in
   seconds.

4. Plug the board's **UART** USB port in, find its port (`ls /dev/cu.*` on
   macOS, `ls /dev/ttyUSB* /dev/ttyACM*` on Linux), then flash and watch the
   console:

   ```sh
   make flash PORT=/dev/cu.usbserial-110
   make monitor PORT=/dev/cu.usbserial-110   # exit with Ctrl+]
   ```

The first lines should include the self-check and `ready name="Moonboard A"`.
See [docs/firmware.md](docs/firmware.md) for the console output and
troubleshooting, and for building without Docker.

## Development

Run any task in the image with `scripts/in-docker <command>`:

```sh
scripts/in-docker make check                      # every host-side check below
scripts/in-docker make test                       # run the test suite
scripts/in-docker make test32                     # same suite on 32-bit Lua, like the firmware's
scripts/in-docker make lint                       # run fennel-ls
scripts/in-docker make bundle-check               # compile fnl/ to Lua and run it like the firmware does
scripts/in-docker make firmware-test              # host tests for the firmware's C code
scripts/in-docker make firmware                   # build the firmware
scripts/in-docker make sim < sim/samples.txt      # one BLE write per line, draws each result
scripts/in-docker idf.py -C firmware menuconfig   # LED pin, count and colour order
```

The same `make` targets work without Docker if Fennel 1.6.1 (as a Lua
script), Lua 5.5, fennel-ls and a C compiler are installed. `make test32`
then downloads and builds the 32-bit Lua in `build/` on first use.

## License

sendo is licensed under the GNU General Public License v3.0 only
(SPDX: `GPL-3.0-only`). See [LICENSE](LICENSE).

The firmware links third-party components under their own licences, all
compatible with the GPLv3: ESP-IDF, NimBLE and led_strip (Apache-2.0), Lua and
esp_littlefs (MIT).

sendo is not affiliated with or endorsed by Moon Climbing, maker of the
MoonBoard and its app.
