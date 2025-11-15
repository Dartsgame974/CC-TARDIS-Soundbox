-- TARDIS Soundbox Script for ComputerCraft
-- Requires AUKit library installed as "aukit"
-- Assume speaker peripheral attached

local aukit = require "aukit"
local speaker = peripheral.find("speaker")
if not speaker then error("No speaker found") end

local base_url = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/"

local sounds = {
  startup = "startup_tardis.wav",
  shutdown = "shutdowntardis.wav",
  emergency = "emergencyshutdown.wav",
  door_open = "door_open.wav",
  close_door = "close_door.wav",
  takeoff = "tardistakeoff.wav",
  depart = "depart_tardis.wav",
  flight_loop = "tardis_flight_loop.wav",
  short_flight = "short_flight.wav",
  landing = "landing.wav",
  mater = "tardismater.wav",
  cloister = "cloister_ding.wav",
  bip = "bip_sound_error_1.wav",
  denied = "denied_flight.wav",
  ambiance = "ambience.wav"  -- Renamed as per note
}

local function get_url(sound)
  return base_url .. sounds[sound]
end

-- Global states
local current_background_url = nil
local previous_background_url = nil
local current_foreground_url = nil
local is_on = false
local is_error = false
local shutdown_count = 0

-- Create background source function
local function create_background_source()
  local current_url = ""
  local handle = nil
  local lines = nil
  local stream = nil

  local function reset_stream()
    if handle then handle.close() end
    handle = http.get(current_background_url, nil, {binary = true})
    if not handle then error("Failed to download background audio") end
    lines = function() return handle.read(48000) end
    stream = aukit.stream.wav(lines)
  end

  return function()
    if current_background_url == nil then return nil end
    if current_background_url ~= current_url then
      current_url = current_background_url
      reset_stream()
    end
    local chunk = stream()
    if chunk then return chunk end
    reset_stream()
    return stream()
  end
end

-- Create foreground source function
local function create_foreground_source()
  local current_url = ""
  local handle = nil
  local lines = nil
  local stream = nil

  local function reset_stream()
    if handle then handle.close() end
    handle = http.get(current_foreground_url, nil, {binary = true})
    if not handle then error("Failed to download foreground audio") end
    lines = function() return handle.read(48000) end
    stream = aukit.stream.wav(lines)
  end

  return function()
    if current_foreground_url == nil then return nil end
    if current_foreground_url ~= current_url then
      current_url = current_foreground_url
      reset_stream()
    end
    local chunk = stream()
    if chunk then return chunk end
    current_url = ""
    current_foreground_url = nil
    if handle then handle.close() end
    handle = nil
    stream = nil
    return nil
  end
end

-- Callback for playing mixed samples to speaker
local function callback(samples)
  local buffer = {}
  for i = 1, #samples do
    local s = samples[i]
    buffer[i] = math.floor(s * 127 + 0.5)
  end
  speaker.playAudio(buffer)
  os.pullEvent("speaker_audio_empty")
end

-- Playback function
local function playback()
  aukit.play(callback, nil, 1.0, create_background_source(), create_foreground_source())
end

-- Main UI and logic function
local function main()
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()

  local buttons = {
    {label = "Startup", action = function()
      if not is_on then
        is_on = true
        current_foreground_url = get_url("startup")
        current_background_url = get_url("ambiance")
        redstone.setOutput("bottom", true)
      end
    end},
    {label = "Shutdown", action = function()
      if is_error then
        shutdown_count = shutdown_count + 1
        if shutdown_count == 3 then
          is_error = false
          shutdown_count = 0
          current_background_url = previous_background_url
        end
      else
        if is_on then
          is_on = false
          current_foreground_url = get_url("shutdown")
          current_background_url = nil
          redstone.setOutput("bottom", false)
        end
      end
    end},
    {label = "Emergency Shutdown", action = function()
      current_foreground_url = get_url("emergency")
      current_background_url = nil
      redstone.setOutput("bottom", false)
      is_on = false
      is_error = false
      shutdown_count = 0
    end},
    {label = "Takeoff", action = function()
      if is_on then
        current_foreground_url = get_url("takeoff")
        current_background_url = get_url("flight_loop")
      end
    end},
    {label = "Depart", action = function()
      if is_on then
        current_foreground_url = get_url("depart")
        current_background_url = get_url("flight_loop")
      end
    end},
    {label = "Short Flight", action = function()
      current_foreground_url = get_url("short_flight")
    end},
    {label = "Materialize", action = function()
      if is_on then
        current_foreground_url = get_url(math.random() < 0.5 and "landing" or "mater")
        current_background_url = get_url("ambiance")
      end
    end},
    {label = "Open Door", action = function()
      current_foreground_url = get_url("door_open")
    end},
    {label = "Close Door", action = function()
      current_foreground_url = get_url("close_door")
    end},
    {label = "Denied Flight", action = function()
      current_foreground_url = get_url("denied")
    end},
  }

  local button_width = 20
  local start_y = math.floor((h - #buttons) / 2) + 1
  local start_x = math.floor((w - button_width) / 2) + 1
  local button_positions = {}

  for i, btn in ipairs(buttons) do
    local y = start_y + i - 1
    term.setCursorPos(start_x, y)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.orange)
    local label_len = #btn.label
    local padding_left = math.floor((button_width - label_len) / 2)
    local padding_right = button_width - label_len - padding_left
    term.write(string.rep(" ", padding_left) .. btn.label .. string.rep(" ", padding_right))
    button_positions[i] = {x = start_x, y = y, width = button_width, btn = btn}
  end

  -- Random error timer (every hour, 10% chance)
  local probability_per_hour = 0.1
  local timer_id = os.startTimer(3600)

  while true do
    local event, p1, p2, p3 = os.pullEvent()
    if event == "mouse_click" then
      local click_x, click_y = p2, p3
      for _, pos in ipairs(button_positions) do
        if click_x >= pos.x and click_x < pos.x + pos.width and click_y == pos.y then
          -- Press effect (change to yellow background, black text)
          term.setCursorPos(pos.x, pos.y)
          term.setBackgroundColor(colors.yellow)
          term.setTextColor(colors.black)
          local label_len = #pos.btn.label
          local padding_left = math.floor((button_width - label_len) / 2)
          local padding_right = button_width - label_len - padding_left
          term.write(string.rep(" ", padding_left) .. pos.btn.label .. string.rep(" ", padding_right))
          os.sleep(0.2)
          -- Reset
          term.setCursorPos(pos.x, pos.y)
          term.setBackgroundColor(colors.black)
          term.setTextColor(colors.orange)
          term.write(string.rep(" ", padding_left) .. pos.btn.label .. string.rep(" ", padding_right))
          -- Execute action
          pos.btn.action()
          break
        end
      end
    elseif event == "timer" and p1 == timer_id then
      if not is_error and math.random() < probability_per_hour then
        is_error = true
        previous_background_url = current_background_url
        local error_sound = math.random() < 0.5 and "cloister" or "bip"
        current_background_url = get_url(error_sound)
      end
      timer_id = os.startTimer(3600)
    end
  end
end

parallel.waitForAll(main, playback)
