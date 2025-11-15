-- TARDIS SOUNDBOARD v2.0 - Streaming avec AUKit
-- Interface terminal native pour ComputerCraft/CC:Tweaked

local BASE_URL = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/dfpwm/"
local AUKIT_URL = "https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua"

-- Liste des sons
local SOUNDS = {
    startup = "startup_tardis.dfpwm",
    ambiance = "ambiance.dfpwm",
    flight = "tardis_flight_loop.dfpwm",
    bip = "bip_sound_error_1.dfpwm",
    short_flight = "short_flight.dfpwm",
    emergency = "emergencyshutdown.dfpwm",
    landing = "landing.dfpwm",
    takeoff = "tardistakeoff.dfpwm",
    denied = "denied_flight.dfpwm",
    shutdown = "shutdowntardis.dfpwm",
    door_close = "close_door.dfpwm",
    door_open = "door_open.dfpwm",
    cloister = "cloister.dfpwm"
}

-- État global
local state = {
    powered = false,
    ambiance = false,
    flight = false,
    cloister = false,
    bip = false,
    speakers = {}
}

-- Contrôle des loops et audio
local audioControl = {
    currentLoop = nil,
    stopLoop = false,
    queue = {}
}

local aukit = nil

-- ========================================
-- INITIALISATION AUKIT
-- ========================================

local function downloadAukit()
    if fs.exists("aukit.lua") then
        return true
    end
    
    print("Téléchargement d'AUKit...")
    local response = http.get(AUKIT_URL)
    
    if not response then
        print("Erreur: impossible de télécharger AUKit")
        return false
    end
    
    local file = fs.open("aukit.lua", "w")
    file.write(response.readAll())
    file.close()
    response.close()
    
    print("AUKit téléchargé!")
    return true
end

local function initAukit()
    if not downloadAukit() then
        return false
    end
    
    aukit = require("aukit")
    return true
end

-- ========================================
-- GESTION AUDIO
-- ========================================

local function findSpeakers()
    local speakers = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "speaker" then
            table.insert(speakers, peripheral.wrap(name))
        end
    end
    return speakers
end

local function playAudioStream(url, loop, controlKey)
    if #state.speakers == 0 then
        return
    end
    
    -- Streaming HTTP
    local response = http.get(url, nil, true)
    if not response then
        print("Erreur: impossible de streamer " .. url)
        return
    end
    
    repeat
        local audio = aukit.stream.dfpwm(function()
            return response.read(48000)
        end)
        
        -- Lecture sur tous les speakers
        for chunk in audio do
            if controlKey and not audioControl[controlKey] then
                response.close()
                return
            end
            
            for _, speaker in ipairs(state.speakers) do
                while not speaker.playAudio(chunk) do
                    os.pullEvent("speaker_audio_empty")
                end
            end
        end
        
        response.close()
        
        -- Si c'est une boucle, on recommence
        if loop and controlKey and audioControl[controlKey] then
            response = http.get(url, nil, true)
        end
    until not loop or not audioControl[controlKey] or not response
    
    if response then
        response.close()
    end
end

local function queueAudio(soundKey, loop, callback)
    table.insert(audioControl.queue, {
        url = BASE_URL .. SOUNDS[soundKey],
        loop = loop,
        controlKey = loop and soundKey or nil,
        callback = callback
    })
    os.queueEvent("_audio_queue")
end

-- ========================================
-- THREAD AUDIO
-- ========================================

local function audioThread()
    while true do
        os.pullEvent("_audio_queue")
        
        while #audioControl.queue > 0 do
            local item = table.remove(audioControl.queue, 1)
            
            if item.loop then
                audioControl[item.controlKey] = true
                state[item.controlKey] = true
            end
            
            playAudioStream(item.url, item.loop, item.controlKey)
            
            if item.callback then
                item.callback()
            end
        end
    end
end

-- ========================================
-- CONTRÔLE DES LOOPS
-- ========================================

local function startLoop(soundKey)
    if not audioControl[soundKey] then
        queueAudio(soundKey, true)
    end
end

local function stopLoop(soundKey)
    audioControl[soundKey] = false
    state[soundKey] = false
end

local function stopAllLoops()
    stopLoop("ambiance")
    stopLoop("flight")
    stopLoop("cloister")
    stopLoop("bip")
end

-- ========================================
-- LOGIQUE TARDIS
-- ========================================

local function tardisStartup()
    if state.powered then return end
    state.powered = true
    
    queueAudio("startup", false, function()
        startLoop("ambiance")
    end)
end

local function tardisDematerialization()
    if not state.powered then return end
    
    stopLoop("ambiance")
    queueAudio("takeoff", false, function()
        startLoop("flight")
    end)
end

local function tardisLanding()
    if not state.powered then return end
    
    stopLoop("flight")
    queueAudio("landing", false, function()
        startLoop("ambiance")
    end)
end

local function tardisDeniedFlight()
    if not state.powered then return end
    queueAudio("denied", false)
end

local function tardisShortFlight()
    if not state.powered then return end
    queueAudio("short_flight", false)
end

local function tardisShutdown()
    if not state.powered then return end
    
    stopAllLoops()
    queueAudio("shutdown", false, function()
        state.powered = false
    end)
end

local function toggleCloister()
    if not state.powered then return end
    
    if state.cloister then
        stopLoop("cloister")
    else
        startLoop("cloister")
    end
end

local function toggleBip()
    if not state.powered then return end
    
    if state.bip then
        stopLoop("bip")
    else
        startLoop("bip")
    end
end

