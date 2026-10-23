--[[
  VoltFuel Tools -- Logs: list, check and delete log files

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

  Shows every log of an aircraft with its size and length, and deletes
  logs: the marked ones, one file, or in bulk (all logs of the aircraft,
  shorter than N s, older than N days, or all but the newest N).
  Deleting cannot be undone, so every delete asks for confirmation (twice
  for more than one file). Do not delete while the radio is logging.
--]]

local L
local state = "models"
local models, mnames, mlist = {}, {}, nil
local g                      -- chosen aircraft: { name, files }
local flist, marks, nmarks = nil, {}, 0
local info = {}              -- name -> { size, dur }
local ilist, idx = nil, 0
local menu, mnu = {}, nil
local param, pval, pkind = nil, 0, nil
local todo, confirmStage, confirmNeed = {}, 1, 1
local dpos, dcount = 0, 0
local msg

local FROWS                  -- rows in the file list (one row is kept for the button)
local BTN = { w = 100, h = 20 }

local function refresh()
  local grp = L.groupModels(L.listLogs())
  models, mnames = {}, {}
  for _, m in ipairs(grp) do
    models[#models + 1] = m
    mnames[#mnames + 1] = string.format("%s   (%d logs)", m.name, #m.files)
  end
end

local function goModels()
  refresh()
  mlist = L.newList()
  state = "models"
end

local function goLoad()
  -- re-read the folder, keep only this aircraft
  refresh()
  local fresh
  for _, m in ipairs(models) do if g and m.name == g.name then fresh = m end end
  if not fresh then return goModels() end
  g = fresh
  marks, nmarks = {}, 0
  idx = 0
  state = "load"
end

local function stampShort(stamp)
  local mo, d, h, mi = string.match(stamp or "", "^%d%d%d%d%-(%d%d)%-(%d%d)%-(%d%d)(%d%d)")
  if mo then return mo .. "-" .. d .. " " .. h .. ":" .. mi end
  return stamp or "?"
end

local function toggle(f)
  if marks[f.name] then
    marks[f.name] = nil
    nmarks = nmarks - 1
  else
    marks[f.name] = true
    nmarks = nmarks + 1
  end
end

---------------------------------------------------------------------------
-- selections for the delete actions: lists of file entries
---------------------------------------------------------------------------
local function selMarked()
  local t = {}
  for _, f in ipairs(g.files) do if marks[f.name] then t[#t + 1] = f end end
  return t
end

local function selShorter(sec)
  local t = {}
  for _, f in ipairs(g.files) do
    local i = info[f.name]
    if i and i.dur and i.dur < sec then t[#t + 1] = f end
  end
  return t
end

local function selOlder(days)
  local t, today = {}, L.today()
  if not today then return t end
  for _, f in ipairs(g.files) do
    local d = L.stampDays(f.stamp)
    if d and today - d > days then t[#t + 1] = f end
  end
  return t
end

local function selKeep(n)
  local t = {}
  for i = n + 1, #g.files do t[#t + 1] = g.files[i] end
  return t
end

local function askConfirm(list, need)
  if #list == 0 then
    msg = "Nothing to delete"
    state = "files"
    return
  end
  todo, confirmStage, confirmNeed = list, 1, need
  state = "confirm"
end

---------------------------------------------------------------------------
-- menus
---------------------------------------------------------------------------
local PARAMS = {
  shorter = { "Delete logs shorter than", " s", 30, 5, 5, 900 },
  older   = { "Delete logs older than", " days", 30, 1, 1, 400 },
  keep    = { "Keep the newest", " logs (delete the rest)", 5, 1, 1, 100 },
}

local function openMenu()
  menu = {}
  local function add(label, fn) menu[#menu + 1] = { label = label, fn = fn } end
  if nmarks > 0 then
    add(string.format("Delete marked (%d)", nmarks), function() askConfirm(selMarked(), 1) end)
  end
  add("Delete this file", function() askConfirm({ g.files[flist.sel] }, 1) end)
  if nmarks < #g.files then
    add("Mark all", function()
      for _, f in ipairs(g.files) do
        if not marks[f.name] then toggle(f) end
      end
      state = "files"
    end)
  end
  if nmarks > 0 then
    add("Clear marks", function() marks, nmarks = {}, 0 state = "files" end)
  end
  add(string.format("Delete ALL logs of %s (%d)", g.name, #g.files),
    function() askConfirm(g.files, 2) end)
  for _, k in ipairs({ "shorter", "older", "keep" }) do
    add(PARAMS[k][1] .. " ...", function()
      pkind, pval = k, PARAMS[k][3]
      state = "param"
    end)
  end
  add("Cancel", function() state = "files" end)
  mnu = L.newList()
  state = "menu"
end

local function drawFiles()
  local C = L.C
  L.header(g.name, string.format("%d/%d   marked %d", flist.sel, #g.files, nmarks))
  for r = 1, FROWS do
    local i = flist.top + r
    local f = g.files[i]
    if not f then break end
    local y = L.LIST_Y + (r - 1) * L.ROW_H
    if i == flist.sel then L.box(0, y, LCD_W, L.ROW_H, C.sel) end
    L.txt(10, y + 3, marks[f.name] and "[x]" or "[ ]", SMLSIZE, marks[f.name] and C.warn or C.dim)
    L.txt(44, y + 3, stampShort(f.stamp), SMLSIZE, C.text)
    local inf = info[f.name]
    L.txt(176, y + 3, inf and L.fmtSize(inf.size) or "...", SMLSIZE, C.text)
    L.txt(262, y + 3, inf and L.fmtDur(inf.dur) or "...", SMLSIZE, C.text)
  end
  local by = LCD_H - BTN.h - 4
  L.box(LCD_W - BTN.w - 6, by, BTN.w, BTN.h, C.bar)
  L.txt(LCD_W - 6 - BTN.w / 2, by + 3, "Actions", SMLSIZE + CENTER, C.text)
  L.txt(10, by + 3, msg or "ENTER/tap = mark   long ENTER = actions", SMLSIZE, msg and C.warn or C.dim)
end

---------------------------------------------------------------------------
-- interface
---------------------------------------------------------------------------
local function init(lib)
  L = lib
  FROWS = L.ROWS - 1
  info = {}
  goModels()
end

local function run(event, ts)
  if event ~= 0 and state ~= "files" then msg = nil end

  if state == "models" then
    local r = L.listNav(mlist, event, ts, #mnames)
    if r == "exit" then return 1 end
    if r == "enter" then
      g = models[mlist.sel]
      msg = nil
      goLoad()
    end
    if state == "models" then
      L.drawList("VoltFuel Logs: select aircraft", mnames, mlist)
      if #models == 0 then L.txt(10, L.LIST_Y + 40, "No log files in /LOGS", SMLSIZE, L.C.warn) end
    end

  elseif state == "load" then
    if event == EVT_VIRTUAL_EXIT then
      goModels()
    else
      local t0 = getTime()
      repeat
        idx = idx + 1
        local f = g.files[idx]
        if not f then break end
        info[f.name] = { size = L.fileSize(f.name), dur = L.duration(f.name) }
      until getTime() - t0 >= L.BUDGET
      if idx >= #g.files then
        flist = L.newList()
        state = "files"
      else
        L.progress("Reading " .. g.name, idx / #g.files, string.format("%d / %d logs", idx, #g.files))
      end
    end

  elseif state == "files" then
    if event == EVT_TOUCH_TAP and ts and ts.y >= LCD_H - BTN.h - 8 then
      if ts.x >= LCD_W - BTN.w - 12 then openMenu() end
    elseif (EVT_VIRTUAL_ENTER_LONG and event == EVT_VIRTUAL_ENTER_LONG)
        or (EVT_VIRTUAL_MENU and event == EVT_VIRTUAL_MENU) then
      openMenu()
    else
      if event ~= 0 then msg = nil end
      local r = L.listNav(flist, event, ts, #g.files, FROWS)
      if r == "exit" then
        goModels()
      elseif r == "enter" and g.files[flist.sel] then
        toggle(g.files[flist.sel])
      end
    end
    if state == "files" then drawFiles() end

  elseif state == "menu" then
    local labels = {}
    for i, m in ipairs(menu) do labels[i] = m.label end
    local r = L.listNav(mnu, event, ts, #labels)
    if r == "exit" then
      state = "files"
    elseif r == "enter" then
      menu[mnu.sel].fn()
    end
    if state == "menu" then L.drawList("Actions: " .. g.name, labels, mnu) end

  elseif state == "param" then
    local p = PARAMS[pkind]
    if event == EVT_VIRTUAL_EXIT then
      state = "menu"
    elseif event == EVT_VIRTUAL_NEXT then
      pval = math.min(pval + p[4], p[6])
    elseif event == EVT_VIRTUAL_PREV then
      pval = math.max(pval - p[4], p[5])
    elseif event == EVT_TOUCH_TAP and ts then
      if ts.y > LCD_H / 2 + 20 then
        -- bottom area: confirm
        local list
        if pkind == "shorter" then list = selShorter(pval)
        elseif pkind == "older" then list = selOlder(pval)
        else list = selKeep(pval) end
        askConfirm(list, 2)
      elseif ts.x < LCD_W / 2 then
        pval = math.max(pval - p[4], p[5])
      else
        pval = math.min(pval + p[4], p[6])
      end
    elseif event == EVT_VIRTUAL_ENTER then
      local list
      if pkind == "shorter" then list = selShorter(pval)
      elseif pkind == "older" then list = selOlder(pval)
      else list = selKeep(pval) end
      askConfirm(list, 2)
    end
    if state == "param" then
      L.header("Actions: " .. g.name)
      L.txt(LCD_W / 2, 50, p[1], SMLSIZE + CENTER, L.C.dim)
      L.txt(LCD_W / 2, 80, tostring(pval) .. p[2], MIDSIZE + CENTER, L.C.warn)
      if pkind == "older" and not L.today() then
        L.txt(LCD_W / 2, 118, "(today's date is not available)", SMLSIZE + CENTER, L.C.err)
      end
      L.txt(LCD_W / 2, 150, "roller / tap < > to change", SMLSIZE + CENTER, L.C.dim)
      L.txt(LCD_W / 2, LCD_H - 56, "ENTER or tap here = preview", SMLSIZE + CENTER, L.C.text)
      L.txt(LCD_W / 2, LCD_H - 22, "EXIT = back", SMLSIZE + CENTER, L.C.dim)
    end

  elseif state == "confirm" then
    if event == EVT_VIRTUAL_EXIT then
      state = "files"
    elseif event == EVT_VIRTUAL_ENTER or (event == EVT_TOUCH_TAP and ts and ts.y > LCD_H - 60) then
      if confirmStage < confirmNeed then
        confirmStage = confirmStage + 1
      else
        dpos, dcount = 0, 0
        state = "delete"
      end
    end
    if state == "confirm" then
      local C, bytes = L.C, 0
      for _, f in ipairs(todo) do bytes = bytes + ((info[f.name] and info[f.name].size) or 0) end
      L.header(confirmStage == 1 and "Delete these logs?" or "REALLY delete?", g.name)
      L.txt(10, 28, string.format("%d file%s, %s", #todo, #todo == 1 and "" or "s", L.fmtSize(bytes)),
        MIDSIZE, confirmStage == 2 and C.err or C.warn)
      for i = 1, math.min(#todo, 5) do
        L.txt(14, 60 + (i - 1) * 18, stampShort(todo[i].stamp), SMLSIZE, C.text)
      end
      if #todo > 5 then L.txt(14, 60 + 5 * 18, string.format("... and %d more", #todo - 5), SMLSIZE, C.dim) end
      L.txt(10, LCD_H - 56, "This cannot be undone.", SMLSIZE, C.err)
      L.txt(LCD_W / 2, LCD_H - 38, confirmStage < confirmNeed and "ENTER or tap here = continue" or "ENTER or tap here = DELETE",
        SMLSIZE + CENTER, C.text)
      L.txt(LCD_W / 2, LCD_H - 20, "EXIT = cancel", SMLSIZE + CENTER, C.dim)
    end

  elseif state == "delete" then
    local t0 = getTime()
    repeat
      dpos = dpos + 1
      local f = todo[dpos]
      if not f then break end
      pcall(del, L.LOGDIR .. "/" .. f.name)
      if not L.fileSize(f.name) then dcount = dcount + 1 end
    until getTime() - t0 >= L.BUDGET
    if dpos >= #todo then
      info = {}
      goLoad()
      msg = string.format("Deleted %d of %d", dcount, #todo)
    else
      L.progress("Deleting", dpos / #todo, string.format("%d / %d", dpos, #todo), "")
    end
  end
  return 0
end

return { init = init, run = run, _test = function() return { state = state, g = g, nmarks = nmarks, msg = msg } end }
