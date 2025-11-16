-- =========================
--  TARDIS COMPLETE CODE
--  With Compact Monitor UI
-- =========================

local powered = false
local speaker_on = false
local cloister_state = false
local speaker = peripheral.find("speaker")
local monitor = peripheral.find("monitor")
local box = peripheral.find("chatBox")
local turtle = peripheral.find("turtle") or peripheral.find("turtleWireless") or peripheral.find("turtleAdvanced") or peripheral.find("turtleAdvancedWireless")

local tardisState = {
    lanterns = false,
    shields = false,
    invisibility = false,
    isFlying = false,
    controlMode = "manual",
    destination = "none",
    flightMode = "none",
    cloakState = false,
}

local door_state = "closed"

-- ================
--  SOUND SUPPORT
-- ================

local ping = {
    "C3", 0.1,
    "G3", 0.1,
    "D3", 0.1,
    "F3", 0.1,
}

local errorBeepSequence = {
    {frequency = 880, duration = 0.2},
    {frequency = 698, duration = 0.2},
}

local function playErrorBeep()
    if not speaker then return end
    for _,note in ipairs(errorBeepSequence) do
        speaker.playSound("block.note_block.bass", 3, note.frequency/880)
        sleep(note.duration)
    end
end

local function bip_toggle()
    powered = true
    playErrorBeep()
end

local function shield_toggle()
    tardisState.shields = not tardisState.shields
    if tardisState.shields then
        playErrorBeep()
    end
end

local function play_tone(note, duration)
    if speaker then speaker.playSound("block.note_block.pling", 3, note) end
    sleep(duration)
end

local function short_flight_func()
    powered = true
    tardisState.flightMode = "short"
    if speaker then
        speaker.playSound("tardis:takeoff", 3, 1)
        sleep(2.5)
        speaker.playSound("tardis:land", 3, 1)
    end
end

local function takeoff()
    powered = true
    tardisState.flightMode = "takeoff"
    tardisState.isFlying = true
    if speaker then speaker.playSound("tardis:takeoff", 3, 1) end
end

local function landing()
    tardisState.flightMode = "landing"
    tardisState.isFlying = false
    if speaker then speaker.playSound("tardis:land", 3, 1) end
end

local function denied()
    if speaker then speaker.playSound("tardis:denied", 3, 1) end
end

local function cloister_toggle()
    cloister_state = not cloister_state
    if cloister_state then
        if turtle then
            for _,v in ipairs(ping) do
                if type(v)=="string" then
                    turtle.playNote(v, 3)
                else
                    sleep(v)
                end
            end
        end
    end
end

local function door_toggle()
    if door_state == "closed" then
        door_state = "open"
    else
        door_state = "closed"
    end

    if speaker then
        speaker.playSound("block.iron_door.open", 3, 1)
        sleep(2)
        speaker.playSound("block.iron_door.close", 3, 1)
    end
end

local function power_toggle()
    powered = not powered
    speaker_on = powered

    if speaker_on and speaker then
        speaker.playSound("tardis:startup", 3, 1)
    end
end

local function audio_loop()
    while true do sleep(0.1) end
end

local function interface_loop()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("TARDIS Control Panel")
        print("----------------------")
        print("Powered: " .. tostring(powered))
        print("Flying : " .. tostring(tardisState.isFlying))
        print("Shield : " .. tostring(tardisState.shields))
        print("Cloist : " .. tostring(cloister_state))
        print("Door   : " .. door_state)
        print("")
        print("Use the monitor for controls.")
        sleep(0.5)
    end
end


-- =======================================
--  NEW COMPACT MONITOR UI (1×1 SCREEN)
-- =======================================

local function compact_interface_loop()
    if not monitor then return end

    local disp = monitor
    disp.setTextScale(0.5)  -- small text for 1×1 monitor

    local buttons = {
        {txt="SHORT", action=short_flight_func},
        {txt="DENY", action=denied},
        {txt="CLOIST", action=cloister_toggle},
        {txt="BIP", action=bip_toggle},
        {txt_func=function() return door_state=="closed" and "OPEN DOOR" or "CLOSE DOOR" end,
            action=door_toggle},

        {txt_func=function() return powered and "POWER OFF" or "POWER ON" end,
            action=power_toggle},
        {txt="TAKEOFF", action=takeoff},
        {txt="LAND", action=landing},
    }

    while true do
        disp.setBackgroundColor(colors.black)
        disp.setTextColor(colors.orange)
        disp.clear()

        local w, h = disp.getSize()

        disp.setCursorPos(math.floor(w/2 - 6), 1)
        disp.write("TARDIS PANEL")

        disp.setCursorPos(1, 2)
        disp.write(string.rep("-", w))

        local y = 4
        for _,b in ipairs(buttons) do
            local label = b.txt or b.txt_func()
            disp.setCursorPos(2, y)
            disp.setBackgroundColor(colors.orange)
            disp.setTextColor(colors.white)
            disp.write("["..label.."]")

            b.x = 2
            b.y = y
            b.w = #label + 2

            y = y + 2
        end

        local ev, side, x, ypress = os.pullEvent("monitor_touch")
        if side == peripheral.getName(monitor) then
            for _,b in ipairs(buttons) do
                if ypress == b.y and x >= b.x and x <= b.x + b.w - 1 then
                    b.action()
                    break
                end
            end
        end
    end
end


-- ======================
--  RUN EVERYTHING
-- ======================

parallel.waitForAll(
    audio_loop,
    interface_loop,
    compact_interface_loop
)
