# Firmware

Building, flashing and reading the ESP32-S3 firmware. For how it fits with
the Fennel code, see [architecture.md](architecture.md); for wiring, see
[hardware.md](hardware.md).

## What it does today

1. Starts a Lua task, which mounts the `assets` LittleFS partition, runs the
   boot self-check, starts the LED driver and loads `sendo.firmware`.
2. Advertises over BLE as `Moonboard A` with the Nordic UART Service.
3. Logs every write from the app, plus connection events, on the console.
4. Queues each write for the Lua task, which runs the protocol core and shows
   the resulting problem on the LED string.

None of this has run on hardware yet.

## Requirements

- ESP-IDF v6.1, installed for the ESP32-S3 (see the README).
- `make` and Fennel on the `PATH`: `idf.py build` runs `make bundle`.
  Developed with Fennel 1.6.1, installed as a Lua script (`make test32` runs
  that script with a different Lua, so a standalone Fennel binary won't do).
- An ESP32-S3-DevKitC-1-N8R8.

## Build and flash

```sh
source ~/esp/esp-idf/export.fish   # once per shell (export.sh for bash/zsh)
cd firmware
idf.py build
idf.py -p <port> flash monitor
```

- **Port:** the DevKitC has two USB-C ports. Use the one labelled **UART**; it
  appears as `/dev/cu.usbserial-…` or `/dev/cu.wchusbserial…` on macOS
  (`ls /dev/cu.*` before and after plugging in).
- **Always flash with `idf.py flash`.** It writes the app *and* the `assets`
  partition with the Lua. `idf.py app-flash` writes the app only and leaves old
  or missing Lua behind.
- **Exit the monitor** with Ctrl+].
- **After editing `sdkconfig.defaults`**, delete `firmware/sdkconfig`. idf.py
  only applies the defaults when it generates a new one.

## LED settings

In `idf.py menuconfig`, menu **sendo**:

