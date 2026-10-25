# VoltFuel

**Voltage-only battery gauge widget for EdgeTX** — no current sensor needed.
日本語版は [README.ja.md](README.ja.md) をご覧ください。

VoltFuel estimates the remaining capacity of a LiPo pack from the pack-voltage telemetry alone and shows it as a bar and two numbers, e.g. **`62%(48%)`**:

| Number | Meaning |
|---|---|
| `62%` | The **VoltFuel estimate**. It starts from the resting-voltage value and then only ever goes *down*. A sag filter and a drop-rate limit stop throttle bursts from making it jump. Also published as the telemetry sensor **`sBAT`**. |
| `(48%)` | The **BattAnalog-style value**: the plain per-cell voltage → % table of EdgeTX's BattAnalog widget, applied to the *current* voltage. An independent reference, most useful on the ground after landing, once the voltage has settled. |

> **Not affiliated with Rotorflight.** Rotorflight's "SmartFuel" is a separate feature. VoltFuel works with any pack-voltage telemetry source.

## Requirements

- EdgeTX **2.12 or newer**, color-LCD touch radios (developed on TX16S, TX15, GX15). Not for black-and-white radios. VoltFuel uses 10 widget options.
- A telemetry sensor that reports the **pack** voltage (VFAS, RxBt, Vbat, …). A receiver that only reports its own BEC voltage will not work.

## Install

1. Copy the **`voltfuel`** folder to `/WIDGETS/` on the SD card, so that the file is `/WIDGETS/voltfuel/main.lua`. (The folder name must stay 8 characters or less.)
2. On the radio: long-press a Main View → add a widget → **VoltFuel**.
3. Long-press the widget → **Settings**, and choose **Source**.
4. Once the widget shows a value, the **`sBAT`** sensor appears in the Telemetry sensor list. (If it does not, run *Discover new sensors* on the Telemetry page.)

Do not run VoltFuel together with another widget that publishes an `sBAT` sensor.

## Before you start: check the voltage source

VoltFuel can only be as accurate as the voltage you feed it. Telemetry voltages (RxBt and others) are usually not calibrated: they can read a few hundredths of a volt high or low, and many report only in 0.1 V steps. On a small pack this matters: 0.01 V per cell moves the converted level by about 2 points in the middle of the range, and a 0.05 V error on a 2S pack is 0.025 V per cell.

1. Measure a pack **at rest** (no load) with a voltmeter or battery checker you trust, and note the value.
2. At the same moment, read the Source sensor on the radio's Telemetry screen.
3. If they differ, correct the sensor in *Model Settings → Telemetry*: select the sensor, choose *Edit*, and set **Offset** (a constant difference: measured − shown) and/or **Ratio** (a proportional error: measured ÷ shown). If the offset has a fraction, set the sensor's **Precision** to 0.00 so that it can be entered.
4. For a better fix, repeat with a second pack at a different voltage (for example a full and a part-used pack) and use both points.
5. Do this **before** tuning MinCv. A tuned MinCv is only valid for the calibration it was tuned with; if you change the offset or ratio later, tune again.

A reference meter has tolerances too, so use one you trust.

## Options

| Option | Default | Meaning |
|---|---|---|
| Source | – | Pack-voltage telemetry sensor. |
| BattType | LiPo | LiPo / LiPo-HV / Li-Ion / LiFePO4. Used **only** for cell-count auto-detection and for the BattAnalog-style value in parentheses. It does **not** change MinCv / MaxCv. |
| Cells | 0 | Cell count. `0` = auto-detect (BattAnalog rule, re-checked for the first 8 s, then locked). |
| ResPct | 35 | Reserve: the point on the curve that is shown as 0 %. Higher = reads lower and reaches 0 % sooner. If you change it, re-tune MinCv. |
| FallMv | 50 | Sag filter: how fast the filtered voltage may fall, in mV per second. Lower = smoother. |
| MinCv | 286 | "Empty" cell voltage ×100 → curve 0 %. **The main tuning knob.** Higher MinCv = lower reading. |
| MaxCv | 410 | "Full" cell voltage ×100 → curve 100 %. Not tuned for other chemistries (LiPo-HV: only one 2S flight checked). |
| TxtColor | white | Text color. |
| ResetSw | – | Optional switch. On the rising edge, jumps the value to the BattAnalog-style value at that instant. |
| ExtraTelem | off | Also publish the telemetry sensors `rBAT`, `rCEL` and `rMIN` for later analysis (see below). |

## Telemetry sensors

| Sensor | Published | Meaning |
|---|---|---|
| `sBAT` | always | The VoltFuel estimate (%). |
| `rBAT` | ExtraTelem on | The BattAnalog-style value (%): a plain voltage → % conversion of the **current** voltage. It reads low under load and is closest to the real remaining capacity at rest. |
| `rCEL` | ExtraTelem on | Cell voltage (V). |
| `rMIN` | ExtraTelem on | The MinCv setting in use, in V (260 → 2.60). It records each flight's tuning in the SD log. |

