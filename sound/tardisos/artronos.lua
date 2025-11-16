-- TARDIS Soundboard for ComputerCraft/CC:Tweaked
-- With dual interface: full UI on terminal, compact UI on external monitor
-- Uses AUKit for streaming audio from GitHub

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

-- External monitor
local monitor = peripheral.find("monitor")
if monitor then monitor.setTextScale(0.5) end

-- Loop display names
local loop_names = {
    ambiance = "AMBIANCE",
    tardis_flight_loop = "FLIGHT",
    cloister_ding = "CLOISTER",
    bip_sound_error_1 = "BIP"
}

-- Global state
local powered = false
local door_state = "closed"
local current_loop = nil
local pending_actions = {}

-- Update redstone
local function update_redstone()
    rs.setOutput("bottom", powered)
end

-- Send chat message
local function send_chat(message)
    if chat_box then
        chat_box.sendMessage("&e" .. message)
    end
end

-- Stream a sound
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

-- Play temporary sound
local function play_temp(sound)
    if not powered then return end
    local saved = current_loop
    if saved then
        table.insert(pending_actions, { type="set_loop", loop=nil })
        table.insert(pending_actions, { type="play", sound=sound })
        table.insert(pending_actions, { type="set_loop", loop=saved })
    else
        table.insert(pending_actions, { type="play", sound=sound })
    end
    os.queueEvent("audio_action")
end

-- Logic functions
local function power_toggle()
    if powered then
        powered = false
        table.insert(pending_actions, {type="set_loop", loop=nil})
        table.insert(pending_actions, {type="play", sound="shutdowntardis"})
    else
        powered = true
        table.insert(pending_actions, {type="play", sound="startup_tardis"})
        table.insert(pending_actions, {type="set_loop", loop="ambiance"})
    end
    os.queueEvent("audio_action")
    update_redstone()
end

local function takeoff()
    if not powered then return end
    send_chat("TARDIS is taking off!")
    table.insert(pending_actions, {type="set_loop", loop=nil})
    table.insert(pending_actions, {type="play", sound="tardistakeoff"})
    table.insert(pending_actions, {type="set_loop", loop="tardis_flight_loop"})
    os.queueEvent("audio_action")
end

local function landing()
    if not powered then return end
    send_chat("TARDIS is landing!")
    table.insert(pending_actions, {type="set_loop", loop=nil})
    table.insert(pending_actions, {type="play", sound="landing"})
    table.insert(pending_actions, {type="set_loop", loop="ambiance"})
    os.queueEvent("audio_action")
end

local function short_flight_func() play_temp("short_flight") end
local function denied()             play_temp("denied_flight") end

local function cloister_toggle()
    if not powered then return end
    if current_loop == "cloister_ding" then current_loop = "ambiance"
    else current_loop = "cloister_ding" end
    os.queueEvent("audio_action")
end

local function bip_toggle()
    if not powered then return end
    if current_loop == "bip_sound_error_1" then current_loop = "ambiance"
    else current_loop = "bip_sound_error_1" end
    os.queueEvent("audio_action")
end

local function door_toggle()
    if not powered then return end
    if door_state == "closed" then play_temp("door_open") door_state = "open"
    else play_temp("close_door") door_state = "closed" end
end

