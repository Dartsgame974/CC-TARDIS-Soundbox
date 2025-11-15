-- Artron OS – Type 40 TARDIS (revamped)
-- Sons streamés via shell.run("austream", url")
-- Interface orange/noir avec logique sonore réaliste

local speaker = peripheral.find("speaker")
if not speaker then error("No speaker found!") end

local baseURL = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/"

-- Sons
local sounds = {
    startup = baseURL.."startup_tardis.wav",
    shutdown = baseURL.."shutdowntardis.wav",
    emergency = baseURL.."emergencyshutdown.wav",
    ambiance = baseURL.."ambience%20tardis.wav",
    takeoff = baseURL.."tardistakeoff.wav",
    flight_loop = baseURL.."tardis_flight_loop.wav",
    landing = baseURL.."landing.wav",
    mater = baseURL.."tardismater.wav",
    door_open = baseURL.."door_open.wav",
    door_close = baseURL.."close_door.wav",
    cloister = baseURL.."cloister_ding.wav",
    bipsound = baseURL.."bip_sound_error_1.wav",
    denied = baseURL.."denied_flight.wav"
}

-- État des sons
local ambianceStop, flightStop, errorStop
local state = {
    inFlight = false,
    ambiancePlaying = false
}

-- Jouer un son simple
local function play(url)
    shell.run("austream", url)
end

-- Boucle son en parallèle
local function loop(url)
    local running = true
    local co = coroutine.create(function()
        while running do
            shell.run("austream", url)
            os.sleep(0.1)
        end
    end)
    coroutine.resume(co)
    return function() running=false end
end

-- TARDIS Logic
local function startAmbiance()
    if ambianceStop then ambianceStop() end
    ambianceStop = loop(sounds.ambiance)
    state.ambiancePlaying = true
end

local function startup()
    if ambianceStop then ambianceStop() end
    if flightStop then flightStop() end
    play(sounds.startup)
    os.sleep(3) -- approximation du temps startup
    startAmbiance()
end

local function shutdown()
    if ambianceStop then ambianceStop() end
    if flightStop then flightStop() end
    state.inFlight = false
    state.ambiancePlaying = false
    play(sounds.shutdown)
end

local function emergency()
    if ambianceStop then ambianceStop() end
    if flightStop then flightStop() end
    state.inFlight = false
    state.ambiancePlaying = false
    play(sounds.emergency)
end

local function takeoff()
    if ambianceStop then ambianceStop() end
    play(sounds.takeoff)
    os.sleep(2) -- approximatif du son takeoff
    if flightStop then flightStop() end
    flightStop = loop(sounds.flight_loop)
    state.inFlight = true
end

local function materialize()
    if flightStop then
        flightStop()
        flightStop = nil
    end
    state.inFlight = false
    local choice = math.random(2)
    if choice == 1 then play(sounds.landing)
    else play(sounds.mater) end
    os.sleep(3) -- approximation durée mater/landing
    startAmbiance()
end

local function doorOpen() play(sounds.door_open) end
local function doorClose() play(sounds.door_close) end
local function cloisterDing() loop(sounds.cloister) end
local function bipsound() loop(sounds.bipsound) end
local function deniedFlight() play(sounds.denied) end

-- Interface graphique améliorée
local buttons = {
    {x=2, y=4, w=20, h=3, text="Startup", action=startup},
    {x=2, y=8, w=20, h=3, text="Shutdown", action=shutdown},
    {x=2, y=12, w=20, h=3, text="Emergency", action=emergency},
    {x=25, y=4, w=20, h=3, text="Takeoff", action=takeoff},
    {x=25, y=8, w=20, h=3, text="Materialize", action=materialize},
    {x=2, y=16, w=20, h=3, text="Door Open", action=doorOpen},
    {x=25, y=12, w=20, h=3, text="Door Close", action=doorClose},
    {x=2, y=20, w=20, h=3, text="Cloister Ding", action=cloisterDing},
    {x=25, y=16, w=20, h=3, text="Bip Sound", action=bipsound},
    {x=25, y=20, w=20, h=3, text="Denied Flight", action=deniedFlight}
}

-- Dessiner boutons
local function drawButton(btn, pressed)
    local bg, fg = colors.black, colors.orange
    if pressed then bg, fg = colors.orange, colors.black end
    paintutils.drawFilledBox(btn.x, btn.y, btn.x+btn.w-1, btn.y+btn.h-1, bg)
    term.setCursorPos(btn.x + math.floor((btn.w - #btn.text)/2), btn.y + math.floor(btn.h/2))
    term.setTextColor(fg)
    term.write(btn.text)
end

-- Dessiner UI
local function drawUI()
    term.clear()
    local w,h = term.getSize()
    local title = "Artron OS – Type 40"
    term.setTextColor(colors.orange)
    term.setCursorPos(math.floor((w-#title)/2)+1, 1)
    term.write(title)

    -- Dessiner boutons
    for _, btn in ipairs(buttons) do drawButton(btn,false) end

    -- Forcer la barre de lecture tout en bas
    paintutils.drawFilledBox(1, h, w, h, colors.black)
end

-- Gestion touch
local function handleTouch(x, y)
    for _, btn in ipairs(buttons) do
        if x>=btn.x and x<=btn.x+btn.w-1 and y>=btn.y and y<=btn.y+btn.h-1 then
            drawButton(btn,true)
            btn.action()
            os.sleep(0.1)
            drawButton(btn,false)
            break
        end
    end
end

-- Lancer interface
drawUI()
while true do
    local event, side, x, y = os.pullEvent("mouse_click")
    handleTouch(x,y)
end
