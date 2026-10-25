--[[
  VoltFuel Tools -- Tune: suggests a MinCv from the SD-card logs

  Copyright (C) 2026 Masayuki
  License: GNU General Public License, version 2 (see LICENSE).
  Part of the VoltFuel project. Contains per-cell voltage tables from
  EdgeTX's BattAnalog widget (Copyright Offer Shmuely, GPLv2).
  The code was written with Claude (Anthropic), an AI assistant.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation. It is distributed in the
  hope that it will be useful, but WITHOUT ANY WARRANTY; without even
  the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  How it works: for each of the newest logs of the chosen aircraft it
  (1) decides whether the log is a usable flight, (2) converts the
  resting voltage at the end of the log with the BattAnalog table,
  (3) simulates the VoltFuel estimator (the same algorithm as the widget)
  to find the MinCv for which the final sBAT equals that conversion, and
  (4) combines the usable logs into one MinCv per aircraft.
--]]

local L
local CFG                  -- settings file, next to the modules

-- usable-flight rules
local MIN_DUR = 60        -- s of valid voltage
local MIN_SAG = 0.15      -- V/cell lost between start and the lowest point ...
local MIN_DROP = 5        -- ... or sBAT points lost in the log
local TAIL_SEC = 30       -- resting voltage = mean of the last TAIL_SEC s
local TAIL_RANGE = 0.06   -- V/cell: largest spread allowed in that tail
local MIN_RECOVER = 0.03  -- V/cell: the tail must be above the lowest point
local MIN_SENS = 0.15     -- points per MinCv step: below this a log is left out
local MAX_SCAN = 30       -- newest logs looked at per aircraft
local NEAR = 5            -- "flown near the recommendation" = used MinCv within +-NEAR

local BT_NAMES = { "LiPo", "LiPo-HV", "Li-Ion", "LiFePO4" }
local TOP = { 4.30, 4.45, 4.30, 3.50 }
-- settings: { name, min, max, step, default }
local SET = {
  { "Battery type", 1, 4, 1, 1 },
  { "Cells (0=auto)", 0, 12, 1, 0 },
  { "ResPct", 0, 60, 1, 35 },
  { "FallMv", 10, 200, 5, 50 },
  { "MaxCv x100", 380, 440, 1, 410 },
  { "Logs to analyse", 1, 20, 1, 8 },
}
local cfg = {}

