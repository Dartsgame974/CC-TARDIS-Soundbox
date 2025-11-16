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

-- Find chat_box
local chat_box = peripheral.find("chatBox")

-- Loop display names
local loop_names = {
    ambiance = "AMBIANCE",
    tardis_flight_loop = "FLIGHT",
    cloister_ding = "CLOISTER",
    bip_sound_error_1 = "BIP"
}

-- Global state
local powered = false
local door_state = "closed"  -- initial door closed
local current_loop = nil
local pending_actions = {}

-- Function to update redstone
local function update_redstone()
    rs.setOutput("bottom", powered)
end

-- Function to send chat message if chat_box connected
local function send_chat(message)
    if chat_box then
        chat_box.sendMessage("&e" .. message)
    end
end

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
local function power_toggle()
    if powered then
        powered = false
        table.insert(pending_actions, {type = "set_loop", loop = nil})
        table.insert(pending_actions, {type = "play", sound = "shutdowntardis"})
        os.queueEvent("audio_action")
    else
        powered = true
        table.insert(pending_actions, {type = "play", sound = "startup_tardis"})
        table.insert(pending_actions, {type = "set_loop", loop = "ambiance"})
        os.queueEvent("audio_action")
    end
    update_redstone()
end

local function takeoff()
    if not powered then return end
    send_chat("TARDIS is taking off!")
    table.insert(pending_actions, {type = "set_loop", loop = nil})
    table.insert(pending_actions, {type = "play", sound = "tardistakeoff"})
    table.insert(pending_actions, {type = "set_loop", loop = "tardis_flight_loop"})
    os.queueEvent("audio_action")
end

local function landing()
    if not powered then return end
    send_chat("TARDIS is landing!")
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
    if current_loop == "cloister_ding" then
        current_loop = "ambiance"
    else
        current_loop = "cloister_ding"
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

local function door_toggle()
    if not powered then return end
    if door_state == "closed" then
        play_temp("door_open")
        door_state = "open"
    else
        play_temp("close_door")
        door_state = "closed"
    end
end

-- Interface loop
local function interface_loop()
    local button_defs = {
        {text_func = function() return powered and "POWER OFF" or "POWER ON" end, action = power_toggle, is_active = function() return true end, can_click = function() return true end},
        {text = "TAKEOFF", action = takeoff, is_active = function() return powered end, can_click = function() return powered end},
        {text = "LANDING", action = landing, is_active = function() return powered end, can_click = function() return powered end},
        {text = "SHORT FLIGHT", action = short_flight_func, is_active = function() return powered end, can_click = function() return powered end},
        {text = "DENIED", action = denied, is_active = function() return powered end, can_click = function() return powered end},
        {text = "CLOISTER", action = cloister_toggle, is_active = function() return powered and current_loop == "cloister_ding" end, can_click = function() return powered end},
        {text = "ERROR BIP", action = bip_toggle, is_active = function() return powered and current_loop == "bip_sound_error_1" end, can_click = function() return powered end},
        {text_func = function() return door_state == "closed" and "OPEN DOOR" or "CLOSE DOOR" end, action = door_toggle, is_active = function() return powered end, can_click = function() return powered end},
    }

    local function get_status_text()
        local status = powered and "ACTIVE" or "INACTIVE"
        if powered and current_loop == "tardis_flight_loop" then
            status = status .. " (IN FLIGHT)"
        end
        return status
    end

    local function redraw()
        term.setBackgroundColor(colors.black)
        term.clear()
        local w, h = term.getSize()
        -- Title to left
        term.setCursorPos(1, 1)
        term.setTextColor(colors.orange)
        term.write("ARTRON OS TYPE 40")
        -- Buttons at top, in two columns
        local max_left_w = 0
        for i = 1, 4 do
            local left_text = button_defs[2 * i - 1].text or button_defs[2 * i - 1].text_func()
            max_left_w = math.max(max_left_w, #left_text + 2)
        end
        local left_x = math.floor((w - (max_left_w * 2 + 4)) / 2) + 1  -- center the two columns
        local right_x = left_x + max_left_w + 2
        local start_y = 3
        for i = 1, 4 do
            local y = start_y + i - 1
            -- Left button
            local left = button_defs[2 * i - 1]
            local btn_text = left.text or left.text_func()
            term.setCursorPos(left_x, y)
            if left.is_active() then
                term.setBackgroundColor(colors.orange)
                term.setTextColor(colors.white)
            else
                term.setBackgroundColor(colors.brown)
                term.setTextColor(colors.orange)
            end
            term.write("[" .. btn_text .. "]")
            left.curr_x = left_x
            left.curr_y = y
            left.curr_w = #btn_text + 2
            left.curr_h = 1
            -- Right button
            local right = button_defs[2 * i]
            local btn_text_right = right.text or right.text_func()
            term.setCursorPos(right_x, y)
            if right.is_active() then
                term.setBackgroundColor(colors.orange)
                term.setTextColor(colors.white)
            else
                term.setBackgroundColor(colors.brown)
                term.setTextColor(colors.orange)
            end
            term.write("[" .. btn_text_right .. "]")
            right.curr_x = right_x
            right.curr_y = y
            right.curr_w = #btn_text_right + 2
            right.curr_h = 1
        end
        -- Status at bottom, centered
        local status_lines = {
            "TARDIS Status: " .. get_status_text(),
            "Speakers Connected: " .. #speakers,
            "Chat Box: " .. (chat_box and "Connected" or "Not Connected"),
            "Active Loop: " .. (loop_names[current_loop] or "None")
        }
        local status_start_y = h - #status_lines
        for i, line in ipairs(status_lines) do
            term.setCursorPos(math.floor((w - #line) / 2) + 1, status_start_y + i - 1)
            term.setTextColor(colors.orange)
            term.setBackgroundColor(colors.black)
            term.write(line)
        end
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    -- Initial redstone
    update_redstone()

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
