-- TARDIS Soundboard for ComputerCraft/CC:Tweaked
-- Uses AUKit for streaming audio from GitHub
-- Interface in terminal with mouse support
-- Theme: Orange-based

local base_url = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/sound/"

-- Download AUKit if not present
if not fs.exists("aukit.lua") then
    shell.run("wget https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua")
end

local aukit = require("aukit")

-- Find all speakers
local speakers = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "speaker" then
        table.insert(speakers, peripheral.wrap(name))
    end
end

if #speakers == 0 then
    error("No speakers connected!")
end

-- Loop display names
local loop_names = {
    ambiance = "AMBIANCE",
    tardis_flight_loop = "FLIGHT",
    cloister = "CLOISTER",
    bip_sound_error_1 = "BIP"
}

-- Global state
local powered = false
local current_loop = nil
local pending_actions = {}

-- Function to play a stream
local function play_stream(sound)
    local url = base_url .. sound .. ".wav"
    local resp = http.get(url, nil, true)
    if not resp then
        print("Failed to stream " .. url)
        return
    end
    local reader = function()
        local data = resp.read(48000)
        if data == "" then data = nil end
        return data
    end
    local stream = aukit.stream.wav(reader)
    aukit.play(stream, table.unpack(speakers))
    resp.close()
end

-- Audio loop
local function audio_loop()
    while true do
        while #pending_actions > 0 do
            local action = table.remove(pending_actions, 1)
            if action.type == "play" then
                play_stream(action.sound)
            elseif action.type == "set_loop" then
                current_loop = action.loop
            end
        end
        if current_loop then
            play_stream(current_loop)
        else
            os.pullEvent("audio_action")
        end
    end
end

-- Play temporary sound (interrupt loop if active)
local function play_temp(sound)
    if not powered then return end
    local saved = current_loop
    if saved then
        table.insert(pending_actions, {type = "set_loop", loop = nil})
        table.insert(pending_actions, {type = "play", sound = sound})
        table.insert(pending_actions, {type = "set_loop", loop = saved})
    else
        table.insert(pending_actions, {type = "play", sound = sound})
    end
    os.queueEvent("audio_action")
end

-- Logic functions
local function power_on()
    if powered then return end
    powered = true
    table.insert(pending_actions, {type = "play", sound = "startup_tardis"})
    table.insert(pending_actions, {type = "set_loop", loop = "ambiance"})
    os.queueEvent("audio_action")
end

local function power_off()
    if not powered then return end
    powered = false
    table.insert(pending_actions, {type = "set_loop", loop = nil})
    table.insert(pending_actions, {type = "play", sound = "shutdowntardis"})
    os.queueEvent("audio_action")
end

local function takeoff()
    if not powered then return end
    table.insert(pending_actions, {type = "set_loop", loop = nil})
    table.insert(pending_actions, {type = "play", sound = "tardistakeoff"})
    table.insert(pending_actions, {type = "set_loop", loop = "tardis_flight_loop"})
    os.queueEvent("audio_action")
end

local function landing()
    if not powered then return end
    table.insert(pending_actions, {type = "set_loop", loop = nil})
    table.insert(pending_actions, {type = "play", sound = "landing"})
    table.insert(pending_actions, {type = "set_loop", loop = "ambiance"})
    os.queueEvent("audio_action")
end

local function short_flight_func()
    play_temp("short_flight")
end

local function denied()
    play_temp("denied_flight")
end

local function cloister_toggle()
    if not powered then return end
    if current_loop == "cloister" then
        current_loop = "ambiance"
    else
        current_loop = "cloister"
    end
    os.queueEvent("audio_action")
end

local function bip_toggle()
    if not powered then return end
    if current_loop == "bip_sound_error_1" then
        current_loop = "ambiance"
    else
        current_loop = "bip_sound_error_1"
    end
    os.queueEvent("audio_action")
end

local function door_open()
    play_temp("door_open")
end

local function door_close()
    play_temp("close_door")