local TBL = {
  [1] = {3.000,0,3.093,1,3.196,2,3.301,3,3.401,4,3.477,5,3.544,6,3.601,7,3.637,8,3.664,9,3.679,10,3.683,11,3.689,12,3.692,13,3.705,14,3.710,15,3.713,16,3.715,17,3.720,18,3.731,19,3.735,20,3.744,21,3.753,22,3.756,23,3.758,24,3.762,25,3.767,26,3.774,27,3.780,28,3.783,29,3.786,30,3.789,31,3.794,32,3.797,33,3.800,34,3.802,35,3.805,36,3.808,37,3.811,38,3.815,39,3.818,40,3.822,41,3.825,42,3.829,43,3.833,44,3.836,45,3.840,46,3.843,47,3.847,48,3.850,49,3.854,50,3.857,51,3.860,52,3.863,53,3.866,54,3.870,55,3.874,56,3.879,57,3.888,58,3.893,59,3.897,60,3.902,61,3.906,62,3.911,63,3.918,64,3.923,65,3.928,66,3.939,67,3.943,68,3.949,69,3.955,70,3.961,71,3.968,72,3.974,73,3.981,74,3.987,75,3.994,76,4.001,77,4.007,78,4.014,79,4.021,80,4.029,81,4.036,82,4.044,83,4.052,84,4.062,85,4.074,86,4.085,87,4.095,88,4.105,89,4.111,90,4.116,91,4.120,92,4.125,93,4.129,94,4.135,95,4.145,96,4.176,97,4.179,98,4.193,99,4.200,100},
  [2] = {3.000,0,3.093,1,3.196,2,3.301,3,3.401,4,3.477,5,3.544,6,3.601,7,3.637,8,3.664,9,3.679,10,3.683,11,3.689,12,3.692,13,3.705,14,3.710,15,3.713,16,3.715,17,3.720,18,3.731,19,3.735,20,3.744,21,3.753,22,3.756,23,3.758,24,3.762,25,3.767,26,3.774,27,3.780,28,3.783,29,3.786,30,3.789,31,3.794,32,3.797,33,3.800,34,3.802,35,3.805,36,3.808,37,3.811,38,3.815,39,3.828,40,3.832,41,3.836,42,3.841,43,3.846,44,3.850,45,3.855,46,3.859,47,3.864,48,3.868,49,3.873,50,3.877,51,3.881,52,3.885,53,3.890,54,3.895,55,3.900,56,3.907,57,3.917,58,3.924,59,3.929,60,3.936,61,3.942,62,3.949,63,3.957,64,3.964,65,3.971,66,3.984,67,3.990,68,3.998,69,4.006,70,4.015,71,4.024,72,4.032,73,4.042,74,4.050,75,4.060,76,4.069,77,4.078,78,4.088,79,4.098,80,4.109,81,4.119,82,4.130,83,4.141,84,4.154,85,4.169,86,4.184,87,4.197,88,4.211,89,4.220,90,4.229,91,4.237,92,4.246,93,4.254,94,4.264,95,4.278,96,4.302,97,4.320,98,4.339,99,4.350,100},
  [3] = {2.800,0,2.840,1,2.880,2,2.920,3,2.960,4,3.000,5,3.040,6,3.080,7,3.096,8,3.112,9,3.128,10,3.144,11,3.160,12,3.176,13,3.192,14,3.208,15,3.224,16,3.240,17,3.256,18,3.272,19,3.288,20,3.304,21,3.320,22,3.336,23,3.352,24,3.368,25,3.384,26,3.400,27,3.416,28,3.432,29,3.448,30,3.464,31,3.480,32,3.496,33,3.504,34,3.512,35,3.520,36,3.528,37,3.536,38,3.544,39,3.552,40,3.560,41,3.568,42,3.576,43,3.584,44,3.592,45,3.600,46,3.608,47,3.616,48,3.624,49,3.632,50,3.640,51,3.648,52,3.656,53,3.664,54,3.672,55,3.680,56,3.688,57,3.696,58,3.704,59,3.712,60,3.720,61,3.728,62,3.736,63,3.744,64,3.752,65,3.760,66,3.768,67,3.776,68,3.784,69,3.792,70,3.800,71,3.810,72,3.820,73,3.830,74,3.840,75,3.850,76,3.860,77,3.870,78,3.880,79,3.890,80,3.900,81,3.910,82,3.920,83,3.930,84,3.940,85,3.950,86,3.960,87,3.970,88,3.980,89,3.990,90,4.000,91,4.010,92,4.030,93,4.050,94,4.070,95,4.090,96,4.10,100,4.15,100,4.20,100},
  [4] = {2.500,0,2.509,1,2.518,2,2.527,3,2.536,4,2.545,5,2.554,6,2.563,7,2.572,8,2.581,9,2.590,10,2.599,11,2.608,12,2.617,13,2.626,14,2.635,15,2.644,16,2.653,17,2.662,18,2.671,19,2.680,20,2.689,21,2.698,22,2.707,23,2.716,24,2.725,25,2.734,26,2.743,27,2.752,28,2.761,29,2.770,30,2.779,31,2.788,32,2.797,33,2.806,34,2.815,35,2.824,36,2.833,37,2.842,38,2.851,39,2.860,40,2.869,41,2.878,42,2.887,43,2.896,44,2.905,45,2.914,46,2.923,47,2.932,48,2.941,49,2.950,50,2.959,51,2.968,52,2.977,53,2.986,54,2.995,55,3.004,56,3.013,57,3.022,58,3.031,59,3.040,60,3.049,61,3.058,62,3.067,63,3.076,64,3.085,65,3.094,66,3.103,67,3.112,68,3.121,69,3.130,70,3.139,71,3.148,72,3.157,73,3.166,74,3.175,75,3.184,76,3.193,77,3.202,78,3.211,79,3.220,80,3.229,81,3.238,82,3.247,83,3.256,84,3.265,85,3.274,86,3.283,87,3.292,88,3.301,89,3.310,90,3.319,91,3.328,92,3.337,93,3.346,94,3.355,95,3.364,96,3.373,97,3.382,98,3.391,99,3.400,100},
}

