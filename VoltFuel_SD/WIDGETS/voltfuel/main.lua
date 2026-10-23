--[[
  VoltFuel 0.9.4 -- voltage-only battery gauge widget for EdgeTX
  (color-LCD touch radios: TX16S, TX15, GX15, ...; EdgeTX 2.12 or newer)

  Copyright (C) 2026 Masayuki
  License: GNU General Public License, version 2 (see LICENSE).
  This widget contains per-cell voltage tables and cell-count logic taken
  from EdgeTX's BattAnalog widget (Copyright Offer Shmuely, GPLv2), so it
  is distributed under the same license. See CREDITS at the end.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation. It is distributed in the
  hope that it will be useful, but WITHOUT ANY WARRANTY; without even
  the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  WHAT IT DOES
  ------------------------------------------------------------------------
  Estimates the remaining pack capacity from the pack-voltage telemetry
  alone -- no current sensor needed. It shows two numbers, e.g. "62%(48%)":

    62%  the VoltFuel estimate. It starts from the resting-voltage value,
         then only ever goes DOWN (a sag filter and a drop-rate limit keep
         throttle bursts from making it jump). It is also published as the
         telemetry sensor "sBAT" for voice call-outs, logical switches and
         SD logging.
    (48%) the BattAnalog-style value: the plain voltage->% table of
         EdgeTX's BattAnalog widget applied to the CURRENT voltage. It is
         an independent reference -- most useful on the ground, after
         landing, once the voltage has settled.
    In taller zones a line above the bar also shows the pack voltage,
    the cell count and the cell voltage, e.g. "25.15V 6S (4.19V/c)".

  INSTALL
  ------------------------------------------------------------------------
  Copy the whole "voltfuel" folder to  /WIDGETS/voltfuel/main.lua  on the
  SD card (the folder name must stay 8 characters or less -- an EdgeTX
  requirement). Then: long-press a Main View -> add a widget -> VoltFuel.
  Long-press the widget -> Settings to configure it. Once the widget
  shows a value, the "sBAT" sensor appears in the Telemetry sensor list
  (if it does not, run "Discover new sensors" on the Telemetry page).
  Do not run this together with another widget that publishes an "sBAT"
  sensor.

  BEFORE YOU START: the voltage source (RxBt etc.) is usually not
  calibrated. Compare it with a trusted voltmeter on a resting pack and
  correct it with the sensor's Offset / Ratio (Model Settings ->
  Telemetry -> select the sensor -> Edit); use Precision 0.00 to enter a
  fractional offset. Do this BEFORE tuning MinCv -- a tuned MinCv is only
  valid for the calibration it was tuned with. See the README.

  OPTIONS
  ------------------------------------------------------------------------
    Source   -- your pack-voltage telemetry sensor (VFAS, RxBt, Vbat, ...).
                Must be the PACK voltage, not a receiver BEC voltage.
    BattType -- LiPo / LiPo-HV / Li-Ion / LiFePO4. Used ONLY for cell-count
                auto-detection and for the BattAnalog-style value in
                parentheses. It does NOT change MinCv/MaxCv -- set those
                yourself for the VoltFuel curve.
    Cells    -- cell count. 0 = auto-detect (BattAnalog rule; re-checked
                for the first 8 seconds, then locked).
    ResPct   -- reserve percent (0-60, default 35): the point on the curve
                that is shown as 0%. Higher = reads lower / reaches 0%
                sooner. If you change it, re-tune MinCv.
    FallMv   -- sag-filter limit in mV per second (default 50): how fast
                the filtered voltage may fall. Lower = smoother.
    MinCv    -- "empty" cell voltage x100 -> curve 0% (default 290). The
                main tuning knob; see CALIBRATION. Higher MinCv = lower
                reading.
    MaxCv    -- "full" cell voltage x100 (410 = 4.10 V) -> curve 100%.
                Not tuned for other chemistries (LiPo-HV: only one 2S flight checked).
    TxtColor -- text color.
    ResetSw  -- optional switch / logical switch. On the rising edge it
                jumps the VoltFuel value to the BattAnalog-style value at
                that instant (cell count is re-detected when Cells = 0).
                Use it after a ground pause, or after putting the same
                pack back, while the radio stays on -- and only while the
                aircraft is still and the voltage has settled.
    ExtraTelem -- on/off (default off). When on, three more telemetry
                sensors are published for later analysis (see TELEMETRY
                SENSORS below).

  TELEMETRY SENSORS
  ------------------------------------------------------------------------
    sBAT  -- the VoltFuel estimate, % (always published).
    rBAT  -- the BattAnalog-style value, % (only when ExtraTelem is on).
             A plain voltage->% conversion of the CURRENT voltage, so it
             reads low under load (sag) and is closest to the real
             remaining capacity at rest.
    rCEL  -- cell voltage, V (only when ExtraTelem is on).
    rMIN  -- the MinCv setting in use, V (260 -> 2.60). Only when
             ExtraTelem is on. It records the tuning of each flight in
             the SD log.
  rBAT, rCEL and rMIN are published only once the cell count is settled
  (about 8 seconds after telemetry appears with Cells = 0). The sensors show up
  in the Telemetry sensor list after their first value; a sensor name is
  fixed when the sensor is created.

  POWER-ON AND RESET
  ------------------------------------------------------------------------
  The starting value is NOT 100%. Once the cell count is locked and the
  voltage has settled (about 8-9 seconds after telemetry appears with auto cell
  count, about 2 seconds with a fixed Cells value), VoltFuel
  starts from the BattAnalog-style resting-voltage value, so a half-used
  pack starts at its real level (a fully charged 4.19 V/cell pack starts
  at about 99%). Nothing is ever reset automatically afterwards -- not on
  landing, not on a telemetry dropout. To change packs, power-cycle the
  radio (or flip ResetSw).

  DISPLAY
  ------------------------------------------------------------------------
  The level is drawn as a segmented bar graph (20 segments): red up to
  20%, orange up to 50%, green above (BAR_RED_END / BAR_ORANGE_END near
  the top of the display code). Before the first value -- e.g. the
  aircraft is not powered yet -- the normal layout is drawn with zeros,
  so the layout can be checked on the bench. In taller zones the line
  above the bar then shows a status instead of the voltage:
    Select Source  -- no Source chosen in the widget settings
    Check Source   -- the Source value is not a plausible pack voltage
    Acquiring...   -- telemetry is present; cell detection / settling
  After a value has appeared and telemetry is lost, the last value is
  held and the line shows "No telemetry (value held)". Zones too short
  for a status line show the message text instead of the layout.

  CALIBRATION NOTES
  ------------------------------------------------------------------------
  The default MinCv (290) comes from the author's 9 logged flights: 8 on
  6S packs (about 4.2 V/cell when full) and 1 on a 2S LiPo-HV pack; one airplane
  and three helicopters; voltage from Vbat or RxBt. The reference was the
  resting-voltage conversion of the final settled voltage, NOT a measured
  charge in mAh. The MinCv that made the final VoltFuel value match that
  reference was 283-298 on 6S (one short, low-sag flight was left out
  because its result barely depends on MinCv) and 277 on the 2S LiPo-HV heli.
  Expect to fine-tune it per aircraft over a few flights -- see the
  README.

  LIMITATIONS
  ------------------------------------------------------------------------
  This is an ESTIMATE from voltage only. Its accuracy against the real
  remaining capacity has not been measured. It has been checked only on
  6S packs charged to about 4.2 V/cell (and one flight with a 2S LiPo-HV pack); aged packs,
  cold packs and other chemistries are untested. During a session the
  value never rises, except through ResetSw. Auto cell detection can
  mistake a deeply discharged pack for one cell fewer (and a LiPo-HV pack
  for one cell more if BattType is LiPo) -- set Cells manually in that
  case. Do not use it as your only landing criterion.

  CREDITS
  ------------------------------------------------------------------------
  - The voltage-only estimator (sigmoid voltage->% curve, reserve
    rescale, sag-limited voltage filter, rate-limited consumption,
    stability gate) follows the approach of the voltage-only mode of
    SmartFuel in the Rotorflight Lua suite for EdgeTX. This is an
    independent re-implementation, not a copy, and VoltFuel is not
    affiliated with or endorsed by the Rotorflight project. (Rotorflight's
    SmartFuel is a separate feature.)
  - BattAnalog (EdgeTX; Copyright Offer Shmuely; GPLv2): the per-cell
    voltage->% tables, the battery types and the cell-count detection
    rule.
  - Concept, requirements, flight testing and calibration: Masayuki.
    The code was written with Claude (Anthropic), an AI assistant.
--]]

