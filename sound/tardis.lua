-- Artron OS – Type 40: TARDIS Soundbox for ComputerCraft
-- Created by Grok 4
-- Interface: Orange on black GUI with interactive buttons
-- Sounds streamed via shell.run("austream", url) to avoid AUKit/Austream direct issues

local base_url = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/"

local sounds = {
    startup = base_url .. "startup_tardis.wav",
    shutdown = base_url .. "shutdowntardis.wav",
    emergency = base_url .. "emergencyshutdown.wav",
    ambience = base_url .. "ambience%20tardis.wav",
    takeoff = base_url .. "tardistakeoff.wav",
    flight_loop = base_url .. "tardis_flight_loop.wav",
    landing = base_url .. "landing.wav",
    mater = base_url .. "tardismater.wav",
    door_open = base_url .. "door_open.wav",
    door_close = base_url .. "close_door.wav",
    cloister = base_url .. "cloister_ding.wav",
    bip = base_url .. "bip_sound_error_1.wav",
    denied = base_url .. "denied_flight.wav"
}

local durations = {  -- Approximate durations in seconds (assumed values; adjust if known)
    startup = 10,
    shutdown = 10,
    emergency = 15,
    ambience = 30,
    takeoff = 5,
    flight_loop = 15,
    landing = 5,
    mater = 5,
    door_open = 2,
    door_close = 2,
    cloister = 3,
    bip = 1,
    denied = 3
}

-- States for logic
local state = "off"  -- off, idle, flying
local bip_looping = false

-- Command queue for sound manager
local commands = {}

-- Progress variables
local current_duration = 0
local start_time = 0
local timer_id = nil

-- Get screen size
local w, h = term.getSize()

-- Colors
local bg_color = colors.black
local fg_color = colors.orange

-- Button class
local buttons = {}

local function addButton(x, y, width, label, action, section)
    table.insert(buttons, {x = x, y = y, width = width, height = 1, label = label, action = action, section = section})
end

-- Draw button
local function drawButton(btn, inverted)
    local btn_bg = inverted and colors.orange or colors.black
    local btn_fg = inverted and colors.black or colors.orange
    term.setBackgroundColor(btn_bg)
    term.setTextColor(btn_fg)
    term.setCursorPos(btn.x, btn.y)
    term.write(string.rep(" ", btn.width))
    term.setCursorPos(btn.x + 1, btn.y)
    term.write(btn.label)
end

-- Draw all buttons
local function drawButtons()
    for _, btn in ipairs(buttons) do
        drawButton(btn, false)
    end
end

-- Draw title and sections
local function drawGUI()
    term.setBackgroundColor(bg_color)
    term.setTextColor(fg_color)
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Artron OS - Type 40")
    
    -- Section labels
    term.setCursorPos(2, 3)
    term.write("Main")
    term.setCursorPos(2, 6)
    term.write("Flight")
    term.setCursorPos(2, 9)
    term.write("Doors")
    term.setCursorPos(2, 12)
    term.write("Errors")
    
    drawButtons()
    drawProgressBar(0)
end

-- Progress bar at bottom
local function drawProgressBar(progress)
    local bar_width = 20
    local bar_x = math.floor((w - bar_width - 2) / 2)
    local bar_y = h
    term.setCursorPos(bar_x, bar_y)
    term.setBackgroundColor(bg_color)
    term.setTextColor(fg_color)
    local filled = math.floor(progress * bar_width)
    term.write("[")
    term.write(string.rep("#", filled))
    term.write(string.rep("-", bar_width - filled))
    term.write("]")
end

-- Update progress
local function updateProgress()
    if current_duration > 0 then
        local elapsed = os.clock() - start_time
        local prog = elapsed / current_duration
        if prog > 1 then prog = 1 end
        drawProgressBar(prog)
        if prog < 1 then
            timer_id = os.startTimer(0.5)
        else
            current_duration = 0
        end
    end
end

-- Check if click on button
local function handleClick(x, y)
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x < btn.x + btn.width and y == btn.y then
            drawButton(btn, true)
            sleep(0.2)
            drawButton(btn, false)
            btn.action()
            return
        end
    end
end

-- Disable buttons based on state
local function isButtonEnabled(btn)
    if state == "off" then
        return btn.label == "Startup"
    elseif state == "idle" then
        return btn.label ~= "Startup" and btn.label ~= "Materialize"
    elseif state == "flying" then
        return btn.label ~= "Startup" and btn.label ~= "Takeoff"
    end
    return true  -- Alerts and doors always
