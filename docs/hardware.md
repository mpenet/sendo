# Hardware

What to buy and how to wire a sendo LED system for a MoonBoard Mini.

## Bill of materials

| Qty | Part | Notes |
|---|---|---|
| 1 | **ESP32-S3-DevKitC-1-N8R8** (Espressif) | 8 MB flash, 8 MB PSRAM. N16R8 also fine. Avoid boards without PSRAM ("R"); the on-device REPL needs it. |
| 3 | **WS2811 12 mm bullet pixel string, 5 V, 50 pixels, 25 cm wire spacing** | 150 pixels for 132 holds. 25 cm spacing is needed to reach between holes on the hold grid. |
| 1 | WS2811 string as above (spare) | Replacement pixels. |
| 1 | **74AHCT125** in DIP-14 (e.g. SN74AHCT125N) | 3.3 V → 5 V level shifter for the data line. Must be AHCT/HCT, not HC. |
| 1 | 330 Ω resistor | In series on the data line, close to the shifter output. |
| 1 | 1000 µF electrolytic capacitor, ≥ 6.3 V | Across 5 V / GND where power enters the LED strings. |
| 1 | **5 V 4 A power supply** (20 W) | Firmware limits LED current to 3 A. |
| 1 | Inline fuse holder + 5 A slow-blow fuse | On the 5 V output of the supply. |
| — | Power wire ≥ 0.75 mm², data wire, connectors (JST SM 3-pin match most strings) | For power injection and the controller. |
| 1 | Breadboard or perfboard, jumper wires | Bench setup and the final controller. |

Optional: a smaller board for the final install. A **Seeed XIAO ESP32S3** has
the same chip, flash and PSRAM, plus an external antenna connector for metal
enclosures. Only pin numbers change.

## Power budget

| Case | Current |
|---|---|
| Idle (150 pixels, all off) | ~0.15 A (about 1 mA quiescent per pixel) |
| Typical problem (≤ 20 holds lit, plus lights above with `D`) | ~0.4–0.8 A |
| Worst case without limits (150 pixels full white) | ~9 A |
| Firmware limit (`:max-current-ma` in `render`) | 3 A |

The 4 A supply covers the firmware limit plus idle and the ESP32 (~0.3 A peak).
Anything that lights LEDs, including future self-tests, must go through the same
limit.

## Wiring

Every connection, grouped by net:

| Net | Connects |
|---|---|
| **+5V** | PSU +5V through the 5 A fuse · capacitor + · +5V at the start of strings 1, 2 and 3 · 74AHCT125 pin 14 (VCC) · 74AHCT125 pins 4, 10, 13 (unused 2OE, 3OE, 4OE) · ESP32 5V pin (installed use only, see below) |
| **GND** | PSU GND · capacitor − · GND at the start of strings 1, 2 and 3 · 74AHCT125 pin 7 (GND) · 74AHCT125 pin 1 (1OE) · 74AHCT125 pins 5, 9, 12 (unused inputs 2A, 3A, 4A) · ESP32 GND |
| **data (3.3 V)** | ESP32 GPIO4 · 74AHCT125 pin 2 (1A) |
| **data (5 V)** | 74AHCT125 pin 3 (1Y) · 330 Ω resistor · string 1 DATA IN (A1 end) |

- The capacitor sits where power enters string 1. Mind its polarity.
- Pin 1 (1OE) is active low, so tying it to GND keeps the used buffer on.
  Pins 4, 10 and 13 tie the unused enables high so those outputs stay
  disconnected. Unused inputs go to GND so they don't float.
- Strings 2 and 3 get data from the end of the previous string, through their
  own connectors. Only power is added at their start.

### Data line