local function doorOpen()
    if not state.powered then return end
    queueAudio("door_open", false)
end

local function doorClose()
    if not state.powered then return end
    queueAudio("door_close", false)
end

-- ========================================
-- INTERFACE TERMINAL
-- ========================================

local function drawButton(x, y, width, text, active)
    term.setCursorPos(x, y)
    
    if active then
        term.setBackgroundColor(colors.lime)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
    end
    
    local padding = math.floor((width - #text) / 2)
    term.write(string.rep(" ", padding) .. text .. string.rep(" ", width - padding - #text))
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

local function isClickInButton(x, y, btnX, btnY, btnWidth)
    return x >= btnX and x < btnX + btnWidth and y == btnY
end

local function drawInterface()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Titre
    term.setCursorPos(math.floor(w/2 - 10), 2)
    term.setTextColor(colors.blue)
    term.write("TARDIS SOUNDBOARD v2")
    
    -- Statut
    term.setCursorPos(2, 4)
    term.setTextColor(colors.white)
    term.write("Statut: ")
    term.setTextColor(state.powered and colors.lime or colors.red)
    term.write(state.powered and "ACTIF" or "INACTIF")
    
    term.setTextColor(colors.white)
    term.setCursorPos(2, 5)
    term.write("Haut-parleurs: ")
    term.setTextColor(#state.speakers > 0 and colors.lime or colors.red)
    term.write(#state.speakers > 0 and (#state.speakers .. " connecte(s)") or "Aucun")
    
    -- Boutons principaux
    term.setTextColor(colors.white)
    drawButton(2, 7, 14, "POWER ON", false)
    drawButton(18, 7, 14, "POWER OFF", false)
    
    drawButton(2, 9, 14, "DEPART", state.powered)
    drawButton(18, 9, 14, "ATTERRIR", state.powered)
    
    drawButton(2, 11, 14, "VOL COURT", state.powered)
    drawButton(18, 11, 14, "VOL REFUSE", state.powered)
    
    -- Toggles
    drawButton(2, 13, 14, "CLOISTER", state.cloister)
    drawButton(18, 13, 14, "BIP ERREUR", state.bip)
    
    -- Portes
    drawButton(2, 15, 14, "OUVRIR", state.powered)
    drawButton(18, 15, 14, "FERMER", state.powered)
    
    -- État des loops
    term.setCursorPos(2, 17)
    term.setTextColor(colors.yellow)
    term.write("Loops actives:")
    
    term.setCursorPos(2, 18)
    term.setTextColor(colors.white)
    if state.ambiance then term.write("[Ambiance] ") end
    if state.flight then term.write("[Vol] ") end
    if state.cloister then term.write("[Cloister] ") end
    if state.bip then term.write("[Bip] ") end
    
    -- File d'attente
    term.setCursorPos(2, 19)
    term.setTextColor(colors.lightGray)
    if #audioControl.queue > 0 then
        term.write("File: " .. #audioControl.queue .. " son(s)")
    end
    
    -- Instructions
    term.setCursorPos(2, h - 1)
    term.setTextColor(colors.lightGray)
    term.write("Streaming audio via AUKit - Cliquez pour controler")
end

local function handleClick(x, y)
    if isClickInButton(x, y, 2, 7, 14) then
        tardisStartup()
    elseif isClickInButton(x, y, 18, 7, 14) then
        tardisShutdown()
    elseif isClickInButton(x, y, 2, 9, 14) then
        tardisDematerialization()
    elseif isClickInButton(x, y, 18, 9, 14) then
        tardisLanding()
    elseif isClickInButton(x, y, 2, 11, 14) then
        tardisShortFlight()
    elseif isClickInButton(x, y, 18, 11, 14) then
        tardisDeniedFlight()
    elseif isClickInButton(x, y, 2, 13, 14) then
        toggleCloister()
    elseif isClickInButton(x, y, 18, 13, 14) then
        toggleBip()
    elseif isClickInButton(x, y, 2, 15, 14) then
        doorOpen()
    elseif isClickInButton(x, y, 18, 15, 14) then
        doorClose()
    end
end

local function interfaceLoop()
    drawInterface()
    
    while true do
        local event, button, x, y = os.pullEvent()
        
        if event == "mouse_click" then
            handleClick(x, y)
            drawInterface()
        elseif event == "term_resize" then
            drawInterface()
        elseif event == "_audio_queue" then
            drawInterface()
        end
    end
end

-- ========================================
-- MAIN
-- ========================================

local function main()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("=" .. string.rep("=", 40))
    print(" TARDIS SOUNDBOARD v2.0 - Streaming")
    print("=" .. string.rep("=", 40))
    print("")
    
    -- Initialisation AUKit
    print("Initialisation d'AUKit...")
    if not initAukit() then
        print("ERREUR: Impossible d'initialiser AUKit")
        print("Appuyez sur une touche pour quitter...")
        os.pullEvent("key")
        return
    end
    print("AUKit charge!")
    
    -- Recherche des haut-parleurs
    print("")
    print("Recherche des haut-parleurs...")
    state.speakers = findSpeakers()
    
    if #state.speakers == 0 then
        print("ATTENTION: Aucun haut-parleur trouve!")
        print("Connectez un haut-parleur et redemarrez.")
        print("")
        print("Appuyez sur une touche pour continuer quand meme...")
        os.pullEvent("key")
    else
        print("Trouve: " .. #state.speakers .. " haut-parleur(s)")
        sleep(1)
    end
    
    -- Lancement en parallèle
    parallel.waitForAny(
        interfaceLoop,
        audioThread
    )
end

-- Lancement
main()