| Option | Default | Notes |
|---|---|---|
| LED data GPIO | 4 | See [hardware.md](hardware.md#data-line) for why 4. |
| Number of LEDs on the string | 150 | All pixels, including unused ones. The protocol core takes this count from the `leds` module, so it can't disagree. |
| LED colour order | RGB | WS2811 strings differ. If red and green are swapped, pick GRB. |

## Flash layout

From `firmware/partitions.csv`, 8 MB flash:

| Partition | Size | Contents |
|---|---|---|
| `nvs` | 24 KB | Bluetooth bonds, PHY calibration |
| `phy_init` | 4 KB | RF calibration data |
| `factory` | 2 MB | The firmware (about 630 KB today) |
| `assets` | 1 MB | LittleFS with the compiled Lua (about 11 KB today) |

About 4.9 MB stays free for later A/B updates.

## Components

Pinned in `firmware/dependencies.lock`, fetched by idf.py into
`firmware/managed_components/`:

| Component | Version | Use |
|---|---|---|
| `espressif/lua` | 5.5.1 | Lua runtime, 32-bit numbers |
| `joltwallet/littlefs` | 1.23.1 | Filesystem for the Lua bundle, image built at compile time |
| `espressif/led_strip` | 3.1.1 | WS2811 driver over the RMT peripheral |

## Console output

ESP-IDF's own lines start with a level and a timestamp, like `I (312) …`.
sendo's lines start with a lowercase word and use `key=value` pairs, so they
are easy to grep.

### Boot

```
selfcheck leds=5 0:0,255,0 1:32,32,0 5:0,0,255 6:32,32,0 131:255,0,0 free-heap=…
lua-ready firmware=yes stack-free=…
ready name="Moonboard A"
```

The Lua task and Bluetooth start in parallel, so `ready` can appear before
the Lua lines.

- The `selfcheck` line must match `make bundle-check` on the host, apart from
  `free-heap`.
- `free-heap` is measured while Bluetooth is still starting, so the heap left
  at runtime is lower.
- `stack-free` is the Lua task's unused stack in bytes at that point. It shows
  whether `LUA_TASK_STACK_BYTES` in `main.c` can shrink or must grow.

### Line reference

| Line | Meaning |
|---|---|
| `selfcheck leds=<n> <led>:<r>,<g>,<b> … free-heap=<bytes>` | The protocol core ran on the device. |
| `lua-ready firmware=<yes/no> stack-free=<bytes>` | The Lua task is waiting for writes. `no`: an error line above says why; writes are then only logged. |
| `ready name="<name>"` | Bluetooth is up and advertising. |
| `connect conn=<handle> status=<code>` | A phone connected (`status=0`) or a connection attempt failed. |
| `disconnect conn=<handle> reason=<code>` | A phone disconnected. See the reason codes below. |
| `mtu conn=<handle> mtu=<bytes>` | The phone negotiated the maximum packet size. |
| `subscribe conn=<handle> notify=<0/1>` | The phone (un)subscribed to the TX characteristic. |
| `encryption conn=<handle> status=<code>` | The link was encrypted (`status=0`): the app pairs. |
| `repeat-pairing conn=<handle>` | A phone that lost its bond paired again; the old bond was dropped. |
| `rx ms=<uptime> conn=<handle> len=<n> hex=<bytes> text="<text>"` | One write from the app. `hex` is exact; in `text`, `\"`, `\\` and `\xHH` are escapes. |
| `rx-error conn=<handle> reason=too-long` | A write over 512 bytes was rejected. |
| `event-dropped conn=<handle> type=<0/1>` | The queue to the Lua task was full (16 events); a write (0) or disconnect (1) was lost. The parser resyncs on the next message. |
| `adv-error step=<fields/response/start/address> rc=<code>` | Advertising couldn't start; the board is invisible. |
| `ble-reset reason=<code>` | The Bluetooth stack reset itself. |
| `lua-error step=mount err=<name>` | The `assets` partition didn't mount. |
| `lua-error step=newstate` | Lua couldn't allocate its state. |
| `lua-error step=selfcheck message="<error>"` | The Lua bundle failed to load or run. |
| `lua-error step=firmware message="<error>"` | `sendo.firmware` failed to load; the LEDs won't follow the app. |
| `lua-error step=<received/disconnected> message="<error>"` | The protocol core raised an error on one event. The task keeps running. |
| `leds-error step=init err=<name>` | The LED driver couldn't start (check the GPIO setting). |

Common disconnect reasons (NimBLE adds 0x200 to the Bluetooth error code):

| `reason` | Meaning |
|---|---|
| 531 (0x213) | The phone closed the connection |
| 520 (0x208) | Link lost: the phone went out of range or stopped responding |
| 574 (0x23e) | The connection failed to establish |

## Capture session

The firmware is first a sniffer: its job is to record what the current app
really sends. A session that answers the open questions in
[protocol.md](protocol.md):

1. Start a log: in the monitor press Ctrl+T, then Ctrl+L. It writes
   `firmware/log.sendo.<timestamp>.txt` (ignored by git).
2. Connect from the app. Note whether `encryption` appears: that says whether
   the app pairs.
3. With the app's "V2" setting **off**, send two or three problems. Note their
   names.
4. Turn "V2" **on**. Send the same problems with "show lights above holds"
   off, then on. Compare the options blocks (`~…*`).
5. Toggle every other app setting that affects the board (hand colours, beta)
   one at a time and send a problem after each. This should reveal what `M`
   means.
6. Clear the board from the app. Note whether `~Z*` arrives alone or with other
   options.
7. Connect a second phone and send from both, to see how writes interleave.
8. Reset the board (EN button) and reconnect from the same phone: does it
   reconnect without "forget device"?
9. Stop logging (Ctrl+T, Ctrl+L) and take a screenshot of each problem in the
   app.

Then feed the `text` of the `rx` lines to the simulator (`make sim`) and
compare the boards with the screenshots. Add confirmed messages to
`sim/samples.txt` and update [protocol.md](protocol.md).

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `make: fennel: No such file or directory` during `idf.py build` | Fennel isn't on the `PATH` of the shell running idf.py. Install it or fix `PATH`. |
| `lua-error step=mount` | The `assets` partition was never written. Flash with `idf.py flash`, not `app-flash`. |
| `lua-error step=selfcheck message="module 'sendo.…' not found"` | Stale or partial assets. Rebuild and `idf.py flash`. |
| No `ready` line, or `adv-error` | Bluetooth didn't start; check the lines just before. `idf.py fullclean` then rebuild if the config changed. |
| The app doesn't list the board | Check for `ready`. Toggle the phone's Bluetooth. iOS caches names and services: forget the device and scan again. |
| Phone connects then drops right away after a reflash | After `idf.py erase-flash`, the board lost its bonds while the phone kept them. Forget the device on the phone. (`idf.py flash` keeps the `nvs` partition and the bonds.) |
| Changes in `sdkconfig.defaults` have no effect | Delete `firmware/sdkconfig` and rebuild. |
| Wrong colours: red and green swapped | Set the colour order to GRB in menuconfig. |
| Wrong holds light up | The string isn't wired in the app's order. Check [hardware.md](hardware.md#led-layout-on-the-board); map around detours with `:ledmap`. |
| Nothing lights, but `rx` lines appear | Look for `lua-ready firmware=no` or `lua-error`. Then check power, the shared ground and the level shifter. |
