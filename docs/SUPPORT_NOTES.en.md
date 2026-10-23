# VoltFuel Support Notes (0.9.4)

These notes summarize how VoltFuel works and how to tune it. Paste them into an AI chat to get help. 日本語: [SUPPORT_NOTES.ja.md](SUPPORT_NOTES.ja.md)

## 1. What VoltFuel is
An EdgeTX widget that estimates remaining battery capacity from voltage alone (no current sensor). It shows `62%(48%)`:
- `62%` = **sBAT**, the VoltFuel estimate. It starts from the resting-voltage value and then only goes **down**.
- `(48%)` = **rBAT**, the BattAnalog-style value: the table conversion of the *current* voltage. It reads low under load.

Telemetry sensors: `sBAT` (always); `rBAT`, `rCEL` (cell voltage) and `rMIN` (the MinCv in use, in V) only when ExtraTelem is on.

## 2. Options
| Option | Default | Role |
|---|---|---|
| Source | – | Pack-voltage telemetry |
| BattType | LiPo | LiPo / LiPo-HV / Li-Ion / LiFePO4. Used only for cell-count auto-detection and the `rBAT` / start-value tables. Does not change MinCv/MaxCv |
| Cells | 0 | 0 = auto-detect (re-checked for the first 8 s, then locked) |
| ResPct | 35 | Reserve: the point on the curve shown as 0 % |
| FallMv | 50 | Sag filter (mV/s). A limit on the Source voltage |
| MinCv | 290 | "Empty" cell voltage ×100. The main tuning knob |
| MaxCv | 410 | "Full" cell voltage ×100 |
| ResetSw | – | On the rising edge, jumps to the `rBAT`-style value |
| ExtraTelem | off | Publishes `rBAT`, `rCEL`, `rMIN` |

## 3. How sBAT is computed (summary)
1. Cell voltage = Source ÷ cell count.
2. **Sag filter**: the filtered voltage may fall by at most `FallMv ÷ 1000 × 0.8` V per second (rises are immediate).
3. **Curve**: `s = 3.00 + (v − MinCv) ÷ (MaxCv − MinCv) × 1.2` (clamped to 3.00–4.20), `raw% = 100 ÷ (1 + exp(−6 × (s − 3.70)))`. v ≥ MaxCv gives 100, v ≤ MinCv gives 0.
4. **Reserve**: `(raw − ResPct) × 100 ÷ (100 − ResPct)` (clamped to 0–100).
5. **Consumption** can only increase, by at most 1 %/s. `sBAT = 100 − consumption`.

Key property: **the final sBAT is set by the lowest filtered cell voltage of the flight.** It does not recover when the voltage rises after landing. Hard flights read low, gentle flights read high.

## 4. Tuning MinCv
- Reference: the **resting voltage** after landing, converted with the BattAnalog table (`rBAT`, or "Rest conv %" in the analyzer). It is not a measured mAh figure.
- sBAT **higher** than the conversion → **raise** MinCv. **Lower** → **lower** it.
- One step (0.01 V) changes sBAT by 0.3–1 point; flight-to-flight scatter is ±3–5 points. Move in steps of **5–10** and judge over **about three flights**.
- ResPct acts in the same direction (a larger effect per step). If you change ResPct, tune MinCv again.
- Examples (the author's data; they depend on aircraft and calibration): 6S LiPo aircraft 283–298; a small 2S LiPo-HV helicopter 258–277.
- Deeply discharged flights (low resting voltage) tend to read higher than the conversion at the same MinCv. For aircraft flown deep, a somewhat higher MinCv is the safer side.

## 5. Reading the analyzer (VoltFuel_Tune.html, or Tune on the radio)
The radio's Tune screen shows the same columns (Conv, sBAT, Used, Match, Sens; `!` = the simulation differs from the log by more than 3) and skips the same unusable logs (too short, no flight, no resting stretch at the end).
| Column | Meaning |
|---|---|
| Rest V/cell, Rest conv % | Mean voltage of the last 30 s of the log and its conversion |
| Logged final sBAT | The last sBAT in the log |
| MinCv used | `rMIN` from the log (×100) |
| Model diff | Simulation minus logged final sBAT. Beyond ±3, your ResPct, FallMv or MaxCv probably differ from those used for the log |
| MinCv to match | The MinCv for which the simulated final sBAT equals the rest conversion |
| Sens. | sBAT change per MinCv step (points). Flights below 0.15 in absolute value are left out of the aircraft recommendation |

The per-aircraft "Recommended" MinCv minimizes the error over that aircraft's flights.

## 6. Things to watch
- **Calibrate the voltage source** first (Offset / Ratio). Without it, a MinCv value does not transfer to other aircraft or users.
- Sensors with 0.1 V steps (e.g. RxBt) make the conversion jump by 5 points or more on small packs (2S–3S).
- If the Source is a per-cell voltage sensor, set Cells to 1. FallMv limits the Source voltage, so it acts differently than on a pack voltage.
- Auto cell detection can mistake a deeply discharged 6S for 5S, and a LiPo-HV 6S for 7S when BattType is LiPo.
- Verified only on a few 6S LiPo aircraft and a small 2S LiPo-HV helicopter. Aged packs, cold packs and other chemistries are untested.
- In one logged session on the ground, the sensor values (sBAT and the others) were recorded as 0 for about ten seconds. The cause is unknown. To be safe, do not open the widget's settings screen in flight.
- Logging needs a Special Function *SD Logs*. If it is always ON, a log is created every time the radio is switched on. At the least, switch it with a logical switch `a>x` (V1 = the voltage Source, V2 = 2 V) so that logs exist only while the aircraft is powered. Keep it powered for 30–60 s after landing to record the resting voltage. Logging interval: 1.0 s.

## 7. Asking an AI for help
Paste these together with this note:
1. Aircraft, battery (cells, chemistry, capacity), voltage Source and its calibration
2. Settings (BattType, Cells, ResPct, FallMv, MinCv, MaxCv)
3. The analyzer table (text or screenshot)
4. What worries you (e.g. "sBAT reads too high")

An AI's advice can be wrong. The MinCv guidance is an estimate from a small number of flights. Do not use it for landing decisions.
