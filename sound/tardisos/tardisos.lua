-- TARDIS SOUNDBOARD v1.0
-- Interface terminal native pour ComputerCraft/CC:Tweaked

local BASE_URL = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/dfpwm/"
local SOUNDS_DIR = "tardis_sounds/"

-- Liste des sons
local SOUNDS = {
    "startup_tardis.dfpwm",
    "ambiance.dfpwm",
    "tardis_flight_loop.dfpwm",
    "bip_sound_error_1.dfpwm",
    "short_flight.dfpwm",
    "emergencyshutdown.dfpwm",
    "landing.dfpwm",
    "tardistakeoff.dfpwm",
    "denied_flight.dfpwm",
    "shutdowntardis.dfpwm",
    "close_door.dfpwm",
    "door_open.dfpwm",
    "cloister.dfpwm"
}

-- État global
local state = {
    powered = false,
    ambiance = false,
    flight = false,
    cloister = false,
    bip = false,
    speaker = nil,
    audioCache = {}
}

-- Contrôle des loops
local loopControl = {
    ambiance = false,
    flight = false,
    cloister = false,
    bip = false
}

-- ========================================
-- GESTION DES FICHIERS ET TÉLÉCHARGEMENTS
-- ========================================

local function ensureDir()
    if not fs.exists(SOUNDS_DIR) then
        fs.makeDir(SOUNDS_DIR)
    end
end

local function downloadSound(filename)
    local path = SOUNDS_DIR .. filename
    if fs.exists(path) then
        return true
    end
    
    print("Téléchargement: " .. filename)
    local response = http.get(BASE_URL .. filename)
    
    if not response then
        print("Erreur: impossible de télécharger " .. filename)
        return false
    end
    
    local file = fs.open(path, "wb")
    file.write(response.readAll())
    file.close()
    response.close()
    
    return true
end

local function downloadAllSounds()
    ensureDir()
    print("Vérification des sons...")
    
    for _, sound in ipairs(SOUNDS) do
        if not downloadSound(sound) then
            print("Échec du téléchargement: " .. sound)
        end
    end
    
    print("Téléchargements terminés!")
    sleep(1)
end

-- ========================================
-- GESTION AUDIO
-- ========================================

local function findSpeaker()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "speaker" then
            return peripheral.wrap(name)
        end
    end
    return nil
end

local function decodeAudio(filename)
    if state.audioCache[filename] then
        return state.audioCache[filename]
    end
    
    local path = SOUNDS_DIR .. filename
    if not fs.exists(path) then
        return nil
    end
    
    local file = fs.open(path, "rb")
    local data = file.readAll()
    file.close()
    
    local decoder = cc.audio.dfpwm.make_decoder()
    local decoded = decoder(data)
    
    state.audioCache[filename] = decoded
    return decoded
end