local STABLE_WINDOW_VOLTS = 0.15
local STABLE_SAMPLE_COUNT = 5
local STABILIZE_DELAY_SECONDS = 1.5
local FUEL_DROP_PERCENT_PER_SECOND = 1.0
local SAG_GAIN = 40  -- 0-100: scales the FallMv limit down by up to 50% (40 -> x0.8)

-- Custom telemetry sensor (setTelemetryValue) identity for the published
-- VoltFuel % value. id/subID/instance just need to not collide with a
-- real physical sensor on your receiver -- these are arbitrary high
-- values chosen to make a collision unlikely. If "sBAT%" ends up merged
-- with an unrelated sensor on your radio, change SENSOR_ID below.
local SENSOR_ID = 0x7C00
local SENSOR_SUBID = 0
local SENSOR_INSTANCE = 0
local SENSOR_NAME = "sBAT"
-- Optional extra sensors (ExtraTelem option): BattAnalog-style % and cell voltage.
local REF_SENSOR_ID = 0x7C01
local REF_SENSOR_NAME = "rBAT"
local CEL_SENSOR_ID = 0x7C02
local CEL_SENSOR_NAME = "rCEL"
local MIN_SENSOR_ID = 0x7C03
local MIN_SENSOR_NAME = "rMIN"