`rBAT`, `rCEL` and `rMIN` are published once the cell count is settled (about 8 seconds after telemetry appears with auto cell count). The sensors appear in the Telemetry sensor list after their first value; a sensor's name is fixed when it is created. Turn on SD logging for them to analyse flights afterwards.

## Power-on, packs and reset

- The starting value is **not 100 %**. About 8–9 seconds after telemetry appears with auto cell count (about 2 seconds with a fixed *Cells* value), once cell detection and voltage settling are done, VoltFuel starts from the BattAnalog-style resting-voltage value. A half-used pack therefore starts at its real level; a fully charged pack (4.19 V/cell) starts at about 99 %.
- **Nothing is reset automatically** — not on landing, not on a telemetry dropout.
- **Changing packs:** power-cycle the radio.
- **Putting the same pack back** with the radio left on: wait until the voltage is stable, then flip **ResetSw** (aircraft still, voltage settled).

## Display

- The level is drawn as a **segmented bar graph** (20 segments): red up to 20 %, orange up to 50 %, green above. Lit segments are filled; unlit ones are outlined.
- In taller widget zones a line above the bar shows the pack voltage, the cell count and the cell voltage, e.g. `25.15V 6S (4.19V/c)`. Small zones show only the percentages.
- **Before the first value** (for example the aircraft is not powered yet) the normal layout is drawn with zeros, so you can check the layout on the bench.

| Status line (taller zones, before the first value) | Meaning |
|---|---|
| Select Source | No Source chosen in the widget settings. |
| Check Source | The Source value is not a plausible pack voltage. |
| Acquiring... | Telemetry is present; cell detection and settling in progress. |

After a value has appeared and telemetry is lost, the last value is held and the line shows "No telemetry (value held)". Zones too short for a status line show the message text instead of the layout.

## Calibrating MinCv

Calibrate the voltage source first (see above).

The default (286) is based on the author's logs of 4S and 6S aircraft (one airplane, three helicopters; voltage from RxBt or Vbat). The MinCv that made the final VoltFuel value match the resting-voltage conversion of the final settled voltage — **not** a measured charge in mAh — was between about **270 and 298**, centred near 283. The default is set a little higher on purpose, so that the first readings err on the cautious (low) side. A small, high-load pack (for example a 2S 400 mAh helicopter) needed a much lower value (about 268) and reads low with the default. Expect to fine-tune it per aircraft over a few flights:

1. Fly as usual and land. Leave the aircraft powered.
2. Wait until the voltage has settled (30–60 s).
3. Compare the VoltFuel value (big number) with the value in parentheses.
4. If VoltFuel is **higher** than the parenthesized value, **raise** MinCv; if it is **lower**, **lower** MinCv. Near the landing region, one MinCv step (0.01 V) changes the result by roughly 0.7–1 point, so a 5-point gap is about 5–7 steps.
5. Repeat for 2–3 flights. Change **one** option at a time.

Notes: the parenthesized value is a plain resting-voltage conversion, so it is only a fair reference once the voltage has recovered after landing. A sensor with 0.1 V resolution (typical RxBt) limits the accuracy to a few percent.

## Voice call-out example

Create a logical switch on `sBAT < 60`, and a Special Function on that switch: *Play Value* `sBAT` (repeat every few seconds). Adjust the thresholds to your own landing policy.

## Limitations — please read

- It is an **estimate from voltage only**. Its accuracy against the real remaining capacity has **not** been measured. Checked only on 6S packs charged to about 4.2 V/cell (and one flight with a 2S LiPo-HV pack); aged packs, cold packs and other chemistries are untested.
- During a session the value **never rises**, except through ResetSw.
- Auto cell detection can mistake a deeply discharged pack for one cell fewer, and a LiPo-HV pack for one cell more when BattType is LiPo. Set **Cells** manually in that case.
- **Do not use it as your only landing criterion.**

## Credits and license

- The voltage-only estimator (sigmoid voltage → % curve, reserve rescale, sag-limited voltage filter, rate-limited consumption, stability gate) follows the approach of the voltage-only mode of SmartFuel in the Rotorflight Lua suite for EdgeTX. VoltFuel is an independent re-implementation, not a copy.
- **BattAnalog** (EdgeTX, Copyright Offer Shmuely, GPLv2): per-cell voltage → % tables, battery types, cell-count detection rule.
- Concept, requirements, flight testing and calibration: Masayuki. The code was written with Claude (Anthropic), an AI assistant.

VoltFuel is free software under the **GNU General Public License, version 2** (see `LICENSE`). Copyright (C) 2026 Masayuki.

## Changelog

- **0.9.5** — default MinCv changed from 290 to 286 (based on more logs; cautious side).
- **0.9.4** — README: how to check and calibrate the voltage source before tuning MinCv.
- **0.9.3** — optional `rMIN` telemetry sensor (the MinCv in use) for the SD log.
- **0.9.2** — segmented bar graph; zeros instead of a "No telemetry" message before the first value.
- **0.9.1** — pack voltage / cell count / cell voltage line; optional `rBAT` and `rCEL` telemetry sensors (ExtraTelem option).
- **0.9.0** — first public release.
