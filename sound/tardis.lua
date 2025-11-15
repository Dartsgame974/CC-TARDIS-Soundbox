-- TARDIS Soundboard (pure Lua / ComputerCraft, no KubeUI)
-- Buttons drawn with term, sounds in dfpwm/, auto-download if missing.

local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
if not speaker then error("No speaker peripheral found.") end

local AUDIO_DIR = "dfpwm"
if not fs.exists(AUDIO_DIR) then fs.makeDir(AUDIO_DIR) end

local GITHUB_RAW_ROOT = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/dfpwm/"

local FILES = {
  startup = "startup_tardis.dfpwm",
  ambiance = "ambiance.dfpwm",
  bip = "bip_sound_error_1.dfpwm",
  short_flight = "short_flight.dfpwm",
  emergency = "emergencyshutdown.dfpwm",
  landing = "landing.dfpwm",
  takeoff = "tardistakeoff.dfpwm",
  flight_loop = "tardis_flight_loop.dfpwm",
  denied = "denied_flight.dfpwm",
  door_open = "door_open.dfpwm",
  door_close = "close_door.dfpwm",
  shutdown = "shutdowntardis.dfpwm",
  -- cloister: use a separate file if you have one, otherwise it uses ambiance
  cloister = "ambiance.dfpwm"
}

-- Helper: full path
local function path(name) return AUDIO_DIR .. "/" .. name end

-- Try to download missing file into dfpwm/; prefer http.get, fallback to wget if available.
local function ensure_file(fname)
  local p = path(fname)
  if fs.exists(p) then return true end
  local url = GITHUB_RAW_ROOT .. fname
  if http then
    local res = http.get(url)
    if not res then
      print("Failed to download " .. fname .. " via http")
      return false
    end
    local data = res.readAll(); res.close()
    local f = fs.open(p, "wb"); f.write(data); f.close()
    return true
  else
    -- try shell wget (may or may not exist depending on environment)
    local ok, _ = pcall(shell.run, "wget", url, p)
    if ok and fs.exists(p) then return true end
    return false
  end
end

-- Ensure all files (best-effort)
for _, name in pairs(FILES) do
  ensure_file(name)
end

-- Decoded cache
local decoded_cache = {}
local function load_decoded(fname)
  if decoded_cache[fname] then return decoded_cache[fname] end
  local p = path(fname)
  if not fs.exists(p) then
    print("Missing audio: " .. p) return nil
  end
  local f = fs.open(p, "rb"); local raw = f.readAll(); f.close()
  -- use convenience decode (works for entire file)
  local ok, decoded = pcall(dfpwm.decode, raw)
  if not ok then
    print("Failed to decode " .. fname) return nil
  end
  decoded_cache[fname] = decoded
  return decoded
end

-- Play helpers
local function play_once_decoded(decoded)
  if not decoded then return end
  while not speaker.playAudio(decoded) do
    os.pullEvent("speaker_audio_empty")
  end
  -- wait until it finishes (speaker_audio_empty signals buffer empty)
  os.pullEvent("speaker_audio_empty")
end

local function try_queue(decoded)
  if not decoded then return false end
  if speaker.playAudio(decoded) then return true end
  return false
end

-- State
local state = {
  running = true,
  powered = false,
  inFlight = false,
  loops = {
    ambiance = false,
    flight = false,
    cloister = false,
    bip = false
  }
}

-- High-level actions (non-blocking where appropriate)
local function action_startup()
  local d = load_decoded(FILES.startup); if d then play_once_decoded(d) end
  state.loops.ambiance = true
  state.powered = true
end

local function action_shutdown()
  -- stop loops then play shutdown
  for k in pairs(state.loops) do state.loops[k] = false end
  local d = load_decoded(FILES.shutdown); if d then play_once_decoded(d) end
  state.powered = false
  state.inFlight = false
end

local function action_demat()
  state.loops.ambiance = false
  local d = load_decoded(FILES.takeoff); if d then play_once_decoded(d) end
  state.loops.flight = true
  state.inFlight = true
end

local function action_landing()
  state.loops.flight = false
  local d = load_decoded(FILES.landing); if d then play_once_decoded(d) end
  state.inFlight = false
  if state.powered then state.loops.ambiance = true end
end

local function action_denied()
  state.loops.ambiance = false
  local d = load_decoded(FILES.denied); if d then play_once_decoded(d) end
  if state.powered then state.loops.ambiance = true end
end

local function action_shortflight()
  local d = load_decoded(FILES.short_flight); if d then play_once_decoded(d) end
  if state.powered then state.loops.ambiance = true end
end

local function action_emergency()
  local d = load_decoded(FILES.emergency); if d then play_once_decoded(d) end
end

local function action_door_open()
  local d = load_decoded(FILES.door_open); if d then play_once_decoded(d) end
end

local function action_door_close()
  local d = load_decoded(FILES.door_close); if d then play_once_decoded(d) end
end

