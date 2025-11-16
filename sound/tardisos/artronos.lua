-- TARDIS Soundboard for ComputerCraft / CC:Tweaked
-- Full program with:
--  * Full, interactive main UI on the computer terminal (all controls + statuses)
--  * Compact UI on an external single-block monitor (condensed icons/labels)
--  * Audio streaming using AUKit (keeps original streaming approach)
--  * Buttons separated so POWER / TAKEOFF don't overlap
--  * Flight status highlighted in center of the main UI

-- ------- CONFIG -------
local base_url = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/sound/"

-- ------- DEPENDENCIES (AUKit) -------
if not fs.exists("aukit.lua") then
    shell.run("wget https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua")
end
local aukit = require("aukit")

-- ------- PERIPHERALS -------
-- speakers discovery (works with multiple speakers)
local speakers = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "speaker" then
        table.insert(speakers, peripheral.wrap(name))
    end
end
if #speakers == 0 then
    -- we won't abort: allow UI to function even without speakers,
    -- but notify in main UI
end

local chat_box = peripheral.find("chatBox")
local monitor = peripheral.find("monitor") -- external single-block monitor (optional)
if monitor then
    -- small text for single-block monitor
    pcall(function() monitor.setTextScale(0.5) end)
end

-- ------- STATE -------
local powered = false
local door_state = "closed"
local current_loop = nil   -- loop filename (e.g. "ambiance" or "tardis_flight_loop")
local pending_actions = {}
local loop_names = {
    ambiance = "AMBIANCE",
    tardis_flight_loop = "FLIGHT",
    cloister_ding = "CLOISTER",
    bip_sound_error_1 = "BIP"
}

-- ------- UTIL -------
local function update_redstone()
    -- keep an output for automation; adjust side as needed
    if rs then pcall(function() rs.setOutput("bottom", powered) end) end
end

local function send_chat(message)
    if chat_box then
        pcall(function() chat_box.sendMessage("&e" .. message) end)
    end
end

-- ------- AUDIO (streaming) -------
local function play_stream(sound)
    if #speakers == 0 then
        -- no speakers, just return
        return
    end
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

local function audio_loop()
    while true do
        while #pending_actions > 0 do
            local action = table.remove(pending_actions, 1)
            if action.type == "play" then
                pcall(play_stream, action.sound)
            elseif action.type == "set_loop" then
                current_loop = action.loop
            end
        end
        if current_loop then
            -- continuous loop
            pcall(play_stream, current_loop)
        else
            os.pullEvent("audio_action")
        end
    end
end

local function play_temp(sound)
    if not powered then return end
    local saved = current_loop
    if saved then
        table.insert(pending_actions, {type="set_loop", loop = nil})
        table.insert(pending_actions, {type="play", sound = sound})
        table.insert(pending_actions, {type="set_loop", loop = saved})
    else
        table.insert(pending_actions, {type="play", sound = sound})
    end
    os.queueEvent("audio_action")
end

-- ------- ACTIONS -------
local function power_toggle()
    if powered then
        powered = false
        table.insert(pending_actions, {type="set_loop", loop = nil})
        table.insert(pending_actions, {type="play", sound = "shutdowntardis"})
    else
        powered = true
        table.insert(pending_actions, {type="play", sound = "startup_tardis"})
        table.insert(pending_actions, {type="set_loop", loop = "ambiance"})
    end
    os.queueEvent("audio_action")
    update_redstone()
end

local function takeoff()
    if not powered then return end
    send_chat("TARDIS: dematerialisation (TAKEOFF)")
    table.insert(pending_actions, {type="set_loop", loop = nil})
    table.insert(pending_actions, {type="play", sound = "tardistakeoff"})
    table.insert(pending_actions, {type="set_loop", loop = "tardis_flight_loop"})
    os.queueEvent("audio_action")
end

local function landing()
    if not powered then return end
    send_chat("TARDIS: rematerialisation (LANDING)")
    table.insert(pending_actions, {type="set_loop", loop = nil})
    table.insert(pending_actions, {type="play", sound = "landing"})
    table.insert(pending_actions, {type="set_loop", loop = "ambiance"})
    os.queueEvent("audio_action")
end

local function short_flight_func()
    if not powered then return end
    play_temp("short_flight")
end

local function denied()
    if not powered then return end
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

