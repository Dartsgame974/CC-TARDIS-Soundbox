-- TARDIS Soundboard for CC:Tweaked
-- Uses KubeUI for GUI and cc.audio.dfpwm for playback
-- Generated to match user's requirements: startup -> ambiance loop, demat -> takeoff -> flight loop, landing -> back to ambiance, cloister & bip toggle loops, denied flight interrupts ambience, short_flight is single-play, auto-download from GitHub if missing.

-- CONFIG -------------------------------------------------
local AUDIO_DIR = "dfpwm"
local GITHUB_RAW_ROOT = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/dfpwm/"
local FILES = {
  tardis_flight_loop = "tardis_flight_loop.dfpwm",
  ambiance = "ambiance.dfpwm",
  bip = "bip_sound_error_1.dfpwm",
  short_flight = "short_flight.dfpwm",
  emergencyshutdown = "emergencyshutdown.dfpwm",
  landing = "landing.dfpwm",
  startup = "startup_tardis.dfpwm",
  close_door = "close_door.dfpwm",
  door_open = "door_open.dfpwm",
  denied = "denied_flight.dfpwm",
  takeoff = "tardistakeoff.dfpwm",
  shutdown = "shutdowntardis.dfpwm",
  cloister = "ambiance.dfpwm" -- if you have a separate cloister file change this entry
}

-- STATE --------------------------------------------------
local state = {
  running = true,
  powered = false, -- "ooo" button state: false = off, true = on (powered -> ambiance runs)
  inFlight = false,
  ambianceLoop = false,
  flightLoop = false,
  cloisterLoop = false,
  bipLoop = false,
}

-- Dependencies -------------------------------------------
local fs = fs
local http = http
local speaker = peripheral.find("speaker")
local dfpwm = require("cc.audio.dfpwm")

if not speaker then
  print("Error: no speaker peripheral found. Attach a speaker and rerun.")
  return
end

-- Ensure audio directory exists
if not fs.exists(AUDIO_DIR) then
  fs.makeDir(AUDIO_DIR)
end

-- UTIL: download missing file from GitHub
local function ensure_file(name)
  local fname = AUDIO_DIR .. "/" .. name
  if fs.exists(fname) then return true end
  if not http then
    print("HTTP API not available; cannot download "..name)
    return false
  end
  local url = GITHUB_RAW_ROOT .. name
  print("Downloading "..name.." from GitHub...")
  local ok, res = pcall(http.get, url)
  if not ok or not res then
    print("Failed to download "..name)
    return false
  end
  local data = res.readAll()
  res.close()
  local f = fs.open(fname, "wb")
  f.write(data)
  f.close()
  print("Downloaded "..name)
  return true
end

-- Pre-check all audio files (attempt download if missing)
for k,v in pairs(FILES) do
  ensure_file(v)
end

-- AUDIO helpers -----------------------------------------
local decodedCache = {}

local function loadDecoded(name)
  if decodedCache[name] then return decodedCache[name] end
  local path = AUDIO_DIR.."/"..name
  if not fs.exists(path) then
    print("Missing audio: "..path)
    return nil
  end
  local f = fs.open(path, "rb")
  local raw = f.readAll()
  f.close()
  local ok, decoded = pcall(dfpwm.decode, raw)
  if not ok then
    print("Failed to decode "..name)
    return nil
  end
  decodedCache[name] = decoded
  return decoded
end

local function playOnceDecoded(decoded)
  if not decoded then return end
  while not speaker.playAudio(decoded) do
    os.pullEvent("speaker_audio_empty")
  end
  -- wait until audio finished (speaker_audio_empty will be fired when queue empties)
  os.pullEvent("speaker_audio_empty")
end

local function playOnceFile(name)
  local decoded = loadDecoded(name)
  if decoded then playOnceDecoded(decoded) end
end

-- Looping players: these functions block while their corresponding state flag is true.
-- They will be run inside parallel.waitForAny along with the GUI.
local function loopPlayer(flagGetter, fileName)
  while state.running do
    if flagGetter() then
      local decoded = loadDecoded(fileName)
      if decoded then
        while flagGetter() do
          -- attempt to queue audio, if can't, wait for empty then try again
          while not speaker.playAudio(decoded) do
            os.pullEvent("speaker_audio_empty")
          end
          -- wait for it to finish before possibly replaying
          os.pullEvent("speaker_audio_empty")
        end
      else
        -- file missing: break to avoid tight busy loop
        sleep(1)
      end
    end
    sleep(0.1)
  end