local SIGMOID_MIN, SIGMOID_MAX = 3.00, 4.20
-- Steepness of the voltage->% curve. Lower = flatter through the middle.
-- With the default MinCv/MaxCv, a steeper value of 12 would squeeze the
-- 60-30% band into about 0.1 V per cell; at 6 it spans about 0.2 V.
local SIGMOID_K = 6

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function sigmoidPercent(vScaled)
  vScaled = clamp(vScaled, SIGMOID_MIN, SIGMOID_MAX)
  return 100 / (1 + math.exp(-SIGMOID_K * (vScaled - 3.70)))
end

local function rawPercentFromCellVoltage(vCell, minV, maxV)
  if vCell >= maxV then return 100 end
  if vCell <= minV then return 0 end
  local scaled = SIGMOID_MIN + (vCell - minV) / (maxV - minV) * (SIGMOID_MAX - SIGMOID_MIN)
  return sigmoidPercent(scaled)
end

local function applyReserve(rawPct, reservePct)
  reservePct = clamp(reservePct, 0, 99)
  if reservePct <= 0 then return clamp(rawPct, 0, 100) end
  local pct = (rawPct - reservePct) * 100 / (100 - reservePct)
  return clamp(pct, 0, 100)
end

-- ===========================================================================
-- BattAnalog-compatible per-cell voltage -> % tables and cell-count logic.
-- Tables, top-cell voltages, the cell-count boundary rule and the
-- nearest-entry lookup follow EdgeTX BattAnalog (app.lua), by Offer
-- Shmuely, GPLv2. They are used ONLY for (a) auto cell-count detection
-- and (b) the parenthetical comparison value on the display. They are
-- NOT tied to MinCv/MaxCv/ResPct, and they do not affect sBAT%.
-- BattType option index: 1=LiPo, 2=LiPo-HV, 3=Li-Ion, 4=LiFePO4.
-- ===========================================================================
local percent_list_lipo = {
    {3.000,  0},
    {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10},
    {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20},
    {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30},
    {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.818, 40},
    {3.822, 41}, {3.825, 42}, {3.829, 43}, {3.833, 44}, {3.836, 45}, {3.840, 46}, {3.843, 47}, {3.847, 48}, {3.850, 49}, {3.854, 50},
    {3.857, 51}, {3.860, 52}, {3.863, 53}, {3.866, 54}, {3.870, 55}, {3.874, 56}, {3.879, 57}, {3.888, 58}, {3.893, 59}, {3.897, 60},
    {3.902, 61}, {3.906, 62}, {3.911, 63}, {3.918, 64}, {3.923, 65}, {3.928, 66}, {3.939, 67}, {3.943, 68}, {3.949, 69}, {3.955, 70},
    {3.961, 71}, {3.968, 72}, {3.974, 73}, {3.981, 74}, {3.987, 75}, {3.994, 76}, {4.001, 77}, {4.007, 78}, {4.014, 79}, {4.021, 80},
    {4.029, 81}, {4.036, 82}, {4.044, 83}, {4.052, 84}, {4.062, 85}, {4.074, 86}, {4.085, 87}, {4.095, 88}, {4.105, 89}, {4.111, 90},
    {4.116, 91}, {4.120, 92}, {4.125, 93}, {4.129, 94}, {4.135, 95}, {4.145, 96}, {4.176, 97}, {4.179, 98}, {4.193, 99}, {4.200,100},
}

local percent_list_hv = {
    {3.000,  0},
    {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10},
    {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20},
    {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30},
    {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.828, 40},
    {3.832, 41}, {3.836, 42}, {3.841, 43}, {3.846, 44}, {3.850, 45}, {3.855, 46}, {3.859, 47}, {3.864, 48}, {3.868, 49}, {3.873, 50},
    {3.877, 51}, {3.881, 52}, {3.885, 53}, {3.890, 54}, {3.895, 55}, {3.900, 56}, {3.907, 57}, {3.917, 58}, {3.924, 59}, {3.929, 60},
    {3.936, 61}, {3.942, 62}, {3.949, 63}, {3.957, 64}, {3.964, 65}, {3.971, 66}, {3.984, 67}, {3.990, 68}, {3.998, 69}, {4.006, 70},
    {4.015, 71}, {4.024, 72}, {4.032, 73}, {4.042, 74}, {4.050, 75}, {4.060, 76}, {4.069, 77}, {4.078, 78}, {4.088, 79}, {4.098, 80},
    {4.109, 81}, {4.119, 82}, {4.130, 83}, {4.141, 84}, {4.154, 85}, {4.169, 86}, {4.184, 87}, {4.197, 88}, {4.211, 89}, {4.220, 90},
    {4.229, 91}, {4.237, 92}, {4.246, 93}, {4.254, 94}, {4.264, 95}, {4.278, 96}, {4.302, 97}, {4.320, 98}, {4.339, 99}, {4.350,100},
}

