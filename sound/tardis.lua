-- tardis.lua
-- TARDIS Soundbox single file. Utilise Basalt UI déjà généré (basalt-ui.lua).
-- Respecte EXACTEMENT les noms de fichiers fournis par l'utilisateur.

-- dépendances
local basalt = require("basalt")
dofile("basalt-ui.lua") -- ton fichier UI existant (doit définir element3, element4, ...)

-- vérif speaker
local speaker = peripheral.find("speaker")
if not speaker then
    error("Aucun speaker détecté. Branche un speaker et relance.")
end

-- AUKit
local ok, aukit = pcall(require, "aukit")
if not ok then
    error("AUKit introuvable. Télécharge 'aukit.lua' et place-le dans ton path.")
end

-- liste exacte des fichiers fournis (noms tels que fournis)
local filenames = {
    startup      = "startup_tardis.wav",
    shutdown     = "shutdowntardis.wav",
    emergency    = "emergencyshutdown.wav",

    door_open    = "door_open.wav",
    door_close   = "close_door.wav",

    takeoff      = "tardistakeoff.wav",
    depart       = "depart_tardis.wav", -- si absent, ok

    flight_loop  = "tardis_flight_loop.wav",
    short_flight = "short_flight.wav",

    landing_1    = "landing.wav",
    landing_2    = "tardismater.wav",

    ambience     = "ambience tardis.wav", -- note : espace dans le nom, comme fourni

    cloister     = "cloister_ding.wav",
    bip_error    = "bip_sound_error_1.wav",

    denied       = "denied_flight.wav",

    chaos_loop   = "denied_flight.wav" -- temporaire: tu remplacerais plus tard
}

-- répertoires locaux testés (ordre : courant -> sound -> compress)
local search_dirs = {"", "sound", "compress"}

-- helper: join path
local function joinPath(dir, name)
    if dir == "" then return name end
    return fs.combine(dir, name)
end

-- helper: url encode pour espaces et caractères spéciaux
local function url_encode(str)
    if (str) then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = str:gsub(" ", "%%20")
    end
    return str
end

-- repo RAW GitHub de fallback (si besoin)
local GITHUB_RAW_BASE = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/"

-- trouve le chemin local (ou nil)
local function findLocalFile(name)
    for _, d in ipairs(search_dirs) do
        local p = joinPath(d, name)
        if fs.exists(p) then return p end
    end
    return nil
end

-- construit la source (local path string ou remote url)
local function resolveSource(name)
    local localp = findLocalFile(name)
    if localp then
        return { type = "local", path = localp }
    else
        -- fallback : RAW GitHub
        local remote = GITHUB_RAW_BASE .. url_encode(name)
        return { type = "remote", url = remote, name = name }
    end
end

