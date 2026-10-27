# MoonBoard app ⇄ LED box protocol

Reference for what the official MoonBoard app sends to the LED box over BLE.
Status markers: **confirmed** (implemented by at least one firmware that works
with the app; facts from a single source name it), **assumed** (our choice, to
verify with captures), **open** (unknown).

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
- The original box advertises roughly every 600 ms (8cH9azbsFifZ only).

## GATT (confirmed)

| Characteristic | UUID | Properties |
|---|---|---|
| RX (app writes) | `6e400002-b5a3-f393-e0a9-e50e24dcca9e` | write, write-without-response |
| TX | `6e400003-b5a3-f393-e0a9-e50e24dcca9e` | notify |

TX is never used, but some iOS versions refuse to connect without it
(8cH9azbsFifZ only).

## Messages (confirmed)

ASCII. The app splits a message across writes of about 20 bytes.

```
options  = "~" option *("," option) "*"
option   = UPPER
problem  = "l#" [hold *("," hold)] "#"
hold     = role 1*DIGIT
role     = "S" / "P" / "E" / "R" / "L" / "M" / "F"
```

Samples documented by labs-tibox:

```
l#S69,S4,P93,P81,P49,P28,P10,E54#
~D,M*l#S69,S4,P82,P8,P57,P49,P28,E54#
~M*l#S103,E161,L115,R134,F150,M133#
~Z*
```

An options block is only sent when the app's "V2" setting is on (FabianRig
only). Options are separated by commas.

| Option | Meaning |
|---|---|
| `D` | also light the LED above each hold (app: "show lights above holds") |
| `Z` | turn all LEDs off (labs-tibox only) |
| `M` | **open**: in two of the three documented samples, one of them for a standard board (index 161), so it does not mean "Mini" |

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

Mini (including the Mini 2025): 11 columns (A–K) × 12 rows = 132 positions,
confirmed by Moon's template. Standard: 11 × 18 = 198.

## LED above a hold (confirmed)

With option `D`, the firmwares also light the next position up in the same
column, dimmed (yellow in one firmware, white in the other). Each LED sits
below its own hold, so the next LED up is physically just above the hold (see
[hardware.md](hardware.md#hole-geometry)).

- No extra LED for holds in the bottom or top row of a column.
- No extra LED for end holds.
- Hold LEDs take priority over extra LEDs.

sendo skips only the top row, which has no position above. On the board, the
LED of a row-2 hold sits just above the row-1 hold, so bottom-row holds get
their light above too.

## sendo behaviour (assumed)

- Message boundaries come only from the bytes. Write boundaries are ignored.
- `~` or `l` restarts parsing from any state, so a broken message resyncs on the next one.
- A byte outside the expected alphabet drops the open frame.
- A frame body (options or holds) longer than 512 bytes is dropped.
- Every connection has its own parser state and pending options (the app supports several users at once).
- Options apply to the next problem on the same connection, then reset.
- `Z` clears the board and discards pending options.
- `l##` (no holds) clears the board.
- A disconnect drops that connection's partial input. The LEDs stay as they are.

## Open questions

1. What does option `M` mean?
2. Is `Z` ever combined with other options in one block?