local function playSound(filename, callback)
    if not state.speaker then
        return
    end
    
    local audio = decodeAudio(filename)
    if not audio then
        return
    end
    
    local chunkSize = 128 * 1024
    for i = 1, #audio, chunkSize do
        local chunk = audio:sub(i, math.min(i + chunkSize - 1, #audio))
        while not state.speaker.playAudio(chunk) do
            os.pullEvent("speaker_audio_empty")
        end
    end
    
    if callback then
        callback()
    end
end

-- ========================================
-- BOUCLES AUDIO
-- ========================================

local function loopSound(filename, controlKey)
    while loopControl[controlKey] do
        if not state.speaker then
            sleep(0.1)
        else
            local audio = decodeAudio(filename)
            if audio then
                local chunkSize = 128 * 1024
                for i = 1, #audio, chunkSize do
                    if not loopControl[controlKey] then
                        break
                    end
                    
                    local chunk = audio:sub(i, math.min(i + chunkSize - 1, #audio))
                    while not state.speaker.playAudio(chunk) do
                        if not loopControl[controlKey] then
                            return
                        end
                        os.pullEvent("speaker_audio_empty")
                    end
                end
            else
                sleep(0.1)
            end
        end
    end
end

local function startLoop(soundFile, controlKey)
    loopControl[controlKey] = true
    state[controlKey] = true
end

local function stopLoop(controlKey)
    loopControl[controlKey] = false
    state[controlKey] = false
end

local function stopAllLoops()
    loopControl.ambiance = false
    loopControl.flight = false
    loopControl.cloister = false
    loopControl.bip = false
    state.ambiance = false
    state.flight = false
    state.cloister = false
    state.bip = false
end

-- ========================================
-- LOGIQUE TARDIS
-- ========================================

local function tardisStartup()
    if state.powered then return end
    
    state.powered = true
    playSound("startup_tardis.dfpwm", function()
        startLoop("ambiance.dfpwm", "ambiance")
    end)
end

local function tardisDematerialization()
    if not state.powered then return end
    
    stopLoop("ambiance")
    playSound("tardistakeoff.dfpwm", function()
        startLoop("tardis_flight_loop.dfpwm", "flight")
    end)
end

local function tardisLanding()
    if not state.powered then return end
    
    stopLoop("flight")
    playSound("landing.dfpwm", function()
        startLoop("ambiance.dfpwm", "ambiance")
    end)
end

local function tardisDeniedFlight()
    if not state.powered then return end
    
    playSound("denied_flight.dfpwm")
end

local function tardisShortFlight()
    if not state.powered then return end
    
    playSound("short_flight.dfpwm")
end

local function tardisShutdown()
    if not state.powered then return end
    
    stopAllLoops()
    playSound("shutdowntardis.dfpwm", function()
        state.powered = false
    end)
end

local function toggleCloister()
    if not state.powered then return end
    
    if state.cloister then
        stopLoop("cloister")
    else
        startLoop("cloister.dfpwm", "cloister")
    end
end

local function toggleBip()
    if not state.powered then return end
    
    if state.bip then
        stopLoop("bip")
    else
        startLoop("bip_sound_error_1.dfpwm", "bip")
    end
end

local function doorOpen()
    if not state.powered then return end
    playSound("door_open.dfpwm")
end

local function doorClose()
    if not state.powered then return end
    playSound("close_door.dfpwm")
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
    term.write("TARDIS SOUNDBOARD")
    
    -- Statut
    term.setCursorPos(2, 4)
    term.setTextColor(colors.white)
    term.write("Statut: ")
    term.setTextColor(state.powered and colors.lime or colors.red)
    term.write(state.powered and "ACTIF" or "INACTIF")
    
    term.setTextColor(colors.white)
    term.setCursorPos(2, 5)
    term.write("Haut-parleur: ")
    term.setTextColor(state.speaker and colors.lime or colors.red)
    term.write(state.speaker and "Connecté" or "Non trouvé")
    
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
    
    -- Instructions
    term.setCursorPos(2, h - 1)
    term.setTextColor(colors.lightGray)
    term.write("Cliquez sur les boutons pour controler le TARDIS")
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
        end
    end
end

-- ========================================
-- MAIN
-- ========================================

local function main()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("TARDIS SOUNDBOARD - Initialisation")
    print("")
    
    -- Téléchargement des sons
    downloadAllSounds()
    
    -- Recherche du haut-parleur
    print("Recherche d'un haut-parleur...")
    state.speaker = findSpeaker()
    
    if not state.speaker then
        print("ATTENTION: Aucun haut-parleur trouvé!")
        print("Connectez un haut-parleur et redémarrez.")
        sleep(3)
    else
        print("Haut-parleur trouvé!")
        sleep(1)
    end
    
    -- Lancement en parallèle
    parallel.waitForAny(
        interfaceLoop,
        function() loopSound("ambiance.dfpwm", "ambiance") end,
        function() loopSound("tardis_flight_loop.dfpwm", "flight") end,
        function() loopSound("cloister.dfpwm", "cloister") end,
        function() loopSound("bip_sound_error_1.dfpwm", "bip") end
    )
end

-- Lancement
main()