-- ------- MAIN UI (TERMINAL) -------
local function main_interface_loop()
    local display = term
    local w, h = display.getSize()

    -- define buttons layout to match user's requested layout:
    -- Left column (top->down): POWER, LAND, DENY, BIP
    -- Right column (top->down): (empty top), SHORT, CLOIST, DOOR
    -- Bottom center: TAKEOFF
    -- Flight status: center, highlighted; Landing to right of flight status

    local buttons = {
        power = {label = "POWER", action = power_toggle},
        land  = {label = "LAND", action = landing},
        deny  = {label = "DENY", action = denied},
        bip   = {label = "BIP", action = bip_toggle},
        short = {label = "SHORT", action = short_flight_func},
        cloist= {label = "CLOIST", action = cloister_toggle},
        door  = {label = "DOOR", action = door_toggle},
        take  = {label = "TAKEOFF", action = takeoff},
    }

    local function draw()
        display.clear()
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.orange)
        w, h = display.getSize()

        -- Title
        display.setCursorPos(1,1)
        display.setTextColor(colors.orange)
        display.write("TARDIS CONTROL PANEL")
        display.setCursorPos(1,2)
        display.write(string.rep("-", w))

        -- Calculate positions
        local left_x = 2
        local right_x = math.floor(w / 2) + 4
        local top_y = 4

        -- Left column
        local y = top_y
        for _, key in ipairs({"power","land","deny","bip"}) do
            local b = buttons[key]
            display.setCursorPos(left_x, y)
            -- highlight active/available states
            local bg, fg = colors.brown, colors.orange
            if key == "power" and powered then bg, fg = colors.orange, colors.white end
            display.setBackgroundColor(bg)
            display.setTextColor(fg)
            display.write("[" .. b.label .. "]")
            b.curr_x = left_x
            b.curr_y = y
            b.curr_w = #b.label + 2
            b.curr_h = 1
            y = y + 2
        end

        -- Right column
        y = top_y
        for _, key in ipairs({"short","cloist","door"}) do
            local b = buttons[key]
            display.setCursorPos(right_x, y)
            local bg, fg = colors.brown, colors.orange
            -- show active loop states as highlighted
            if key == "cloist" and current_loop == "cloister_ding" then bg, fg = colors.orange, colors.white end
            if key == "short" then -- nothing special
            end
            display.setBackgroundColor(bg)
            display.setTextColor(fg)
            display.write("[" .. b.label .. "]")
            b.curr_x = right_x
            b.curr_y = y
            b.curr_w = #b.label + 2
            b.curr_h = 1
            y = y + 2
        end

        -- Bottom center: TAKEOFF button
        local take_b = buttons.take
        local take_x = math.floor((w - (#take_b.label + 2)) / 2) + 1
        local take_y = h - 3
        display.setCursorPos(take_x, take_y)
        local bg, fg = colors.brown, colors.orange
        if current_loop == "tardis_flight_loop" then
            -- if in flight, disable takeoff (show as brown)
            bg, fg = colors.brown, colors.orange
        else
            bg, fg = colors.orange, colors.white
        end
        display.setBackgroundColor(bg)
        display.setTextColor(fg)
        display.write("[" .. take_b.label .. "]")
        take_b.curr_x = take_x
        take_b.curr_y = take_y
        take_b.curr_w = #take_b.label + 2
        take_b.curr_h = 1

        -- Flight status area centered above bottom
        local flight_status = "IDLE"
        if powered then
            if current_loop == "tardis_flight_loop" then flight_status = "FLYING" end
        else
            flight_status = "OFF"
        end
        local flight_text = flight_status
        local flight_x = math.floor((w - (#flight_text + 2 + 1 + #("LANDING") + 2)) / 2) + 1
        -- draw flight box (highlight if flying)
        display.setCursorPos(flight_x, take_y)
        if flight_status == "FLYING" then
            display.setBackgroundColor(colors.orange); display.setTextColor(colors.white)
        else
            display.setBackgroundColor(colors.black); display.setTextColor(colors.orange)
        end
        display.write("[" .. flight_text .. "]")
        -- draw landing label to the right
        local landing_label = "LANDING"
        local land_x = flight_x + (#flight_text + 2) + 2
        display.setCursorPos(land_x, take_y)
        if current_loop == "tardis_flight_loop" then
            display.setBackgroundColor(colors.brown); display.setTextColor(colors.orange)
        else
            display.setBackgroundColor(colors.black); display.setTextColor(colors.orange)
        end
        display.write(" " .. landing_label)
        -- store a fake clickable zone for landing (we'll use the right-of-flight text as a button)
        -- create a temporary button record for landing
        buttons._landing_area = { curr_x = land_x, curr_y = take_y, curr_w = #(" "..landing_label), curr_h = 1, action = landing }

        -- Status block on lower-left
        local status_lines = {
            "STATUS: " .. (powered and "POWERED" or "OFF"),
            "Door: " .. door_state,
            "Loop: " .. (current_loop or "none"),
            "Speakers: " .. tostring(#speakers),
            "ChatBox: " .. (chat_box and "Connected" or "Not connected")
        }
        local sx = 2
        local sy = h - (#status_lines) - 1
        for i,ln in ipairs(status_lines) do
            display.setCursorPos(sx, sy + i - 1)
            display.setBackgroundColor(colors.black)
            display.setTextColor(colors.orange)
            display.write(ln .. string.rep(" ", w - sx - #ln))
        end

        -- Reset background for future writes
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.white)
    end

    -- initial redstone state
    update_redstone()

    while true do
        draw()
        local event, p1, p2, p3 = os.pullEvent()
        if event == "term_resize" then
            -- redraw on resize automatically
        elseif event == "mouse_click" then
            local button, x, y = p1, p2, p3
            -- test all named buttons
            for k,b in pairs({
                power = true, land = true, deny = true, bip = true,
                short = true, cloist = true, door = true, take = true
            }) do
                local bd = (k == "power" and nil) -- placeholder to get actual table below
            end
            -- We have 'buttons' local above; iterate it
            for name,b in pairs(buttons) do
                if b.curr_x and b.curr_y then
                    if x >= b.curr_x and x < b.curr_x + b.curr_w and y == b.curr_y then
                        -- special rules: TAKEOFF shouldn't be active when already flying
                        if name == "take" then
                            if current_loop == "tardis_flight_loop" then
                                -- ignore
                            else
                                b.action()
                            end
                        else
                            b.action()
                        end
                        break
                    end
                end
            end
            -- landing right-of-flight clickable zone
            local l = buttons._landing_area
            if l and x >= l.curr_x and x < l.curr_x + l.curr_w and y == l.curr_y then
                l.action()
            end
        end
    end
end

-- ------- COMPACT MONITOR UI (single-block monitor) -------
-- Layout per user: condensed icons/short labels.
-- We'll use two columns on the small monitor:
-- Left column: SHORT, DENY, CLOIST, BIP, DOOR  (stacked)
-- Bottom row / center: TK (TAKEOFF), PWR (POWER), LAND
-- Show flight status near bottom center (FLY / LANDING)
local function compact_interface_loop()
    if not monitor then return end
    local disp = monitor
    pcall(function() disp.setTextScale(0.5) end)

    local buttons = {
        {id="short", label="SH", action=short_flight_func},   -- SH = short
        {id="deny",  label="DN", action=denied},
        {id="clo",   label="CL", action=cloister_toggle},
        {id="bip",   label="BP", action=bip_toggle},
        {id="door",  label="DR", action=door_toggle},
        -- bottom row
        {id="power", label="PWR", action=power_toggle},
        {id="take",  label="TK",  action=takeoff},  -- TK = takeoff (condensed)
        {id="land",  label="LD",  action=landing},
    }

    local function draw()
        disp.clear()
        disp.setBackgroundColor(colors.black)
        disp.setTextColor(colors.orange)
        local w,h = disp.getSize()

        -- Header
        disp.setCursorPos(2,1)
        disp.write("TARDIS")

        -- Left stacked buttons (start y = 3)
        local y = 3
        for i=1,5 do
            local b = buttons[i]
            disp.setCursorPos(2, y)
            disp.setBackgroundColor(colors.orange)
            disp.setTextColor(colors.white)
            disp.write("["..b.label.."]")
            b.x = 2; b.y = y; b.w = #b.label + 2; b.h = 1
            y = y + 2
        end

        -- Bottom row: three buttons centered
        local bottom_y = h - 3
        local total_w = 3 * (3 + 2) -- each label ~3 chars + 2 brackets (approx)
        local start_x = math.floor((w - ( (#buttons[6].label+2) + (#buttons[7].label+2) + (#buttons[8].label+2) + 4 ))/2) + 1
        -- place PWR, TK, LD
        local bx = start_x
        for i=6,8 do
            local b = buttons[i]
            disp.setCursorPos(bx, bottom_y)
            -- highlight power if on
            if b.id == "power" and powered then
                disp.setBackgroundColor(colors.orange); disp.setTextColor(colors.white)
            else
                disp.setBackgroundColor(colors.brown); disp.setTextColor(colors.orange)
            end
            disp.write("["..b.label.."]")
            b.x = bx; b.y = bottom_y; b.w = #b.label + 2; b.h = 1
            bx = bx + b.w + 2
        end

        -- Flight status in the lower center (between bottom row and header)
        local status = "OFF"
        if powered then
            if current_loop == "tardis_flight_loop" then status = "FLY" else status = "IDLE" end
        end
        local st_text = status
        local st_x = math.floor((w - #st_text) / 2) + 1
        disp.setCursorPos(st_x, bottom_y - 2)
        if status == "FLY" then
            disp.setBackgroundColor(colors.orange); disp.setTextColor(colors.white)
        else
            disp.setBackgroundColor(colors.black); disp.setTextColor(colors.orange)
        end
        disp.write(st_text)

        disp.setBackgroundColor(colors.black); disp.setTextColor(colors.white)
    end

    while true do
        draw()
        local ev, side, x, y = os.pullEvent("monitor_touch")
        if side == peripheral.getName(monitor) then
            for _,b in ipairs(buttons) do
                if x >= b.x and x <= b.x + b.w - 1 and y == b.y then
                    -- TAKEOFF condensed label "TK" should still obey same constraint: ignore if already flying
                    if b.id == "take" and current_loop == "tardis_flight_loop" then
                        -- ignore
                    else
                        b.action()
                    end
                    break
                end
            end
        end
    end
end

-- ------- RUN (parallel) -------
parallel.waitForAll(audio_loop, main_interface_loop, compact_interface_loop)
