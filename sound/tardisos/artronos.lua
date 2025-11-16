-----------------------------------------
--            ARTRON OS v1.0           --
--     Dual Interface TARDIS System    --
--      Main Computer + 1x1 Monitor    --
-----------------------------------------

-- ============= PERIPHERALS =============
local speaker = peripheral.find("speaker")
local monitor = peripheral.find("monitor")

-- ============= TARDIS INTERNAL STATE =============
local tardis = {
    powered = false,
    isFlying = false,
    flightMode = "idle",   -- idle / takeoff / landing
    door = "closed",
    cloister = false,
}

------------------------------------------------------
--                  SOUND SYSTEM                    --
------------------------------------------------------

local function play(name)
    if speaker then speaker.playSound(name, 3, 1) end
end

local function takeoff_sound()
    play("tardis:takeoff")
end

local function land_sound()
    play("tardis:land")
end

local function denied_sound()
    play("tardis:denied")
end

local function power_sound()
    play("tardis:startup")
end

------------------------------------------------------
--            STATE CHANGE FUNCTIONS                --
------------------------------------------------------

local function toggle_power()
    tardis.powered = not tardis.powered
    if tardis.powered then power_sound() end
end

local function do_takeoff()
    tardis.isFlying = true
    tardis.flightMode = "takeoff"
    takeoff_sound()
    sleep(2)
    tardis.flightMode = "idle"
end

local function do_landing()
    tardis.flightMode = "landing"
    land_sound()
    tardis.isFlying = false
    sleep(1.5)
    tardis.flightMode = "idle"
end

local function do_short_flight()
    do_takeoff()
    sleep(2)
    do_landing()
end

local function toggle_cloister()
    tardis.cloister = not tardis.cloister
end

local function toggle_door()
    tardis.door = (tardis.door == "open") and "closed" or "open"
end

local function bip()
    play("block.note_block.bass")
end

------------------------------------------------------
--           MAIN COMPUTER BIG INTERFACE            --
------------------------------------------------------

local function getStateWord()
    if tardis.flightMode == "takeoff" then return "Takeoff" end
    if tardis.flightMode == "landing" then return "Landing" end
    if tardis.isFlying then return "Fly" end
    return "Station"
end

local buttons_main = {}

local function addButton(tbl,x,y,text,fn)
    table.insert(tbl,{
        x=x, y=y, text=text, fn=fn,
        w=#text
    })
end

local function draw_main_interface()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.clear()

    term.setCursorPos(1,1)
    print("         ARTRON OS")

    term.setTextColor(colors.white)

    -- Left column
    addButton(buttons_main, 2, 4, "[POWER]", toggle_power)
    addButton(buttons_main, 2, 6, "[DENY]", denied_sound)
    addButton(buttons_main, 2, 8, "[BIP]", bip)

    -- Right column
    addButton(buttons_main, 20, 4, "[SHORT]", do_short_flight)
    addButton(buttons_main, 20, 6, "[CLOIST]", toggle_cloister)
    addButton(buttons_main, 20, 8, "[DOOR]", toggle_door)

    -- Center timeline block
    local state = getStateWord()

    term.setCursorPos(2,12)
    term.write("[TAKEOFF]")

    term.setCursorPos(14,12)
    term.write(state)

    term.setCursorPos(25,12)
    term.write("[LAND]")

    addButton(buttons_main, 2,12,"[TAKEOFF]",do_takeoff)
    addButton(buttons_main,25,12,"[LAND]",do_landing)
end


local function main_interface_loop()
    draw_main_interface()

    while true do
        local ev,btn,x,y = os.pullEvent("mouse_click")
        for _,b in ipairs(buttons_main) do
            if y == b.y and x>=b.x and x<=b.x+b.w-1 then
                b.fn()
                buttons_main = {}
                draw_main_interface()
                break
            end
        end
    end
end

------------------------------------------------------
--         MONITOR EXTERNAL COMPACT PANEL           --
------------------------------------------------------

local function smallState()
    if tardis.flightMode == "takeoff" then return "T" end
    if tardis.flightMode == "landing" then return "L" end
    if tardis.isFlying then return "F" end
    return "S"
end

local buttons_monitor = {}

local function monitor_addButton(tbl,x,y,text,fn)
    table.insert(tbl,{
        x=x, y=y, text=text, fn=fn, w=#text
    })
end

local function monitor_interface()
    if not monitor then return end

    local m = monitor
    m.setTextScale(0.5)
    m.setBackgroundColor(colors.black)
    m.setTextColor(colors.white)

    while true do
        m.clear()
        local w,h = m.getSize()

        local cx = math.floor(w/2)

        buttons_monitor = {}

        -- Center vertical layout
        monitor_addButton(buttons_monitor, cx-3, 2, "[ON]", toggle_power)
        monitor_addButton(buttons_monitor, cx-2, 4, "[TK]", do_takeoff)
        monitor_addButton(buttons_monitor, cx-2, 6, "[LD]", do_landing)

        m.setCursorPos(cx-1, 8)
        m.write(smallState())

        -- Draw buttons visually
        for _,b in ipairs(buttons_monitor) do
            m.setCursorPos(b.x,b.y)
            m.write(b.text)
        end

        -- handle touch
        local ev,side,x,y = os.pullEvent("monitor_touch")
        if side == peripheral.getName(monitor) then
            for _,b in ipairs(buttons_monitor) do
                if y==b.y and x>=b.x and x<=b.x+b.w-1 then
                    b.fn()
                end
            end
        end
    end
end

------------------------------------------------------
--                 RUNTIME START                    --
------------------------------------------------------

parallel.waitForAll(main_interface_loop, monitor_interface)
