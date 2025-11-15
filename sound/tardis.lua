-- TARDIS Soundbox - Système Audio Complet
-- Basé sur Basalt UI et système audio simple

local basalt = require("basalt")

-- Configuration
local GITHUB_BASE = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/"
local speakers = {peripheral.find("speaker")}

if #speakers == 0 then
    error("Aucun haut-parleur détecté. Veuillez en connecter un.")
end

-- Variables d'état globales
local systemStarted = false
local isFlying = false
local errorActive = false
local errorCount = 0
local currentError = nil

-- Threads audio actifs
local activeThreads = {}

-- Fonction simple pour jouer un son WAV en streaming
local function playSound(filename, loop)
    local threadName = filename
    
    -- Arrêter le thread existant si présent
    if activeThreads[threadName] then
        activeThreads[threadName] = false
    end
    
    activeThreads[threadName] = true
    
    -- Thread pour streaming audio
    basalt.schedule(function()
        while activeThreads[threadName] do
            local url = GITHUB_BASE .. filename
            local response = http.get(url, nil, true)
            
            if not response then
                print("Erreur téléchargement: " .. filename)
                activeThreads[threadName] = false
                break
            end
            
            -- Lire l'en-tête WAV pour trouver les données
            local header = response.read(44) -- En-tête WAV standard
            if not header or #header < 44 then
                response.close()
                activeThreads[threadName] = false
                break
            end
            
            -- Lire et jouer les données audio chunk par chunk
            local decoder = dfpwm.make_decoder()
            local chunkSize = 16 * 1024 -- 16KB chunks
            
            while activeThreads[threadName] do
                local chunk = response.read(chunkSize)
                if not chunk then
                    break
                end
                
                -- Convertir en DFPWM (approximation simple)
                -- Note: Pour un vrai WAV, il faudrait parser le format PCM
                -- Ici on utilise une méthode simplifiée
                local pcm = {}
                for i = 1, #chunk do
                    pcm[i] = string.byte(chunk, i) - 128
                end
                
                -- Jouer sur tous les speakers
                for _, speaker in ipairs(speakers) do
                    -- Conversion simple en buffer audio
                    local buffer = {}
                    for i = 1, math.min(#pcm, 128 * 1024) do
                        buffer[i] = pcm[i]
                    end
                    
                    while not speaker.playAudio(buffer) do
                        os.pullEvent("speaker_audio_empty")
                        if not activeThreads[threadName] then
                            break
                        end
                    end
                end
                
                if not activeThreads[threadName] then
                    break
                end
            end
            
            response.close()
            
            -- Si pas en boucle, arrêter
            if not loop then
                activeThreads[threadName] = false
                break
            end
            
            -- Petite pause avant de reboucler
            sleep(0.1)
        end
    end)
    
    return {
        stop = function()
            activeThreads[threadName] = false
        end
    }
end

-- Fonction pour arrêter un son spécifique
local function stopSound(filename)
    activeThreads[filename] = false
    
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
end

-- Fonction pour arrêter tous les sons
local function stopAllSounds()
    for name, _ in pairs(activeThreads) do
        activeThreads[name] = false
    end
    
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
end

-- Fonction pour inverser les couleurs d'un bouton
local function toggleButtonColors(button)
    local bg = button:getBackground()
    local fg = button:getForeground()
    
    button:setBackground(fg)
    button:setForeground(bg)
    
    -- Remettre les couleurs après 0.2s
    basalt.schedule(function()
        sleep(0.2)
        button:setBackground(bg)
        button:setForeground(fg)
    end)
end

-- Create main frame
local main = basalt.createFrame()
    :setSize(51, 19)
    :setBackground(colors.black)

-- Label element - Titre
local titleLabel = main:addLabel()
    :setPosition(2, 2)
    :setSize(49, 1)
    :setText("ARTRON OS - TYPE 40")
    :setForeground(colors.orange)
    :setBackground(colors.black)

-- Frame element avec bordure
local mainFrame = main:addFrame()
    :setPosition(2, 4)
    :setSize(49, 15)
    :setBackground(colors.black)
    :setForeground(colors.orange)
    :setBorder(colors.orange)

-- Button START/OFF
local startButton = mainFrame:addButton()
    :setPosition(2, 2)
    :setSize(16, 3)
    :setText("START/OFF")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- Button EMERGENCY
local emergencyButton = mainFrame:addButton()
    :setPosition(2, 5)
    :setSize(16, 3)
    :setText("EMERGENCY")
    :setBackground(colors.red)
    :setForeground(colors.white)

-- Button Cloister
local cloisterButton = mainFrame:addButton()
    :setPosition(18, 2)
    :setSize(10, 3)
    :setText("Cloister")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- Button ERROR BIP
local errorBipButton = mainFrame:addButton()
    :setPosition(28, 2)
    :setSize(11, 3)
    :setText("ERROR BIP")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- Button DOOR
local doorButton = mainFrame:addButton()
    :setPosition(39, 2)
    :setSize(10, 3)
    :setText("DOOR")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- Button DENIED TO
local deniedButton = mainFrame:addButton()
    :setPosition(18, 5)
    :setSize(14, 3)
    :setText("DENIED TO")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- Button CHAOS FLIGHT
local chaosButton = mainFrame:addButton()
    :setPosition(31, 5)
    :setSize(18, 3)
    :setText("CHAOS FLIGHT")
    :setBackground(colors.red)
    :setForeground(colors.white)

-- Labels d'information
local infoLabel1 = mainFrame:addLabel()
    :setPosition(2, 9)
    :setSize(29, 1)
    :setText("THE SILENCE")
    :setBackground(colors.black)
    :setForeground(colors.orange)

local infoLabel2 = mainFrame:addLabel()
    :setPosition(2, 10)
    :setSize(33, 1)
    :setText("ARTRON : 120AeU/photon")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- ProgressBar element (pour effet visuel)
local progressBar = mainFrame:addProgressBar()
    :setPosition(36, 9)
    :setSize(13, 2)
    :setProgress(50)
    :setProgressColor(colors.orange)
    :setBackground(colors.gray)

-- Button DEMAT (Dématérialisation)
local dematButton = mainFrame:addButton()
    :setPosition(2, 12)
    :setSize(8, 3)
    :setText("DEMAT")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- Button FLIGHT
local flightButton = mainFrame:addButton()
    :setPosition(10, 12)
    :setSize(16, 3)
    :setText("FLIGHT")
    :setBackground(colors.orange)
    :setForeground(colors.black)

-- Button Landing (Matérialisation)
local landingButton = mainFrame:addButton()
    :setPosition(26, 12)
    :setSize(13, 3)
    :setText("Landing")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- Button AMB (Ambiance manuelle)
local ambButton = mainFrame:addButton()
    :setPosition(39, 12)
    :setSize(10, 3)
    :setText("AMB")
    :setBackground(colors.black)
    :setForeground(colors.orange)

-- Événements des boutons

startButton:onClick(function(self)
    toggleButtonColors(self)
    
    if errorActive then
        errorCount = errorCount + 1
        
        if errorCount >= 3 then
            -- Arrêter l'erreur
            stopSound("cloister_ding.wav")
            stopSound("bip_sound_error_1.wav")
            cloisterButton:setBackground(colors.black)
            errorBipButton:setBackground(colors.black)
            
            errorActive = false
            errorCount = 0
            currentError = nil
        end
        return
    end
    
    if not systemStarted then
        -- Démarrage
        systemStarted = true
        playSound("startup_tardis.wav", false)
        
        basalt.schedule(function()
            sleep(3) -- Attendre la fin du son de démarrage
            if systemStarted then
                playSound("ambience_tardis.wav", true)
                redstone.setOutput("bottom", true)
            end
        end)
        
        self:setText("SYSTEM ON")
    else
        -- Arrêt
        systemStarted = false
        stopSound("ambience_tardis.wav")
        playSound("shutdowntardis.wav", false)
        redstone.setOutput("bottom", false)
        self:setText("START/OFF")
    end
end)

emergencyButton:onClick(function(self)
    toggleButtonColors(self)
    
    systemStarted = false
    stopAllSounds()
    playSound("emergencyshutdown.wav", false)
    redstone.setOutput("bottom", false)
    startButton:setText("START/OFF")
    
    errorActive = false
    errorCount = 0
end)

flightButton:onClick(function(self)
    toggleButtonColors(self)
    
    if not systemStarted then
        return
    end
    
    if not isFlying then
        isFlying = true
        stopSound("ambience_tardis.wav")
        playSound("tardistakeoff.wav", false)
        
        basalt.schedule(function()
            sleep(2)
            if isFlying then
                playSound("tardis_flight_loop.wav", true)
            end
        end)
        
        self:setText("IN FLIGHT")
    end
end)

dematButton:onClick(function(self)
    toggleButtonColors(self)
    
    if not systemStarted then
        return
    end
    
    playSound("depart_tardis.wav", false)
end)

landingButton:onClick(function(self)
    toggleButtonColors(self)
    
    if not isFlying then
        return
    end
    
    stopSound("tardis_flight_loop.wav")
    
    -- Choisir aléatoirement
    local landingSounds = {"landing.wav", "tardismater.wav"}
    local selectedSound = landingSounds[math.random(1, 2)]
    
    playSound(selectedSound, false)
    
    basalt.schedule(function()
        sleep(2)
        playSound("ambience_tardis.wav", true)
        isFlying = false
        flightButton:setText("FLIGHT")
    end)
end)

cloisterButton:onClick(function(self)
    toggleButtonColors(self)
    
    if not errorActive then
        errorActive = true
        currentError = "cloister"
        errorCount = 0
        playSound("cloister_ding.wav", true)
        self:setBackground(colors.red)
    end
end)

errorBipButton:onClick(function(self)
    toggleButtonColors(self)
    
    if not errorActive then
        errorActive = true
        currentError = "bip"
        errorCount = 0
        playSound("bip_sound_error_1.wav", true)
        self:setBackground(colors.red)
    end
end)

doorButton:onClick(function(self)
    toggleButtonColors(self)
    
    local text = self:getText()
    if text == "DOOR" or text == "CLOSED" then
        playSound("door_open.wav", false)
        self:setText("OPEN")
    else
        playSound("close_door.wav", false)
        self:setText("CLOSED")
    end
end)

deniedButton:onClick(function(self)
    toggleButtonColors(self)
    playSound("denied_flight.wav", false)
end)

chaosButton:onClick(function(self)
    toggleButtonColors(self)
    
    if systemStarted then
        stopSound("ambience_tardis.wav")
        playSound("short_flight.wav", false)
        
        basalt.schedule(function()
            sleep(2)
            if systemStarted then
                playSound("ambience_tardis.wav", true)
            end
        end)
    end
end)

ambButton:onClick(function(self)
    toggleButtonColors(self)
    
    if activeThreads["ambience_tardis.wav"] then
        stopSound("ambience_tardis.wav")
        self:setText("AMB OFF")
    else
        playSound("ambience_tardis.wav", true)
        self:setText("AMB ON")
    end
end)

-- Erreurs aléatoires
basalt.schedule(function()
    while true do
        sleep(3600) -- Toutes les heures
        
        if math.random(1, 100) <= 30 and not errorActive and systemStarted then
            errorActive = true
            errorCount = 0
            
            local errorTypes = {"cloister", "bip"}
            currentError = errorTypes[math.random(1, 2)]
            
            if currentError == "cloister" then
                playSound("cloister_ding.wav", true)
                cloisterButton:setBackground(colors.red)
            else
                playSound("bip_sound_error_1.wav", true)
                errorBipButton:setBackground(colors.red)
            end
        end
    end
end)

-- Animation de la barre de progression
basalt.schedule(function()
    while true do
        sleep(0.1)
        local progress = progressBar:getProgress()
        progress = progress + 1
        if progress > 100 then progress = 0 end
        progressBar:setProgress(progress)
    end
end)

-- Start the UI
basalt.run()
