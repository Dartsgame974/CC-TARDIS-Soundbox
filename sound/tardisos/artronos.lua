-- ARTRON OS TYPE 40 - TARDIS Soundboard
-- Dependencies: AUKit (downloaded automatically if absent)
-- CC:Tweaked / ComputerCraft Lua

local SOUND_BASE_URL = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/sound/"
local SOUND_FILES = {
    startup = "startup_tardis.wav",
    ambiance = "ambiance.wav",
    flight = "tardis_flight_loop.wav",
    bip = "bip_sound_error_1.wav",
    short_flight = "short_flight.wav",
    landing = "landing.wav",
    takeoff = "tardistakeoff.wav",
    denied = "denied_flight.wav",
    shutdown = "shutdowntardis.wav",
    door_open = "door_open.wav",
    door_close = "close_door.wav",
    cloister = "cloister.wav"
}

-- Colors
local ORANGE = colors.orange
local BROWN = colors.brown
local WHITE = colors.white

-- Download AUKit if missing
if not fs.exists("aukit.lua") then
    print("Downloading AUKit...")
    shell.run("wget https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua")
end
local aukit = require("aukit")

-- Find speakers
local speakers = {}
for _, p in ipairs(peripheral.getNames()) do
    if peripheral.getType(p) == "speaker" then
        table.insert(speakers, peripheral.wrap(p))
    end
end

-- Ensure at least one speaker
if #speakers == 0 then
    error("No speakers found!")
end

-- Audio management
local currentLoop = nil
local loopThread = nil
local savedLoop = nil

local function playSound(file)
    local url = SOUND_BASE_URL .. file
    local ok, res = pcall(http.get, url, nil, true)
    if not ok or not res then
        print("Failed to stream: "..file)
        return
    end
    local audio = aukit.stream.wav(function() return res.read(48000) end)
    for chunk in audio do
        for _, sp in ipairs(speakers) do
            while not sp.playAudio(chunk) do
                os.pullEvent("speaker_audio_empty")
            end
        end
    end
    res.close()
end

local function startLoop(name)
    -- Stop previous loop
    if loopThread then
        parallel.waitForAny(function() end) -- Let previous thread die
    end
    currentLoop = name
    loopThread = coroutine.create(function()
        while true do
            playSound(SOUND_FILES[name])
        end
    end)
    coroutine.resume(loopThread)
end

local function stopLoop()
    loopThread = nil
    currentLoop = nil
end

-- TARDIS Logic
local tardisState = {powered=false, activeLoop=nil}

local function powerOn()
    tardisState.powered = true
    playSound(SOUND_FILES.startup)
    startLoop("ambiance")
    tardisState.activeLoop = "ambiance"
end

local function powerOff()
    stopLoop()
    playSound(SOUND_FILES.shutdown)
    tardisState.powered = false
    tardisState.activeLoop = nil
end

local function takeOff()
    if tardisState.activeLoop then stopLoop() end
    playSound(SOUND_FILES.takeoff)
    startLoop("flight")
    tardisState.activeLoop = "flight"
end

local function landing()
    if tardisState.activeLoop then stopLoop() end
    playSound(SOUND_FILES.landing)
    startLoop("ambiance")
    tardisState.activeLoop = "ambiance"
end

local function denied()
    savedLoop = tardisState.activeLoop
    if savedLoop then stopLoop() end
    playSound(SOUND_FILES.denied)
    if savedLoop then startLoop(savedLoop) end
end

local function shortFlight()
    savedLoop = tardisState.activeLoop
    if savedLoop then stopLoop() end
    playSound(SOUND_FILES.short_flight)
    if savedLoop then startLoop(savedLoop) end
end

local cloisterActive = false
local function toggleCloister()
    if cloisterActive then
        cloisterActive = false
        if tardisState.activeLoop then startLoop(tardisState.activeLoop) end
    else
        cloisterActive = true
        if tardisState.activeLoop then stopLoop() end
        startLoop("cloister")
        tardisState.activeLoop = "cloister"
    end
end

local bipActive = false
local function toggleBip()
    if bipActive then
        bipActive = false
        if tardisState.activeLoop then startLoop(tardisState.activeLoop) end
    else
        bipActive = true
        if tardisState.activeLoop then stopLoop() end
        startLoop("bip")
        tardisState.activeLoop = "bip"
    end
end

local function openDoor()
    savedLoop = tardisState.activeLoop
    if savedLoop then stopLoop() end
    playSound(SOUND_FILES.door_open)
    if savedLoop then startLoop(savedLoop) end
end

local function closeDoor()
    savedLoop = tardisState.activeLoop
    if savedLoop then stopLoop() end
    playSound(SOUND_FILES.door_close)
    if savedLoop then startLoop(savedLoop) end
end

-- Interface
local buttons = {
    {label="POWER ON", action=powerOn, x=2, y=3},
    {label="POWER OFF", action=powerOff, x=18, y=3},
    {label="TAKEOFF", action=takeOff, x=2, y=5},
    {label="LANDING", action=landing, x=18, y=5},
    {label="SHORT FLIGHT", action=shortFlight, x=2, y=7},
    {label="DENIED", action=denied, x=18, y=7},
    {label="CLOISTER", action=toggleCloister, x=2, y=9},
    {label="ERROR BIP", action=toggleBip, x=18, y=9},
    {label="OPEN DOOR", action=openDoor, x=2, y=11},
    {label="CLOSE DOOR", action=closeDoor, x=18, y=11},
}

local function drawButton(b)
    term.setCursorPos(b.x, b.y)
    term.setBackgroundColor(b.active and ORANGE or BROWN)
    term.setTextColor(WHITE)
    term.write(" "..b.label.." ")
    term.setBackgroundColor(colors.black)
end

local function redraw()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(ORANGE)
    print("ARTRON OS TYPE 40")
    print("TARDIS Status: "..(tardisState.powered and "ACTIVE" or "INACTIVE"))
    print("Active Loop: "..(tardisState.activeLoop or "None"))
    print("Speakers: "..#speakers)
    for _, b in ipairs(buttons) do
        drawButton(b)
    end
end

-- Mouse click handler
local function handleClick(x,y)
    for _, b in ipairs(buttons) do
        local bx, by = b.x, b.y
        local bw = #b.label + 2
        if x >= bx and x <= bx+bw and y == by then
            b.action()
            redraw()
        end
    end
end

-- Main
redraw()
while true do
    local event, p1, p2 = os.pullEvent()
    if event == "mouse_click" then
        handleClick(p2,p3)
    elseif event == "term_resize" then
        redraw()
    end
end
