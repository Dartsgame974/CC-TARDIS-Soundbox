-- TARDIS Ambiance Test
local speaker = peripheral.find("speaker")
if not speaker then error("No speaker found!") end

-- URL du son ambiance
local ambianceURL = "https://raw.githubusercontent.com/Dartsgame974/CC-TARDIS-Soundbox/main/sound/ambiance.wav"

-- État de la boucle
local ambianceStop = nil
local ambianceActive = false

-- Fonction pour jouer en boucle
local function startAmbiance()
    if ambianceStop then ambianceStop() end
    local running = true
    ambianceStop = function() running = false end
    local co = coroutine.create(function()
        while running do
            shell.run("austream", ambianceURL)
            os.sleep(0.1)
        end
    end)
    coroutine.resume(co)
    ambianceActive = true
end

local function stopAmbiance()
    if ambianceStop then ambianceStop() end
    ambianceActive = false
end

-- Toggle
local function toggleAmbiance()
    if ambianceActive then
        stopAmbiance()
    else
        startAmbiance()
    end
end

-- Interface
local button = {x=10, y=5, w=30, h=3, text="Toggle Ambiance"}

local function drawButton(btn, pressed)
    local bg, fg = colors.black, colors.orange
    if pressed then bg, fg = colors.orange, colors.black end
    paintutils.drawFilledBox(btn.x, btn.y, btn.x+btn.w-1, btn.y+btn.h-1, bg)
    term.setCursorPos(btn.x + math.floor((btn.w - #btn.text)/2), btn.y + math.floor(btn.h/2))
    term.setTextColor(fg)
    term.write(btn.text)
end

local function drawUI()
    term.clear()
    local w,h = term.getSize()
    term.setTextColor(colors.orange)
    local title = "Artron OS – Ambiance Test"
    term.setCursorPos(math.floor((w-#title)/2)+1,1)
    term.write(title)
    drawButton(button,false)
    -- barre de lecture forcée en bas
    paintutils.drawFilledBox(1,h,w,h,colors.black)
end

local function handleTouch(x,y)
    if x>=button.x and x<=button.x+button.w-1 and y>=button.y and y<=button.y+button.h-1 then
        drawButton(button,true)
        toggleAmbiance()
        os.sleep(0.1)
        drawButton(button,false)
    end
end

-- Lancement
drawUI()
while true do
    local event, side, x, y = os.pullEvent("mouse_click")
    handleTouch(x,y)
end
