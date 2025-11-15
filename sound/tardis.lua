-- TARDIS Soundbox - Système Audio Complet
-- Basé sur Basalt UI et AUKit

local basalt = require("basalt")
local aukit = require("aukit")

-- Configuration
local GITHUB_BASE = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/"
local speakers = {peripheral.find("speaker")}

if #speakers == 0 then
    error("Aucun haut-parleur détecté. Veuillez en connecter un.")
end

-- Variables d'état globales
local systemStarted = false
local isFlying = false
local ambianceLoop = nil
local flightLoop = nil
local errorActive = false
local errorCount = 0
local currentError = nil

-- Threads audio actifs
local audioThreads = {}

-- Timer pour les erreurs aléatoires (probabilité par heure)
local errorTimer = os.startTimer(3600) -- 1 heure

-- Fonction pour télécharger et jouer un son
local function playSound(filename, loop, callback)
    local url = GITHUB_BASE .. filename
    
    -- Arrêter le thread existant si présent
    if audioThreads[filename] then
        pcall(function() audioThreads[filename].stop() end)
        audioThreads[filename] = nil
    end
    
    -- Thread pour télécharger et jouer le son
    local thread = coroutine.create(function()
        local response, err = http.get(url, nil, true)
        if not response then
            print("Erreur téléchargement: " .. filename)
            return
        end
        
        local data = response.readAll()
        response.close()
        
        -- Créer un stream à partir des données
        local iter, length = aukit.stream.wav(data, false)
        
        if loop then
            -- Boucle infinie
            while true do
                local success = pcall(function()
                    aukit.play(iter, nil, 1.0, speakers)
                end)
                if not success then break end
                
                -- Recréer l'itérateur pour la boucle
                iter, length = aukit.stream.wav(data, false)
            end
        else
            -- Jouer une seule fois
            pcall(function()
                aukit.play(iter, nil, 1.0, speakers)
            end)
            
            if callback then
                callback()
            end
        end
    end)
    
    audioThreads[filename] = {
        thread = thread,
        stop = function()
            -- Arrêter tous les haut-parleurs
            for _, speaker in ipairs(speakers) do
                speaker.stop()
            end
        end
    }
    
    -- Démarrer le thread
    local ok, err = coroutine.resume(thread)
    if not ok then
        print("Erreur lecture: " .. tostring(err))
    end
    
    return audioThreads[filename]
end

-- Fonction pour arrêter un son spécifique
local function stopSound(filename)
    if audioThreads[filename] then
        audioThreads[filename].stop()
        audioThreads[filename] = nil
    end
end

-- Fonction pour arrêter tous les sons
local function stopAllSounds()
    for name, thread in pairs(audioThreads) do
        thread.stop()
    end
    audioThreads = {}
    
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
    os.startTimer(0.2)
    basalt.schedule(function()
        sleep(0.2)
        button:setBackground(bg)
        button:setForeground(fg)
    end)
end

-- Create main frame
local main = basalt.createFrame()
    :setSize(51, 19)

-- Frame element
local mainFrame = main:addFrame()
    :setPosition(2, 4)
    :setSize(49, 15)
    :setForeground(colors.orange)

-- Label element - Titre
local titleLabel = main:addLabel()
    :setPosition(2, 2)
    :setSize(49, 1)
    :setText("ARTRON OS - TYPE 40")
    :setForeground(colors.orange)

-- Button START/OFF
local startButton = main:addButton()
    :setPosition(3, 5)
    :setSize(16, 3)
    :setText("START/OFF")
    :setForeground(colors.orange)
    :onClick(function(self)
        toggleButtonColors(self)
        
        if not systemStarted then
            -- Démarrage
            systemStarted = true
            
            -- Jouer le son de démarrage
            playSound("startup_tardis.wav", false, function()
                -- À la fin du démarrage, lancer l'ambiance
                ambianceLoop = playSound("ambience_tardis.wav", true)
                
                -- Activer le signal redstone
                redstone.setOutput("bottom", true)
            end)
            
            self:setText("SYSTEM ON")
        else
            -- Arrêt
            systemStarted = false
            
            -- Arrêter l'ambiance
            stopSound("ambience_tardis.wav")
            
            -- Jouer le son d'arrêt
            playSound("shutdowntardis.wav", false)
            
            -- Désactiver le signal redstone
            redstone.setOutput("bottom", false)
            
            self:setText("START/OFF")
        end
    end)