local percent_list_lion = {
    { 2.800,  0 }, { 2.840,  1 }, { 2.880,  2 }, { 2.920,  3 }, { 2.960,  4 },
    { 3.000,  5 }, { 3.040,  6 }, { 3.080,  7 }, { 3.096,  8 }, { 3.112,  9 },
    { 3.128, 10 }, { 3.144, 11 }, { 3.160, 12 }, { 3.176, 13 }, { 3.192, 14 },
    { 3.208, 15 }, { 3.224, 16 }, { 3.240, 17 }, { 3.256, 18 }, { 3.272, 19 },
    { 3.288, 20 }, { 3.304, 21 }, { 3.320, 22 }, { 3.336, 23 }, { 3.352, 24 },
    { 3.368, 25 }, { 3.384, 26 }, { 3.400, 27 }, { 3.416, 28 }, { 3.432, 29 },
    { 3.448, 30 }, { 3.464, 31 }, { 3.480, 32 }, { 3.496, 33 }, { 3.504, 34 },
    { 3.512, 35 }, { 3.520, 36 }, { 3.528, 37 }, { 3.536, 38 }, { 3.544, 39 },
    { 3.552, 40 }, { 3.560, 41 }, { 3.568, 42 }, { 3.576, 43 }, { 3.584, 44 },
    { 3.592, 45 }, { 3.600, 46 }, { 3.608, 47 }, { 3.616, 48 }, { 3.624, 49 },
    { 3.632, 50 }, { 3.640, 51 }, { 3.648, 52 }, { 3.656, 53 }, { 3.664, 54 },
    { 3.672, 55 }, { 3.680, 56 }, { 3.688, 57 }, { 3.696, 58 }, { 3.704, 59 },
    { 3.712, 60 }, { 3.720, 61 }, { 3.728, 62 }, { 3.736, 63 }, { 3.744, 64 },
    { 3.752, 65 }, { 3.760, 66 }, { 3.768, 67 }, { 3.776, 68 }, { 3.784, 69 },
    { 3.792, 70 }, { 3.800, 71 }, { 3.810, 72 }, { 3.820, 73 }, { 3.830, 74 },
    { 3.840, 75 }, { 3.850, 76 }, { 3.860, 77 }, { 3.870, 78 }, { 3.880, 79 },
    { 3.890, 80 }, { 3.900, 81 }, { 3.910, 82 }, { 3.920, 83 }, { 3.930, 84 },
    { 3.940, 85 }, { 3.950, 86 }, { 3.960, 87 }, { 3.970, 88 }, { 3.980, 89 },
    { 3.990, 90 }, { 4.000, 91 }, { 4.010, 92 }, { 4.030, 93 }, { 4.050, 94 },
    { 4.070, 95 }, { 4.090, 96 }, { 4.10, 100 }, { 4.15 ,100 }, { 4.20, 100},
}

local percent_list_life_po4 = {
    {2.500,  0},
    {2.509,  1}, {2.518,  2}, {2.527,  3}, {2.536,  4}, {2.545,  5}, {2.554,  6}, {2.563,  7}, {2.572,  8}, {2.581,  9}, {2.590, 10},
    {2.599, 11}, {2.608, 12}, {2.617, 13}, {2.626, 14}, {2.635, 15}, {2.644, 16}, {2.653, 17}, {2.662, 18}, {2.671, 19}, {2.680, 20},
    {2.689, 21}, {2.698, 22}, {2.707, 23}, {2.716, 24}, {2.725, 25}, {2.734, 26}, {2.743, 27}, {2.752, 28}, {2.761, 29}, {2.770, 30},
    {2.779, 31}, {2.788, 32}, {2.797, 33}, {2.806, 34}, {2.815, 35}, {2.824, 36}, {2.833, 37}, {2.842, 38}, {2.851, 39}, {2.860, 40},
    {2.869, 41}, {2.878, 42}, {2.887, 43}, {2.896, 44}, {2.905, 45}, {2.914, 46}, {2.923, 47}, {2.932, 48}, {2.941, 49}, {2.950, 50},
    {2.959, 51}, {2.968, 52}, {2.977, 53}, {2.986, 54}, {2.995, 55}, {3.004, 56}, {3.013, 57}, {3.022, 58}, {3.031, 59}, {3.040, 60},
    {3.049, 61}, {3.058, 62}, {3.067, 63}, {3.076, 64}, {3.085, 65}, {3.094, 66}, {3.103, 67}, {3.112, 68}, {3.121, 69}, {3.130, 70},
    {3.139, 71}, {3.148, 72}, {3.157, 73}, {3.166, 74}, {3.175, 75}, {3.184, 76}, {3.193, 77}, {3.202, 78}, {3.211, 79}, {3.220, 80},
    {3.229, 81}, {3.238, 82}, {3.247, 83}, {3.256, 84}, {3.265, 85}, {3.274, 86}, {3.283, 87}, {3.292, 88}, {3.301, 89}, {3.310, 90},
    {3.319, 91}, {3.328, 92}, {3.337, 93}, {3.346, 94}, {3.355, 95}, {3.364, 96}, {3.373, 97}, {3.382, 98}, {3.391, 99}, {3.400,100},
}

