local base_url = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/sound/"

if not fs.exists("aukit.lua") then
    shell.run("wget https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua")
end

local aukit = require("aukit")

local speakers = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "speaker" then
        table.insert(speakers, peripheral.wrap(name))
    end
end
if #speakers == 0 then error("No speakers connected!") end

local chat_box = peripheral.find("chatBox")
local monitor = peripheral.find("monitor")
local display = term
local is_monitor = false
local touch_event = "mouse_click"
if monitor then
    display = monitor
    is_monitor = true
    touch_event = "monitor_touch"
    monitor.setTextScale(0.5)
end

local loop_names = {
    ambiance = "AMBIANCE",
    tardis_flight_loop = "FLIGHT",
    cloister_ding = "CLOISTER",
    bip_sound_error_1 = "BIP"
}

local powered = false
local door_state = "closed"
local current_loop = nil
local pending_actions = {}

local function update_redstone()
    rs.setOutput("bottom", powered)
end

local function send_chat(message)
    if chat_box then chat_box.sendMessage("&e" .. message) end
end

local function play_stream(sound)
    local url = base_url .. sound .. ".wav"
    local resp = http.get(url, nil, true)
    if not resp then print("Failed to stream " .. url) return end
    local reader = function()
        local data = resp.read(48000)
        if data == "" then data = nil end
        return data
    end
    local stream = aukit.stream.wav(reader)
    aukit.play(stream, table.unpack(speakers))
    resp.close()
end

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

local function get_status_text()
    if current_loop == "tardis_flight_loop" then return "FLY" end
    if current_loop == "ambiance" then return "STATION" end
    if current_loop == "takeoff_tardis" then return "TAKEOFF" end
    if current_loop == "landing" then return "LANDING" end
    return "STATION"
end

local function interface_loop()
    local button_defs = {
        {id = "power", text_func = function() return powered and "POWER OFF" or "POWER ON" end, action = power_toggle, is_active = function() return true end, can_click = function() return true end},
        {id = "takeoff", text = "TAKEOFF", action = takeoff, is_active = function() return powered and current_loop ~= "tardis_flight_loop" end, can_click = function() return powered and current_loop ~= "tardis_flight_loop" end},
        {id = "landing", text = "LANDING", action = landing, is_active = function() return powered and current_loop == "tardis_flight_loop" end, can_click = function() return powered and current_loop == "tardis_flight_loop" end},
        {id = "short_flight", text = "SHORT FLIGHT", action = short_flight_func, is_active = function() return powered end, can_click = function() return powered end},
        {id = "denied", text = "DENIED", action = denied, is_active = function() return powered end, can_click = function() return powered end},
        {id = "cloister", text = "CLOISTER", action = cloister_toggle, is_active = function() return powered and current_loop == "cloister_ding" end, can_click = function() return powered end},
        {id = "bip", text = "ERROR BIP", action = bip_toggle, is_active = function() return powered and current_loop == "bip_sound_error_1" end, can_click = function() return powered end},
        {id = "door", text_func = function() return door_state == "closed" and "OPEN DOOR" or "CLOSE DOOR" end, action = door_toggle, is_active = function() return powered end, can_click = function() return powered end},
    }

    local function redraw()
        display.setBackgroundColor(colors.black)
        display.clear()
        local w,h = display.getSize()
        display.setCursorPos(1,1)
        display.setTextColor(colors.orange)
        display.write("ARTRON OS TYPE 40")
        display.setCursorPos(1,2)
        display.write(string.rep("-",w))

        local other_buttons = {button_defs[4], button_defs[5], button_defs[6], button_defs[7], button_defs[8]}
        local max_other_w = 0
        for _, b in ipairs(other_buttons) do
            local btn_text = b.text or b.text_func()
            max_other_w = math.max(max_other_w,#btn_text+2)
        end
        local other_x = w - max_other_w + 1
        local other_y = 3
        for i,b in ipairs(other_buttons) do
            local y = other_y + i - 1
            local btn_text = b.text or b.text_func()
            display.setCursorPos(other_x,y)
            if b.is_active() then
                display.setBackgroundColor(colors.orange)
                display.setTextColor(colors.white)
            else
                display.setBackgroundColor(colors.brown)
                display.setTextColor(colors.orange)
            end
            display.write("["..btn_text.."]")
            b.curr_x = other_x
            b.curr_y = y
            b.curr_w = #btn_text+2
            b.curr_h = 1
        end

        local power_b = button_defs[1]
        local power_text = power_b.text_func()
        display.setCursorPos(1,h)
        if power_b.is_active() then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write("["..power_text.."]")
        power_b.curr_x = 1
        power_b.curr_y = h
        power_b.curr_w = #power_text+2
        power_b.curr_h = 1

        local takeoff_b = button_defs[2]
        local landing_b = button_defs[3]
        local state_text = get_status_text()
        local center_x = math.floor((w-#state_text)/2)
        display.setCursorPos(center_x,h)
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.orange)
        display.write(state_text)
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.white)

        local takeoff_x = center_x - #takeoff_b.text - 3
        display.setCursorPos(takeoff_x,h)
        if takeoff_b.is_active() then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write("["..takeoff_b.text.."]")
        takeoff_b.curr_x = takeoff_x
        takeoff_b.curr_y = h
        takeoff_b.curr_w = #takeoff_b.text+2
        takeoff_b.curr_h = 1

        local landing_x = center_x + #state_text + 3
        display.setCursorPos(landing_x,h)
        if landing_b.is_active() then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write("["..landing_b.text.."]")
        landing_b.curr_x = landing_x
        landing_b.curr_y = h
        landing_b.curr_w = #landing_b.text+2
        landing_b.curr_h = 1
    end

    update_redstone()

    while true do
        redraw()
        local event,param1,param2,param3 = os.pullEvent()
        if event == "term_resize" or (is_monitor and event == "monitor_resize") then
        elseif event == touch_event or (not is_monitor and event == "mouse_click") then
            local side,x,y
            if is_monitor then side,x,y = param1,param2,param3
            else side,x,y = param1,param2,param3 end
            for _,b in ipairs(button_defs) do
                if x>=b.curr_x and x<b.curr_x+b.curr_w and y>=b.curr_y and y<b.curr_y+b.curr_h then
                    if b.can_click() then b.action() end
                    break
                end
            end
        end
    end
end

local function monitor_interface()
    if not monitor then return end
    monitor.setTextScale(0.5)
    monitor.clear()
    while true do
        local w,h = monitor.getSize()
        local cx = math.floor(w/2)
        monitor.setBackgroundColor(colors.black)
        monitor.clear()
        monitor.setTextColor(colors.orange)
        monitor.setCursorPos(cx-2,2)
        monitor.write("[ON]")
        monitor.setCursorPos(cx-2,4)
        monitor.write("[TK]")
        monitor.setCursorPos(cx-2,6)
        monitor.write("[LD]")
        local state_char = "S"
        if current_loop == "tardis_flight_loop" then state_char = "F"
        elseif current_loop == "takeoff_tardis" then state_char = "T"
        elseif current_loop == "landing" then state_char = "L" end
        monitor.setCursorPos(cx,8)
        monitor.write(state_char)
        local event,side,x,y = os.pullEvent("monitor_touch")
        if side == peripheral.getName(monitor) then
            if y==2 then power_toggle()
            elseif y==4 then takeoff()
            elseif y==6 then landing() end
        end
    end
end

parallel.waitForAll(audio_loop,interface_loop,monitor_interface)
