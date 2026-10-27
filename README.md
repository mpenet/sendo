# sendo

Firmware for a DIY MoonBoard Mini LED system on ESP32, written in Fennel.
The official MoonBoard app connects to it over BLE and lights the holds of the
selected problem.

The protocol and board logic is pure Fennel and runs identically on a laptop
and on the ESP32. See [docs/protocol.md](docs/protocol.md).

## Layout

```
fnl/sendo/   firmware logic
  app        BLE events -> LED effects, one input state per connection
  stream     splits BLE writes into options and holds frames
  problem    interprets options ("D", "Z") and holds ("S5" -> start at 5)
  grid       hold index <-> grid cell / name ("A1".."K12")
  render     holds -> lit LEDs: colours, mapping, lights above, power limit
sim/         host simulator drawing the board in the terminal
test/        tests (*_test.fnl), runner and assertion helpers
docs/        protocol reference
```

## Development

Requires Fennel and Lua 5.5.

```sh
make test   # run the test suite
make lint   # run fennel-ls
make sim < sim/samples.txt   # one BLE write per line, draws each result
```