local PERCENT_LISTS = {
  percent_list_lipo, percent_list_hv, percent_list_lion, percent_list_life_po4,
}

-- Full-charge cell voltage per type; the cell-count boundary for N cells
-- is TOP_CELL_VOLTAGE * N (same rule as BattAnalog).
local TOP_CELL_VOLTAGE = { 4.30, 4.45, 4.30, 3.50 }  -- LiFePO4: reliable up to 3 cells only
local CELL_DETECTION_SECONDS = 8

local function calcCellCount(totalVoltage, battType)
  local top = TOP_CELL_VOLTAGE[battType] or TOP_CELL_VOLTAGE[1]
  for i = 1, 12 do
    if totalVoltage < top * i then return i end
  end
  return 1  -- no match (same fallback as BattAnalog)
end

-- Same result as BattAnalog's getCellPercent: 0 / 100 outside the table,
-- otherwise the nearer of the two neighbouring table entries.
local function batteryCellPercent(vCell, battType)
  local list = PERCENT_LISTS[battType] or PERCENT_LISTS[1]
  if vCell <= list[1][1] then return 0 end
  if vCell >= list[#list][1] then return 100 end
  local l, u = 1, #list
  while u - l > 1 do
    local n = math.floor((l + u) / 2)
    if vCell >= list[n][1] then l = n else u = n end
  end
  if vCell < (list[l][1] + list[u][1]) / 2 then
    return list[l][2]
  end
  return list[u][2]
end

local function nowSeconds()
  return getTime() / 100
end

-- ===========================================================================
-- Widget interface
-- ===========================================================================
local options = {
  { "Source", SOURCE, 0 },
  { "BattType", CHOICE, 1, { "LiPo", "LiPo-HV", "Li-Ion", "LiFePO4" } },
  { "Cells", VALUE, 0, 0, 20 },
  { "ResPct", VALUE, 35, 0, 60 },
  { "FallMv", VALUE, 50, 0, 1000 },
  { "MinCv", VALUE, 290, 250, 400 },
  { "MaxCv", VALUE, 410, 250, 430 },
  { "TxtColor", COLOR, WHITE },
  { "ResetSw", SOURCE, 0 },
  { "ExtraTelem", BOOL, 0 },
}

local function create(zone, opt)
  return {
    zone = zone,
    options = opt,
    startedAt = nil,
    cellCount = nil,
    cellLocked = false,
    detectStartedAt = nil,
    voltageSamples = {},
    voltageStable = false,
    filteredVoltage = nil,
    lastTimestamp = nil,
    initialized = false,
    virtualConsumedPct = nil,
    lastFuelPercent = nil,
    lastInstantRawPct = nil,
    lastVcell = nil,
    lastRawPct = nil,
    resetSwPrevActive = false,
    status = "nolink",
  }
end

-- Manual re-sync: jumps VoltFuel's internal state straight to the
-- BattAnalog-style reading (see batteryCellPercent above) at the
-- CURRENT voltage, discarding whatever the rate-limited virtual
-- consumption had accumulated. Use this after anything VoltFuel's own
-- continuous-flight model doesn't expect: a ground pause mid-session
-- (power stays on, you tinker with something, then fly again), or
-- swapping in a different/partially-used pack without power-cycling the
-- radio. Trigger it via the ResetSw option (a switch or logical switch)
-- -- do this ONLY while the aircraft is sitting still with a settled
-- voltage, same as any other ground reading, or you'll bake in a sag-
-- affected number. When Cells = 0 the cell count is re-detected from
-- the current voltage and locked immediately.
local function performReset(wgt, voltage)
  local battType = wgt.options.BattType or 1
  if not (wgt.options.Cells and wgt.options.Cells > 0) then
    wgt.cellCount = calcCellCount(voltage, battType)
    wgt.cellLocked = true
  end
  local vCell = voltage / wgt.cellCount
  local genericPct = batteryCellPercent(vCell, battType)

  wgt.virtualConsumedPct = 100 - genericPct
  wgt.filteredVoltage = voltage
  wgt.voltageSamples = {}
  wgt.startedAt = nil
  wgt.lastTimestamp = nowSeconds()
  wgt.initialized = true
  -- Also push the display value directly, so the reset is visible on
  -- the SAME cycle rather than waiting out the normal stabilize delay
  -- (the switch flip IS the person's attestation that this reading is
  -- trustworthy right now, so there is nothing left to "prove").
  local maxCellVoltage = (wgt.options.MaxCv or 410) / 100
  local minCellVoltage = (wgt.options.MinCv or 290) / 100
  wgt.lastFuelPercent = clamp(genericPct, 0, 100)
  wgt.lastVcell = vCell
  wgt.lastRawPct = rawPercentFromCellVoltage(vCell, minCellVoltage, maxCellVoltage)
end

local function update(wgt, opt)
  wgt.options = opt
  -- Any settings change restarts cell-count detection (BattType may have
  -- changed). step() applies a manual Cells value immediately.
  wgt.cellCount = nil
  wgt.cellLocked = false
  wgt.detectStartedAt = nil
end

local function updateStability(wgt, voltage, now)
  if wgt.startedAt == nil then wgt.startedAt = now end
  if (now - wgt.startedAt) < STABILIZE_DELAY_SECONDS then
    return false
  end

  local samples = wgt.voltageSamples
  samples[#samples + 1] = voltage
  if #samples > STABLE_SAMPLE_COUNT then
    table.remove(samples, 1)
  end
  if #samples < STABLE_SAMPLE_COUNT then
    return false
  end

  local vmin, vmax = samples[1], samples[1]
  for i = 2, #samples do
    if samples[i] < vmin then vmin = samples[i] end
    if samples[i] > vmax then vmax = samples[i] end
  end
  wgt.voltageStable = (vmax - vmin) <= STABLE_WINDOW_VOLTS
  return wgt.voltageStable
end

-- Runs the estimator one tick. Safe to call from both background() and
-- refresh() -- it just no-ops if nothing changed.
local MAX_PLAUSIBLE_VOLTAGE = 70  -- 16S x 4.35 V = 69.6 V; above this it is not a pack voltage

local function step(wgt)
  local src = wgt.options.Source
  if src == nil or src == 0 then
    wgt.status = "nosrc"
    return
  end
  local voltage = getValue(src)
  if type(voltage) ~= "number" or voltage <= 1 then
    wgt.status = "nolink"
    return
  end
  if voltage > MAX_PLAUSIBLE_VOLTAGE then
    wgt.status = "badsrc"
    return
  end
  wgt.status = "ok"
  wgt.lastVoltage = voltage

  local maxCellVoltage = (wgt.options.MaxCv or 410) / 100
  local minCellVoltage = (wgt.options.MinCv or 290) / 100
  local reservePct = wgt.options.ResPct or 35

  local now = nowSeconds()
  local battType = wgt.options.BattType or 1

  -- Cell count. Manual: used as-is. Auto (BattAnalog method): re-evaluated
  -- every cycle for CELL_DETECTION_SECONDS after the first valid reading,
  -- then locked. A ResetSw rising edge re-detects (see performReset).
  if wgt.options.Cells and wgt.options.Cells > 0 then
    wgt.cellCount = wgt.options.Cells
    wgt.cellLocked = true
  elseif not wgt.cellLocked then
    if wgt.detectStartedAt == nil then wgt.detectStartedAt = now end
    wgt.cellCount = calcCellCount(voltage, battType)
    if (now - wgt.detectStartedAt) >= CELL_DETECTION_SECONDS then
      wgt.cellLocked = true
    end
  end

  -- Manual reset: fires once on the rising edge of ResetSw (not
  -- continuously while held), so a held switch doesn't keep re-pinning
  -- the value every cycle.
  if wgt.options.ResetSw and wgt.options.ResetSw ~= 0 then
    local swVal = getValue(wgt.options.ResetSw)
    local swActive = (swVal == true) or (type(swVal) == "number" and swVal > 0)
    if swActive and not wgt.resetSwPrevActive then
      performReset(wgt, voltage)
    end
    wgt.resetSwPrevActive = swActive
  end

  -- "Raw voltage-converted" reading: the BattAnalog-style table applied
  -- straight to the CURRENT, unfiltered voltage, every single cycle --
  -- no sag filter, no stability gate, no rate limiting, no reserve.
  -- This is intentionally a different, independent method from
  -- VoltFuel's own calibrated curve, so it serves as an outside
  -- reference point (e.g. displayed as "62%(48%)").
  wgt.lastInstantRawPct = batteryCellPercent(voltage / wgt.cellCount, battType)

  if not wgt.initialized then
    -- Stability gate applies ONLY here -- to pin down a trustworthy
    -- starting point before anything is displayed. Once initialized,
    -- this gate is never consulted again; see the note below on why.
    -- With auto cell count, also wait until detection has locked, so a
    -- provisional cell count can never be baked into the starting point.
    if updateStability(wgt, voltage, now) and wgt.cellLocked then
      wgt.filteredVoltage = voltage
      local vCell = voltage / wgt.cellCount
      -- Starting point = resting-voltage conversion (BattAnalog-style),
      -- same as ResetSw. The VoltFuel curve is calibrated for voltage
      -- UNDER LOAD, so it reads far too high at rest for a part-used pack.
      local rawPct = rawPercentFromCellVoltage(vCell, minCellVoltage, maxCellVoltage)
      local startPct = batteryCellPercent(vCell, battType)
      wgt.virtualConsumedPct = 100 - startPct
      wgt.lastFuelPercent = startPct
      wgt.lastTimestamp = now
      wgt.lastVcell = vCell
      wgt.lastRawPct = rawPct
      wgt.initialized = true
    end
  else
    -- Every cycle, using REAL elapsed time. Earlier versions only ran
    -- this block when updateStability() passed, and measured dt against
    -- the last STABLE update -- so a noisy stretch (common mid-maneuver)
    -- would freeze the display, then dump the whole accumulated "catch
    -- up" allowance in one jump the instant a stable sample reappeared
    -- (a multi-second gap times the %/s rate limit, applied all at
    -- once). Running every cycle with real dt closes that loophole: the
    -- sag filter alone (downward-only slew limit, below) is what
    -- protects against a brief transient dip, so the stability gate was
    -- redundant here and actively harmful to smoothness.
    local dt = math.max(0, now - wgt.lastTimestamp)

    local voltageFallPerSecond = (wgt.options.FallMv or 50) / 1000
    local filtered = voltage
    if wgt.filteredVoltage then
      local sagFactor = 1.0 - clamp((SAG_GAIN / 100) * 0.5, 0, 0.5)
      local maxDrop = dt * voltageFallPerSecond * sagFactor
      if voltage < wgt.filteredVoltage then
        filtered = math.max(voltage, wgt.filteredVoltage - maxDrop)
      end
    end

    local vCell = filtered / wgt.cellCount
    local rawPct = rawPercentFromCellVoltage(vCell, minCellVoltage, maxCellVoltage)
    local targetPct = applyReserve(rawPct, reservePct)
    local targetConsumedPct = 100 - targetPct

    if targetConsumedPct > wgt.virtualConsumedPct then
      local maxIncrease = dt * FUEL_DROP_PERCENT_PER_SECOND
      wgt.virtualConsumedPct = math.min(targetConsumedPct, wgt.virtualConsumedPct + maxIncrease)
    end

    wgt.lastFuelPercent = clamp(100 - wgt.virtualConsumedPct, 0, 100)
    wgt.filteredVoltage = filtered
    wgt.lastTimestamp = now
    wgt.lastVcell = vCell
    wgt.lastRawPct = rawPct
  end

  -- Publish the VoltFuel % as a real telemetry sensor ("sBAT%") so it
  -- can be used on other telemetry screens, voice/logical-switch alerts,
  -- and EdgeTX's own SD telemetry logging -- independent of this widget
  -- being on-screen. Published every cycle (held value included) so the
  -- sensor doesn't go stale during an unstable/holding period.
  if wgt.lastFuelPercent ~= nil then
    setTelemetryValue(SENSOR_ID, SENSOR_SUBID, SENSOR_INSTANCE,
      math.floor(wgt.lastFuelPercent + 0.5), UNIT_PERCENT, 0, SENSOR_NAME)
  end

  -- Optional analysis sensors. Only once the cell count is settled, so a
  -- provisional count can never be published.
  local extra = wgt.options.ExtraTelem
  if (extra == 1 or extra == true) and wgt.cellLocked and wgt.cellCount
      and wgt.lastInstantRawPct ~= nil then
    setTelemetryValue(REF_SENSOR_ID, SENSOR_SUBID, SENSOR_INSTANCE,
      math.floor(wgt.lastInstantRawPct + 0.5), UNIT_PERCENT, 0, REF_SENSOR_NAME)
    setTelemetryValue(CEL_SENSOR_ID, SENSOR_SUBID, SENSOR_INSTANCE,
      math.floor(voltage / wgt.cellCount * 100 + 0.5), UNIT_VOLTS, 2, CEL_SENSOR_NAME)
    -- MinCv in use (option value x100 = value in V with 2 decimals).
    setTelemetryValue(MIN_SENSOR_ID, SENSOR_SUBID, SENSOR_INSTANCE,
      math.floor(wgt.options.MinCv or 290), UNIT_VOLTS, 2, MIN_SENSOR_NAME)
  end
end

local function background(wgt)
  step(wgt)
end

local BAR_SEGMENTS = 20
local BAR_RED_END = 20      -- segments up to this % are red
local BAR_ORANGE_END = 50   -- up to this % orange, above it green
local ZONE_RGB = { {236, 53, 47}, {243, 191, 69}, {103, 186, 46} }  -- red, orange, green

-- Colour flag for zone 1 (red) / 2 (orange) / 3 (green). Uses a custom RGB
-- colour when the radio supports it, otherwise the theme's RED/YELLOW/GREEN.
local customColorOk = nil
local function zoneFlag(zi)
  if customColorOk == nil then
    customColorOk = (lcd.RGB ~= nil and lcd.setColor ~= nil and CUSTOM_COLOR ~= nil)
      and pcall(lcd.setColor, CUSTOM_COLOR, lcd.RGB(0, 0, 0)) or false
  end
  if customColorOk then
    local c = ZONE_RGB[zi]
    lcd.setColor(CUSTOM_COLOR, lcd.RGB(c[1], c[2], c[3]))
    return CUSTOM_COLOR
  end
  if zi == 1 then return RED end
  if zi == 2 then return YELLOW end
  return GREEN
end

-- Segmented bar graph: lit segments are filled, unlit ones are outlined in
-- their zone colour. Segment colour depends on the segment's position.
local function drawSegmentBar(x, y, w, h, pct)
  local n = BAR_SEGMENTS
  if w < 100 then n = math.floor(n / 2) end
  local gap = math.max(2, math.floor(w / n * 0.25 + 0.5))
  local segW = math.floor((w - gap * (n - 1)) / n)
  if segW < 1 then segW = 1 end
  local used = n * segW + (n - 1) * gap
  local x0 = x + math.floor((w - used) / 2)

  pct = clamp(pct, 0, 100)
  local lit = math.floor(pct * n / 100 + 0.5)
  if pct >= 1 and lit == 0 then lit = 1 end

  local lastZone, flag = 0, nil
  for i = 1, n do
    local frac = i * 100 / n
    local zi = 3
    if frac <= BAR_RED_END then zi = 1 elseif frac <= BAR_ORANGE_END then zi = 2 end
    if zi ~= lastZone then flag = zoneFlag(zi); lastZone = zi end
    local sx = x0 + (i - 1) * (segW + gap)
    if i <= lit then
      lcd.drawFilledRectangle(sx, y, segW, h, flag)
    else
      lcd.drawRectangle(sx, y, segW, h, flag)
    end
  end
end

local function formatInfo(voltage, cells, zoneW)
  local cellV = voltage / math.max(cells, 1)
  if zoneW >= 180 then
    return string.format("%.2fV %dS (%.2fV/c)", voltage, cells, cellV)
  end
  return string.format("%.2fV (%.2fV/c)", voltage, cellV)
end

local function refresh(wgt, event, touchState)
  step(wgt)

  local zone = wgt.zone
  local pct = wgt.lastFuelPercent
  local textColor = wgt.options.TxtColor or WHITE
  local status = wgt.status
  local tall = zone.h >= 60

  -- Short zones have no room for a status line: show a message instead.
  -- (No telemetry at start-up is NOT a message: the layout is drawn with
  -- zeros so it can be checked on the bench.)
  if not tall and pct == nil and status ~= "nolink" then
    local msg = "Acquiring..."
    if status == "nosrc" then msg = "Select Source"
    elseif status == "badsrc" then msg = "Check Source" end
    lcd.drawText(zone.x + 4, zone.y + 4, msg, bit32.bor(SMLSIZE, textColor))
    return
  end

  local shown = pct or 0
  local ref = 0
  if pct ~= nil then ref = wgt.lastInstantRawPct or pct end

  local barH = math.max(8, math.floor(zone.h * 0.25))
  local barY = zone.y + zone.h - barH - 4
  drawSegmentBar(zone.x + 4, barY, zone.w - 8, barH, shown)

  local pctFlag = tall and DBLSIZE or MIDSIZE
  local label = string.format("%d%%(%d%%)", math.floor(shown + 0.5), math.floor(ref + 0.5))
  lcd.drawText(zone.x + 4, zone.y + 2, label, bit32.bor(pctFlag, textColor))

  if tall then
    local info
    if pct == nil then
      if status == "nosrc" then info = "Select Source"
      elseif status == "badsrc" then info = "Check Source"
      elseif status == "nolink" then info = formatInfo(0, 0, zone.w)
      else info = "Acquiring..." end
    elseif status == "nolink" then
      info = "No telemetry (value held)"
    else
      info = formatInfo(wgt.lastVoltage or 0, wgt.cellCount or 0, zone.w)
    end
    lcd.drawText(zone.x + 4, zone.y + zone.h - barH - 20, info, bit32.bor(SMLSIZE, textColor))
  end
end

return {
  name = "VoltFuel",
  options = options,
  create = create,
  update = update,
  background = background,
  refresh = refresh,
}
