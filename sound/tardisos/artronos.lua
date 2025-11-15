-- ARTRON OS TYPE 40 - TARDIS SOUNDBOARD v3.0
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
    currentLoop = nil, -- ambiance, flight, cloister, ou bip
    speakers = {},
    playing = false
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

-- Jouer un son unique (non-loop)
local function playSound(soundKey, callback)
    if #state.speakers == 0 then
        if callback then callback() end
        return
    end
    
    state.playing = true
    os.queueEvent("_play_sound", soundKey, callback)
end

-- Démarrer une loop (arrête toute autre loop en cours)
local function startLoop(loopKey)
    state.currentLoop = loopKey
    state.playing = true
    os.queueEvent("_start_loop", loopKey)
end

-- Arrêter la loop actuelle
local function stopLoop()
    state.currentLoop = nil
end

-- ========================================
-- THREAD AUDIO
-- ========================================

local function audioThread()
    while true do
        local event, param1, param2 = os.pullEvent()
        
        if event == "_play_sound" then
            local soundKey = param1
            local callback = param2
            
            local url = BASE_URL .. SOUNDS[soundKey]
            local response = http.get(url, nil, true)
            
            if response then
                local audio = aukit.stream.dfpwm(function()
                    return response.read(48000)
                end)
                
                for chunk in audio do
                    -- Vérifier si on doit arrêter
                    if state.currentLoop then
                        response.close()
                        state.playing = false
                        os.queueEvent("_redraw")
                        break
                    end
                    
                    for _, speaker in ipairs(state.speakers) do
                        while not speaker.playAudio(chunk) do
                            os.pullEvent("speaker_audio_empty")
                        end
                    end
                end
                
                response.close()
                state.playing = false
                os.queueEvent("_redraw")
                
                -- Callback après la fin du son
                if callback then
                    callback()
                end
            end
            
        elseif event == "_start_loop" then
            local loopKey = param1
            
            -- Boucle infinie tant que c'est la loop active
            while state.currentLoop == loopKey do
                local url = BASE_URL .. SOUNDS[loopKey]
                local response = http.get(url, nil, true)
                
                if response then
                    local audio = aukit.stream.dfpwm(function()
                        return response.read(48000)
                    end)
                    
                    for chunk in audio do
                        -- Vérifier si on doit arrêter cette loop
                        if state.currentLoop ~= loopKey then
                            response.close()
                            break
                        end
                        
                        for _, speaker in ipairs(state.speakers) do
                            while not speaker.playAudio(chunk) do
                                if state.currentLoop ~= loopKey then
                                    response.close()
                                    break
                                end
                                os.pullEvent("speaker_audio_empty")
                            end
                        end
                    end
                    
                    response.close()
                else
                    break
                end
                
                -- Petite pause avant de reboucler
                sleep(0.05)
            end
            
            state.playing = false
            os.queueEvent("_redraw")
        end
    end
end

-- ========================================
-- LOGIQUE TARDIS
-- ========================================

local function tardisStartup()
    if state.powered then return end
    state.powered = true
    
    -- Jouer startup, puis lancer ambiance
    playSound("startup", function()
        startLoop("ambiance")
    end)
end

local function tardisDematerialization()
    if not state.powered then return end
    
    -- Arrêter toute loop, jouer takeoff, puis flight loop
    stopLoop()
    playSound("takeoff", function()
        startLoop("flight")
    end)
end

local function tardisLanding()
    if not state.powered then return end
    
    -- Arrêter flight, jouer landing, puis ambiance
    stopLoop()
    playSound("landing", function()
        startLoop("ambiance")
    end)
end

local function tardisDeniedFlight()
    if not state.powered then return end
    
    -- Sauvegarder la loop actuelle
    local previousLoop = state.currentLoop
    stopLoop()
    
    playSound("denied", function()
        if previousLoop then
            startLoop(previousLoop)
        end
    end)
end

local function tardisShortFlight()
    if not state.powered then return end
    
    local previousLoop = state.currentLoop
    stopLoop()
    
    playSound("short_flight", function()
        if previousLoop then
            startLoop(previousLoop)
        end
    end)
end

local function tardisShutdown()
    if not state.powered then return end
    
    stopLoop()
    playSound("shutdown", function()
        state.powered = false
    end)
end

