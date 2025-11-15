-- TARDIS Soundboard for ComputerCraft/CC:Tweaked
-- Streams audio using AUKit, terminal interface in orange theme

-- Download AUKit if not present
if not fs.exists("aukit.lua") then
    shell.run("wget https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua")
end

local aukit = require "aukit"

-- Base URL for sounds
local base_url = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/sound/"

-- Sound filenames
local sound_files = {
    startup = "startup_tardis",
    ambiance = "ambiance",
    flight = "tardis_flight_loop",
    bip = "bip_sound_error_1",
    cloister = "cloister",
    takeoff = "tardistakeoff",
    landing = "landing",
    short_flight = "short_flight",
    denied = "denied_flight",
    shutdown = "shutdowntardis",
    open_door = "door_open",
    close_door = "close_door"
}

-- Global states
local powered = false
local current_loop = nil
local speakers = {peripheral.find("speaker")}
if #speakers == 0 then
    print("No speaker found!")
    return
end

-- Function to get URL for a sound
local function get_url(name)
    return base_url .. sound_files[name] .. ".wav"
end

-- Interruptible stream play function
local function play_stream(url)
    local response = http.get(url, nil, true)
    if not response then
        return false
    end
    local audio = aukit.stream.wav(function()
        return response.read(48000)
    end)
    for chunk in audio do
        for _, speaker in ipairs(speakers) do
            local played = false
            while not played do
                played = speaker.playAudio(chunk)
                if not played then
                    local ev = os.pullEvent()
                    if ev == "_stop_audio" then
                        response.close()
                        return false
                    elseif ev == "speaker_audio_empty" then
                        -- Continue to retry playAudio
                    end
                end
            end
        end
    end
    response.close()
    return true
end

-- Stop current audio
local function stop_current()
    if current_loop then
        current_loop = nil
        os.queueEvent("_stop_audio")
        os.queueEvent("_redraw")
    end
end

-- Play a single sound
local function play_single(sound, callback)
    stop_current()
    local completed = play_stream(get_url(sound))
    if completed and callback then
        callback()
    end
end

-- Start a loop
local function start_loop(loop_name)
    stop_current()
    current_loop = loop_name
    os.queueEvent("_redraw")
    while current_loop == loop_name do
        local completed = play_stream(get_url(loop_name))
        if not completed then
            break
        end
    end
end

-- Audio loop
local function audio_manager()
    while true do
        local ev, p1, p2 = os.pullEvent()
        if ev == "_play_single" then
            play_single(p1, p2)
        elseif ev == "_start_loop" then
            start_loop(p1)
        elseif ev == "_stop" then
            stop_current()
        end
    end
end

-- Draw interface
local function draw_interface()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Title
    term.setTextColor(colors.orange)
    term.setCursorPos(math.floor((w - #("ARTRON OS TYPE 40")) / 2) + 1, 1)
    term.write("ARTRON OS TYPE 40")
    
    -- Status
    term.setCursorPos(1, 3)
    term.write("TARDIS Status: " .. (powered and "ACTIVE" or "INACTIVE"))
    term.setCursorPos(1, 4)
    term.write("Speakers Connected: " .. #speakers)
    term.setCursorPos(1, 5)
    term.write("Active Loop: " .. (current_loop and current_loop:upper() or "None"))
    
    -- Buttons
    local buttons = {
        {label = "POWER ON", x = 2, y = 7, w = 12, is_active = function() return not powered end, action = function()
            os.queueEvent("_play_single", "startup", function()
                powered = true
                os.queueEvent("_start_loop", "ambiance")
                os.queueEvent("_redraw")
            end)
        end},
        {label = "POWER OFF", x = 20, y = 7, w = 12, is_active = function() return powered end, action = function()
            os.queueEvent("_play_single", "shutdown", function()
                powered = false
                os.queueEvent("_redraw")
            end)
        end},
        {label = "TAKEOFF", x = 2, y = 9, w = 12, is_active = function() return powered end, action = function()
            os.queueEvent("_play_single", "takeoff", function()
                os.queueEvent("_start_loop", "flight")
                os.queueEvent("_redraw")
            end)
        end},
        {label = "LANDING", x = 20, y = 9, w = 12, is_active = function() return powered end, action = function()
            os.queueEvent("_play_single", "landing", function()
                os.queueEvent("_start_loop", "ambiance")
                os.queueEvent("_redraw")
            end)
        end},
        {label = "SHORT FLIGHT", x = 2, y = 11, w = 14, is_active = function() return powered end, action = function()
            local save = current_loop
            os.queueEvent("_play_single", "short_flight", function()
                if save then
                    os.queueEvent("_start_loop", save)
                end
                os.queueEvent("_redraw")
            end)
        end},
        {label = "DENIED", x = 20, y = 11, w = 12, is_active = function() return powered end, action = function()
            local save = current_loop
            os.queueEvent("_play_single", "denied", function()
                if save then
                    os.queueEvent("_start_loop", save)
                end
                os.queueEvent("_redraw")
            end)
        end},
        {label = "CLOISTER", x = 2, y = 13, w = 12, is_active = function() return powered end, action = function()
            if current_loop == "cloister" then
                os.queueEvent("_start_loop", "ambiance")
            else
                os.queueEvent("_start_loop", "cloister")
            end
        end},
        {label = "ERROR BIP", x = 20, y = 13, w = 12, is_active = function() return powered end, action = function()
            if current_loop == "bip" then
                os.queueEvent("_start_loop", "ambiance")
            else
                os.queueEvent("_start_loop", "bip")
            end
        end},
        {label = "OPEN DOOR", x = 2, y = 15, w = 12, is_active = function() return powered end, action = function()
            local save = current_loop
            os.queueEvent("_play_single", "open_door", function()
                if save then
                    os.queueEvent("_start_loop", save)
                end
                os.queueEvent("_redraw")
            end)
        end},
        {label = "CLOSE DOOR", x = 20, y = 15, w = 12, is_active = function() return powered end, action = function()
            local save = current_loop
            os.queueEvent("_play_single", "close_door", function()
                if save then
                    os.queueEvent("_start_loop", save)
                end
                os.queueEvent("_redraw")
            end)
        end}
    }
    
    -- Draw buttons and record bounds
    for _, b in ipairs(buttons) do
        term.setCursorPos(b.x, b.y)
        if b.is_active() then
            term.setBackgroundColor(colors.orange)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.brown)
            term.setTextColor(colors.orange)
        end
        local text = "[" .. b.label .. "]"
        term.write(text)
        b.left = b.x
        b.right = b.x + #text - 1
    end
    
    return buttons
end

-- Interface loop
local function interface_manager()
    local buttons = draw_interface()
    while true do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "term_resize" or ev == "_redraw" then
            buttons = draw_interface()
        elseif ev == "mouse_click" then
            local button_side, mx, my = p1, p2, p3
            for _, b in ipairs(buttons) do
                if my == b.y and mx >= b.left and mx <= b.right and b.is_active() then
                    b.action()
                    break
                end
            end
        end
    end
end

-- Run in parallel
parallel.waitForAny(audio_manager, interface_manager)
