--[[
  VoltFuel Tools -- Graph / Tune / Logs for the VoltFuel widget

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

  Install: copy the SD-card folder SCRIPTS/TOOLS (VoltFuel_Tools.lua and the
  folder VoltFuel/ next to it).
  Run: SYS (or the Tools menu) -> VoltFuel_Tools.
    Graph -- graph of a log (sBAT, voltage, ...)
    Tune  -- suggests a MinCv from your logs
    Logs  -- list, check and delete log files
--]]

-- The modules live next to this file. The old location (/SCRIPTS/VoltFuel/)
-- is still accepted so that an earlier installation keeps working.
local DIRS = { "/SCRIPTS/TOOLS/VoltFuel/", "/SCRIPTS/VoltFuel/" }
local DIR
local L, mod
local items = { "Graph   (draw a log)", "Tune    (suggest a MinCv)", "Logs    (manage log files)" }
local names = { "graph", "tune", "logs" }
local lst

local function load(name)
  for _, d in ipairs(DIR and { DIR } or DIRS) do
    local chunk = loadScript(d .. name .. ".lua")
    if chunk then
      DIR = d
      return chunk()
    end
  end
  return nil
end

local function init()
  L = load("lib")
  if L then
    L.DIR = DIR
    L.init()
  end
  lst = L and L.newList() or nil
end

local function run(event, ts)
  if not L then
    lcd.drawText(6, 6, "VoltFuel: /SCRIPTS/TOOLS/VoltFuel/ is missing", 0)
    return event == EVT_VIRTUAL_EXIT and 1 or 0
  end
  if mod then
    if mod.run(event, ts) == 1 then
      mod = nil
      collectgarbage()
    end
    return 0
  end
  local r = L.listNav(lst, event, ts, #items)
  if r == "exit" then return 1 end
  if r == "enter" then
    mod = load(names[lst.sel])
    if mod then mod.init(L) end
  end
  if not mod then
    L.drawList("VoltFuel Tools", items, lst)
    L.txt(10, LCD_H - 22, "Estimates only. Do not rely on them alone for landing.", SMLSIZE, L.C.dim)
  end
  return 0
end

return { init = init, run = run }