local function toggleCloister()
    if not state.powered then return end
    
    if state.currentLoop == "cloister" then
        stopLoop()
        startLoop("ambiance")
    else
        stopLoop()
        startLoop("cloister")
    end
end

local function toggleBip()
    if not state.powered then return end
    
    if state.currentLoop == "bip" then
        stopLoop()
        startLoop("ambiance")
    else
        stopLoop()
        startLoop("bip")
    end
end

local function doorOpen()
    if not state.powered then return end
    
    local previousLoop = state.currentLoop
    stopLoop()
    
    playSound("door_open", function()
        if previousLoop then
            startLoop(previousLoop)
        end
    end)
end

local function doorClose()
    if not state.powered then return end
    
    local previousLoop = state.currentLoop
    stopLoop()
    
    playSound("door_close", function()
        if previousLoop then
            startLoop(previousLoop)
        end
    end)
end

-- ========================================
-- INTERFACE TERMINAL
-- ========================================

local function drawButton(x, y, width, text, active)
    term.setCursorPos(x, y)
    
    if active then
        term.setBackgroundColor(colors.orange)
        term.setTextColor(colors.white)
    else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
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
    term.setCursorPos(math.floor(w/2 - 12), 2)
    term.setTextColor(colors.orange)
    term.write("ARTRON OS TYPE 40")
    
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
    drawButton(2, 7, 14, "POWER ON", state.powered and not state.playing)
    drawButton(18, 7, 14, "POWER OFF", false)
    
    drawButton(2, 9, 14, "DEPART", state.powered and state.currentLoop == "flight")
    drawButton(18, 9, 14, "ATTERRIR", state.powered)
    
    drawButton(2, 11, 14, "VOL COURT", state.powered)
    drawButton(18, 11, 14, "VOL REFUSE", state.powered)
    
    -- Toggles
    drawButton(2, 13, 14, "CLOISTER", state.powered and state.currentLoop == "cloister")
    drawButton(18, 13, 14, "BIP ERREUR", state.powered and state.currentLoop == "bip")
    
    -- Portes
    drawButton(2, 15, 14, "OUVRIR", state.powered)
    drawButton(18, 15, 14, "FERMER", state.powered)
    
    -- État de la loop active
    term.setCursorPos(2, 17)
    term.setTextColor(colors.orange)
    term.write("Loop active: ")
    term.setTextColor(colors.white)
    if state.currentLoop then
        term.write(state.currentLoop:upper())
    else
        term.setTextColor(colors.gray)
        term.write("Aucune")
    end
    
    -- Instructions
    term.setCursorPos(2, h - 1)
    term.setTextColor(colors.lightGray)
    term.write("Streaming audio via AUKit - Un seul son a la fois")
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
    
    drawInterface()
end

local function interfaceLoop()
    drawInterface()
    
    while true do
        local event, button, x, y = os.pullEvent()
        
        if event == "mouse_click" then
            handleClick(x, y)
        elseif event == "term_resize" then
            drawInterface()
        elseif event == "_redraw" then
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
    
    term.setTextColor(colors.orange)
    print("=" .. string.rep("=", 45))
    print(" ARTRON OS TYPE 40 - TARDIS SOUNDBOARD v3.0")
    print("=" .. string.rep("=", 45))
    term.setTextColor(colors.white)
    print("")
    
    -- Initialisation AUKit
    print("Initialisation d'AUKit...")
    if not initAukit() then
        term.setTextColor(colors.red)
        print("ERREUR: Impossible d'initialiser AUKit")
        term.setTextColor(colors.white)
        print("Appuyez sur une touche pour quitter...")
        os.pullEvent("key")
        return
    end
    term.setTextColor(colors.lime)
    print("AUKit charge!")
    term.setTextColor(colors.white)
    
    -- Recherche des haut-parleurs
    print("")
    print("Recherche des haut-parleurs...")
    state.speakers = findSpeakers()
    
    if #state.speakers == 0 then
        term.setTextColor(colors.red)
        print("ATTENTION: Aucun haut-parleur trouve!")
        term.setTextColor(colors.white)
        print("Connectez un haut-parleur et redemarrez.")
        print("")
        print("Appuyez sur une touche pour continuer quand meme...")
        os.pullEvent("key")
    else
        term.setTextColor(colors.lime)
        print("Trouve: " .. #state.speakers .. " haut-parleur(s)")
        term.setTextColor(colors.white)
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
