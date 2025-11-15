-- Test simple : ambiance en boucle via un bouton

-- Vérifie le speaker
local speaker = peripheral.find("speaker")
if not speaker then error("No speaker trouvé !") end

-- URL du son
local ambianceURL = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/ambiance.wav"

-- État de la boucle
local running = false
local co = nil

-- Fonction pour démarrer la boucle
local function startAmbiance()
    if running then return end
    running = true
    co = coroutine.create(function()
        while running do
            shell.run("austream", ambianceURL)
            os.sleep(0.1)
        end
    end)
    coroutine.resume(co)
end

-- Fonction pour stopper la boucle
local function stopAmbiance()
    running = false
end

-- Toggle
local function toggleAmbiance()
    if running then
        stopAmbiance()
    else
        startAmbiance()
    end
end

-- Interface minimaliste
local button = {x=10, y=5, w=20, h=3, text="Toggle Ambiance"}

local function drawButton(btn, pressed)
    local bg, fg = colors.black, colors.orange
    if pressed then bg, fg = colors.orange, colors.black end
    paintutils.drawFilledBox(btn.x, btn.y, btn.x+btn.w-1, btn.y+btn.h-1, bg)
    term.setCursorPos(btn.x + math.floor((btn.w - #btn.text)/2), btn.y + math.floor(btn.h/2))
    term.setTextColor(fg)
    term.write(btn.text)
end

-- Dessine interface
term.clear()
drawButton(button,false)

-- Gestion des clics
while true do
    local event, side, x, y = os.pullEvent("mouse_click")
    if x>=button.x and x<=button.x+button.w-1 and y>=button.y and y<=button.y+button.h-1 then
        drawButton(button,true)
        toggleAmbiance()
        os.sleep(0.1)
        drawButton(button,false)
    end
end
