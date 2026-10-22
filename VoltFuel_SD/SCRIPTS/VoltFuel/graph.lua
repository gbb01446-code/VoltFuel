--[[
  VoltFuel Tools -- Graph: log viewer for the VoltFuel widget (EdgeTX)

  Copyright (C) 2026 Masayuki
  License: GNU General Public License, version 2 (see LICENSE).
  Part of the VoltFuel project. The code was written with Claude
  (Anthropic), an AI assistant.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation. It is distributed in the
  hope that it will be useful, but WITHOUT ANY WARRANTY; without even
  the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.
--]]

---------------------------------------------------------------------------
-- graph.lua  -  EdgeTX log viewer for VoltFuel (color LCD radios)
--
-- Install : SD:/SCRIPTS/VoltFuel/graph.lua (started from VoltFuel_Tools)
-- Run     : SYS (or long-press SYS) > Tools > VoltFuel_Tools > Graph
--
-- Default graph : left axis  = rCEL (cell voltage)
--                 right axis = sBAT and rBAT (shared scale, two lines)
--
-- Flow    : file list -> graph (when the default columns are in the log)
--           otherwise  -> Y1 (left) -> Y2 (right) -> Y3 (right, 2nd) -> graph
-- Keys    : roller / +- = move, ENTER = select, EXIT = back
-- Graph   : roller = move cursor (1 step), PAGE keys = move 10 steps,
--           touch tap/drag = jump cursor, ENTER = change columns,
--           EXIT = back to file list
---------------------------------------------------------------------------

local TITLE    = "Graph"
local LOGDIR   = "/LOGS"
local HEAD_H   = 22          -- title bar height
local ROW_H    = 22          -- list row height
local PL, PR   = 52, 52      -- graph margins (left / right axis labels)
local BUDGET   = 3           -- work per run() call, in 10 ms ticks
local MAXFILES = 300

-- Default columns (case-insensitive, unit in "(...)" is ignored).
-- Y1 and at least one of Y2/Y3 found -> the selection screens are skipped.
local DEFAULT1 = "rcel"      -- left axis
local DEFAULT2 = "sbat"      -- right axis (1st line)
local DEFAULT3 = "rbat"      -- right axis (2nd line)
local DEFAULTS = { DEFAULT1, DEFAULT2, DEFAULT3 }

local C = {}                 -- colors (filled in init)
local state = "files"
local msg = nil

-- list handling
local files = {}
local lsel, ltop = 1, 0
local ROWS = 8
local LIST_Y = HEAD_H + 2

-- file / header info
local path, fh
local scanBytes, scanNL, lastByte, total
local header = {}
local colNames, colIdx = {}, {}
local optNames = {}              -- "(none)" + colNames
local cc, nm = {}, {}            -- chosen header index / name for Y1..Y3
local cmin, minv                 -- rMIN column index / last non-zero rMIN value

-- load pass
local carry, skipHeader, lineNo
local N, S, K
local t0str, t1str

-- result
local ys = {}                    -- ys[1..3] = bucket values (or nil)
local lo1, hi1, rlo, rhi, dur, cur

---------------------------------------------------------------------------
-- drawing helpers
---------------------------------------------------------------------------
local function setc(c) lcd.setColor(CUSTOM_COLOR, c) end

local function txt(x, y, s, fl, c)
  setc(c)
  lcd.drawText(x, y, s, (fl or 0) + CUSTOM_COLOR)
end

local function ln(x1, y1, x2, y2, pat, c)
  setc(c)
  lcd.drawLine(x1, y1, x2, y2, pat, CUSTOM_COLOR)
end

local function box(x, y, w, h, c)
  setc(c)
  lcd.drawFilledRectangle(x, y, w, h, CUSTOM_COLOR)
end

local function textW(s)
  local ok, w = pcall(lcd.sizeText, s, SMLSIZE)
  if ok and type(w) == "number" then return w end
  return #s * 7
end

local function fmt(v, range)
  if range >= 100 then
    return string.format("%.0f", v)
  elseif range >= 10 then
    return string.format("%.1f", v)
  end
  return string.format("%.2f", v)
end

local function fmtTime(sec)
  if not sec then return "--:--" end
  local m = math.floor(sec / 60)
  local s = math.floor(sec - m * 60)
  return string.format("%d:%02d", m, s)
