# VoltFuel

**Voltage-only battery gauge for EdgeTX — plus tools to analyse your flights.**
日本語版は [README.ja.md](README.ja.md) をご覧ください。

VoltFuel estimates the remaining capacity of a LiPo pack from the pack-voltage telemetry alone (no current sensor) and shows it as a bar and two numbers, e.g. `62%(48%)`. It is published as the telemetry sensor `sBAT` for voice call-outs and SD logging.

> **Not affiliated with Rotorflight.** Rotorflight's "SmartFuel" is a separate feature.

## What is in this repository

| Part | File | Purpose |
|---|---|---|
| Widget | `VoltFuel_SD/WIDGETS/voltfuel/main.lua` | The gauge widget (EdgeTX 3.x+, color-LCD touch radios) |
| Log viewer (radio) | `VoltFuel_SD/SCRIPTS/TOOLS/VoltFuel_Log.lua` | Graph a flight log on the radio (default: rCEL, sBAT, rBAT) |
| Log viewer (PC) | `VoltFuel_Compare.html` | Compare several flights in a web browser. UI language: Japanese |

## Quick install

1. Copy the contents of `VoltFuel_SD/` to the root of the radio's SD card, so that you get `/WIDGETS/voltfuel/main.lua` and `/SCRIPTS/TOOLS/VoltFuel_Log.lua`.
2. On the radio: long-press a Main View → add a widget → **VoltFuel**, then pick your pack-voltage **Source** in its settings.
3. For flight analysis, turn on the widget's **ExtraTelem** option and enable SD logging for `sBAT`, `rBAT`, `rCEL` and `rMIN`.

**Read [the widget README](VoltFuel_SD/WIDGETS/voltfuel/README.md) before flying** — in particular the sections on voltage-source calibration, MinCv tuning and limitations.

## Analysing logs

- **On the radio:** SYS → Tools → **VoltFuel_Log**. Pick a log file; if it contains `rCEL`, `sBAT` and `rBAT` the graph opens directly.
- **On a PC:** copy the log CSV files from the SD card's `/LOGS`, open `VoltFuel_Compare.html` in a browser (no installation, no upload — the files are processed locally) and select the CSV files or a folder.

## Limitations

VoltFuel is an **estimate from voltage only**; its accuracy against the real remaining capacity has not been measured. Do not use it as your only landing criterion.

## Credits and license

- The estimator follows the approach of the voltage-only mode of SmartFuel in the Rotorflight Lua suite; VoltFuel is an independent re-implementation, not a copy.
- **BattAnalog** (EdgeTX, Copyright Offer Shmuely, GPLv2): per-cell voltage → % tables, battery types, cell-count detection rule.
- Concept, requirements, flight testing and calibration: Masayuki. The code was written with Claude (Anthropic), an AI assistant.

Free software under the **GNU General Public License, version 2** — see [LICENSE](LICENSE). Copyright (C) 2026 Masayuki.