local NT = { 0, 0, 0, 0 }
for i = 1, 4 do NT[i] = #TBL[i] / 2 end

---------------------------------------------------------------------------
-- model of the VoltFuel estimator (same as the widget / the HTML tool)
---------------------------------------------------------------------------
local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

local function pct(v, t)
  local l, n = TBL[t], NT[t]
  if v <= l[1] then return 0 end
  if v >= l[2 * n - 1] then return 100 end
  local a, b = 1, n
  while b - a > 1 do
    local m = math.floor((a + b) / 2)
    if v >= l[2 * m - 1] then a = m else b = m end
  end
  if v < (l[2 * a - 1] + l[2 * b - 1]) / 2 then return l[2 * a] end
  return l[2 * b]
end

local function cellsOf(v, t)
  for i = 1, 12 do if v < TOP[t] * i then return i end end
  return 1
end

local function raw(v, mn, mx)
  if v >= mx then return 100 end
  if v <= mn then return 0 end
  local s = clamp(3 + (v - mn) / (mx - mn) * 1.2, 3, 4.2)
  return 100 / (1 + math.exp(-6 * (s - 3.7)))
end

local function reserve(p, r)
  r = clamp(r, 0, 99)
  if r <= 0 then return clamp(p, 0, 100) end
  return clamp((p - r) * 100 / (100 - r), 0, 100)
end

-- final sBAT of a log for a given MinCv (x100)
local function sim(T, V, c, k)
  local bt, res, fall, mx = cfg[1], cfg[3], cfg[4], cfg[5] / 100
  local mn = k / 100
  local cons = 100 - pct(V[1] / c, bt)
  local f, last = V[1], T[1]
  local slew = fall / 1000 * 0.8
  for i = 2, #T do
    local dt = T[i] - last
    if dt < 0 then dt = 0 end
    local g = V[i]
    if g < f then
      local lim = f - dt * slew
      if lim > g then g = lim end
    end
    local tc = 100 - reserve(raw(g / c, mn, mx), res)
    if tc > cons then
      cons = cons + dt
      if tc < cons then cons = tc end
    end
    f, last = g, T[i]
  end
  return clamp(100 - cons, 0, 100)
end

