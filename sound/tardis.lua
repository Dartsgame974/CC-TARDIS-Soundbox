--==============================--
--      TARDIS SOUNDBOARD      --
--     Interface sans API UI    --
--==============================--

local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

if not speaker then
    error("Aucun haut-parleur détecté.")
end

--==============================--
--        AUDIO SYSTEM          --
--==============================--

local sounds = {
    startup       = "startup_tardis.dfpwm",
    ambiance      = "ambiance.dfpwm",
    takeoff       = "tardistakeoff.dfpwm",
    flight        = "tardis_flight_loop.dfpwm",
    landing       = "landing.dfpwm",
    cloister      = "cloister.dfpwm",
    bip           = "bip_sound_error_1.dfpwm",
    denied        = "denied_flight.dfpwm",
    short         = "short_flight.dfpwm",
    emergency     = "emergencyshutdown.dfpwm",
    shutdown      = "shutdowntardis.dfpwm",
    door_open     = "door_open.dfpwm",
    close_door    = "close_door.dfpwm"
}

local decoded_cache = {}
local activeLoops = {
    ambiance = false,
    flight = false,
    cloister = false,
    bip = false
}

-- Téléchargement automatique si fichier absent
local function ensureSound(name)
    if not fs.exists(name) then
        shell.run(
            "wget",
            "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/dfpwm/" .. name,
            name
        )
    end
end

for _, f in pairs(sounds) do ensureSound(f) end

-- Décodage / buffer
local function getDecoded(name)
    if decoded_cache[name] then return decoded_cache[name] end

    local decoder = dfpwm.make_decoder()
    local handle = fs.open(name, "rb")
    local raw = handle.readAll()
    handle.close()

    local decoded = decoder(raw)
    decoded_cache[name] = decoded
    return decoded
end

-- Lecture non bloquante
local function playAudio(decoded)
    while not speaker.playAudio(decoded) do
        os.pullEvent("speaker_audio_empty")
    end
end

-- Gestion des loops
local function loopManager()
    while true do
        if activeLoops.ambiance then playAudio(getDecoded(sounds.ambiance)) end
        if activeLoops.flight then playAudio(getDecoded(sounds.flight)) end
        if activeLoops.cloister then playAudio(getDecoded(sounds.cloister)) end
        if activeLoops.bip then playAudio(getDecoded(sounds.bip)) end
        sleep(0)
    end
end

parallel.waitForAny(loopManager, function()
    --==============================--
    --        INTERFACE UI         --
    --==============================--

    local w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.orange)
    term.clear()

    local function centerText(y, text)
        term.setCursorPos(math.floor(w/2 - #text/2), y)
        term.write(text)
    end

    -- Dessin d'un bouton simple
    local function drawButton(x, y, label)
        term.setCursorPos(x, y)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.black)
        term.clearLine()
        term.setCursorPos(x, y)
        term.write(label)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.orange)
    end

    -- Tableau des boutons
    local buttons = {}
    local function addButton(x, y, label, action)
        table.insert(buttons, {
            x = x,
            y = y,
            label = label,
            action = action
        })
        drawButton(x, y, label)
    end

    --==============================--
    --       LOGIQUE DU TARDIS     --
    --==============================--

    local powered = false

    local function stopAllLoops()
        for k in pairs(activeLoops) do activeLoops[k] = false end
    end

    local function startup()
        stopAllLoops()
        playAudio(getDecoded(sounds.startup))
        activeLoops.ambiance = true
    end

    local function shutdown()
        stopAllLoops()
        playAudio(getDecoded(sounds.shutdown))
    end

    local function demat()
        stopAllLoops()
        playAudio(getDecoded(sounds.takeoff))
        activeLoops.flight = true
    end

    local function land()
        stopAllLoops()
        playAudio(getDecoded(sounds.landing))
        activeLoops.ambiance = true
    end

    local function denied()
        stopAllLoops()
        playAudio(getDecoded(sounds.denied))
    end

    local function short_flight()
        stopAllLoops()
        playAudio(getDecoded(sounds.short))
        activeLoops.ambiance = true
    end

    local function toggleCloister()
        activeLoops.cloister = not activeLoops.cloister
    end

    local function toggleBip()
        activeLoops.bip = not activeLoops.bip
    end

    --==============================--
    --       BOUTONS UI            --
    --==============================--

    centerText(1, "ARTRON OS - TYPE 40")

    addButton(2, 3, "POWER", function()
        powered = not powered
        if powered then startup()
        else shutdown() end
    end)

    addButton(2, 5, "DEMAT", demat)
    addButton(2, 7, "LANDING", land)
    addButton(2, 9, "DENIED", denied)
    addButton(2, 11, "SHORT FLIGHT", short_flight)
    addButton(2, 13, "CLOISTER", toggleCloister)
    addButton(2, 15, "BIP", toggleBip)
    addButton(2, 17, "DOOR OPEN", function()
        playAudio(getDecoded(sounds.door_open))
    end)
    addButton(2, 19, "DOOR CLOSE", function()
        playAudio(getDecoded(sounds.close_door))
    end)

    --==============================--
    --       EVENT LOOP UI         --
    --==============================--

    while true do
        local ev, btn, x, y = os.pullEvent("mouse_click")
        for _, b in ipairs(buttons) do
            if y == b.y and x >= b.x and x <= b.x + #b.label then
                b.action()
            end
        end
    end
end)
