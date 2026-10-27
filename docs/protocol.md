# MoonBoard app ⇄ LED box protocol

Reference for what the official MoonBoard app sends to the LED box over BLE.
Status markers: **confirmed** (agreed on by independent implementations),
**assumed** (our choice, to verify with captures), **open** (unknown).

Sources (community reverse engineering, none endorsed by Moon Climbing):

- [FabianRig/ArduinoMoonBoardLED](https://github.com/FabianRig/ArduinoMoonBoardLED)
  (Nano 33 BLE, states compatibility with the 2026 app update)
- [labs-tibox/moonboard-esp32-ledble](https://github.com/labs-tibox/moonboard-esp32-ledble)
  (ESP32, documents real message samples)
- [8cH9azbsFifZ/moonboard](https://github.com/8cH9azbsFifZ/moonboard) (Raspberry Pi, advertising dump)
- [e-sr/moonboard_nrf52](https://github.com/e-sr/moonboard_nrf52) (nRF52840)

## Advertising (confirmed)

- 128-bit service UUID list (AD type 0x06 or 0x07):
  Nordic UART Service `6e400001-b5a3-f393-e0a9-e50e24dcca9e`.
- Local name (AD 0x09), may sit in the scan response. The original box uses
  `Moonboard A`. Working DIY boxes use `Moonboard A`, `MoonBoard A` and
  `MoonBoard`, so the app does not need an exact match.
- The original box advertises roughly every 600 ms.

## GATT (confirmed)

| Characteristic | UUID | Properties |
|---|---|---|
| RX (app writes) | `6e400002-b5a3-f393-e0a9-e50e24dcca9e` | write, write-without-response |
| TX | `6e400003-b5a3-f393-e0a9-e50e24dcca9e` | notify |

TX is never used, but some iOS versions refuse to connect without it.

## Messages (confirmed)

ASCII. The app splits a message across writes of about 20 bytes.

```
options  = "~" option *("," option) "*"
problem  = "l#" [hold *("," hold)] "#"
hold     = role 1*DIGIT
```

Samples documented by labs-tibox:

```
l#S69,S4,P93,P81,P49,P28,P10,E54#
~D,M*l#S69,S4,P82,P8,P57,P49,P28,E54#
~M*l#S103,E161,L115,R134,F150,M133#
~Z*
```

An options block is only sent when the app's "V2" setting is on. Options are
separated by commas.

| Option | Meaning |
|---|---|
| `D` | also light the LED above each hold (app: "show lights above holds") |
| `Z` | turn all LEDs off |
| `M` | **open**: present in most V2 messages, including standard-board ones, so it does not mean "Mini" |

Both firmwares that support options apply them to the next problem only and
reset them afterwards.

| Role | Meaning | Colour used by DIY firmwares |
|---|---|---|
| `S` | start | green |
| `P` | move | blue |
| `R` | right hand | blue |
| `L` | left hand | violet |
| `M` | match | pink |
| `F` | foot | cyan |
| `E` | end (top) | red |

## Hold index → grid (confirmed)

The index is 0-based and follows the LED strip: A1 is 0, up column A, down
column B, and so on.

```
col = index // rows          (0-based, A = 0)
row = index %  rows + 1      (even col: bottom to top)
row = rows - index % rows    (odd col: top to bottom)
```

Mini: 11 columns (A–K) × 12 rows = 132 positions. Standard: 11 × 18 = 198.

## LED above a hold (confirmed)

With option `D`, the firmwares also light the next position up in the same
column, dimmed (yellow in one firmware, white in the other).

- No extra LED for holds in the bottom or top row of a column.
- No extra LED for end holds.
- Hold LEDs take priority over extra LEDs.

sendo skips only the top row, which has no position above. Skipping the
bottom row has no evident reason in either firmware.

## Parser behaviour (assumed)

- Message boundaries come only from the bytes. Write boundaries are ignored.
- `~` or `l` restarts parsing from any state, so a broken message resyncs on the next one.
- A byte outside the expected alphabet drops the open frame.
- A holds body longer than 512 bytes is dropped.
- Every connection has its own parser state (the app supports several users at once).

## Open questions

1. What does option `M` mean?
2. Does the Mini 2025 still use 11 × 12? Every source covers the Mini 2020 grid. The FabianRig firmware works with the 2026 app, but no source names the Mini 2025.
3. Is `Z` ever combined with other options in one block?
