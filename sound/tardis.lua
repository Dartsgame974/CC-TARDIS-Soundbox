-- TARDIS Soundbox - Version Native ComputerCraft (sans Basalt)
-- Utilise uniquement les APIs natives de CC:Tweaked

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
local errorActive = false
local errorCount = 0
local currentError = nil
local doorOpen = false
local ambianceActive = false

-- Threads audio actifs
local audioThreads = {}
local activeCoroutines = {}

-- Définition des boutons
local buttons = {
    startup = {x = 3, y = 5, w = 16, h = 3, label = "START/OFF", bg = colors.black, fg = colors.orange},
    emergency = {x = 3, y = 8, w = 16, h = 3, label = "EMERGENCY", bg = colors.red, fg = colors.white},
    cloister = {x = 19, y = 5, w = 10, h = 3, label = "Cloister", bg = colors.black, fg = colors.orange},
    errorBip = {x = 29, y = 5, w = 11, h = 3, label = "ERROR BIP", bg = colors.black, fg = colors.orange},
    door = {x = 40, y = 5, w = 10, h = 3, label = "DOOR", bg = colors.black, fg = colors.orange},
    denied = {x = 19, y = 8, w = 14, h = 3, label = "DENIED TO", bg = colors.black, fg = colors.white},
    chaos = {x = 32, y = 8, w = 18, h = 3, label = "CHAOS FLIGHT", bg = colors.red, fg = colors.white},
    demat = {x = 3, y = 15, w = 7, h = 3, label = "DEMAT", bg = colors.black, fg = colors.orange},
    flight = {x = 11, y = 15, w = 16, h = 3, label = "FLIGHT", bg = colors.orange, fg = colors.black},
    landing = {x = 27, y = 15, w = 13, h = 3, label = "Landing", bg = colors.black, fg = colors.orange},
    amb = {x = 40, y = 15, w = 10, h = 3, label = "AMB", bg = colors.black, fg = colors.orange},
}