end

local function split(s)
  local t, pos = {}, 1
  while true do
    local e = string.find(s, ",", pos, true)
    if not e then
      t[#t + 1] = string.sub(s, pos)
      break
    end
    t[#t + 1] = string.sub(s, pos, e - 1)
    pos = e + 1
  end
  return t
end

-- "HH:MM:SS.ss" or "MM:SS.s" -> seconds, and the wrap-around period
local function parseTime(s)
  if not s then return nil end
  local h, m, sec, frac = string.match(s, "^(%d+):(%d+):(%d+)%.?(%d*)")
  local period = 86400
  if not h then
    m, sec, frac = string.match(s, "^(%d+):(%d+)%.?(%d*)")
    if not m then return nil end
    h = "0"
    period = 3600
  end
  local t = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
  if frac and #frac > 0 then t = t + tonumber("0." .. frac) end
  return t, period
end

---------------------------------------------------------------------------
-- list UI
---------------------------------------------------------------------------
local function drawList(title, list)
  box(0, 0, LCD_W, LCD_H, C.bg)
  box(0, 0, LCD_W, HEAD_H, C.bar)
  txt(6, 3, title, SMLSIZE, C.text)
  if #list == 0 then
    txt(10, LIST_Y + 8, "(empty)", SMLSIZE, C.dim)
    return
  end
  txt(LCD_W - 6, 3, lsel .. "/" .. #list, SMLSIZE + RIGHT, C.dim)
  for r = 1, ROWS do
    local i = ltop + r
    if i > #list then break end
    local y = LIST_Y + (r - 1) * ROW_H
    if i == lsel then box(0, y, LCD_W, ROW_H, C.sel) end
    txt(10, y + 3, list[i], SMLSIZE, C.text)
  end
end

-- returns "enter", "exit" or nil
local function listNav(event, ts, n)
  local r = nil
  if n > 0 then
    if event == EVT_VIRTUAL_NEXT then
      lsel = lsel + 1
      if lsel > n then lsel = 1 end
    elseif event == EVT_VIRTUAL_PREV then
      lsel = lsel - 1
      if lsel < 1 then lsel = n end
    elseif event == EVT_VIRTUAL_ENTER then
      r = "enter"
    elseif event == EVT_TOUCH_TAP and ts and ts.y >= LIST_Y then
      local i = math.floor((ts.y - LIST_Y) / ROW_H) + ltop + 1
      if i >= 1 and i <= n then
        lsel = i
        r = "enter"
      end
    end
  end
  if event == EVT_VIRTUAL_EXIT then r = "exit" end
  if lsel <= ltop then ltop = lsel - 1 end
  if lsel > ltop + ROWS then ltop = lsel - ROWS end
  if ltop < 0 then ltop = 0 end
  return r
end

-- "rCEL(V)" -> "rcel"
local function norm(s)
  s = string.lower(s or "")
  s = string.gsub(s, "%(.-%)", "")
  s = string.gsub(s, "%s+", "")
  return s
end

-- position of the first column whose normalized name equals want
local function findCol(want)
  if not want then return nil end
  want = norm(want)
  for i = 1, #colNames do
    if norm(colNames[i]) == want then return i end
  end
  return nil
end

-- put the list cursor on item i and scroll so it is visible
local function selectItem(i)
  lsel = i
  ltop = 0
  if lsel > ROWS then ltop = lsel - ROWS end
end

local function drawProgress(title, frac, sub)
  box(0, 0, LCD_W, LCD_H, C.bg)
  box(0, 0, LCD_W, HEAD_H, C.bar)
  txt(6, 3, title, SMLSIZE, C.text)
  local bx, bw, by = 30, LCD_W - 60, math.floor(LCD_H / 2) - 8
  box(bx, by, bw, 16, C.grid)
  if frac > 1 then frac = 1 end
  if frac > 0 then box(bx, by, math.floor(bw * frac), 16, C.s1) end
  txt(LCD_W / 2, by + 26, sub or "", SMLSIZE + CENTER, C.dim)
  txt(LCD_W / 2, LCD_H - 22, "EXIT = cancel", SMLSIZE + CENTER, C.dim)
end

---------------------------------------------------------------------------
-- state transitions
---------------------------------------------------------------------------
local function listFiles()
  local t = {}
  pcall(function()
    for name in dir(LOGDIR) do
      if string.find(string.lower(name), "%.csv$") then
        local k = string.match(name, "(%d%d%d%d%-%d%d%-%d%d%-%d+)") or ""
        t[#t + 1] = { name = name, key = k }
      end
    end
  end)
  table.sort(t, function(a, b)
    if a.key ~= b.key then return a.key > b.key end
    return a.name > b.name
  end)
  files = {}
  for i = 1, math.min(#t, MAXFILES) do files[i] = t[i].name end
end

local function closeFile()
  if fh then
    io.close(fh)
    fh = nil
  end
end

local function goFiles()
  closeFile()
  listFiles()
  lsel, ltop = 1, 0
  state = "files"
end

local function goPick1()
  closeFile()
  selectItem(findCol(nm[1]) or findCol(DEFAULT1) or 1)
  state = "pick1"
end

-- k = 2 or 3
local function goPick(k)
  closeFile()
  local i = findCol(nm[k]) or findCol(DEFAULTS[k])
  selectItem(i and (i + 1) or 1)
  state = "pick" .. k
end

local function startScan(name)
  closeFile()
  path = LOGDIR .. "/" .. name
  fh = io.open(path, "r")
  if not fh then
    msg = "Cannot open file"
    return
  end
  scanBytes, scanNL, lastByte, total = 0, 0, 0, 0
  header, colNames, colIdx = {}, {}, {}
  state = "scan"
end

local startLoad   -- forward declaration (defined below)

local function finishScan()
  closeFile()
  total = scanNL - 1
  if lastByte ~= 10 then total = total + 1 end
  if #colNames == 0 or total < 2 then
    msg = "No usable data in file"
    goFiles()
    return
  end
  optNames = { "(none)" }
  for i = 1, #colNames do optNames[i + 1] = colNames[i] end
  local dm = findCol("rmin")
  cmin = dm and colIdx[dm] or nil

  -- default columns present -> skip the selection screens
  local d1, d2, d3 = findCol(DEFAULT1), findCol(DEFAULT2), findCol(DEFAULT3)
  if d1 and (d2 or d3) then
    local right = {}
    if d2 then right[#right + 1] = d2 end
    if d3 then right[#right + 1] = d3 end
    cc, nm = {}, {}
    cc[1], nm[1] = colIdx[d1], colNames[d1]
    for k = 1, #right do
      cc[k + 1], nm[k + 1] = colIdx[right[k]], colNames[right[k]]
    end
    startLoad()
    return
  end
  cc, nm = {}, {}
  goPick1()
end

local function scanStep()
  local t0 = getTime()
  repeat
    local chunk = io.read(fh, 4096)
    if not chunk or #chunk == 0 then
      finishScan()
      return
    end
    if scanBytes == 0 then
      local nl = string.find(chunk, "\n", 1, true)
      local h = string.sub(chunk, 1, (nl or (#chunk + 1)) - 1)
      h = (string.gsub(h, "\r", ""))
      header = split(h)
      for i = 1, #header do
        local n = header[i]
        if n ~= "Date" and n ~= "Time" and #n > 0 then
          colNames[#colNames + 1] = n
          colIdx[#colIdx + 1] = i
        end
      end
    end
    local _, n = string.gsub(chunk, "\n", "")
    scanNL = scanNL + n
    scanBytes = scanBytes + #chunk
    lastByte = string.byte(chunk, -1)
  until getTime() - t0 >= BUDGET
end

function startLoad()
  closeFile()
  -- "(none)" for Y2 but a column for Y3 -> move Y3 up to Y2
  if not cc[2] and cc[3] then
    cc[2], nm[2] = cc[3], nm[3]
    cc[3], nm[3] = nil, nil
  end
  fh = io.open(path, "r")
  if not fh then
    msg = "Cannot open file"
    goFiles()
    return
  end
  local plotW = LCD_W - PL - PR
  N = math.min(plotW, total)
  S, K = { {}, {}, {} }, { {}, {}, {} }
  for k = 1, 3 do
    if cc[k] then
      for i = 1, N do
        S[k][i], K[k][i] = 0, 0
      end
    end
  end
  carry, skipHeader, lineNo = "", true, 0
  t0str, t1str = nil, nil
  minv = nil
  state = "load"
end

-- values of the chosen columns in one line
local function extract(line)
  local v1, v2, v3, v4
  local last = cc[1]
  if cmin and cmin > last then last = cmin end
  if cc[2] and cc[2] > last then last = cc[2] end
  if cc[3] and cc[3] > last then last = cc[3] end
  local pos, idx = 1, 1
  while idx <= last do
    local e = string.find(line, ",", pos, true)
    local f
    if e then f = string.sub(line, pos, e - 1) else f = string.sub(line, pos) end
    if idx == cc[1] then v1 = tonumber(f) end
    if idx == cc[2] then v2 = tonumber(f) end
    if idx == cc[3] then v3 = tonumber(f) end
    if idx == cmin then v4 = tonumber(f) end
    if not e then break end
    pos = e + 1
    idx = idx + 1
  end
  return v1, v2, v3, v4
end

local function acc(k, v, b)
  if v then
    local s, c = S[k], K[k]
    s[b] = s[b] + v
    c[b] = c[b] + 1
  end
end

local function handleLine(line)
  if string.byte(line, -1) == 13 then line = string.sub(line, 1, -2) end
  if #line == 0 then return end
  lineNo = lineNo + 1
  if lineNo > total then return end
  if lineNo == 1 then t0str = string.match(line, "^[^,]*,([^,]*)") end
  if lineNo == total then t1str = string.match(line, "^[^,]*,([^,]*)") end
  local b = math.floor((lineNo - 1) * N / total) + 1
  if b > N then b = N end
  local v1, v2, v3, v4 = extract(line)
  if v4 and v4 ~= 0 then minv = v4 end
  acc(1, v1, b)
  acc(2, v2, b)
  acc(3, v3, b)
end

-- bucket averages and their raw min / max
local function series(sum, cnt)
  local out, lo, hi = {}, nil, nil
  for i = 1, N do
    if cnt[i] > 0 then
      local v = sum[i] / cnt[i]
      out[i] = v
      if not lo or v < lo then lo = v end
      if not hi or v > hi then hi = v end
    end
  end
  if not lo then return nil end
  return out, lo, hi
end

local function padRange(lo, hi)
  if hi - lo < 1e-9 then return lo - 1, hi + 1 end
  local pad = (hi - lo) * 0.03
  return lo - pad, hi + pad
end

local function finishLoad()
  closeFile()
  local raw = {}
  ys = {}
  for k = 1, 3 do
    if cc[k] then
      local o, lo, hi = series(S[k], K[k])
      ys[k] = o
      if o then raw[k] = { lo, hi } end
    end
  end
  S, K = nil, nil
  if not ys[1] then
    msg = "No numeric data in " .. tostring(nm[1])
    goPick1()
    return
  end
  lo1, hi1 = padRange(raw[1][1], raw[1][2])

  -- right axis: shared scale for Y2 and Y3
  rlo, rhi = nil, nil
  for k = 2, 3 do
    if raw[k] then
      if not rlo or raw[k][1] < rlo then rlo = raw[k][1] end
      if not rhi or raw[k][2] > rhi then rhi = raw[k][2] end
    end
  end
  if rlo then rlo, rhi = padRange(rlo, rhi) end

  local a, per = parseTime(t0str)
  local b = parseTime(t1str)
  dur = nil
  if a and b then
    if b < a then b = b + per end
    dur = b - a
  end
  cur = 1
  state = "graph"
end

local function loadStep()
  local t0 = getTime()
  repeat
    local chunk = io.read(fh, 2048)
    if not chunk or #chunk == 0 then
      if #carry > 0 and not skipHeader then handleLine(carry) end
      carry = ""
      finishLoad()
      return
    end
    local buf = carry .. chunk
    local pos = 1
    while true do
      local nl = string.find(buf, "\n", pos, true)
      if not nl then break end
      if skipHeader then
        skipHeader = false
      else
        handleLine(string.sub(buf, pos, nl - 1))
      end
      pos = nl + 1
    end
    carry = string.sub(buf, pos)
  until getTime() - t0 >= BUDGET
end

---------------------------------------------------------------------------
-- graph
---------------------------------------------------------------------------
local function drawGraph()
  local x0, x1 = PL, LCD_W - PR
  local gy0, gy1 = HEAD_H + 10, LCD_H - 30
  local pw = x1 - x0
  local den = N - 1
  if den < 1 then den = 1 end
  local hasR = (ys[2] or ys[3]) and true or false

  box(0, 0, LCD_W, LCD_H, C.bg)

  -- header: column names (right ones are right-aligned, 3rd at the edge)
  txt(4, 3, nm[1], SMLSIZE, C.s1)
  -- title: MinCv from rMIN (drawn left-aligned at a computed x, no CENTER flag)
  local mt, mc = "MinCv=--", C.dim
  if minv then mt, mc = string.format("MinCv=%.2f", minv), C.text end
  txt(math.floor((LCD_W - textW(mt)) / 2), 3, mt, SMLSIZE, mc)
  local rx = LCD_W - 4
  if ys[3] then
    txt(rx, 3, nm[3], SMLSIZE + RIGHT, C.s3)
    rx = rx - textW(nm[3]) - 12
  end
  if ys[2] then txt(rx, 3, nm[2], SMLSIZE + RIGHT, C.s2) end

  -- right axis label color: neutral when two lines share it
  local rcol = C.text
  if ys[2] and not ys[3] then rcol = C.s2 end
  if ys[3] and not ys[2] then rcol = C.s3 end

  -- grid + axis labels
  local r1 = hi1 - lo1
  local rr = hasR and (rhi - rlo) or 0
  for i = 0, 4 do
    local y = gy0 + math.floor((gy1 - gy0) * i / 4 + 0.5)
    ln(x0, y, x1, y, DOTTED, C.grid)
    txt(x0 - 4, y - 7, fmt(hi1 - r1 * i / 4, r1), SMLSIZE + RIGHT, C.s1)
    if hasR then
      txt(x1 + 4, y - 7, fmt(rhi - rr * i / 4, rr), SMLSIZE, rcol)
    end
    local x = x0 + math.floor(pw * i / 4 + 0.5)
    ln(x, gy0, x, gy1, DOTTED, C.grid)
  end

  -- series
  local function plot(vals, lo, hi, color)
    setc(color)
    local span = hi - lo
    local px, py
    for i = 1, N do
      local v = vals[i]
      if v then
        local x = x0 + math.floor((i - 1) * pw / den + 0.5)
        local y = gy1 - math.floor((v - lo) / span * (gy1 - gy0) + 0.5)
        if px then
          lcd.drawLine(px, py, x, y, SOLID, CUSTOM_COLOR)
        else
          lcd.drawLine(x, y, x, y, SOLID, CUSTOM_COLOR)
        end
        px, py = x, y
      else
        px = nil
      end
    end
  end
  plot(ys[1], lo1, hi1, C.s1)
  if ys[2] then plot(ys[2], rlo, rhi, C.s2) end
  if ys[3] then plot(ys[3], rlo, rhi, C.s3) end

  -- cursor
  local cx = x0 + math.floor((cur - 1) * pw / den + 0.5)
  ln(cx, gy0, cx, gy1, SOLID, C.cursor)

  -- footer: time and the values at the cursor
  local fy = LCD_H - 22
  local el = dur and (dur * (cur - 1) / den) or nil
  txt(4, fy, fmtTime(el), SMLSIZE, C.text)
  local v = ys[1][cur]
  txt(LCD_W * 0.15, fy, v and fmt(v, r1) or "-", SMLSIZE, C.s1)
  if ys[2] then
    v = ys[2][cur]
    txt(LCD_W * 0.35, fy, v and fmt(v, rr) or "-", SMLSIZE, C.s2)
  end
  if ys[3] then
    v = ys[3][cur]
    txt(LCD_W * 0.55, fy, v and fmt(v, rr) or "-", SMLSIZE, C.s3)
  end
  txt(LCD_W - 4, fy, "len " .. fmtTime(dur), SMLSIZE + RIGHT, C.dim)
end

local function graphEvent(event, ts)
  if event == EVT_VIRTUAL_NEXT then
    cur = math.min(N, cur + 1)
  elseif event == EVT_VIRTUAL_PREV then
    cur = math.max(1, cur - 1)
  elseif event == EVT_VIRTUAL_NEXT_PAGE then
    cur = math.min(N, cur + 10)
  elseif event == EVT_VIRTUAL_PREV_PAGE then
    cur = math.max(1, cur - 10)
  elseif event == EVT_VIRTUAL_ENTER then
    goPick1()
  elseif event == EVT_VIRTUAL_EXIT then
    goFiles()
  elseif ts and (event == EVT_TOUCH_TAP or event == EVT_TOUCH_FIRST
                 or event == EVT_TOUCH_SLIDE) then
    local x0, pw = PL, LCD_W - PL - PR
    local den = N - 1
    if den < 1 then den = 1 end
    local i = math.floor((ts.x - x0) * den / pw + 0.5) + 1
    if i < 1 then i = 1 end
    if i > N then i = N end
    cur = i
  end
end

---------------------------------------------------------------------------
-- tool entry points
---------------------------------------------------------------------------
local function init()
  C.bg     = lcd.RGB(12, 14, 20)
  C.bar    = lcd.RGB(36, 40, 56)
  C.sel    = lcd.RGB(40, 90, 150)
  C.grid   = lcd.RGB(60, 64, 78)
  C.text   = lcd.RGB(230, 230, 235)
  C.dim    = lcd.RGB(140, 145, 160)
  C.s1     = lcd.RGB(70, 170, 255)
  C.s2     = lcd.RGB(255, 170, 50)
  C.s3     = lcd.RGB(120, 225, 130)
  C.cursor = lcd.RGB(200, 200, 200)
  C.err    = lcd.RGB(255, 90, 90)
  ROWS = math.floor((LCD_H - LIST_Y) / ROW_H)
  goFiles()
end

local function run(event, ts)
  if event ~= 0 then msg = nil end

  if state == "files" then
    local r = listNav(event, ts, #files)
    if r == "exit" then
      closeFile()
      return 1
    elseif r == "enter" then
      startScan(files[lsel])
    end
    drawList(TITLE .. ": select log file", files)
    if msg then txt(10, LCD_H - 22, msg, SMLSIZE, C.err) end

  elseif state == "scan" then
    if event == EVT_VIRTUAL_EXIT then
      goFiles()
    else
      scanStep()
      if state == "scan" then
        drawProgress("Scanning...", 0, string.format("%d KB read", math.floor(scanBytes / 1024)))
      end
    end

  elseif state == "pick1" then
    local r = listNav(event, ts, #colNames)
    if r == "exit" then
      goFiles()
    elseif r == "enter" then
      cc[1], nm[1] = colIdx[lsel], colNames[lsel]
      goPick(2)
    end
    if state == "pick1" then
      drawList("Y1 (left axis, blue)", colNames)
      if msg then txt(10, LCD_H - 22, msg, SMLSIZE, C.err) end
    end

  elseif state == "pick2" then
    local r = listNav(event, ts, #optNames)
    if r == "exit" then
      goPick1()
    elseif r == "enter" then
      if lsel == 1 then
        cc[2], nm[2] = nil, nil
      else
        cc[2], nm[2] = colIdx[lsel - 1], colNames[lsel - 1]
      end
      goPick(3)
    end
    if state == "pick2" then
      drawList("Y2 (right axis, orange)  Y1=" .. tostring(nm[1]), optNames)
    end

  elseif state == "pick3" then
    local r = listNav(event, ts, #optNames)
    if r == "exit" then
      goPick(2)
    elseif r == "enter" then
      if lsel == 1 then
        cc[3], nm[3] = nil, nil
      else
        cc[3], nm[3] = colIdx[lsel - 1], colNames[lsel - 1]
      end
      startLoad()
    end
    if state == "pick3" then
      drawList("Y3 (right axis, green)  Y2=" .. tostring(nm[2] or "none"), optNames)
    end

  elseif state == "load" then
    if event == EVT_VIRTUAL_EXIT then
      goPick(3)
    else
      loadStep()
      if state == "load" then
        drawProgress("Loading...", lineNo / total,
          string.format("%d / %d samples", lineNo, total))
      end
    end

  elseif state == "graph" then
    graphEvent(event, ts)
    if state == "graph" then drawGraph() end
  end

  return 0
end

return { init = init, run = run }
