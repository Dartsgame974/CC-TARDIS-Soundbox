-- TARDIS Soundboard for ComputerCraft/CC:Tweaked
-- Uses AUKit for streaming audio from GitHub
-- Interface in terminal or monitor with touch support
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

-- Find monitor
local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(0.5)
end

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

-- Function to update redstone
local function update_redstone()
    rs.setOutput("right", powered)
end

-- Function to check redstone input for landing
local function check_redstone_landing()
    if rs.getInput("left") then
        landing()
    end
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

-- Interface condensée pour monitor externe
local function monitor_interface_loop()
    if not monitor then return end
    
    local display = monitor
    
    local button_defs = {
        {id = "power", text_func = function() return powered and "POWER OFF" or "POWER ON" end, action = power_toggle, can_click = function() return true end},
        {id = "takeoff", text = "TAKEOFF", action = takeoff, can_click = function() return powered and current_loop ~= "tardis_flight_loop" end},
        {id = "landing", text = "LANDING", action = landing, can_click = function() return powered and current_loop == "tardis_flight_loop" end},
    }
    
    local function redraw()
        display.setBackgroundColor(colors.black)
        display.clear()
        local w, h = display.getSize()
        
        -- Cadre supérieur décoratif
        display.setCursorPos(1, 1)
        display.setTextColor(colors.orange)
        display.write(string.rep("=", w))
        
        -- Titre centré avec style
        local title = "[ ARTRON OS ]"
        display.setCursorPos(math.floor((w - #title) / 2) + 1, 3)
        display.setTextColor(colors.orange)
        display.setBackgroundColor(colors.black)
        display.write(title)
        
        -- Cadre inférieur titre
        display.setCursorPos(1, 5)
        display.setTextColor(colors.orange)
        display.write(string.rep("=", w))
        
        -- Bouton POWER centré
        local power_b = button_defs[1]
        local power_text = "[ " .. power_b.text_func() .. " ]"
        local power_y = math.floor(h / 2) - 2
        display.setCursorPos(math.floor((w - #power_text) / 2) + 1, power_y)
        if powered then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.gray)
            display.setTextColor(colors.lightGray)
        end
        display.write(power_text)
        power_b.curr_x = math.floor((w - #power_text) / 2) + 1
        power_b.curr_y = power_y
        power_b.curr_w = #power_text
        power_b.curr_h = 1
        
        display.setBackgroundColor(colors.black)
        
        -- Séparateur
        display.setCursorPos(1, power_y + 2)
        display.setTextColor(colors.orange)
        display.write(string.rep("-", w))
        
        -- Boutons TAKEOFF et LANDING en bas
        local takeoff_b = button_defs[2]
        local landing_b = button_defs[3]
        
        local tk_text = "[ " .. takeoff_b.text .. " ]"
        local ld_text = "[ " .. landing_b.text .. " ]"
        
        -- TAKEOFF centré
        local tk_y = h - 4
        display.setCursorPos(math.floor((w - #tk_text) / 2) + 1, tk_y)
        if powered and current_loop ~= "tardis_flight_loop" then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.gray)
            display.setTextColor(colors.lightGray)
        end
        display.write(tk_text)
        takeoff_b.curr_x = math.floor((w - #tk_text) / 2) + 1
        takeoff_b.curr_y = tk_y
        takeoff_b.curr_w = #tk_text
        takeoff_b.curr_h = 1
        
        display.setBackgroundColor(colors.black)
        
        -- LANDING centré
        local ld_y = h - 2
        display.setCursorPos(math.floor((w - #ld_text) / 2) + 1, ld_y)
        if powered and current_loop == "tardis_flight_loop" then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.gray)
            display.setTextColor(colors.lightGray)
        end
        display.write(ld_text)
        landing_b.curr_x = math.floor((w - #ld_text) / 2) + 1
        landing_b.curr_y = ld_y
        landing_b.curr_w = #ld_text
        landing_b.curr_h = 1
        
        display.setBackgroundColor(colors.black)
        
        -- Status FLIGHT centré en bas
        local status_text = "FLIGHT"
        if current_loop == "tardis_flight_loop" then
            display.setCursorPos(math.floor((w - #status_text) / 2) + 1, h)
            display.setTextColor(colors.yellow)
            display.write(status_text)
        end
        
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.white)
    end
    
    update_redstone()
    
    while true do
        redraw()
        while true do
            local event, side, x, y = os.pullEvent()
            if event == "monitor_resize" then
                break
            elseif event == "monitor_touch" then
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
            elseif event == "redstone" then
                -- Vérifier le signal redstone pour landing
                check_redstone_landing()
                break
            end
        end
    end
end

-- Interface complète pour terminal PC
local function terminal_interface_loop()
    local display = term
    
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
        
        -- Cadre décoratif supérieur
        display.setCursorPos(1, 1)
        display.setTextColor(colors.orange)
        display.write(string.rep("=", w))
        
        -- Titre centré
        local title = "[ ARTRON OS TYPE 40 ]"
        display.setCursorPos(math.floor((w - #title) / 2) + 1, 2)
        display.setTextColor(colors.orange)
        display.write(title)
        
        -- Cadre décoratif inférieur titre
        display.setCursorPos(1, 3)
        display.setTextColor(colors.orange)
        display.write(string.rep("=", w))
        
        -- Bouton POWER centré en haut
        local power_b = button_defs[1]
        local power_text = power_b.text_func()
        local power_full = "[ " .. power_text .. " ]"
        display.setCursorPos(math.floor((w - #power_full) / 2) + 1, 5)
        if power_b.is_active() then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write(power_full)
        power_b.curr_x = math.floor((w - #power_full) / 2) + 1
        power_b.curr_y = 5
        power_b.curr_w = #power_full
        power_b.curr_h = 1
        
        -- Autres boutons centrés verticalement au milieu
        local other_buttons = {button_defs[4], button_defs[5], button_defs[6], button_defs[7], button_defs[8]}
        local mid_y = math.floor(h / 2) - 2
        
        for i, b in ipairs(other_buttons) do
            local y = mid_y + (i - 1) * 2
            local btn_text = b.text or b.text_func()
            local btn_full = "[ " .. btn_text .. " ]"
            display.setCursorPos(math.floor((w - #btn_full) / 2) + 1, y)
            if b.is_active() then
                display.setBackgroundColor(colors.orange)
                display.setTextColor(colors.white)
            else
                display.setBackgroundColor(colors.brown)
                display.setTextColor(colors.orange)
            end
            display.write(btn_full)
            b.curr_x = math.floor((w - #btn_full) / 2) + 1
            b.curr_y = y
            b.curr_w = #btn_full
            b.curr_h = 1
        end
        
        -- Status RP en bas (avant les boutons de vol)
        display.setBackgroundColor(colors.black)
        local sys_status = powered and "SYSTEMS ONLINE" or "SYSTEMS OFFLINE"
        local audio_sys = "AUDIO RELAYS: " .. #speakers
        local comms_sys = chat_box and "COMMS LINK: ACTIVE" or "COMMS LINK: OFFLINE"
        
        local status_y = h - 5
        display.setCursorPos(math.floor((w - #sys_status) / 2) + 1, status_y)
        display.setTextColor(powered and colors.lime or colors.red)
        display.write(sys_status)
        
        display.setCursorPos(math.floor((w - #audio_sys) / 2) + 1, status_y + 1)
        display.setTextColor(colors.lightBlue)
        display.write(audio_sys)
        
        display.setCursorPos(math.floor((w - #comms_sys) / 2) + 1, status_y + 2)
        display.setTextColor(chat_box and colors.lime or colors.gray)
        display.write(comms_sys)
        
        -- Boutons de vol en bas avec status au centre
        local takeoff_b = button_defs[2]
        local landing_b = button_defs[3]
        local is_in_flight = current_loop == "tardis_flight_loop"
        
        -- Déterminer le status à afficher
        local status_text
        if is_in_flight then
            status_text = "FLIGHT..."
        elseif powered and current_loop ~= "tardis_flight_loop" then
            status_text = "LANDED..."
        else
            status_text = "STANDBY..."
        end
        
        local takeoff_text = "[ TAKEOFF ]"
        local landing_text = "[ LANDING ]"
        local spacing = 3
        local total_width = #takeoff_text + spacing + #status_text + spacing + #landing_text
        local flight_start_x = math.floor((w - total_width) / 2) + 1
        
        -- TAKEOFF button
        display.setCursorPos(flight_start_x, h)
        if powered and current_loop ~= "tardis_flight_loop" then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write(takeoff_text)
        takeoff_b.curr_x = flight_start_x
        takeoff_b.curr_y = h
        takeoff_b.curr_w = #takeoff_text
        takeoff_b.curr_h = 1
        
        -- Status au centre (non cliquable)
        local status_x = flight_start_x + #takeoff_text + spacing
        display.setCursorPos(status_x, h)
        display.setBackgroundColor(colors.black)
        if is_in_flight then
            display.setTextColor(colors.yellow)
        elseif powered then
            display.setTextColor(colors.lime)
        else
            display.setTextColor(colors.gray)
        end
        display.write(status_text)
        
        -- LANDING button
        local landing_x = status_x + #status_text + spacing
        display.setCursorPos(landing_x, h)
        if powered and current_loop == "tardis_flight_loop" then
            display.setBackgroundColor(colors.orange)
            display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.brown)
            display.setTextColor(colors.orange)
        end
        display.write(landing_text)
        landing_b.curr_x = landing_x
        landing_b.curr_y = h
        landing_b.curr_w = #landing_text
        landing_b.curr_h = 1
        
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.white)
    end

    update_redstone()

    while true do
        redraw()
        while true do
            local event, param1, param2, param3 = os.pullEvent()
            if event == "term_resize" then
                break
            elseif event == "mouse_click" then
                local button, x, y = param1, param2, param3
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
            elseif event == "redstone" then
                -- Vérifier le signal redstone pour landing
                check_redstone_landing()
                break
            end
        end
    end
end

-- Run in parallel
if monitor then
    parallel.waitForAll(audio_loop, terminal_interface_loop, monitor_interface_loop)
else
    parallel.waitForAll(audio_loop, terminal_interface_loop)
end