local function median(a)
  local s = {}
  for i = 1, #a do s[i] = a[i] end
  table.sort(s)
  return s[math.floor(#s / 2) + 1]
end

---------------------------------------------------------------------------
-- settings file
---------------------------------------------------------------------------
local function loadCfg()
  for i = 1, #SET do cfg[i] = SET[i][5] end
  pcall(function()
    local fh = io.open(CFG, "r")
    if not fh then return end
    local s = io.read(fh, 200) or ""
    io.close(fh)
    local i = 0
    for num in string.gmatch(s, "-?%d+") do
      i = i + 1
      if SET[i] then cfg[i] = clamp(tonumber(num), SET[i][2], SET[i][3]) end
    end
  end)
end

local function saveCfg()
  pcall(function()
    local fh = io.open(CFG, "w")
    if not fh then return end
    local t = {}
    for i = 1, #SET do t[i] = tostring(cfg[i]) end
    io.write(fh, table.concat(t, ","))
    io.close(fh)
  end)
end

---------------------------------------------------------------------------
-- task queue: every step is small so run() stays responsive
---------------------------------------------------------------------------
local Q, qh, qt = {}, 1, 0
local function push(f) qt = qt + 1; Q[qt] = f end
local function pump()
  local t0 = getTime()
  while qh <= qt do
    local f = Q[qh]
    Q[qh] = nil
    qh = qh + 1
    f()
    if getTime() - t0 >= L.BUDGET then break end
  end
  return qh > qt
end
local function qclear() Q, qh, qt = {}, 1, 0 end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------
local state = "models"
local models, mlist, mnames = {}, L and L.newList() or nil, {}
local lst
local sel                    -- chosen model group
local files, fi, valid = {}, 0, 0
local results = {}           -- analysed logs (valid and skipped), newest first
local final                  -- { k=, rms=, n= } or nil
local rfh, rs                -- file handle / reader state
local setSel, setEdit = 1, false
local resList
local scanDone = false

local function refreshModels()
  local g = L.groupModels(L.listLogs())
  models = {}
  mnames = { "Settings..." }
  for _, m in ipairs(g) do
    models[#models + 1] = m
    mnames[#mnames + 1] = string.format("%s   (%d logs)", m.name, #m.files)
  end
end

local function goModels()
  qclear()
  if rfh then io.close(rfh) rfh = nil end
  refreshModels()
  lst = L.newList()
  state = "models"
end

---------------------------------------------------------------------------
-- reading one log
---------------------------------------------------------------------------
local nextFile, groupWhenReady   -- forward declarations (scan driver below)

local function skip(r, why)
  r.skip = why
  results[#results + 1] = r
  push(nextFile)
end

local function vcolOf(hdr)
  local want = { "rxbt", "vbat", "vfas", "rcel" }
  for _, w in ipairs(want) do
    for i = 1, #hdr do if L.norm(hdr[i]) == w then return i, hdr[i] end end
  end
  return nil
end

local function finishRead(r)
  if rfh then io.close(rfh) rfh = nil end
  local T, V = rs.T, rs.V
  local n = #T
  r.dur = n > 0 and (T[n] - T[1]) or 0
  if n < 30 or r.dur < MIN_DUR then return skip(r, "too short") end
  local first = {}
  for i = 1, math.min(5, n) do first[i] = V[i] end
  local c = cfg[2] > 0 and cfg[2] or cellsOf(median(first), cfg[1])
  r.c = c
  local vmin = V[1]
  for i = 2, n do if V[i] < vmin then vmin = V[i] end end
  local vstart = median(first) / c
  local sag = vstart - vmin / c
  local drop = (rs.sFirst and rs.sLast) and (rs.sFirst - rs.sLast) or 0
  if sag < MIN_SAG and drop < MIN_DROP then return skip(r, "no flight") end
  local tend, sum, cnt, lo, hi = T[n], 0, 0, 1e9, -1e9
  for i = 1, n do
    if T[i] >= tend - TAIL_SEC then
      sum, cnt = sum + V[i], cnt + 1
      if V[i] < lo then lo = V[i] end
      if V[i] > hi then hi = V[i] end
    end
  end
  local vr = sum / cnt
  if cnt < 5 or (hi - lo) / c > TAIL_RANGE or vr / c - vmin / c < MIN_RECOVER then
    return skip(r, "no rest at end")
  end
  r.vc, r.conv = vr / c, pct(vr / c, cfg[1])
  r.logged = rs.sLast
  local best, bn = nil, 0
  for k, cntk in pairs(rs.hist) do
    if cntk > bn then best, bn = k, cntk end
  end
  r.used = best
  r.fin = function(k) return sim(T, V, c, k) end
  r.lo, r.hi = 250, 400
  valid = valid + 1
  results[#results + 1] = r
  -- recommended MinCv: bisection (final sBAT falls as MinCv rises)
  local function bis()
    if r.hi - r.lo > 1 then
      local m = math.floor((r.lo + r.hi) / 2)
      if r.fin(m) > r.conv then r.lo = m else r.hi = m end
      push(bis)
    else
      local el, eh = math.abs(r.fin(r.lo) - r.conv), math.abs(r.fin(r.hi) - r.conv)
      r.rec = el <= eh and r.lo or r.hi
      push(function()
        r.sens = (r.fin(r.rec + 5) - r.fin(r.rec - 5)) / 10
        if r.used and r.logged then r.chk = r.fin(r.used) - r.logged end
      end)
    end
  end
  push(bis)
  push(nextFile)   -- the next log is read only after this one is finished
end

local function readStep(r)
  local t0 = getTime()
  repeat
    local chunk = rfh and io.read(rfh, 2048)
    if not chunk or #chunk == 0 then
      if #rs.carry > 0 and rs.hdr then rs.line(rs.carry) end
      rs.carry = ""
      return finishRead(r)
    end
    local buf = rs.carry .. chunk
    local pos = 1
    while true do
      local nl = string.find(buf, "\n", pos, true)
      if not nl then break end
      local line = string.sub(buf, pos, nl - 1)
      if not rs.hdr then
        rs.hdr = L.split((string.gsub(line, "\r", "")))
        for i = 1, #rs.hdr do
          local nm = L.norm(rs.hdr[i])
          if rs.hdr[i] == "Time" then rs.tcol = i end
          if nm == "sbat" then rs.scol = i end
          if nm == "rmin" then rs.mcol = i end
        end
        rs.vcol, r.vname = vcolOf(rs.hdr)
        if not rs.tcol or not rs.vcol then
          if rfh then io.close(rfh) rfh = nil end
          return skip(r, "no Time/voltage column")
        end
      else
        rs.line(line)
      end
      pos = nl + 1
    end
    rs.carry = string.sub(buf, pos)
  until getTime() - t0 >= L.BUDGET
  push(function() readStep(r) end)
end

local function startRead(f)
  local r = { name = f.name, stamp = f.stamp }
  rfh = io.open(L.LOGDIR .. "/" .. f.name, "r")
  if not rfh then return skip(r, "cannot open") end
  rs = { T = {}, V = {}, carry = "", hist = {}, wrap = 0, prev = nil }
  rs.line = function(line)
    local fld = L.split((string.gsub(line, "\r", "")))
    local t = L.parseTime(fld[rs.tcol])
    local v = tonumber(fld[rs.vcol])
    if not t or not v then return end
    if rs.prev and t + rs.wrap < rs.prev - 1 then rs.wrap = rs.wrap + 86400 end
    t = t + rs.wrap
    rs.prev = t
    if v <= 1 then return end
    local n = #rs.T
    if n > 0 and t - rs.T[n] < 0.5 then
      if v < rs.V[n] then rs.V[n] = v end
    else
      rs.T[n + 1], rs.V[n + 1] = t, v
    end
    local s = rs.scol and tonumber(fld[rs.scol])
    if s and s > 0 then
      if not rs.sFirst then rs.sFirst = s end
      rs.sLast = s
    end
    local m = rs.mcol and tonumber(fld[rs.mcol])
    if m and m > 0 then
      local k = math.floor(m * 100 + 0.5)
      rs.hist[k] = (rs.hist[k] or 0) + 1
    end
  end
  push(function() readStep(r) end)
end

---------------------------------------------------------------------------
-- per-aircraft recommendation: least squares over the usable logs
---------------------------------------------------------------------------
local function groupStep()
  local G = {}
  for _, r in ipairs(results) do
    if r.rec and r.sens and math.abs(r.sens) >= MIN_SENS then G[#G + 1] = r end
  end
  if #G == 0 then return end
  local sw, swk = 0, 0
  for _, r in ipairs(G) do
    sw = sw + r.sens * r.sens
    swk = swk + r.sens * r.sens * r.rec
  end
  local vals, shifts = {}, 0
  local lo, hi = math.max(math.floor(swk / sw + 0.5) - 3, 250), 0
  hi = math.min(lo + 6, 400)
  local pass
  local function decide()
    local bk, bs = nil, 1e18
    for k = lo, hi do
      if vals[k] and vals[k][2] == #G and vals[k][1] < bs then bk, bs = k, vals[k][1] end
    end
    if bk and shifts < 4 and ((bk == lo and lo > 250) or (bk == hi and hi < 400)) then
      shifts = shifts + 1
      if bk == lo then lo = math.max(lo - 4, 250) else hi = math.min(hi + 4, 400) end
      return pass()
    end
    final = { k = bk, rms = math.sqrt(bs / #G), n = #G }
    -- logs that were flown with a MinCv close to the recommendation: how did they come out?
    local n, sum, lo, hi = 0, 0, 1e9, -1e9
    for _, r in ipairs(results) do
      if not r.skip and r.used and r.logged and math.abs(r.used - bk) <= NEAR then
        local d = r.logged - r.conv
        r.near = true
        n, sum = n + 1, sum + d
        if d < lo then lo = d end
        if d > hi then hi = d end
      end
    end
    final.near = n > 0 and { n = n, avg = sum / n, lo = lo, hi = hi } or { n = 0 }
  end
  pass = function()
    for k = lo, hi do
      if not vals[k] then
        vals[k] = { 0, 0 }
        for _, r in ipairs(G) do
          push(function()
            local e = r.fin(k) - r.conv
            vals[k][1] = vals[k][1] + e * e
            vals[k][2] = vals[k][2] + 1
          end)
        end
      end
    end
    push(decide)
  end
  pass()
end

---------------------------------------------------------------------------
-- scan driver
---------------------------------------------------------------------------
-- waits until every usable log has its own numbers, then combines them
groupWhenReady = function()
  for _, r in ipairs(results) do
    if not r.skip and r.sens == nil then
      push(groupWhenReady)
      return
    end
  end
  groupStep()
end

nextFile = function()
  if valid >= cfg[6] or fi >= #files or fi >= MAX_SCAN then
    push(groupWhenReady)
    scanDone = true
    return
  end
  fi = fi + 1
  startRead(files[fi])
end

local function startScan(m)
  sel = m
  files, fi, valid = m.files, 0, 0
  results, final, scanDone = {}, nil, false
  qclear()
  state = "scan"
  push(nextFile)
end

---------------------------------------------------------------------------
-- screens
---------------------------------------------------------------------------
local function stampShort(stamp)
  local mo, d, h, mi = string.match(stamp or "", "^%d%d%d%d%-(%d%d)%-(%d%d)%-(%d%d)(%d%d)")
  if mo then return mo .. "-" .. d .. " " .. h .. ":" .. mi end
  return stamp or "?"
end

local COLX = { 4, 104, 132, 182, 222, 264, 312, 354, 380 }
local function drawResult()
  local C = L.C
  L.header("Tune: " .. sel.name, string.format("%d usable", valid))
  -- recommendation
  if final then
    L.txt(10, 28, "MinCv", SMLSIZE, C.dim)
    L.txt(70, 22, tostring(final.k), MIDSIZE, C.ok)
    L.txt(LCD_W - 8, 26, string.format("RMS %.1f  n=%d", final.rms, final.n), SMLSIZE + RIGHT, C.dim)
  elseif valid > 0 then
    L.txt(10, 28, "MinCv: logs are not sensitive to MinCv", SMLSIZE, C.warn)
  else
    L.txt(10, 28, "No usable log (see the list below)", SMLSIZE, C.warn)
  end
  if final and final.near then
    local nr = final.near
    local line
    if nr.n > 0 then
      line = string.format("Flown at %d+-%d: n=%d  sBAT-Conv avg %+.1f (%+d..%+d)", final.k, NEAR, nr.n,
        nr.avg, math.floor(nr.lo + 0.5), math.floor(nr.hi + 0.5))
    else
      line = string.format("No log was flown at MinCv %d+-%d", final.k, NEAR)
    end
    L.txt(10, 47, line, SMLSIZE, C.blue)
  end
  local hy = 66
  local heads = { "Log", "S", "V/c", "Conv", "sBAT", "Used", "Match", "", "Sens" }
  for i = 1, #heads do L.txt(COLX[i], hy, heads[i], SMLSIZE, C.dim) end
  local rows = math.floor((LCD_H - hy - 36) / 18)
  for i = 1, rows do
    local r = results[resList.top + i]
    if not r then break end
    local y = hy + 16 + (i - 1) * 18
    L.txt(COLX[1], y, stampShort(r.stamp), SMLSIZE, r.skip and C.dim or C.text)
    if r.skip then
      L.txt(COLX[2], y, "skipped: " .. r.skip, SMLSIZE, C.dim)
    else
      L.txt(COLX[2], y, tostring(r.c) .. "S", SMLSIZE)
      L.txt(COLX[3], y, string.format("%.2f", r.vc), SMLSIZE)
      L.txt(COLX[4], y, tostring(r.conv), SMLSIZE)
      L.txt(COLX[5], y, r.logged and string.format("%d", math.floor(r.logged + 0.5)) or "-", SMLSIZE)
      L.txt(COLX[6], y, r.used and (tostring(r.used) .. (r.near and "*" or "")) or "-", SMLSIZE,
        r.near and C.blue or C.text)
      L.txt(COLX[7], y, r.rec and tostring(r.rec) or "...", SMLSIZE, C.ok)
      if r.chk and math.abs(r.chk) > 3 then L.txt(COLX[8], y, "!", SMLSIZE, C.err) end
      L.txt(COLX[9], y, r.sens and string.format("%.1f", r.sens) or "", SMLSIZE,
        (r.sens and math.abs(r.sens) < MIN_SENS) and C.warn or C.text)
    end
  end
  local foot = "Estimate from resting voltage. ! = settings differ from the log. EXIT = back"
  L.txt(6, LCD_H - 16, foot, SMLSIZE, C.dim)
end

local function drawSettings()
  local C = L.C
  L.header("Tune: settings", setEdit and "EDIT: roller / tap < >" or "ENTER = edit")
  for i = 1, #SET do
    local y = L.LIST_Y + (i - 1) * L.ROW_H
    if i == setSel then L.box(0, y, LCD_W, L.ROW_H, setEdit and C.warn or C.sel) end
    L.txt(10, y + 3, SET[i][1], SMLSIZE, (i == setSel and setEdit) and C.bg or C.text)
    local v = cfg[i]
    local s = tostring(v)
    if i == 1 then s = BT_NAMES[v] end
    if i == 2 and v == 0 then s = "auto" end
    L.txt(LCD_W - 24, y + 3, s, SMLSIZE + RIGHT, (i == setSel and setEdit) and C.bg or C.text)
  end
  L.txt(6, LCD_H - 34, "Use the same values as in the VoltFuel widget.", SMLSIZE, C.dim)
  L.txt(6, LCD_H - 18, "EXIT = save and back", SMLSIZE, C.dim)
end

local function bump(i, d)
  local s = SET[i]
  cfg[i] = clamp(cfg[i] + d * s[4], s[2], s[3])
end

local function runSettings(event, ts)
  if event == EVT_VIRTUAL_EXIT then
    if setEdit then setEdit = false else saveCfg() goModels() end
  elseif event == EVT_VIRTUAL_ENTER then
    setEdit = not setEdit
  elseif event == EVT_VIRTUAL_NEXT then
    if setEdit then bump(setSel, 1) else setSel = setSel % #SET + 1 end
  elseif event == EVT_VIRTUAL_PREV then
    if setEdit then bump(setSel, -1) else setSel = (setSel - 2) % #SET + 1 end
  elseif event == EVT_TOUCH_TAP and ts and ts.y >= L.LIST_Y then
    local i = math.floor((ts.y - L.LIST_Y) / L.ROW_H) + 1
    if i >= 1 and i <= #SET then
      if i == setSel then bump(i, ts.x < LCD_W / 2 and -1 or 1) end
      setSel = i
    end
  end
  drawSettings()
end

---------------------------------------------------------------------------
-- interface
---------------------------------------------------------------------------
local function init(lib)
  L = lib
  CFG = (L.DIR or "/SCRIPTS/TOOLS/VoltFuel/") .. "tune.cfg"
  loadCfg()
  setSel, setEdit = 1, false
  goModels()
end

local function run(event, ts)
  if state == "models" then
    local r = L.listNav(lst, event, ts, #mnames)
    if r == "exit" then return 1 end
    if r == "enter" then
      if lst.sel == 1 then
        state, setSel, setEdit = "settings", 1, false
      else
        startScan(models[lst.sel - 1])
      end
    end
    if state == "models" then
      L.drawList("VoltFuel Tune: select aircraft", mnames, lst)
      if #models == 0 then L.txt(10, L.LIST_Y + 40, "No log files in /LOGS", SMLSIZE, L.C.warn) end
    end
  elseif state == "settings" then
    runSettings(event, ts)
  elseif state == "scan" then
    if event == EVT_VIRTUAL_EXIT then
      goModels()
    else
      if pump() and scanDone then
        state, resList = "result", L.newList()
      end
      if state == "scan" then
        local total = math.min(#files, MAX_SCAN)
        L.progress("Analysing " .. sel.name, fi / math.max(total, 1),
          string.format("log %d / %d   usable %d / %d", fi, total, valid, cfg[6]))
      end
    end
  elseif state == "result" then
    pump()   -- finishes the last steps of each log
    local r = L.listNav(resList, event, ts, #results)
    if r == "exit" then goModels() end
    if state == "result" then drawResult() end
  end
  return 0
end

return { init = init, run = run, _test = { sim = sim, pct = pct, cfg = cfg, results = function() return results end, final = function() return final end } }
