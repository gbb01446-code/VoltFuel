# VoltFuel Tester Guide (0.9.4)

Thank you for testing VoltFuel. This guide covers setup, logging, MinCv tuning and reporting. 日本語: [TESTER_GUIDE.ja.md](TESTER_GUIDE.ja.md)

## In the repository
| File | Purpose |
|---|---|
| `VoltFuel_SD/` | Copy its contents to the root of the SD card. It holds the widget (`WIDGETS/voltfuel/`) and the on-radio tools (`SCRIPTS/TOOLS/VoltFuel_Tools.lua`: Graph / Tune / Logs). See `VoltFuel_SD/WIDGETS/voltfuel/README.md` |
| `VoltFuel_Tune.html` | Suggests a MinCv from your logs (just open it in a browser; logs are not uploaded) |
| `VoltFuel_Compare.html` | Compares several flights as graphs (just open it in a browser; Japanese UI) |
| `docs/SUPPORT_NOTES.en.md` | How it works and how to tune it. Paste it into an AI chat for help |

## Please note
- VoltFuel is an **estimate from voltage only**. Its accuracy against the real remaining capacity has not been measured. **Never use it as your only landing criterion.**
- For EdgeTX 3.x or newer color-LCD touch radios (not black-and-white radios). It uses 10 widget options.

## 1. Setup
1. Copy the contents of `VoltFuel_SD/` to the root of the SD card (you get `/WIDGETS/voltfuel/` and `/SCRIPTS/TOOLS/`).
2. Add the widget to a Main View and open its settings.
3. Choose **Source** (pack-voltage telemetry): a sensor that reports the **pack** voltage, not a receiver BEC voltage.
4. Set **BattType**. **Cells** can stay at 0 (auto); set it by hand for deeply discharged packs or LiPo-HV, where auto detection can be wrong.
5. Turn **ExtraTelem on**: `rBAT`, `rCEL` and `rMIN` are published for analysis.
6. Check that `sBAT` and the other sensors appear in the Telemetry sensor list (if not, run *Discover new sensors*).

## 2. Calibrate the voltage source (do this first)
Telemetry voltages are often uncalibrated and can be off by a few hundredths of a volt. A tuned MinCv then fits only that one aircraft.

1. Measure a pack **at rest** (no load) with a voltmeter or battery checker you trust.
2. At the same moment, read the Source value on the Telemetry screen.
3. If they differ, set **Offset** (constant difference) and/or **Ratio** (proportional error) on the sensor in *Model Settings → Telemetry*. Set Precision to 0.00 to enter a fractional offset.
4. Measuring two packs at different voltages (e.g. full and part-used) is more reliable.

## 3. Log setup
In the model's SD logging, record:
- the voltage Source (RxBt, Vbat, …)
- `sBAT`, `rBAT`, `rCEL`, `rMIN`
- if you have them, current and throttle (useful for analysis)

## 4. Test flights
1. With a fully charged pack, power on the radio and then the aircraft. A value appears after about 9 seconds (about 2 seconds with a fixed Cells value).
2. Fly as usual.
3. **After landing, leave the aircraft powered for 30–60 seconds.** (This records the resting voltage.)
4. If you can, **note the mAh the charger puts back**. It is the most reliable reference for the real remaining capacity.
5. To change packs, **power-cycle the radio**. If you put the same pack back with the radio left on, flip ResetSw once the voltage is stable.

## 5. Tuning MinCv
1. **On the radio:** SYS → Tools → VoltFuel_Tools → Tune, choose the aircraft (first enter your widget settings in *Settings*). Or load about three flights' logs into `VoltFuel_Tune.html` on a PC. Logs that are not usable flights (bench runs, very short logs, no resting stretch at the end) are skipped automatically; **VoltFuel_Tools → Logs** shows the size and length of each log and deletes the ones you do not need.
2. Compare "Logged final sBAT" with "Rest conv %".
   - sBAT **higher** than the conversion (optimistic): **raise** MinCv.
   - sBAT **lower** (pessimistic): **lower** MinCv.
3. Use the per-aircraft "Recommended" MinCv as a guide.
4. Move it in steps of **5–10**. One step changes sBAT by only 0.3–1 point, which is buried in the flight-to-flight scatter (±3–5 points).
5. Change only one option at a time and judge over about three flights.

For reference, on the author's 6S LiPo aircraft MinCv came out at 283–298 (default 290); on a small 2S LiPo-HV helicopter at 258–277. These are examples only and depend on the aircraft and the voltage calibration.

## 6. What to report
Please note and send:
- Aircraft (type, size) and battery (cells, chemistry, capacity, C rating, age or number of cycles)
- The voltage Source and its calibration (Offset or Ratio)
- Settings (BattType, Cells, ResPct, FallMv, MinCv, MaxCv)
- The log CSV files, or the VoltFuel_Tune table
- The sBAT at landing and the mAh charged afterwards (if known)
- Anything you noticed (display, messages, sensors missing, jumps in the values)

## If something goes wrong
- "Select Source" or "Check Source" appears → check the Source setting.
- No value appears → check that the aircraft is powered and the sensor is selected.
- More: `VoltFuel_SD/WIDGETS/voltfuel/README.md` and `docs/SUPPORT_NOTES.en.md`.
