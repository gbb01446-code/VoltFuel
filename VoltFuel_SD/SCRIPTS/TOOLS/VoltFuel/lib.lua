--[[
  VoltFuel Tools -- shared helpers

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

local L = {}
L.LOGDIR = "/LOGS"
L.HEAD_H = 22
L.ROW_H = 22
L.BUDGET = 3            -- work per run() call, in 10 ms ticks
L.MAXFILES = 400
L.C = {}

function L.init()
  local C = L.C
  C.bg   = lcd.RGB(12, 14, 20)
  C.bar  = lcd.RGB(36, 40, 56)
  C.sel  = lcd.RGB(40, 90, 150)
  C.grid = lcd.RGB(60, 64, 78)
  C.text = lcd.RGB(230, 230, 235)
  C.dim  = lcd.RGB(140, 145, 160)
  C.ok   = lcd.RGB(120, 225, 130)
  C.warn = lcd.RGB(255, 170, 50)
  C.err  = lcd.RGB(255, 90, 90)
  C.blue = lcd.RGB(70, 170, 255)
  L.LIST_Y = L.HEAD_H + 2
  L.ROWS = math.floor((LCD_H - L.LIST_Y) / L.ROW_H)
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
function L.txt(x, y, s, fl, c)
  lcd.setColor(CUSTOM_COLOR, c or L.C.text)
  lcd.drawText(x, y, s, (fl or 0) + CUSTOM_COLOR)
end

function L.box(x, y, w, h, c)
  lcd.setColor(CUSTOM_COLOR, c)
  lcd.drawFilledRectangle(x, y, w, h, CUSTOM_COLOR)
end

function L.header(title, right)
  L.box(0, 0, LCD_W, LCD_H, L.C.bg)
  L.box(0, 0, LCD_W, L.HEAD_H, L.C.bar)
  L.txt(6, 3, title, SMLSIZE, L.C.text)
  if right then L.txt(LCD_W - 6, 3, right, SMLSIZE + RIGHT, L.C.dim) end
end

function L.progress(title, frac, sub, hint)
  L.header(title)
  local bx, bw, by = 30, LCD_W - 60, math.floor(LCD_H / 2) - 8
  L.box(bx, by, bw, 16, L.C.grid)
  if frac > 1 then frac = 1 end
  if frac > 0 then L.box(bx, by, math.floor(bw * frac), 16, L.C.blue) end
  L.txt(LCD_W / 2, by + 26, sub or "", SMLSIZE + CENTER, L.C.dim)
  L.txt(LCD_W / 2, LCD_H - 22, hint or "EXIT = cancel", SMLSIZE + CENTER, L.C.dim)
end

---------------------------------------------------------------------------
-- list navigation: lst = { sel = 1, top = 0 }; returns "enter", "exit" or nil
---------------------------------------------------------------------------
function L.newList() return { sel = 1, top = 0 } end

function L.listNav(lst, event, ts, n, rows)
  rows = rows or L.ROWS
  local r = nil
  if n > 0 then
    if event == EVT_VIRTUAL_NEXT then
      lst.sel = lst.sel + 1
      if lst.sel > n then lst.sel = 1 end
    elseif event == EVT_VIRTUAL_PREV then
      lst.sel = lst.sel - 1
      if lst.sel < 1 then lst.sel = n end
    elseif event == EVT_VIRTUAL_ENTER then
      r = "enter"
    elseif event == EVT_TOUCH_TAP and ts and ts.y >= L.LIST_Y
        and ts.y < L.LIST_Y + rows * L.ROW_H then
      local i = math.floor((ts.y - L.LIST_Y) / L.ROW_H) + lst.top + 1
      if i >= 1 and i <= n then
        lst.sel = i
        r = "enter"
      end
    end
  end
  if event == EVT_VIRTUAL_EXIT then r = "exit" end
  if lst.sel > n then lst.sel = math.max(n, 1) end
  if lst.sel <= lst.top then lst.top = lst.sel - 1 end
  if lst.sel > lst.top + rows then lst.top = lst.sel - rows end
  if lst.top < 0 then lst.top = 0 end
  return r
end

-- plain list of strings
function L.drawList(title, list, lst, right)
  L.header(title, right or (#list > 0 and (lst.sel .. "/" .. #list) or nil))
  if #list == 0 then
    L.txt(10, L.LIST_Y + 8, "(empty)", SMLSIZE, L.C.dim)
    return
  end
  for r = 1, L.ROWS do
    local i = lst.top + r
    if i > #list then break end
    local y = L.LIST_Y + (r - 1) * L.ROW_H
    if i == lst.sel then L.box(0, y, LCD_W, L.ROW_H, L.C.sel) end
    L.txt(10, y + 3, list[i], SMLSIZE, L.C.text)
  end
end

---------------------------------------------------------------------------
-- text / time helpers
---------------------------------------------------------------------------
function L.split(s)
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

function L.norm(s)
  s = string.lower(s or "")
  s = string.gsub(s, "%(.-%)", "")
  s = string.gsub(s, "%s+", "")
  return s
end

-- "HH:MM:SS.ss" -> seconds
function L.parseTime(s)
  if not s then return nil end
  local h, m, sec, frac = string.match(s, "^(%d+):(%d+):(%d+)%.?(%d*)")
  if not h then return nil end
  local t = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
  if frac and #frac > 0 then t = t + tonumber("0." .. frac) end
  return t
end

function L.fmtDur(s)
  if not s then return "--" end
  s = math.floor(s + 0.5)
  if s >= 3600 then
    return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60)
  end
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function L.fmtSize(b)
  if not b then return "--" end
  if b >= 1048576 then return string.format("%.1f MB", b / 1048576) end
  return string.format("%d KB", math.floor(b / 1024 + 0.5))
end

---------------------------------------------------------------------------
-- log files:  <Model>-YYYY-MM-DD-HHMMSS.csv
---------------------------------------------------------------------------
function L.stampOf(name)
  return string.match(name, "(%d%d%d%d%-%d%d%-%d%d%-%d+)%.[cC][sS][vV]$") or ""
end

function L.modelOf(name)
  local m = string.match(name, "^(.-)%-%d%d%d%d%-%d%d%-%d%d%-%d+%.[cC][sS][vV]$")
  if m and #m > 0 then return m end
  return "(other)"
end

-- days since 1970-01-01 (civil calendar)
function L.civil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = math.floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

function L.stampDays(stamp)
  local y, m, d = string.match(stamp, "^(%d%d%d%d)%-(%d%d)%-(%d%d)")
  if not y then return nil end
  return L.civil(tonumber(y), tonumber(m), tonumber(d))
end

function L.today()
  local ok, dt = pcall(getDateTime)
  if ok and dt and dt.year then return L.civil(dt.year, dt.mon, dt.day) end
  return nil
end

-- all CSV logs, newest first
function L.listLogs()
  local t = {}
  pcall(function()
    for name in dir(L.LOGDIR) do
      if string.find(string.lower(name), "%.csv$") then
        t[#t + 1] = { name = name, model = L.modelOf(name), stamp = L.stampOf(name) }
      end
    end
  end)
  table.sort(t, function(a, b)
    if a.stamp ~= b.stamp then return a.stamp > b.stamp end
    return a.name > b.name
  end)
  local out = {}
  for i = 1, math.min(#t, L.MAXFILES) do out[i] = t[i] end
  return out
end

-- groups (newest log first inside each group); groups sorted by name
function L.groupModels(list)
  local idx, g = {}, {}
  for _, f in ipairs(list) do
    local k = idx[f.model]
    if not k then
      k = #g + 1
      idx[f.model] = k
      g[k] = { name = f.model, files = {}, bytes = 0 }
    end
    g[k].files[#g[k].files + 1] = f
  end
  table.sort(g, function(a, b) return a.name < b.name end)
  return g
end

function L.fileSize(name)
  local ok, st = pcall(fstat, L.LOGDIR .. "/" .. name)
  if ok and st and st.size then return st.size end
  return nil
end

-- log length in seconds from the first and last data rows (reads ~2.5 KB)
function L.duration(name)
  local path = L.LOGDIR .. "/" .. name
  local fh = io.open(path, "r")
  if not fh then return nil end
  local head = io.read(fh, 1024) or ""
  local nl = string.find(head, "\n", 1, true)
  if not nl then io.close(fh) return nil end
  local hdr = L.split((string.gsub(string.sub(head, 1, nl - 1), "\r", "")))
  local tcol
  for i = 1, #hdr do
    if hdr[i] == "Time" then tcol = i break end
  end
  if not tcol then io.close(fh) return nil end
  local nl2 = string.find(head, "\n", nl + 1, true)
  local first = string.sub(head, nl + 1, (nl2 or (#head + 1)) - 1)
  local t0 = L.parseTime(L.split(first)[tcol])
  local size = L.fileSize(name) or 0
  local tail = head
  if size > 1024 then
    local pos = size - 1536
    if pos < 1024 then pos = 1024 end
    local ok = pcall(io.seek, fh, pos)
    if ok then tail = io.read(fh, 1536) or "" end
  end
  io.close(fh)
  local t1
  local pos, lines = #tail, {}
  for ln in string.gmatch(tail, "[^\r\n]+") do lines[#lines + 1] = ln end
  for i = #lines, math.max(1, #lines - 2), -1 do
    local f = L.split(lines[i])
    local t = L.parseTime(f[tcol])
    if t and #f >= tcol then t1 = t break end
  end
  if not t0 or not t1 then return nil end
  if t1 < t0 then t1 = t1 + 86400 end
  return t1 - t0
end

return L