end

-- UI loop
local function uiLoop()
    drawGUI()
    while true do
        local ev = {os.pullEvent()}
        if ev[1] == "mouse_click" then
            local _, mx, my = ev[2], ev[3], ev[4]
            handleClick(mx, my)
        elseif ev[1] == "timer" and ev[2] == timer_id then
            updateProgress()
        elseif ev[1] == "start_play_clip" then
            start_time = os.clock()
            current_duration = ev[3]
            updateProgress()
            timer_id = os.startTimer(0.5)
        end
        -- Redraw if needed, but minimal
    end
end

-- Sound manager loop
local function soundManager()
    local current_loop_url = nil
    while true do
        if #commands > 0 then
            local cmd = table.remove(commands, 1)
            if cmd.type == "stop" then
                current_loop_url = nil
            elseif cmd.type == "play_single" then
                current_loop_url = nil
                os.queueEvent("start_play_clip", cmd.url, cmd.duration)
                shell.run("austream", cmd.url)
            elseif cmd.type == "start_loop" then
                current_loop_url = cmd.url
                while current_loop_url == cmd.url and #commands == 0 do  -- Stop if new commands queued
                    os.queueEvent("start_play_clip", cmd.url, cmd.duration)
                    shell.run("austream", cmd.url)
                end
                current_loop_url = nil
            end
        else
            sleep(0.1)
        end
    end
end

-- Define buttons and actions

-- Main
addButton(2, 4, 12, "Startup", function()
    if state == "off" then
        table.insert(commands, {type = "play_single", url = sounds.startup, duration = durations.startup})
        table.insert(commands, {type = "start_loop", url = sounds.ambience, duration = durations.ambience})
        state = "idle"
    end
end)
addButton(15, 4, 12, "Shutdown", function()
    if state ~= "off" then
        table.insert(commands, {type = "stop"})
        table.insert(commands, {type = "play_single", url = sounds.shutdown, duration = durations.shutdown})
        state = "off"
        bip_looping = false
    end
end)
addButton(28, 4, 12, "Emergency", function()
    if state ~= "off" then
        table.insert(commands, {type = "stop"})
        table.insert(commands, {type = "play_single", url = sounds.emergency, duration = durations.emergency})
        state = "off"
        bip_looping = false
    end
end)

-- Flight
addButton(2, 7, 12, "Takeoff", function()
    if state == "idle" then
        table.insert(commands, {type = "stop"})
        table.insert(commands, {type = "play_single", url = sounds.takeoff, duration = durations.takeoff})
        table.insert(commands, {type = "start_loop", url = sounds.flight_loop, duration = durations.flight_loop})
        state = "flying"
    end
end)
addButton(15, 7, 12, "Materialize", function()
    if state == "flying" then
        table.insert(commands, {type = "stop"})
        local mat_sound = math.random() < 0.5 and sounds.landing or sounds.mater
        local mat_dur = math.random() < 0.5 and durations.landing or durations.mater
        table.insert(commands, {type = "play_single", url = mat_sound, duration = mat_dur})
        table.insert(commands, {type = "start_loop", url = sounds.ambience, duration = durations.ambience})
        state = "idle"
    end
end)

-- Doors
addButton(2, 10, 12, "Open", function()
    table.insert(commands, {type = "play_single", url = sounds.door_open, duration = durations.door_open})
end)
addButton(15, 10, 12, "Close", function()
    table.insert(commands, {type = "play_single", url = sounds.door_close, duration = durations.door_close})
end)

-- Errors
addButton(2, 13, 12, "Cloister Ding", function()
    table.insert(commands, {type = "play_single", url = sounds.cloister, duration = durations.cloister})
end)
addButton(15, 13, 12, "Bip Sound", function()
    if bip_looping then
        table.insert(commands, {type = "stop"})
        bip_looping = false
    else
        table.insert(commands, {type = "start_loop", url = sounds.bip, duration = durations.bip})
        bip_looping = true
    end
end)
addButton(28, 13, 12, "Denied Flight", function()
    table.insert(commands, {type = "play_single", url = sounds.denied, duration = durations.denied})
end)

-- Run in parallel
parallel.waitForAny(uiLoop, soundManager)
