-- TARDIS Soundbox avec Austream depuis GitHub
local austream = require("austream")
local speaker = peripheral.find("speaker")
if not speaker then
    error("Aucun speaker trouvé !")
end

-- Base URL GitHub (raw)
local baseURL = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/"

-- Sons
local sounds = {
    startup = baseURL .. "startup_tardis.wav",
    shutdown = baseURL .. "shutdowntardis.wav",
    emergency = baseURL .. "emergencyshutdown.wav",
    ambiance = baseURL .. "ambience_tardis.wav",
    flight = baseURL .. "tardis_flight_loop.wav",
    landing = baseURL .. "landing.wav",
    mater = baseURL .. "tardismater.wav",
    cloister = baseURL .. "cloister_ding.wav",
    bip_error = baseURL .. "bip_sound_error_1.wav",
}

-- États
local ambianceHandle
local flightHandle
local errorHandle
local errorActive = false
local shutdownPressCount = 0

-- Fonctions utilitaires
local function playLoop(url)
    return austream(url, {speaker = speaker, loop = true})
end

local function playOnce(url)
    return austream(url, {speaker = speaker, loop = false})
end

local function stopHandle(handle)
    if handle then handle:stop() end
end

-- Actions
local function startup()
    stopHandle(errorHandle)
    errorActive = false
    shutdownPressCount = 0
    playOnce(sounds.startup)
    stopHandle(ambianceHandle)
    ambianceHandle = playLoop(sounds.ambiance)
end

local function shutdown()
    stopHandle(flightHandle)
    stopHandle(ambianceHandle)
    stopHandle(errorHandle)
    playOnce(sounds.shutdown)
    errorActive = false
    shutdownPressCount = 0
end

local function emergencyShutdown()
    stopHandle(flightHandle)
    stopHandle(ambianceHandle)
    stopHandle(errorHandle)
    playOnce(sounds.emergency)
    errorActive = false
    shutdownPressCount = 0
end

local function takeoff()
    stopHandle(ambianceHandle)
    flightHandle = playLoop(sounds.flight)
end

local function materialize()
    stopHandle(flightHandle)
    if math.random(2) == 1 then
        playOnce(sounds.landing)
    else
        playOnce(sounds.mater)
    end
    ambianceHandle = playLoop(sounds.ambiance)
end

local function triggerError()
    if errorActive then return end
    errorActive = true
    shutdownPressCount = 0
    errorHandle = playLoop(sounds.cloister)
    austream(sounds.bip_error, {speaker = speaker, loop = true})
end

-- Erreurs aléatoires
local function errorLoop()
    while true do
        sleep(3600)
        if math.random() < 0.1 then
            triggerError()
        end
    end
end

-- Interface simple
local function drawButton(x, y, w, h, text, pressed)
    local bg, fg = colors.black, colors.orange
    if pressed then bg, fg = colors.orange, colors.black end
    paintutils.drawFilledBox(x, y, x+w-1, y+h-1, bg)
    term.setCursorPos(x + math.floor((w - #text)/2), y + math.floor(h/2))
    term.setTextColor(fg)
    term.write(text)
end

local function drawUI()
    term.clear()
    drawButton(2,2,20,3,"Startup",false)
    drawButton(2,6,20,3,"Shutdown",false)
    drawButton(2,10,20,3,"Emergency",false)
    drawButton(25,2,20,3,"Takeoff",false)
    drawButton(25,6,20,3,"Materialize",false)
end

local function handleTouch(x, y)
    if x>=2 and x<=21 and y>=2 and y<=4 then startup()
    elseif x>=2 and x<=21 and y>=6 and y<=8 then
        if errorActive then
            shutdownPressCount = shutdownPressCount + 1
            if shutdownPressCount >= 3 then
                errorActive = false
                stopHandle(errorHandle)
            end
        else
            shutdown()
        end
    elseif x>=2 and x<=21 and y>=10 and y<=12 then emergencyShutdown()
    elseif x>=25 and x<=44 and y>=2 and y<=4 then takeoff()
    elseif x>=25 and x<=44 and y>=6 and y<=8 then materialize()
    end
end

-- Main
drawUI()
parallel.waitForAny(
    errorLoop,
    function()
        while true do
            local event, side, x, y = os.pullEvent("mouse_click")
            handleTouch(x, y)
        end
    end
)