end

-- AUDIO CONTROL FUNCTIONS --------------------------------
local function startAmbiance()
  if state.ambianceLoop then return end
  state.ambianceLoop = true
end
local function stopAmbiance()
  state.ambianceLoop = false
end

local function startFlightLoop()
  if state.flightLoop then return end
  state.flightLoop = true
end
local function stopFlightLoop()
  state.flightLoop = false
end

local function startCloister()
  state.cloisterLoop = true
end
local function stopCloister()
  state.cloisterLoop = false
end

local function startBip()
  state.bipLoop = true
end
local function stopBip()
  state.bipLoop = false
end

-- HIGH LEVEL ACTIONS -------------------------------------
local function doStartup()
  -- play startup once, then ambiance loop
  playOnceFile(FILES.startup)
  startAmbiance()
  state.powered = true
end

local function doShutdown()
  -- play shutdown and stop everything
  -- stop loops first
  state.ambianceLoop = false
  state.flightLoop = false
  state.cloisterLoop = false
  state.bipLoop = false
  playOnceFile(FILES.shutdown)
  state.powered = false
end

local function doDemat()
  -- dematerialise: stop ambiance, play takeoff, start flight loop
  stopAmbiance()
  playOnceFile(FILES.takeoff)
  startFlightLoop()
  state.inFlight = true
end

local function doLanding()
  -- stop flight loop, play landing, then return to ambiance
  stopFlightLoop()
  playOnceFile(FILES.landing)
  state.inFlight = false
  if state.powered then startAmbiance() end
end

local function doDeniedFlight()
  stopAmbiance()
  playOnceFile(FILES.denied)
  if state.powered then startAmbiance() end
end

local function doShortFlight()
  -- play unique short flight once, then resume ambiance
  playOnceFile(FILES.short_flight)
  if state.powered then startAmbiance() end
end

local function doEmergencyShutdown()
  -- play emergency shutdown once
  playOnceFile(FILES.emergencyshutdown)
  -- you can choose if this also powers down; for safety we won't flip powered
end

-- KubeUI GUI ---------------------------------------------
local gui = require("kubeui")

-- Set font mode
pcall(gui.setFont, "kube")

-- Smart Margin System
local w, h = term.getSize()
local designWidth, designHeight = 51, 19
local scaleX, scaleY = w / designWidth, h / designHeight
local function smartPos(x, y) return math.floor(x * scaleX + 0.5), math.floor(y * scaleY + 0.5) end
local function smartSize(w, h) return math.max(1, math.floor(w * scaleX + 0.5)), math.max(1, math.floor(h * scaleY + 0.5)) end

local manager = gui.new()

local label = gui.Label(smartPos(4,3), "ARTRON OS - TYPE 40")
label.textColor = colors.orange
manager:add(label)

local panel = gui.Panel(smartPos(4,11), smartSize(96,45))
manager:add(panel)

-- "ooo" button: startup/shutdown toggle
local btnPower = gui.Button(smartPos(4,11), smartSize(40,10), "ooo", function()
  if not state.powered then
    -- start sequence
    parallel.waitForAny(function() doStartup() end)
  else
    -- shutdown sequence
    parallel.waitForAny(function() doShutdown() end)
  end
end)
btnPower.bgColor = colors.orange
btnPower.textColor = colors.black
btnPower.hoverColor = colors.gray
manager:add(btnPower)

-- Emergency button (plays emergencyshutdown once)
local btnEmergency = gui.Button(smartPos(4,21), smartSize(40,6), "Emergency", function()
  -- play emergency sound once
  spawn = function(fn) parallel.waitForAny(fn) end
  spawn(function() doEmergencyShutdown() end)
end)
btnEmergency.bgColor = colors.gray
btnEmergency.textColor = colors.orange
btnEmergency.hoverColor = colors.orange
manager:add(btnEmergency)