-- Loop manager: tries to play each active loop. Each loop will attempt to queue its audio
-- and then wait for speaker buffer empty to replay. Loops are run concurrently with parallel.
local function loop_player(getflag, fname)
  while state.running do
    if getflag() then
      local d = load_decoded(fname)
      if d then
        -- Try to queue; if cannot, wait for buffer empty then try again.
        while getflag() and state.running do
          while not try_queue(d) do
            os.pullEvent("speaker_audio_empty")
            if not getflag() or not state.running then break end
          end
          -- once queued, wait for it to finish before looping
          if not state.running then break end
          os.pullEvent("speaker_audio_empty")
        end
      else
        -- missing file: back off
        sleep(1)
      end
    else
      sleep(0.1)
    end
  end
end

-- Terminal UI (pure term)
local ui = {}

local function draw_box(x,y,w,h, bg, fg)
  term.setBackgroundColor(bg); term.setTextColor(fg)
  for yy = y, y+h-1 do
    term.setCursorPos(x, yy)
    term.write(string.rep(" ", w))
  end
end

local function center_text(y, text)
  local w, h = term.getSize()
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  term.setCursorPos(x, y); term.write(text)
end

-- Buttons stored as {x,y,w,h,label,callback}
local buttons = {}

local function addButton(x,y,w,h,label,cb)
  table.insert(buttons, {x=x,y=y,w=w,h=h,label=label,cb=cb})
end

local function drawButton(b)
  draw_box(b.x, b.y, b.w, b.h, colors.gray, colors.black)
  -- center label in box
  local lx = b.x + math.floor((b.w - #b.label)/2)
  local ly = b.y + math.floor(b.h/2)
  term.setCursorPos(lx, ly); term.setTextColor(colors.black); term.write(b.label)
  term.setTextColor(colors.orange)
end

local function redraw_all()
  local sw, sh = term.getSize()
  term.setBackgroundColor(colors.black); term.clear()
  term.setTextColor(colors.orange)
  center_text(1, "ARTRON OS - TYPE 40")
  -- draw a simple panel
  local panel_w = math.min(60, sw - 4)
  local panel_h = math.min(18, sh - 4)
  draw_box(2, 2, panel_w, panel_h, colors.black, colors.orange)
  -- draw buttons
  for _,b in ipairs(buttons) do drawButton(b) end
  -- status
  term.setCursorPos(2, sh - 2)
  local status = string.format("Powered:%s  InFlight:%s  Ambiance:%s  Cloister:%s  Bip:%s",
    tostring(state.powered), tostring(state.inFlight),
    tostring(state.loops.ambiance), tostring(state.loops.cloister), tostring(state.loops.bip))
  term.write(status)
end

-- Build UI (positions chosen to fit most terminals)
local function build_ui()
  buttons = {}
  local sw, sh = term.getSize()
  local col1x = 3
  local col2x = math.min(sw - 22, 30)
  local bw, bh = 18, 3
  addButton(col1x, 4, bw, bh, "POWER", function()
    if not state.powered then
      action_startup()
    else
      action_shutdown()
    end
  end)
  addButton(col2x, 4, bw, bh, "EMERGENCY", action_emergency)

  addButton(col1x, 8, bw, bh, "DEMAT", function() if state.powered and not state.inFlight then action_demat() end end)
  addButton(col2x, 8, bw, bh, "LANDING", function() if state.inFlight then action_landing() end end)

  addButton(col1x, 12, bw, bh, "DENIED", action_denied)
  addButton(col2x, 12, bw, bh, "SHORT FLT", action_shortflight)

  addButton(col1x, 16, bw, bh, "CLOISTER", function() state.loops.cloister = not state.loops.cloister end)
  addButton(col2x, 16, bw, bh, "BIP", function() state.loops.bip = not state.loops.bip end)

  addButton(col1x, 20, bw, bh, "DOOR OPEN", action_door_open)
  addButton(col2x, 20, bw, bh, "DOOR CLOSE", action_door_close)
end

-- UI event loop (mouse)
local function ui_loop()
  build_ui()
  redraw_all()
  while state.running do
    local ev = { os.pullEvent() }
    if ev[1] == "mouse_click" then
      local _, _, mx, my = ev[1], ev[2], ev[3], ev[4]
      for _, b in ipairs(buttons) do
        if mx >= b.x and mx <= (b.x + b.w - 1) and my >= b.y and my <= (b.y + b.h - 1) then
          -- call handler in a pcall to avoid crashing UI
          local ok, err = pcall(b.cb)
          if not ok then
            print("Button error: "..tostring(err))
            sleep(0.5)
          end
          redraw_all()
          break
        end
      end
    elseif ev[1] == "term_resize" then
      build_ui()
      redraw_all()
    elseif ev[1] == "key" and ev[2] == keys.q and (os.pullEvent == os.pullEvent) then
      -- optional: quit with 'q' key (only when in focus)
      -- (keeps compatibility with terminals that don't have mouse)
    end
  end
end

-- Start everything in parallel:
-- loops: ambiance, flight, cloister, bip — each uses loop_player
parallel.waitForAny(
  function() loop_player(function() return state.loops.ambiance end, FILES.ambiance) end,
  function() loop_player(function() return state.loops.flight end, FILES.flight_loop) end,
  function() loop_player(function() return state.loops.cloister end, FILES.cloister) end,
  function() loop_player(function() return state.loops.bip end, FILES.bip) end,
  ui_loop
)

-- Clean up on exit
state.running = false
term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
print("TARDIS soundboard stopped.")
