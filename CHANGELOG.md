# Changelog

The version number is shared by the widget, the tools on the radio and the PC tools.

## 0.9.4

### Added
- **VoltFuel Tools** on the radio (`SCRIPTS/TOOLS/VoltFuel_Tools.lua` and `SCRIPTS/TOOLS/VoltFuel/`), with three menus:
  - **Graph**: the log graph (the former `VoltFuel_Log.lua`).
  - **Tune**: suggests a MinCv from the newest usable logs of an aircraft. Logs without a flight, logs that are too short and logs without a resting stretch at the end are skipped, with the reason shown.
  - **Logs**: lists the logs of an aircraft with size and length; deletes marked logs, one log, or logs in bulk (all of the aircraft, shorter than N s, older than N days, all but the newest N), with confirmation.
- `VoltFuel_Tune.html`: the same MinCv suggestion on a PC, with the same skip rules (Japanese / English).
- `docs/`: user guide and support notes (Japanese / English).
- A "Requirements" section in the README (EdgeTX 2.12 or newer, pack-voltage telemetry).
- Widget README: how to check and calibrate the voltage source before tuning MinCv; how to set up the logging switch.
- Version numbers are shown in the tools.

### Changed
- `VoltFuel_Log.lua` is replaced by **VoltFuel_Tools → Graph**. Delete the old file from the SD card.

## 0.9.3
- Optional telemetry sensor `rMIN` (the MinCv in use), published with `rBAT` and `rCEL` when ExtraTelem is on, so that each flight's tuning is recorded in the SD log.

## 0.9.2
- The level is drawn as a segmented bar graph (red up to 20 %, orange up to 50 %, green above).
- Before the first value, the layout is drawn with zeros instead of a "No telemetry" message.

## 0.9.1
- A line above the bar shows the pack voltage, the cell count and the cell voltage.
- Optional telemetry sensors `rBAT` and `rCEL` (ExtraTelem option) for later analysis.

## 0.9.0
- First release of the widget (named VoltFuel).