-- joue un fichier local une fois (bloquant jusqu'à la fin)
local function playLocalOnce(path)
    -- use io.lines with samplerate 48000 (convention AUKit example)
    -- protect pcall pour éviter crash
    local ok, err = pcall(function()
        aukit.play(aukit.stream.wav(io.lines(path, 48000)), speaker)
    end)
    if not ok then
        print("Erreur lecture locale:", err)
    end
end

-- joue un fichier remote une fois (tente via http.get puis stream via aukit)
local function playRemoteOnce(url)
    if not http.checkURL or not http.checkURL(url) then
        print("HTTP non autorisé ou URL invalide :", url)
        return
    end
    local req = http.get(url, nil, true)
    if not req then
        print("Impossible de récupérer :", url)
        return
    end
    local data = req.readAll()
    req.close()
    -- attempt: aukit.stream.wav accepte io.lines OR a table-like source.
    -- la méthode la plus robuste est de sauvegarder temporairement puis jouer (si fs writable)
    local tmp = "/tmp_tardis_temp.wav"
    local okw, werr = pcall(function()
        local f = fs.open(tmp, "wb")
        f.write(data)
        f.close()
    end)
    if not okw then
        print("Impossible d'écrire fichier temporaire:", werr)
        return
    end
    playLocalOnce(tmp)
    pcall(fs.delete, tmp)
end

-- wrapper play once (choisit local ou remote)
local function playOnceSource(src)
    if src.type == "local" then
        playLocalOnce(src.path)
    else
        playRemoteOnce(src.url)
    end
end

-- play loop: relance tant que flag reste true. (non-blocking wrapper)
local function playLooped(flagTable, flagKey, src)
    -- lance en coroutine (parallel)
    flagTable[flagKey] = true
    -- fonction de loop
    local function loop()
        while flagTable[flagKey] do
            playOnceSource(src)
            -- léger délai pour éviter spin si fichier absent
            sleep(0.1)
        end
    end
    -- run as separate parallel thread
    local co = coroutine.create(loop)
    coroutine.resume(co)
    return co
end

-- stop loop
local function stopLoop(flagTable, flagKey)
    flagTable[flagKey] = false
end

-- états
local flags = {
    ambience = false,
    flight   = false,
    chaos    = false,
    error    = false,
    power    = false
}

local error_press_count = 0
local current_error_src = nil

-- inversion visuelle simple (swap bg/fg)
local function invertButton(btn)
    local bg = btn:getBackground()
    local fg = btn:getForeground()
    btn:setBackground(fg):setForeground(bg)
    sleep(0.12)
    btn:setBackground(bg):setForeground(fg)
end

-- redstone power (basé sur ta spec : bottom)
local function setPower(state)
    flags.power = state
    redstone.setOutput("bottom", state)
end

-- résolutions sources (pour tous les fichiers)
local SRC = {}
for k,v in pairs(filenames) do
    SRC[k] = resolveSource(v)
end

-- Fonctions principales correspondantes aux boutons

-- START/OFF (element3)
local function onStartOff()
    invertButton(element3)
    if not flags.power then
        -- startup: play startup once, puis lancer ambience en boucle
        playOnceSource(SRC.startup)
        -- start ambience loop
        if not flags.ambience then
            flags.ambience = true
            playLooped(flags, "ambience", SRC.ambience)
        end
        setPower(true)
    else
        -- shutdown simple : stop loops, play shutdown once, couper redstone
        flags.ambience = false
        flags.flight = false
        flags.chaos = false
        flags.error = false
        playOnceSource(SRC.shutdown)
        setPower(false)
    end
end

-- EMERGENCY (element5)
local function onEmergency()
    invertButton(element5)
    -- arrêt d'urgence : stop tout et jouer emergency
    flags.ambience = false
    flags.flight = false
    flags.chaos = false
    flags.error = false
    playOnceSource(SRC.emergency)
    setPower(false)
end

-- FLIGHT (element4)
local function onFlight()
    invertButton(element4)
    -- start flight loop: stop ambience, start flight loop (boucle)
    flags.ambience = false
    flags.chaos = false
    if not flags.flight then
        flags.flight = true
        playLooped(flags, "flight", SRC.flight_loop)
    else
        flags.flight = false
    end
end

-- DEMAT (element7)
local function onDemat()
    invertButton(element7)
    -- joue takeoff once (départ)
    playOnceSource(SRC.takeoff)
    -- arrêt ambiance si en cours
    flags.ambience = false
end

-- LANDING (element8)
local function onLanding()
    invertButton(element8)
    -- stop flight loop, choisir aléatoirement landing_1 ou landing_2
    flags.flight = false
    if math.random(1,2) == 1 then
        playOnceSource(SRC.landing_1)
    else
        playOnceSource(SRC.landing_2)
    end
    -- relancer ambiance
    if not flags.ambience then
        flags.ambience = true
        playLooped(flags, "ambience", SRC.ambience)
    end
end

-- DOOR (element10)
local door_open = false
local function onDoor()
    invertButton(element10)
    if not door_open then
        playOnceSource(SRC.door_open)
        door_open = true
    else
        playOnceSource(SRC.door_close)
        door_open = false
    end
end

-- DENIED TO (element11) -> joué en boucle (demandé)
local function onDenied()
    invertButton(element11)
    if not flags.chaos then
        flags.chaos = true
        playLooped(flags, "chaos", SRC.denied) -- denied est aussi mis en loop par l'utilisateur
    else
        flags.chaos = false
    end
end

-- CHAOS FLIGHT (element12) -> boucle aussi (utilise chaos_loop src)
local function onChaosFlight()
    invertButton(element12)
    flags.ambience = false
    flags.flight = false
    if not flags.chaos then
        flags.chaos = true
        playLooped(flags, "chaos", SRC.chaos_loop)
    else
        flags.chaos = false
    end
end

-- Cloister (element6) -> start cloister loop (se joue en boucle)
local function onCloister()
    invertButton(element6)
    if not flags.error then
        flags.error = true
        current_error_src = SRC.cloister
        error_press_count = 0
        playLooped(flags, "error", current_error_src)
    else
        -- si erreur déjà en cours, rien (ou on incrémente contador via shutdown)
    end
end

-- ERROR BIP (element9) -> start bip error loop
local function onBipError()
    invertButton(element9)
    if not flags.error then
        flags.error = true
        current_error_src = SRC.bip_error
        error_press_count = 0
        playLooped(flags, "error", current_error_src)
    end
end

-- AMB toggle (element16)
local function onAmb()
    invertButton(element16)
    if not flags.ambience then
        flags.ambience = true
        playLooped(flags, "ambience", SRC.ambience)
    else
        flags.ambience = false
    end
end

-- Shutdown button should count presses to stop errors (user said: 3 fois sur shutdown pour arrêter une erreur)
-- On associe le compteur à element3 (START/OFF) presses quand erreur en cours => arrête erreur au bout de 3 pressions.
local function tryStopErrorFromShutdownPress()
    if flags.error then
        error_press_count = error_press_count + 1
        if error_press_count >= 3 then
            flags.error = false
            current_error_src = nil
            error_press_count = 0
        end
    end
end

-- assignation des callbacks sur les éléments (noms provenant de basalt-ui.lua)
element3:onClick(function() onStartOff(); tryStopErrorFromShutdownPress() end) -- START/OFF
element5:onClick(onEmergency)      -- EMERGENCY
element4:onClick(onFlight)         -- FLIGHT
element7:onClick(onDemat)          -- DEMAT
element8:onClick(onLanding)        -- Landing
element10:onClick(onDoor)          -- DOOR
element11:onClick(onDenied)        -- DENIED TO (en boucle)
element12:onClick(onChaosFlight)   -- CHAOS FLIGHT (en boucle)
element6:onClick(onCloister)       -- Cloister (erreur boucle)
element9:onClick(onBipError)       -- ERROR BIP (erreur boucle)
element16:onClick(onAmb)           -- AMB toggle

-- Système d'erreurs aléatoires : probabilité par heure. Ici on attend 3600s (1h) et on check
local function randomErrorLoop()
    while true do
        sleep(3600) -- 1 heure
        -- probabilité simple : 1 chance sur 6 par heure
        if math.random(1,6) == 1 and not flags.error then
            -- choix aléatoire cloister ou bip
            if math.random(1,2) == 1 then
                flags.error = true
                current_error_src = SRC.cloister
                error_press_count = 0
                playLooped(flags, "error", current_error_src)
            else
                flags.error = true
                current_error_src = SRC.bip_error
                error_press_count = 0
                playLooped(flags, "error", current_error_src)
            end
        end
    end
end

-- démarrage parallèle : Basalt UI + randomErrorLoop
-- Basalt.run gère l'event loop UI. On exécute randomErrorLoop en parallèle.
parallel.waitForAny(basalt.run, randomErrorLoop)