-- Fonction pour dessiner un bouton
local function drawButton(name, inverted)
    local btn = buttons[name]
    local bg = inverted and btn.fg or btn.bg
    local fg = inverted and btn.bg or btn.fg
    
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    
    for i = 0, btn.h - 1 do
        term.setCursorPos(btn.x, btn.y + i)
        term.write(string.rep(" ", btn.w))
    end
    
    -- Centrer le texte
    local textY = btn.y + math.floor(btn.h / 2)
    local textX = btn.x + math.floor((btn.w - #btn.label) / 2)
    term.setCursorPos(textX, textY)
    term.write(btn.label)
end

-- Fonction pour dessiner l'interface complète
local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Titre
    term.setTextColor(colors.orange)
    term.setCursorPos(2, 2)
    term.write("ARTRON OS - TYPE 40")
    
    -- Cadre principal
    term.setTextColor(colors.orange)
    for i = 4, 18 do
        term.setCursorPos(2, i)
        term.write("|")
        term.setCursorPos(50, i)
        term.write("|")
    end
    term.setCursorPos(2, 4)
    term.write(string.rep("-", 48))
    term.setCursorPos(2, 18)
    term.write(string.rep("-", 48))
    
    -- Dessiner tous les boutons
    for name, _ in pairs(buttons) do
        drawButton(name, false)
    end
    
    -- Labels d'information
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(3, 12)
    term.write("THE SILENCE")
    
    term.setTextColor(colors.orange)
    term.setCursorPos(3, 13)
    term.write("ARTRON : 120AeU/photon")
    
    -- Barre de progression visuelle
    term.setTextColor(colors.orange)
    term.setCursorPos(37, 12)
    term.write("[")
    term.setCursorPos(49, 12)
    term.write("]")
end

-- Fonction pour vérifier si un clic est sur un bouton
local function getClickedButton(x, y)
    for name, btn in pairs(buttons) do
        if x >= btn.x and x < btn.x + btn.w and y >= btn.y and y < btn.y + btn.h then
            return name
        end
    end
    return nil
end

-- Fonction pour flasher un bouton
local function flashButton(name)
    drawButton(name, true)
    sleep(0.2)
    drawButton(name, false)
end

-- Fonction pour télécharger et jouer un son
local function playSound(filename, loop, callback)
    local url = GITHUB_BASE .. filename
    
    -- Arrêter le thread existant si présent
    if audioThreads[filename] then
        audioThreads[filename].active = false
        audioThreads[filename] = nil
    end
    
    local threadData = {
        active = true,
        filename = filename
    }
    audioThreads[filename] = threadData
    
    -- Créer une coroutine pour gérer le son
    local co = coroutine.create(function()
        local response, err = http.get(url, nil, true)
        if not response then
            print("Erreur téléchargement: " .. filename)
            return
        end
        
        local data = response.readAll()
        response.close()
        
        if loop then
            -- Boucle infinie
            while threadData.active do
                local iter, length = aukit.stream.wav(data, false)
                local success = pcall(function()
                    aukit.play(iter, nil, 1.0, speakers)
                end)
                if not success or not threadData.active then break end
                sleep(0.1)
            end
        else
            -- Jouer une seule fois
            local iter, length = aukit.stream.wav(data, false)
            pcall(function()
                aukit.play(iter, nil, 1.0, speakers)
            end)
            
            if callback and threadData.active then
                callback()
            end
        end
        
        audioThreads[filename] = nil
    end)
    
    table.insert(activeCoroutines, co)
    
    return threadData
end

-- Fonction pour arrêter un son spécifique
local function stopSound(filename)
    if audioThreads[filename] then
        audioThreads[filename].active = false
        audioThreads[filename] = nil
    end
    
    for _, speaker in ipairs(speakers) do
        pcall(function() speaker.stop() end)
    end
end

-- Fonction pour arrêter tous les sons
local function stopAllSounds()
    for name, thread in pairs(audioThreads) do
        thread.active = false
    end
    audioThreads = {}
    
    for _, speaker in ipairs(speakers) do
        pcall(function() speaker.stop() end)
    end
end

-- Handlers pour chaque bouton
local buttonHandlers = {
    startup = function()
        if errorActive then
            errorCount = errorCount + 1
            
            if errorCount >= 3 then
                if currentError == "cloister" then
                    stopSound("cloister_ding.wav")
                    buttons.cloister.bg = colors.black
                    drawButton("cloister", false)
                elseif currentError == "bip" then
                    stopSound("bip_sound_error_1.wav")
                    buttons.errorBip.bg = colors.black
                    drawButton("errorBip", false)
                end
                
                errorActive = false
                errorCount = 0
                currentError = nil
            end
            return
        end
        
        if not systemStarted then
            systemStarted = true
            buttons.startup.label = "SYSTEM ON"
            drawButton("startup", false)
            
            playSound("startup_tardis.wav", false, function()
                ambianceActive = true
                playSound("ambience_tardis.wav", true)
                redstone.setOutput("bottom", true)
            end)
        else
            systemStarted = false
            buttons.startup.label = "START/OFF"
            drawButton("startup", false)
            
            stopSound("ambience_tardis.wav")
            ambianceActive = false
            playSound("shutdowntardis.wav", false)
            redstone.setOutput("bottom", false)
        end
    end,
    
    emergency = function()
        systemStarted = false
        stopAllSounds()
        
        playSound("emergencyshutdown.wav", false)
        redstone.setOutput("bottom", false)
        
        buttons.startup.label = "START/OFF"
        drawButton("startup", false)
        
        errorActive = false
        errorCount = 0
        buttons.cloister.bg = colors.black
        buttons.errorBip.bg = colors.black
        drawButton("cloister", false)
        drawButton("errorBip", false)
    end,
    
    cloister = function()
        if not errorActive then
            errorActive = true
            currentError = "cloister"
            errorCount = 0
            
            playSound("cloister_ding.wav", true)
            
            buttons.cloister.bg = colors.red
            drawButton("cloister", false)
        else
            errorCount = errorCount + 1
            if errorCount >= 3 then
                stopSound("cloister_ding.wav")
                errorActive = false
                errorCount = 0
                currentError = nil
                buttons.cloister.bg = colors.black
                drawButton("cloister", false)
            end
        end
    end,
    
    errorBip = function()
        if not errorActive then
            errorActive = true
            currentError = "bip"
            errorCount = 0
            
            playSound("bip_sound_error_1.wav", true)
            
            buttons.errorBip.bg = colors.red
            drawButton("errorBip", false)
        else
            errorCount = errorCount + 1
            if errorCount >= 3 then
                stopSound("bip_sound_error_1.wav")
                errorActive = false
                errorCount = 0
                currentError = nil
                buttons.errorBip.bg = colors.black
                drawButton("errorBip", false)
            end
        end
    end,
    
    door = function()
        if not doorOpen then
            playSound("door_open.wav", false)
            buttons.door.label = "OPEN"
            doorOpen = true
        else
            playSound("close_door.wav", false)
            buttons.door.label = "CLOSED"
            doorOpen = false
        end
        drawButton("door", false)
    end,
    
    denied = function()
        playSound("denied_flight.wav", false)
    end,
    
    chaos = function()
        if systemStarted then
            stopSound("ambience_tardis.wav")
            playSound("short_flight.wav", false, function()
                if systemStarted then
                    ambianceActive = true
                    playSound("ambience_tardis.wav", true)
                end
            end)
        end
    end,
    
    demat = function()
        if systemStarted then
            playSound("depart_tardis.wav", false)
        end
    end,
    
    flight = function()
        if not systemStarted then
            return
        end
        
        if not isFlying then
            isFlying = true
            
            stopSound("ambience_tardis.wav")
            ambianceActive = false
            
            playSound("tardistakeoff.wav", false, function()
                if isFlying then
                    playSound("tardis_flight_loop.wav", true)
                end
            end)
            
            buttons.flight.label = "IN FLIGHT"
            drawButton("flight", false)
        end
    end,
    
    landing = function()
        if not isFlying then
            return
        end
        
        stopSound("tardis_flight_loop.wav")
        
        local landingSounds = {"landing.wav", "tardismater.wav"}
        local selectedSound = landingSounds[math.random(1, 2)]
        
        playSound(selectedSound, false, function()
            if systemStarted then
                ambianceActive = true
                playSound("ambience_tardis.wav", true)
            end
            isFlying = false
            buttons.flight.label = "FLIGHT"
            drawButton("flight", false)
        end)
    end,
    
    amb = function()
        if ambianceActive then
            stopSound("ambience_tardis.wav")
            ambianceActive = false
            buttons.amb.label = "AMB OFF"
        else
            ambianceActive = true
            playSound("ambience_tardis.wav", true)
            buttons.amb.label = "AMB ON"
        end
        drawButton("amb", false)
    end,
}

-- Fonction pour gérer les erreurs aléatoires
local function randomErrorHandler()
    while true do
        sleep(3600) -- 1 heure
        
        if math.random(1, 100) <= 30 and not errorActive and systemStarted then
            errorActive = true
            errorCount = 0
            
            local errorTypes = {"cloister", "bip"}
            currentError = errorTypes[math.random(1, 2)]
            
            if currentError == "cloister" then
                playSound("cloister_ding.wav", true)
                buttons.cloister.bg = colors.red
                drawButton("cloister", false)
            else
                playSound("bip_sound_error_1.wav", true)
                buttons.errorBip.bg = colors.red
                drawButton("errorBip", false)
            end
        end
    end
end

-- Fonction pour mettre à jour la barre de progression
local progressValue = 0
local function updateProgressBar()
    while true do
        sleep(0.1)
        progressValue = progressValue + 1
        if progressValue > 11 then progressValue = 0 end
        
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.orange)
        term.setCursorPos(38, 12)
        
        local bar = ""
        for i = 1, 11 do
            if i <= progressValue then
                bar = bar .. "="
            else
                bar = bar .. " "
            end
        end
        term.write(bar)
    end
end

-- Boucle principale
local function main()
    drawUI()
    
    -- Lancer les coroutines en arrière-plan
    local errorCoroutine = coroutine.create(randomErrorHandler)
    local progressCoroutine = coroutine.create(updateProgressBar)
    
    while true do
        -- Reprendre les coroutines actives
        for i = #activeCoroutines, 1, -1 do
            local co = activeCoroutines[i]
            if coroutine.status(co) ~= "dead" then
                coroutine.resume(co)
            else
                table.remove(activeCoroutines, i)
            end
        end
        
        -- Reprendre les coroutines système
        if coroutine.status(errorCoroutine) ~= "dead" then
            coroutine.resume(errorCoroutine)
        end
        if coroutine.status(progressCoroutine) ~= "dead" then
            coroutine.resume(progressCoroutine)
        end
        
        -- Gérer les événements
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "mouse_click" then
            local button = getClickedButton(param2, param3)
            if button and buttonHandlers[button] then
                flashButton(button)
                buttonHandlers[button]()
            end
        elseif event == "term_resize" then
            drawUI()
        end
    end
end

-- Lancement du programme
local success, error = pcall(main)
if not success then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.clear()
    term.setCursorPos(1, 1)
    print("Erreur: " .. tostring(error))
    
    -- Arrêter tous les sons en cas d'erreur
    stopAllSounds()
    redstone.setOutput("bottom", false)
end
