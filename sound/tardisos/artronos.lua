-- ARTRON OS TYPE 40 - TARDIS SOUNDBOARD v4.0
-- Full English Interface with WAV/DFPWM Toggle

local BASE_URL_DFPWM = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/dfpwm/"
local BASE_URL_WAV = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/sound/"
local AUKIT_URL = "https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua"

-- Sound files list
local SOUNDS = {
    startup = "startup_tardis",
    ambiance = "ambiance",
    flight = "tardis_flight_loop",
    bip = "bip_sound_error_1",
    short_flight = "short_flight",
    landing = "landing",
    takeoff = "tardistakeoff",
    denied = "denied_flight",
    shutdown = "shutdowntardis",
    door_close = "close_door",
    door_open = "door_open",
    cloister = "cloister"
}

-- Global state
local state = {
    powered = false,
    currentLoop = nil,
    speakers = {},
    playing = false,
    audioFormat = "wav" -- "wav" or "dfpwm"
}

local aukit = nil

-- ========================================
-- AUKIT INITIALIZATION
-- ========================================

local function downloadAukit()
    if fs.exists("aukit.lua") then
        return true
    end
    
    print("Downloading AUKit...")
    local response = http.get(AUKIT_URL)
    
    if not response then
        print("Error: Cannot download AUKit")
        return false
    end
    
    local file = fs.open("aukit.lua", "w")
    file.write(response.readAll())
    file.close()
    response.close()
    
    print("AUKit downloaded!")
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
-- AUDIO MANAGEMENT
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

-- Play a single sound (non-loop)
local function playSound(soundKey, callback)
    if #state.speakers == 0 then
        if callback then callback() end
        return
    end
    
    state.playing = true
    os.queueEvent("_play_sound", soundKey, callback)
end

-- Start a loop (stops any other loop)
local function startLoop(loopKey)
    state.currentLoop = loopKey
    state.playing = true
    os.queueEvent("_start_loop", loopKey)
end

-- Stop current loop
local function stopLoop()
    state.currentLoop = nil
end

-- ========================================
-- AUDIO THREAD
-- ========================================

local function audioThread()
    while true do
        local event, param1, param2 = os.pullEvent()
        
        if event == "_play_sound" then
            local soundKey = param1
            local callback = param2
            
            -- Build URL based on format
            local extension = state.audioFormat == "wav" and ".wav" or ".dfpwm"
            local baseUrl = state.audioFormat == "wav" and BASE_URL_WAV or BASE_URL_DFPWM
            local url = baseUrl .. SOUNDS[soundKey] .. extension
            
            print("Playing: " .. url)
            
            local response = http.get(url, nil, true)
            
            if response then
                local streamFunc
                if state.audioFormat == "wav" then
                    streamFunc = aukit.stream.wav
                else
                    streamFunc = aukit.stream.dfpwm
                end
                
                local audio = streamFunc(function()
                    return response.read(48000)
                end)
                
                for chunk in audio do
                    -- Check if we need to stop
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
                
                -- Callback after sound ends
                if callback then
                    callback()
                end
            else
                print("Error loading: " .. url)
                state.playing = false
                os.queueEvent("_redraw")
            end
            
        elseif event == "_start_loop" then
            local loopKey = param1
            
            -- Infinite loop while this is the active loop
            while state.currentLoop == loopKey do
                local extension = state.audioFormat == "wav" and ".wav" or ".dfpwm"
                local baseUrl = state.audioFormat == "wav" and BASE_URL_WAV or BASE_URL_DFPWM
                local url = baseUrl .. SOUNDS[loopKey] .. extension
                
                print("Looping: " .. url)
                
                local response = http.get(url, nil, true)
                
                if response then
                    local streamFunc
                    if state.audioFormat == "wav" then
                        streamFunc = aukit.stream.wav
                    else
                        streamFunc = aukit.stream.dfpwm
                    end
                    
                    local audio = streamFunc(function()
                        return response.read(48000)
                    end)
                    
                    for chunk in audio do
                        -- Check if we need to stop this loop
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
                            
                            if state.currentLoop ~= loopKey then
                                break
                            end
                        end
                        
                        if state.currentLoop ~= loopKey then
                            break
                        end
                    end
                    
                    response.close()
                else
                    print("Error loading: " .. url)
                    break
                end
                
                -- Small pause before looping
                if state.currentLoop == loopKey then
                    sleep(0.1)
                end
            end
            
            state.playing = false
            os.queueEvent("_redraw")
        end
    end
end

-- ========================================
-- TARDIS LOGIC
-- ========================================

local function tardisStartup()
    if state.powered then return end
    state.powered = true
    
    playSound("startup", function()
        startLoop("ambiance")
    end)
end

local function tardisDematerialization()
    if not state.powered then return end
    
    stopLoop()
    playSound("takeoff", function()
        startLoop("flight")
    end)
end

local function tardisLanding()
    if not state.powered then return end
    
    stopLoop()
    playSound("landing", function()
        startLoop("ambiance")
    end)
end

local function tardisDeniedFlight()
    if not state.powered then return end
    
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

local function toggleFormat()
    stopLoop()
    state.audioFormat = state.audioFormat == "wav" and "dfpwm" or "wav"