end

-- Interface loop
local function interface_loop()
    local button_defs = {
        {text = "POWER ON", action = power_on, is_active = function() return not powered end, can_click = function() return not powered end},
        {text = "POWER OFF", action = power_off, is_active = function() return powered end, can_click = function() return powered end},
        {text = "TAKEOFF", action = takeoff, is_active = function() return powered end, can_click = function() return powered end},
        {text = "LANDING", action = landing, is_active = function() return powered end, can_click = function() return powered end},
        {text = "SHORT FLIGHT", action = short_flight_func, is_active = function() return powered end, can_click = function() return powered end},
        {text = "DENIED", action = denied, is_active = function() return powered end, can_click = function() return powered end},
        {text = "CLOISTER", action = cloister_toggle, is_active = function() return powered and current_loop == "cloister" end, can_click = function() return powered end},
        {text = "ERROR BIP", action = bip_toggle, is_active = function() return powered and current_loop == "bip_sound_error_1" end, can_click = function() return powered end},
        {text = "OPEN DOOR", action = door_open, is_active = function() return powered end, can_click = function() return powered end},
        {text = "CLOSE DOOR", action = door_close, is_active = function() return powered end, can_click = function() return powered end},
    }

    local function redraw()
        term.setBackgroundColor(colors.black)
        term.clear()
        local w, h = term.getSize()
        -- Title
        local title = "ARTRON OS TYPE 40"
        term.setCursorPos(math.floor((w - #title) / 2) + 1, 1)
        term.setTextColor(colors.orange)
        term.write(title)
        -- Status
        term.setCursorPos(2, 3)
        term.write("TARDIS Status: " .. (powered and "ACTIVE" or "INACTIVE"))
        term.setCursorPos(2, 4)
        term.write("Speakers Connected: " .. #speakers)
        term.setCursorPos(2, 5)
        term.write("Active Loop: " .. (loop_names[current_loop] or "None"))
        -- Calculate max left width
        local max_left_w = 0
        for i = 1, 5 do
            local left = button_defs[2 * i - 1]
            max_left_w = math.max(max_left_w, #left.text + 2)
        end
        local left_x = 2
        local right_x = left_x + max_left_w + 2
        local start_y = 7
        for i = 1, 5 do
            local y = start_y + i - 1
            -- Left button
            local left = button_defs[2 * i - 1]
            term.setCursorPos(left_x, y)
            if left.is_active() then
                term.setBackgroundColor(colors.orange)
                term.setTextColor(colors.white)
            else
                term.setBackgroundColor(colors.brown)
                term.setTextColor(colors.orange)
            end
            local btn_text = "[" .. left.text .. "]"
            term.write(btn_text)
            left.curr_x = left_x
            left.curr_y = y
            left.curr_w = #btn_text
            left.curr_h = 1
            -- Right button
            local right = button_defs[2 * i]
            term.setCursorPos(right_x, y)
            if right.is_active() then
                term.setBackgroundColor(colors.orange)
                term.setTextColor(colors.white)
            else
                term.setBackgroundColor(colors.brown)
                term.setTextColor(colors.orange)
            end
            btn_text = "[" .. right.text .. "]"
            term.write(btn_text)
            right.curr_x = right_x
            right.curr_y = y
            right.curr_w = #btn_text
            right.curr_h = 1
        end
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    while true do
        redraw()
        while true do
            local event, btn, x, y = os.pullEvent()
            if event == "term_resize" then
                break
            elseif event == "mouse_click" then
                local clicked = false
                for _, b in ipairs(button_defs) do
                    if x >= b.curr_x and x < b.curr_x + b.curr_w and y >= b.curr_y and y < b.curr_y + b.curr_h then
                        if b.can_click() then
                            b.action()
                            clicked = true
                        end
                        break
                    end
                end
                if clicked then
                    break
                end
            end
        end
    end
end

-- Run in parallel
parallel.waitForAll(audio_loop, interface_loop)
