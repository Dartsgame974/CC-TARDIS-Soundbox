-- Artron OS – Type 40 (TARDIS Soundbox)
-- Interface graphique orange sur noir avec boutons cliquables
-- Sons streamés depuis GitHub via shell.run("austream", url")

local speaker = peripheral.find("speaker")
if not speaker then
    error("Aucun speaker trouvé !")
end

-- Base URL GitHub (raw)
local baseURL = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/"

-- Sons
local sounds = {
    startup = baseURL.."startup_tardis.wav",
    shutdown = baseURL.."shutdowntardis.wav",
    emergency = baseURL.."emergencyshutdown.wav",
    ambiance = baseURL.."ambience_tardis.wav",
    flight = baseURL.."tardis_flight_loop.wav",
    landing = baseURL.."landing.wav",
    mater = baseURL.."tardismater.wav",
    cloister = baseURL.."cloister_ding.wav",
    bip_error = baseURL.."bip_sound_error_1.wav",
}

-- État des sons
local ambianceRunning = false
local flightRunning = false

-- Fonctions de lecture
local function playOnce(url)
    shell.run("austream", url)
end

local function playLoop(url)
    -- Boucle simple : on lance austream en parallèle pour simuler le loop
    local running = true
    local co = coroutine.create(function()
        while running do
            shell.run("austream", url)
            os.sleep(0.1)
        end
    end)
    coroutine.resume(co)
    return function() running = false end -- retourne une fonction pour arrêter la boucle
end

-- Actions TARDIS
local function startup()
    if ambianceRunning then ambianceRunning() end
    playOnce(sounds.startup)
    ambianceRunning = playLoop(sounds.ambiance)
end

local function shutdown()
    if ambianceRunning then ambianceRunning() end
    if flightRunning then flightRunning() end
    playOnce(sounds.shutdown)
end

local function emergencyShutdown()
    if ambianceRunning then ambianceRunning() end
    if flightRunning then flightRunning() end
    playOnce(sounds.emergency)
end

local function takeoff()
    if ambianceRunning then ambianceRunning() end
    flightRunning = playLoop(sounds.flight)
end

local function materialize()
    if flightRunning then flightRunning() end
    if math.random(2) == 1 then
        playOnce(sounds.landing)
    else
        playOnce(sounds.mater)
    end
    ambianceRunning = playLoop(sounds.ambiance)
end

-- Interface graphique
local buttons = {
    {x=2, y=4, w=20, h=3, text="Startup", action=startup},
    {x=2, y=8, w=20, h=3, text="Shutdown", action=shutdown},
    {x=2, y=12, w=20, h=3, text="Emergency", action=emergencyShutdown},
    {x=25, y=4, w=20, h=3, text="Takeoff", action=takeoff},
    {x=25, y=8, w=20, h=3, text="Materialize", action=materialize},
}

local function drawButton(btn, pressed)
    local bg, fg = colors.black, colors.orange
    if pressed then bg, fg = colors.orange, colors.black end
    paintutils.drawFilledBox(btn.x, btn.y, btn.x+btn.w-1, btn.y+btn.h-1, bg)
    term.setCursorPos(btn.x + math.floor((btn.w - #btn.text)/2), btn.y + math.floor(btn.h/2))
    term.setTextColor(fg)
    term.write(btn.text)
end

local function drawUI()
    term.clear()
    -- Titre
    local w,h = term.getSize()
    local title = "Artron OS – Type 40"
    term.setTextColor(colors.orange)
    term.setCursorPos(math.floor((w-#title)/2)+1, 1)
    term.write(title)

    -- Boutons
    for _, btn in ipairs(buttons) do
        drawButton(btn, false)
    end
end

local function handleTouch(x, y)
    for _, btn in ipairs(buttons) do
        if x>=btn.x and x<=btn.x+btn.w-1 and y>=btn.y and y<=btn.y+btn.h-1 then
            drawButton(btn, true)
            btn.action()
            os.sleep(0.1)
            drawButton(btn, false)
            break
        end
    end
end

-- Main
drawUI()

-- Boucle événementielle
while true do
    local event, side, x, y = os.pullEvent("mouse_click")
    handleTouch(x, y)
end