-- Button EMERGENCY
local emergencyButton = main:addButton()
    :setPosition(3, 8)
    :setSize(16, 3)
    :setText("EMERGENCY")
    :setBackground(colors.red)
    :onClick(function(self)
        toggleButtonColors(self)
        
        -- Arrêt d'urgence (similaire à l'arrêt normal mais avec son différent)
        systemStarted = false
        stopAllSounds()
        
        playSound("emergencyshutdown.wav", false)
        redstone.setOutput("bottom", false)
        
        startButton:setText("START/OFF")
        
        -- Réinitialiser les erreurs
        errorActive = false
        errorCount = 0
    end)

-- Button FLIGHT
local flightButton = main:addButton()
    :setPosition(11, 15)
    :setSize(16, 3)
    :setText("FLIGHT")
    :setBackground(colors.orange)
    :setForeground(colors.black)
    :onClick(function(self)
        toggleButtonColors(self)
        
        if not systemStarted then
            return
        end
        
        if not isFlying then
            -- Démarrer le vol
            isFlying = true
            
            -- Arrêter l'ambiance
            stopSound("ambience_tardis.wav")
            
            -- Jouer le son de décollage puis la boucle de vol
            playSound("tardistakeoff.wav", false, function()
                flightLoop = playSound("tardis_flight_loop.wav", true)
            end)
            
            self:setText("IN FLIGHT")
        end
    end)

-- Button DEMAT (Dématérialisation)
local dematButton = main:addButton()
    :setPosition(3, 15)
    :setText("DEMAT")
    :setBackground(colors.black)
    :setForeground(colors.orange)
    :onClick(function(self)
        toggleButtonColors(self)
        
        if not systemStarted then
            return
        end
        
        -- Jouer le son de départ
        playSound("depart_tardis.wav", false)
    end)

-- Button Landing (Matérialisation)
local landingButton = main:addButton()
    :setPosition(27, 15)
    :setSize(13, 3)
    :setText("Landing")
    :setBackground(colors.black)
    :setForeground(colors.orange)
    :onClick(function(self)
        toggleButtonColors(self)
        
        if not isFlying then
            return
        end
        
        -- Arrêter la boucle de vol
        stopSound("tardis_flight_loop.wav")
        
        -- Choisir aléatoirement entre landing et tardismater
        local landingSounds = {"landing.wav", "tardismater.wav"}
        local selectedSound = landingSounds[math.random(1, 2)]
        
        playSound(selectedSound, false, function()
            -- Redémarrer l'ambiance
            ambianceLoop = playSound("ambience_tardis.wav", true)
            isFlying = false
            flightButton:setText("FLIGHT")
        end)
    end)

-- Button Cloister
local cloisterButton = main:addButton()
    :setPosition(19, 5)
    :setSize(10, 3)
    :setText("Cloister")
    :setForeground(colors.orange)
    :onClick(function(self)
        toggleButtonColors(self)
        
        if not errorActive then
            errorActive = true
            currentError = "cloister"
            errorCount = 0
            
            -- Démarrer la boucle cloister
            playSound("cloister_ding.wav", true)
            
            self:setBackground(colors.red)
        else
            -- Compter les appuis sur shutdown pour arrêter
            errorCount = errorCount + 1
            if errorCount >= 3 then
                stopSound("cloister_ding.wav")
                errorActive = false
                errorCount = 0
                currentError = nil
                self:setBackground(colors.black)
            end
        end
    end)