---------------------------------------------------------------------
-- FULL INTERFACE (terminal)
---------------------------------------------------------------------
local function full_interface_loop()
    local display = term
    local is_monitor = false
    local touch_event = "mouse_click"

    local button_defs = {
        {id="power", text_func=function() return powered and "POWER OFF" or "POWER ON" end, action=power_toggle,
         is_active=function() return true end, can_click=function() return true end},

        {id="takeoff", text="TAKEOFF", action=takeoff,
         is_active=function() return powered and current_loop ~= "tardis_flight_loop" end,
         can_click=function() return powered and current_loop ~= "tardis_flight_loop" end},

        {id="landing", text="LANDING", action=landing,
         is_active=function() return powered and current_loop == "tardis_flight_loop" end,
         can_click=function() return powered and current_loop == "tardis_flight_loop" end},

        {id="short_flight", text="SHORT FLIGHT", action=short_flight_func,
         is_active=function() return powered end, can_click=function() return powered end},

        {id="denied", text="DENIED", action=denied,
         is_active=function() return powered end, can_click=function() return powered end},

        {id="cloister", text="CLOISTER", action=cloister_toggle,
         is_active=function() return powered and current_loop == "cloister_ding" end,
         can_click=function() return powered end},

        {id="bip", text="ERROR BIP", action=bip_toggle,
         is_active=function() return powered and current_loop == "bip_sound_error_1" end,
         can_click=function() return powered end},

        {id="door", text_func=function() return door_state=="closed" and "OPEN DOOR" or "CLOSE DOOR" end, action=door_toggle,
         is_active=function() return powered end, can_click=function() return powered end},
    }

    local function get_status_text()
        local status = powered and "ACTIVE" or "INACTIVE"
        if powered and current_loop == "tardis_flight_loop" then
            status = status .. " (IN FLIGHT)"
        end
        return status
    end

    local function redraw()
        display.setBackgroundColor(colors.black)
        display.clear()
        local w, h = display.getSize()

        display.setCursorPos(1,1)
        display.setTextColor(colors.orange)
        display.write("ARTRON OS TYPE 40")

        display.setCursorPos(1,2)
        display.write(string.rep("-", w))

        local other_buttons = {button_defs[4],button_defs[5],button_defs[6],button_defs[7],button_defs[8]}
        local max_other_w = 0
        for _,b in ipairs(other_buttons) do
            local t = b.text or b.text_func()
            max_other_w = math.max(max_other_w, #t+2)
        end
        local other_x = w - max_other_w +1
        local other_y = 3
        for i,b in ipairs(other_buttons) do
            local y = other_y + i -1
            local txt = b.text or b.text_func()
            display.setCursorPos(other_x, y)
            if b.is_active() then
                display.setBackgroundColor(colors.orange)
                display.setTextColor(colors.white)
            else
                display.setBackgroundColor(colors.brown)
                display.setTextColor(colors.orange)
            end
            display.write("["..txt.."]")
            b.curr_x = other_x
            b.curr_y = y
            b.curr_w = #txt+2
            b.curr_h = 1
        end

        local power_b = button_defs[1]
        local power_t = power_b.text_func()
        display.setCursorPos(1,h)
        if power_b.is_active() then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write("["..power_t.."]")
        power_b.curr_x = 1
        power_b.curr_y = h
        power_b.curr_w = #power_t+2
        power_b.curr_h = 1

        local takeoff_b = button_defs[2]
        local landing_b = button_defs[3]
        local is_in_flight = current_loop == "tardis_flight_loop"
        local flight_text = "FLIGHT"
        local takeoff_t = takeoff_b.text
        local landing_t = landing_b.text

        local total_width = #takeoff_t+2 + #flight_text+2 + #landing_t+2 +4
        local flight_start_x = math.floor((w - total_width)/2)+1

        display.setCursorPos(flight_start_x, h)
        if takeoff_b.is_active() then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write("["..takeoff_t.."]")
        takeoff_b.curr_x = flight_start_x
        takeoff_b.curr_y = h
        takeoff_b.curr_w = #takeoff_t+2
        takeoff_b.curr_h = 1

        local flight_x = flight_start_x + takeoff_b.curr_w + 2
        display.setCursorPos(flight_x,h)
        if is_in_flight then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.black)
            display.setTextColor(colors.orange)
        end
        display.write("["..flight_text.."]")

        local landing_x = flight_x + #flight_text + 2 + 2
        display.setCursorPos(landing_x,h)
        if landing_b.is_active() then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write("["..landing_t.."]")
        landing_b.curr_x = landing_x
        landing_b.curr_y = h
        landing_b.curr_w = #landing_t+2
        landing_b.curr_h = 1

        local status_lines = {
            "TARDIS Status: "..get_status_text(),
            "Speakers Connected: "..#speakers,
            "Chat Box: "..(chat_box and "Connected" or "Not Connected")
        }
        local status_y = h - #status_lines -1
        for i,line in ipairs(status_lines) do
            display.setCursorPos(math.floor((w - #line)/2)+1, status_y+i-1)
            display.setBackgroundColor(colors.black)
            display.setTextColor(colors.orange)
            display.write(line)
        end
    end

    update_redstone()

    while true do
        redraw()
        local event, p1, p2, p3 = os.pullEvent()
        if event=="term_resize" then
            -- react to resize
        elseif event=="mouse_click" then
            local x,y = p2,p3
            for _,b in ipairs(button_defs) do
                if x>=b.curr_x and x<b.curr_x+b.curr_w and y==b.curr_y then
                    if b.can_click() then b.action() end
                end
            end
        end
    end
end

---------------------------------------------------------------------
-- COMPACT INTERFACE (external monitor)
---------------------------------------------------------------------
local function compact_interface_loop()
    if not monitor then return end
    local disp = monitor
    disp.setTextScale(1)

    local buttons = {
        {txt_func=function() return powered and "PWR OFF" or "PWR ON" end, action=power_toggle},
        {txt="TAKEOFF", action=takeoff},
        {txt="LAND", action=landing},
        {txt="SHORT", action=short_flight_func},
        {txt="DENY", action=denied},
        {txt="CLOIST", action=cloister_toggle},
        {txt="BIPERR", action=bip_toggle},
        {txt_func=function() return door_state=="closed" and "OPEN" or "CLOSE" end, action=door_toggle},
    }

    while true do
        disp.setBackgroundColor(colors.black)
        disp.setTextColor(colors.orange)
        disp.clear()
        local w,h = disp.getSize()

        disp.setCursorPos(2,1)
        disp.write("TARDIS PANEL")

        local y = 3
        for _,b in ipairs(buttons) do
            local label = b.txt or b.txt_func()
            disp.setCursorPos(2,y)
            disp.setBackgroundColor(colors.orange)
            disp.setTextColor(colors.white)
            disp.write("["..label.."]")
            b.x = 2
            b.y = y
            b.w = #label + 2
            y = y + 2
        end

        local ev, side, x, y = os.pullEvent("monitor_touch")
        if side == peripheral.getName(monitor) then
            for _,b in ipairs(buttons) do
                if x >= b.x and x <= b.x + b.w -1 and y == b.y then
                    b.action()
                    break
                end
            end
        end
    end
end

---------------------------------------------------------------------
-- PARALLEL EXECUTION
---------------------------------------------------------------------

parallel.waitForAll(audio_loop, full_interface_loop, compact_interface_loop)
