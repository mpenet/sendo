# sendo

Firmware for a DIY MoonBoard Mini LED system on ESP32, written in Fennel.
The official MoonBoard app connects to it over BLE and lights the holds of the
selected problem.

The protocol and board logic is pure Fennel and runs identically on a laptop
and on the ESP32. See [docs/protocol.md](docs/protocol.md) for the app protocol
and [docs/hardware.md](docs/hardware.md) for parts and wiring.

## Layout

```
fnl/sendo/   firmware logic
  app        BLE events -> LED effects, one input state per connection
  stream     splits BLE writes into options and holds frames
  problem    interprets options ("D", "Z") and holds ("S5" -> start at 5)
  grid       hold index <-> grid cell / name ("A1".."K12")
  render     holds -> lit LEDs: colours, mapping, lights above, power limit
sim/         host simulator drawing the board in the terminal
firmware/    ESP-IDF project for the ESP32-S3 (currently: BLE sniffer logging app writes)
test/        tests (*_test.fnl), runner and assertion helpers
docs/        app protocol and hardware reference
```

## Development

Requires Fennel and Lua 5.5.

```sh
make test   # run the test suite
make lint   # run fennel-ls
make sim < sim/samples.txt   # one BLE write per line, draws each result
make firmware-test           # host tests for the firmware's C code
```

### Firmware

Requires ESP-IDF v6.1:

```sh
git clone --depth 1 --branch v6.1 --recursive --shallow-submodules \
  https://github.com/espressif/esp-idf.git ~/esp/esp-idf
~/esp/esp-idf/install.sh esp32s3
```

Then:

```sh
source ~/esp/esp-idf/export.fish   # once per shell (export.sh for bash/zsh)
cd firmware
idf.py build
idf.py -p <port> flash monitor     # port: ls /dev/cu.* with the board's UART USB port plugged in
```

After editing `sdkconfig.defaults`, delete `firmware/sdkconfig`. idf.py only
applies the defaults when it generates a new one.

The sniffer advertises as `Moonboard A`. Connect from the MoonBoard app and
send problems; each write is logged as one line:

```
rx ms=1234 conn=1 len=6 hex=6c2353352c45 text="l#S5,E"
```

To save a session, press Ctrl+T then Ctrl+L in the monitor. It writes
`log.sendo.<timestamp>.txt` in `firmware/`; the same keys stop logging.