-- Button ERROR BIP
local errorBipButton = main:addButton()
    :setPosition(29, 5)
    :setSize(11, 3)
    :setText("ERROR BIP")
    :setForeground(colors.orange)
    :onClick(function(self)
        toggleButtonColors(self)
        
        if not errorActive then
            errorActive = true
            currentError = "bip"
            errorCount = 0
            
            -- Démarrer la boucle bip
            playSound("bip_sound_error_1.wav", true)
            
            self:setBackground(colors.red)
        else
            -- Compter les appuis pour arrêter
            errorCount = errorCount + 1
            if errorCount >= 3 then
                stopSound("bip_sound_error_1.wav")
                errorActive = false
                errorCount = 0
                currentError = nil
                self:setBackground(colors.black)
            end
        end
    end)

-- Button DOOR
local doorButton = main:addButton()
    :setPosition(40, 5)
    :setSize(10, 3)
    :setText("DOOR")
    :setForeground(colors.orange)
    :onClick(function(self)
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

-- Button DENIED TO
local deniedButton = main:addButton()
    :setPosition(19, 8)
    :setSize(14, 3)
    :setText("DENIED TO")
    :onClick(function(self)
        toggleButtonColors(self)
        playSound("denied_flight.wav", false)
    end)

-- Button CHAOS FLIGHT
local chaosButton = main:addButton()
    :setPosition(32, 8)
    :setSize(18, 3)
    :setText("CHAOS FLIGHT")
    :setBackground(colors.red)
    :onClick(function(self)
        toggleButtonColors(self)
        
        if systemStarted then
            -- Vol chaotique court
            stopSound("ambience_tardis.wav")
            playSound("short_flight.wav", false, function()
                ambianceLoop = playSound("ambience_tardis.wav", true)
            end)
        end
    end)

-- Button AMB (Ambiance manuelle)
local ambButton = main:addButton()
    :setPosition(40, 15)
    :setSize(10, 3)
    :setText("AMB")
    :setBackground(colors.black)
    :setForeground(colors.orange)
    :onClick(function(self)
        toggleButtonColors(self)
        
        if ambianceLoop then
            stopSound("ambience_tardis.wav")
            ambianceLoop = nil
            self:setText("AMB OFF")
        else
            ambianceLoop = playSound("ambience_tardis.wav", true)
            self:setText("AMB ON")
        end
    end)

-- ProgressBar element (pour effet visuel)
local progressBar = main:addProgressBar()
    :setPosition(37, 12)
    :setSize(13, 2)
    :setProgressColor(colors.orange)
    :setProgress(50)

-- Labels d'information
local infoLabel1 = main:addLabel()
    :setPosition(3, 12)
    :setSize(29, 1)
    :setText("THE SILENCE")

local infoLabel2 = main:addLabel()
    :setPosition(3, 13)
    :setSize(33, 1)
    :setText("ARTRON : 120AeU/photon")
    :setForeground(colors.orange)

-- Gestion des erreurs aléatoires
basalt.schedule(function()
    while true do
        sleep(3600) -- Toutes les heures
        
        -- Probabilité d'erreur (30% de chance)
        if math.random(1, 100) <= 30 and not errorActive and systemStarted then
            errorActive = true
            errorCount = 0
            
            -- Choisir aléatoirement le type d'erreur
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

-- Gestion spéciale du shutdown pour arrêter les erreurs
startButton:onClick(function(self)
    toggleButtonColors(self)
    
    if errorActive then
        errorCount = errorCount + 1
        
        if errorCount >= 3 then
            -- Arrêter l'erreur
            if currentError == "cloister" then
                stopSound("cloister_ding.wav")
                cloisterButton:setBackground(colors.black)
            elseif currentError == "bip" then
                stopSound("bip_sound_error_1.wav")
                errorBipButton:setBackground(colors.black)
            end
            
            errorActive = false
            errorCount = 0
            currentError = nil
        end
        return
    end
    
    -- Logique normale du bouton startup
    if not systemStarted then
        systemStarted = true
        playSound("startup_tardis.wav", false, function()
            ambianceLoop = playSound("ambience tardis.wav", true)
            redstone.setOutput("bottom", true)
        end)
        self:setText("SYSTEM ON")
    else
        systemStarted = false
        stopSound("ambience_tardis.wav")
        playSound("shutdowntardis.wav", false)
        redstone.setOutput("bottom", false)
        self:setText("START/OFF")
    end
end)

-- Boucle de mise à jour de la barre de progression (effet visuel)
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