- **GPIO4** carries LED data. It isn't a strapping pin (0, 3, 45, 46), USB
  (19, 20), UART0 (43, 44), octal flash/PSRAM (35–37) or the on-board RGB LED
  (38 on v1.1 boards, 48 on v1.0). The pin, the LED count and the colour order
  are set in menuconfig (see [firmware.md](firmware.md#led-settings)).
- Keep the wire from the 74AHCT125 to the first pixel short, ideally under 1 m.
  Mount the controller near A1.
- Most strings mark the data direction with an arrow. Data enters at the A1 end.

### Ground and power to the ESP32

- **All grounds are shared**: PSU, LED strings, 74AHCT125 and ESP32. Without a
  common ground the LEDs show garbage or nothing.
- The DevKitC-1's power inputs (USB ports, 5V pin, 3V3 pin) are **mutually
  exclusive**: use only one at a time.
  - **On the bench**: power the ESP32 from USB. Leave its 5V pin unconnected.
    Connect only GND to the LED side.
  - **Installed**: feed the ESP32's 5V pin from the PSU. Don't plug in USB
    while the 5V pin is fed. For debugging an installed board, disconnect the
    5V pin first.
- Never leave the data line connected to unpowered LEDs while the ESP32 runs.
  It can damage the first pixel. Switch the PSU on whenever the ESP32 is on.

### Power injection

The thin wires inside pixel strings drop voltage. Bring +5 V and GND from the
supply to the start of **each** 50-pixel string, using ≥ 0.75 mm² wire. Never
connect two power supplies to the same strings.

## LED layout on the board

The firmware expects the strip to follow the app's hold numbering:

```
front view

A12 ──▶ B12     C12 ──▶ D12     ...     K12  (end)
 ▲       │       ▲       │               ▲
 │       ▼       │       ▼               │
A1      B1 ──▶  C1      D1 ──▶  ...     K1
 ▲
data in
```

- Start at **A1** (bottom left seen from the front), go up column A to A12,
  across to B12, down to B1, across to C1, and so on up column K to K12.
- **Seen from the back, the board is mirrored: column A is on the right.**
- Each column uses 12 pixels. The 18 pixels left over (150 − 132) stay unlit
  at the end of string 3 and can be cut off. If back framing forces a detour,
  skip pixels and set `:ledmap` in the render config, which maps a hold index
  to an LED index on the strip.

### Hole geometry

From Moon's [Mini MoonBoard template (metric)](https://moonclimbing.com/media/moonboard-pdf/Mini_MoonBoard_Template_Guide_Metric.pdf),
measured from the PDF's vector data (± 1 mm):

- Board: two 2437 × 1220 mm panels stacked (joint at 1220 mm), plus a 150 mm
  kicker.
- Columns A–K at 200, 400, … 2200 mm from the left edge (front view).
- Each column has 24 holes, all drawn at 12.6 mm: 12 T-nut holes for rows
  1–12 and 12 holes between them. Heights from the bottom edge:

| | Bottom panel | Top panel |
|---|---|---|
| Rows (T-nuts) | 1–6 at 100, 300, 500, 700, 900, 1100 | 7–12 at 1320, 1520, 1720, 1920, 2120, 2320 |
| In-between holes | 20, 200, 400, 600, 800, 1000, 1200 | 1420, 1620, 1820, 2020, 2220 |

The in-between holes are the LED holes: one directly **below** each hold.
The template doesn't label them, but the count (one per hold) and Moon's "an
LED beneath each T-nut" both point that way. "One above each hold" doesn't fit:
it would leave the hole at 20 mm unexplained and row 12 without one.

| Hold row | LED height | LED below hold |
|---|---|---|
| 1 | 20 | 80 mm |
| 2–6 | 200 … 1000 | 100 mm |
| 7 | 1200 | 120 mm (across the panel joint) |
| 8–12 | 1420 … 2220 | 100 mm |

Consequences for the strings:

- Neighbouring LEDs in a column are 180–220 mm apart, and columns are 200 mm
  apart, so 25 cm pixel spacing reaches everywhere with some slack.
- The row-7 LED sits 20 mm below the panel joint. Check that the back framing
  at the joint leaves room for the pixel body and its wires.
- With the LED below its hold, the next hold's LED sits 100 mm above the hold.
  This is the light the app's "lights above holds" option (`D`) turns on.

## Bench setup (before installing)

1. ESP32 on USB, 74AHCT125 on the breadboard, one 50-pixel string.
2. 5 V supply into the string and the 74AHCT125, grounds shared with the ESP32.
3. Flash the firmware and connect from the app. The first 50 holds (A1–E2) light
   up on the test string.

## Where to buy (Switzerland)

- **Board and small parts**: Conrad (ESP32-S3-DevKitC-1-N8R8 is article
  2685021), Distrelec, bastelgarage.ch, pi-shop.ch, or Mouser/DigiKey with
  duties included at checkout. Stock at the Swiss shops is unverified.
- **Pixel strings**: rarely stocked in Swiss shops. AliExpress or eBay.de,
  about €8–10 per 50, 1–3 weeks shipping. Order early.
