-- ARTRON OS TYPE 40 - TARDIS Soundboard (corrected clickable buttons)
-- Dependencies: AUKit

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
local ORANGE, BROWN, WHITE = colors.orange, colors.brown, colors.white

-- Download AUKit if missing
if not fs.exists("aukit.lua") then
    shell.run("wget https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua")
end
local aukit = require("aukit")

-- Speakers
local speakers = {}
for _, p in ipairs(peripheral.getNames()) do
    if peripheral.getType(p) == "speaker" then
        table.insert(speakers, peripheral.wrap(p))
    end
end
if #speakers == 0 then error("No speakers found!") end

-- Audio functions
local currentLoop, loopThread, savedLoop = nil, nil, nil

local function playSound(file)
    local url = SOUND_BASE_URL .. file
    local ok, res = pcall(http.get, url, nil, true)
    if not ok or not res then print("Failed: "..file) return end
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
    if loopThread then loopThread = nil end
    currentLoop = name
    loopThread = coroutine.create(function()
        while true do playSound(SOUND_FILES[name]) end
    end)
    coroutine.resume(loopThread)
end

local function stopLoop()
    loopThread = nil
    currentLoop = nil
end

-- TARDIS logic
local tardisState = {powered=false, activeLoop=nil}
local cloisterActive, bipActive = false, false

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

-- Buttons with proper coords
local buttons = {
    {label="POWER ON", action=powerOn},
    {label="POWER OFF", action=powerOff},
    {label="TAKEOFF", action=takeOff},
    {label="LANDING", action=landing},
    {label="SHORT FLIGHT", action=shortFlight},
    {label="DENIED", action=denied},
    {label="CLOISTER", action=toggleCloister},
    {label="ERROR BIP", action=toggleBip},
    {label="OPEN DOOR", action=openDoor},
    {label="CLOSE DOOR", action=closeDoor},
}

-- Layout buttons in two columns below status (starting line 6)
local function layoutButtons()
    local startX1, startX2, startY = 2, 25, 6
    for i,b in ipairs(buttons) do
        b.x = (i%2==1) and startX1 or startX2
        b.y = startY + math.floor((i-1)/2)
        b.width = #b.label + 2
    end
end
layoutButtons()

local function drawButton(b)
    term.setCursorPos(b.x, b.y)
    term.setBackgroundColor(ORANGE)
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
    for _,b in ipairs(buttons) do drawButton(b) end
end

local function handleClick(x,y)
    for _, b in ipairs(buttons) do
        if x >= b.x and x <= (b.x+b.width-1) and y == b.y then
            b.action()
            redraw()
        end
    end
end

redraw()
while true do
    local event, button, x, y = os.pullEvent()
    if event == "mouse_click" then