end

-- ========================================
-- TERMINAL INTERFACE
-- ========================================

local function drawButton(x, y, width, text, active)
    term.setCursorPos(x, y)
    
    if active then
        term.setBackgroundColor(colors.orange)
        term.setTextColor(colors.white)
    else
        term.setBackgroundColor(colors.brown)
        term.setTextColor(colors.orange)
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
    
    -- Title
    term.setCursorPos(math.floor(w/2 - 12), 2)
    term.setTextColor(colors.orange)
    term.write("ARTRON OS TYPE 40")
    
    -- Status
    term.setCursorPos(2, 4)
    term.setTextColor(colors.orange)
    term.write("Status: ")
    term.setTextColor(state.powered and colors.lime or colors.red)
    term.write(state.powered and "ACTIVE" or "INACTIVE")
    
    term.setTextColor(colors.orange)
    term.setCursorPos(2, 5)
    term.write("Speakers: ")
    term.setTextColor(#state.speakers > 0 and colors.lime or colors.red)
    term.write(#state.speakers > 0 and (#state.speakers .. " connected") or "None")
    
    term.setTextColor(colors.orange)
    term.setCursorPos(2, 6)
    term.write("Format: ")
    term.setTextColor(colors.white)
    term.write(state.audioFormat:upper())
    
    -- Main buttons
    drawButton(2, 8, 14, "POWER ON", state.powered and not state.playing)
    drawButton(18, 8, 14, "POWER OFF", false)
    
    drawButton(2, 10, 14, "TAKEOFF", state.powered and state.currentLoop == "flight")
    drawButton(18, 10, 14, "LANDING", state.powered)
    
    drawButton(2, 12, 14, "SHORT FLIGHT", state.powered)
    drawButton(18, 12, 14, "DENIED", state.powered)
    
    -- Toggles
    drawButton(2, 14, 14, "CLOISTER", state.powered and state.currentLoop == "cloister")
    drawButton(18, 14, 14, "ERROR BIP", state.powered and state.currentLoop == "bip")
    
    -- Doors
    drawButton(2, 16, 14, "OPEN DOOR", state.powered)
    drawButton(18, 16, 14, "CLOSE DOOR", state.powered)
    
    -- Format toggle
    drawButton(2, 18, 30, "TOGGLE FORMAT (WAV/DFPWM)", false)
    
    -- Active loop status
    term.setCursorPos(2, 20)
    term.setTextColor(colors.orange)
    term.write("Active Loop: ")
    term.setTextColor(colors.white)
    if state.currentLoop then
        term.write(state.currentLoop:upper())
    else
        term.setTextColor(colors.gray)
        term.write("None")
    end
    
    -- Instructions
    term.setCursorPos(2, h - 1)
    term.setTextColor(colors.orange)
    term.write("Streaming audio via AUKit - One sound at a time")
end

local function handleClick(x, y)
    if isClickInButton(x, y, 2, 8, 14) then
        tardisStartup()
    elseif isClickInButton(x, y, 18, 8, 14) then
        tardisShutdown()
    elseif isClickInButton(x, y, 2, 10, 14) then
        tardisDematerialization()
    elseif isClickInButton(x, y, 18, 10, 14) then
        tardisLanding()
    elseif isClickInButton(x, y, 2, 12, 14) then
        tardisShortFlight()
    elseif isClickInButton(x, y, 18, 12, 14) then
        tardisDeniedFlight()
    elseif isClickInButton(x, y, 2, 14, 14) then
        toggleCloister()
    elseif isClickInButton(x, y, 18, 14, 14) then
        toggleBip()
    elseif isClickInButton(x, y, 2, 16, 14) then
        doorOpen()
    elseif isClickInButton(x, y, 18, 16, 14) then
        doorClose()
    elseif isClickInButton(x, y, 2, 18, 30) then
        toggleFormat()
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
    print(" ARTRON OS TYPE 40 - TARDIS SOUNDBOARD v4.0")
    print("=" .. string.rep("=", 45))
    term.setTextColor(colors.white)
    print("")
    
    -- Initialize AUKit
    print("Initializing AUKit...")
    if not initAukit() then
        term.setTextColor(colors.red)
        print("ERROR: Cannot initialize AUKit")
        term.setTextColor(colors.white)
        print("Press any key to exit...")
        os.pullEvent("key")
        return
    end
    term.setTextColor(colors.lime)
    print("AUKit loaded!")
    term.setTextColor(colors.white)
    
    -- Find speakers
    print("")
    print("Searching for speakers...")
    state.speakers = findSpeakers()
    
    if #state.speakers == 0 then
        term.setTextColor(colors.red)
        print("WARNING: No speaker found!")
        term.setTextColor(colors.white)
        print("Connect a speaker and restart.")
        print("")
        print("Press any key to continue anyway...")
        os.pullEvent("key")
    else
        term.setTextColor(colors.lime)
        print("Found: " .. #state.speakers .. " speaker(s)")
        term.setTextColor(colors.white)
        sleep(1)
    end
    
    -- Launch in parallel
    parallel.waitForAny(
        interfaceLoop,
        audioThread
    )
end

-- Launch
main()
