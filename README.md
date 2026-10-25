# VoltFuel

**Voltage-only battery gauge for EdgeTX — plus tools to analyse your flights.**
日本語版は [README.ja.md](README.ja.md) をご覧ください。

VoltFuel estimates the remaining capacity of a LiPo pack from the pack-voltage telemetry alone (no current sensor) and shows it as a bar and two numbers, e.g. `62%(48%)`. It is published as the telemetry sensor `sBAT` for voice call-outs and SD logging.

> **Not affiliated with Rotorflight.** Rotorflight's "SmartFuel" is a separate feature.

## Requirements

- **EdgeTX 2.12 or newer**, on a color-LCD touch radio (developed on TX16S, TX15 and GX15). Not for black-and-white radios.
- **Pack-voltage telemetry** (for example RxBt, Vbat or VFAS). VoltFuel works from voltage alone, so no current sensor is needed; a receiver that only reports its own BEC voltage cannot be used.
- The tools on the radio work with the log files that SD logging writes to `/LOGS`.

## What is in this repository

| Part | File | Purpose |
|---|---|---|
| Widget | `VoltFuel_SD/WIDGETS/voltfuel/main.lua` | The gauge widget (EdgeTX 2.12+, color-LCD touch radios) |
| VoltFuel Tools (radio) | `VoltFuel_SD/SCRIPTS/TOOLS/VoltFuel_Tools.lua` (+ `SCRIPTS/TOOLS/VoltFuel/`) | Menu on the radio: **Graph** (a log, default rCEL / sBAT / rBAT), **Tune** (suggests a MinCv from your logs), **Logs** (size and length of each log, delete) |
| Log viewer (PC) | `VoltFuel_Compare.html` | Compare several flights in a web browser. UI language: Japanese |
| MinCv tuning (PC) | `VoltFuel_Tune.html` | Suggests a MinCv from your logs, per flight and per aircraft. UI language: Japanese / English |
| Documents | `docs/` | User guide and support notes (Japanese / English) |

## Quick install

1. Copy the contents of `VoltFuel_SD/` to the root of the radio's SD card, so that you get `/WIDGETS/voltfuel/main.lua`, `/SCRIPTS/TOOLS/VoltFuel_Tools.lua` and `/SCRIPTS/TOOLS/VoltFuel/`.
2. On the radio: long-press a Main View → add a widget → **VoltFuel**, then pick your pack-voltage **Source** in its settings.
3. For flight analysis, turn on the widget's **ExtraTelem** option and enable SD logging for `sBAT`, `rBAT`, `rCEL` and `rMIN`.

**Read [the widget README](VoltFuel_SD/WIDGETS/voltfuel/README.md) before flying** — in particular the sections on voltage-source calibration, MinCv tuning and limitations.

## Analysing logs

- **On the radio:** SYS → Tools → **VoltFuel_Tools** → **Graph**. Pick a log file; if it contains `rCEL`, `sBAT` and `rBAT` the graph opens directly.
- **On a PC:** copy the log CSV files from the SD card's `/LOGS`, open `VoltFuel_Compare.html` in a browser (no installation, no upload — the files are processed locally) and select the CSV files or a folder.

## Tuning MinCv and further reading

- **Tune on the radio:** SYS → Tools → **VoltFuel_Tools** → **Tune**. Choose the aircraft; its newest usable logs (8 by default, set in *Settings*) are analysed (logs without a flight, too short, or without a resting stretch at the end are skipped and listed with the reason) and a MinCv is suggested. Logs that were flown with a MinCv close to the suggestion (±5) are marked `*`, with a summary of how they came out. In *Settings* enter the same battery type, cells, ResPct, FallMv and MaxCv as in the widget. The radio screens are in English.
- **Logs on the radio:** **VoltFuel_Tools → Logs** lists the logs of an aircraft with size and length; mark and delete logs, or delete in bulk (all logs of the aircraft, shorter than N s, older than N days, all but the newest N). Deleting cannot be undone; stop logging first.
- **Tune on a PC:** open `VoltFuel_Tune.html` in a browser (same calculation), load about three flights' CSV logs, and read the suggested MinCv per aircraft (no installation, no upload).
- **User guide:** [docs/USER_GUIDE.en.md](docs/USER_GUIDE.en.md) — setup, voltage-source calibration, logging, MinCv tuning, what to include when you ask for help.
- **Support notes:** [docs/SUPPORT_NOTES.en.md](docs/SUPPORT_NOTES.en.md) — how sBAT is computed and how to tune it. Paste it into an AI chat when you ask for help.

## Limitations

VoltFuel is an **estimate from voltage only**; its accuracy against the real remaining capacity has not been measured. Do not use it as your only landing criterion.

## Credits and license

- The estimator follows the approach of the voltage-only mode of SmartFuel in the Rotorflight Lua suite; VoltFuel is an independent re-implementation, not a copy.
- **BattAnalog** (EdgeTX, Copyright Offer Shmuely, GPLv2): per-cell voltage → % tables, battery types, cell-count detection rule.
- Concept, requirements, flight testing and calibration: Masayuki. The code was written with Claude (Anthropic), an AI assistant.

Free software under the **GNU General Public License, version 2** — see [LICENSE](LICENSE). Copyright (C) 2026 Masayuki.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