-- DEMAT button
local btnDemat = gui.Button(smartPos(3,45), smartSize(30,11), "DEMAT", function()
  -- Dematerialise only if powered and not already in flight
  if state.powered and not state.inFlight then
    spawn = function(fn) parallel.waitForAny(fn) end
    spawn(function() doDemat() end)
  end
end)
btnDemat.bgColor = colors.black
btnDemat.textColor = colors.orange
btnDemat.hoverColor = colors.orange
manager:add(btnDemat)

-- LANDING button
local btnLanding = gui.Button(smartPos(32,45), smartSize(32,11), "LANDING", function()
  if state.inFlight then
    spawn = function(fn) parallel.waitForAny(fn) end
    spawn(function() doLanding() end)
  end
end)
btnLanding.bgColor = colors.black
btnLanding.textColor = colors.orange
btnLanding.hoverColor = colors.orange
manager:add(btnLanding)

-- DOOR button (not wired to audio here but kept)
local btnDoor = gui.Button(smartPos(77,46), smartSize(23,11), "DOOR", function()
  -- play open then close quickly
  spawn = function(fn) parallel.waitForAny(fn) end
  spawn(function()
    playOnceFile(FILES.door_open)
    sleep(0.2)
    playOnceFile(FILES.close_door)
  end)
end)
btnDoor.bgColor = colors.black
btnDoor.textColor = colors.orange
btnDoor.hoverColor = colors.orange
manager:add(btnDoor)

-- CLOISTER button (toggle)
local btnCloister = gui.Button(smartPos(44,11), smartSize(56,5), "CLOISTER", function()
  if state.cloisterLoop then stopCloister() else startCloister() end
end)
btnCloister.bgColor = colors.black
btnCloister.textColor = colors.orange
btnCloister.hoverColor = colors.orange
manager:add(btnCloister)

-- BIP error button (toggle)
local btnBip = gui.Button(smartPos(44,16), smartSize(56,5), "bip error", function()
  if state.bipLoop then stopBip() else startBip() end
end)
btnBip.bgColor = colors.black
btnBip.textColor = colors.orange
btnBip.hoverColor = colors.orange
manager:add(btnBip)

-- DENIED FLIGHT button
local btnDenied = gui.Button(smartPos(44,21), smartSize(56,6), "denied flight", function()
  spawn = function(fn) parallel.waitForAny(fn) end
  spawn(function() doDeniedFlight() end)
end)
btnDenied.bgColor = colors.black
btnDenied.textColor = colors.orange
btnDenied.hoverColor = colors.orange
manager:add(btnDenied)

-- Status labels
local lblStatus = gui.Label(smartPos(4,30), "Status")
lblStatus.textColor = colors.orange
manager:add(lblStatus)

local lblArtron = gui.Label(smartPos(4,36), "ARTRON: 123Aeu/photon")
lblArtron.textColor = colors.orange
manager:add(lblArtron)

-- SHORT FLIGHT button (plays once)
local btnShort = gui.Button(smartPos(4, 40), smartSize(30,5), "SHORT FLIGHT", function()
  spawn = function(fn) parallel.waitForAny(fn) end
  spawn(function() doShortFlight() end)
end)
btnShort.bgColor = colors.black
btnShort.textColor = colors.orange
manager:add(btnShort)

-- Background audio loop runners
local function audioManager()
  -- loops for ambiance, flight, cloister and bip
  local function ambFlag() return state.ambianceLoop end
  local function flightFlag() return state.flightLoop end
  local function cloisterFlag() return state.cloisterLoop end
  local function bipFlag() return state.bipLoop end

  -- run four loopers in parallel but return only when state.running becomes false
  while state.running do
    parallel.waitForAny(
      function() loopPlayer(ambFlag, FILES.ambiance) end,
      function() loopPlayer(flightFlag, FILES.tardis_flight_loop) end,
      function() loopPlayer(cloisterFlag, FILES.cloister) end,
      function() loopPlayer(bipFlag, FILES.bip) end,
      function() -- short sleeper to keep the manager responsive when none are active
        while state.running do
          sleep(1)
        end
      end
    )
  end
end

-- Start GUI + audio manager in parallel
parallel.waitForAny(function() manager:run() end, audioManager)

-- Clean exit
state.running = false
print("TARDIS soundboard stopped")
