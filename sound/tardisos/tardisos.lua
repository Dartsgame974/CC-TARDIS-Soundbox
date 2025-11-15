-- tardis_soundboard.lua
-- Soundboard TARDIS pour CC:Tweaked (terminal only)
-- Auteur: assistant (exemple)
-- Date: 2025-11-15
-- Usage: placez ce fichier sur la machine CC, assurez-vous que http est activé et qu'un speaker est branché.

-- ===========================
-- CONFIG / LISTE DE SONS
-- ===========================
local SOUND_BASE_URL = "https://github.com/Dartsgame974/CC-TARDIS-Soundbox/raw/refs/heads/main/dfpwm/"

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
}

-- noms simplifiés pour l'usage interne (clé -> filename)
local NAME = {}
for _,v in ipairs(SOUNDS) do
  local key = v:gsub("%.dfpwm$","")
  NAME[key] = v
end

-- Répertoire local pour stocker les fichiers téléchargés
local SOUND_DIR = "tardis_sounds"
if not fs.exists(SOUND_DIR) then fs.makeDir(SOUND_DIR) end

-- ===========================
-- DÉTECTION DU SPEAKER
-- ===========================
local speaker = peripheral.find("speaker")
if not speaker then
  error("Aucun périphérique 'speaker' détecté. Branchez un haut-parleur et relancez.")
end

-- ===========================
-- API DFPWM & Cache
-- ===========================
local ok, dfpwm = pcall(require, "cc.audio.dfpwm")
if not ok or not dfpwm then
  error("Impossible de require('cc.audio.dfpwm'). Assurez-vous d'utiliser CC:Tweaked avec l'API dfpwm.")
end

-- cache mémoire pour éviter redécodage
local decoded_cache = {}  -- key = filename (ex: "ambiance.dfpwm") -> decoded_sound_object

-- Estimations de durée (en secondes) pour attendre entre playback lorsque nécessaire
-- Ajustez ces valeurs si le looping est trop court/long. Elles n'ont pas besoin d'être parfaites,
-- elles servent à éviter de relancer instantanément et créer des overlaps indésirables.
local estimated_durations = {
  startup_tardis = 4,
  ambiance = 60,
  tardis_flight_loop = 8,
  bip_sound_error_1 = 1.2,
  short_flight = 6,
  emergencyshutdown = 5,
  landing = 5,
  tardistakeoff = 4,
  denied_flight = 3,
  shutdowntardis = 4,
  close_door = 1,
  door_open = 1,
}

-- ===========================
-- TÉLÉCHARGEMENT / CHARGEMENT
-- ===========================
local function download_if_missing(filename)
  local localpath = fs.combine(SOUND_DIR, filename)
  if fs.exists(localpath) then
    return localpath
  end

  -- essayer de télécharger
  if not http then
    error("Fichier "..filename.." absent localement et 'http' n'est pas disponible sur ce serveur.")
  end

  local url = SOUND_BASE_URL .. filename
  print("Téléchargement: "..url.." ...")
  local res, err = http.get(url)
  if not res then
    error("Échec du téléchargement de "..url.." : "..tostring(err))
  end

  local content = res.readAll()
  res.close()

  local f = fs.open(localpath, "wb")
  f.write(content)
  f.close()

  return localpath
end

local function ensure_all_sounds()
  for _,filename in ipairs(SOUNDS) do
    local ok, err = pcall(download_if_missing, filename)
    if not ok then
      -- afficher un warning mais ne pas quitter : l'utilisateur pourra choisir d'utiliser le programme sans ce son
      print("Warning téléchargement: "..tostring(err))
    end
  end
end

local function load_sound_decoded(filename)
  -- Retourne l'objet décodé (mem cache), ou nil & message en cas d'erreur
  if decoded_cache[filename] then return decoded_cache[filename] end

  local localpath = fs.combine(SOUND_DIR, filename)
  if not fs.exists(localpath) then
    -- essayer téléchargement automatique
    local ok, err = pcall(download_if_missing, filename)
    if not ok then
      return nil, "Absence du fichier local et échec du téléchargement: "..tostring(err)
    end
  end

  local f = fs.open(localpath, "rb")
  if not f then return nil, "Impossible d'ouvrir "..localpath end
  local raw = f.readAll()
  f.close()

  -- décoder avec cc.audio.dfpwm
  local success, sound = pcall(dfpwm.decode, raw)
  if not success or not sound then
    return nil, "Décodage DFPWM échoué pour "..filename
  end

  decoded_cache[filename] = sound
  return sound
end

-- utilitaire : jouer un son (non-bloquant), renvoie true si joué
local function play_sound_byname(shortname, volume)
  volume = volume or 1.0
  local fname = NAME[shortname] or shortname
  local sound, err = load_sound_decoded(fname)
  if not sound then
    print("play_sound_byname: erreur: "..tostring(err))
    return false
  end

  -- La méthode 'playSound' du speaker joue l'objet retourné par dfpwm.decode
  pcall(function() speaker.playSound(sound, volume) end)
  return true
end

-- jouer un son et attendre une estimation de durée (approx), utile pour séquences
local function play_and_wait(shortname, volume)
  play_sound_byname(shortname, volume)
  local dur = estimated_durations[shortname] or 3
  sleep(dur)
end

-- ===========================
-- GESTION DES LOOPS (threads)
-- ===========================
local loops = {
  ambiance = { running = false, shortname = "ambiance" },
  flight = { running = false, shortname = "tardis_flight_loop" },
  cloister = { running = false, shortname = "ambiance" }, -- "cloister" n'a pas de fichier dédié listé; on peut réutiliser 'ambiance' ou config user.
  bip = { running = false, shortname = "bip_sound_error_1" },
}

-- Démarrer un loop (ne bloque pas)
local function start_loop(key)
  if not loops[key] then return end
  loops[key].running = true
end

local function stop_loop(key)
  if not loops[key] then return end
  loops[key].running = false
end

-- stopper toutes les loops
local function stop_all_loops()
  for k,_ in pairs(loops) do loops[k].running = false end
end

-- Thread worker pour une loop
local function loop_worker(key)
  local info = loops[key]
  while true do
    if info.running then
      -- jouer le son et attendre la durée approximative
      play_sound_byname(info.shortname)
      local dur = estimated_durations[info.shortname:gsub("%.dfpwm$","")] or estimated_durations[info.shortname] or 3
      -- si 'dur' est nil, défaut 3s
      sleep(dur or 3)
    else
      os.pullEvent("alarm") -- attente légère: permissive ; permet de sortir rapidement quand running devient true
    end
  end
end

-- ===========================
-- LOGIQUE TARDIS (haute-niveau)
-- ===========================
local TARDIS = {
  powered = false,
}

local function tardis_power_on()
  if TARDIS.powered then return end
  TARDIS.powered = true
  -- Jouer starting sound, puis lancer ambiance en boucle
  parallel.waitForAny(
    function()
      -- Play startup (blocking locally)
      play_and_wait("startup_tardis")
      -- lancer ambiance
      start_loop("ambiance")
      return
    end,
    function() sleep(0) end
  )
end

local function tardis_dematerialise()
  if not TARDIS.powered then return end
  -- stop ambiance, play takeoff, start flight loop
  stop_loop("ambiance")
  play_and_wait("tardistakeoff")
  start_loop("flight")
end

local function tardis_land()
  if not TARDIS.powered then return end
  stop_loop("flight")
  play_and_wait("landing")
  start_loop("ambiance")
end

local function tardis_denied()
  if not TARDIS.powered then return end
  play_and_wait("denied_flight")
  start_loop("ambiance")
end

local function tardis_short_flight()
  if not TARDIS.powered then return end
  play_and_wait("short_flight")
  start_loop("ambiance")
end

local function tardis_toggle_cloister()
  if loops.cloister.running then stop_loop("cloister") else start_loop("cloister") end
end

local function tardis_toggle_bip()
  if loops.bip.running then stop_loop("bip") else start_loop("bip") end
end

local function tardis_shutdown()
  if not TARDIS.powered then return end
  -- arrêter toutes les loops puis jouer shutdown
  stop_all_loops()
  play_and_wait("shutdowntardis")
  TARDIS.powered = false
end

local function tardis_open_door()
  play_and_wait("door_open")
end
local function tardis_close_door()
  play_and_wait("close_door")
end

-- ===========================
-- INTERFACE TERMINAL (100% term funcs)
-- ===========================
-- Boutons et dessin simple
local ui = {
  width = 51,
  height = 20,
  buttons = {}, -- table of {x,y,w,h,label,action}
  needs_redraw = true,
}

local function rect_contains(x,y,w,h, mx,my)
  return mx >= x and mx < x+w and my >= y and my < y+h
end

local function clear_box(x,y,w,h)
  for yy=y, y+h-1 do
    term.setCursorPos(x, yy)
    term.clearLine()
  end
end

local function draw_button(b, inverted)
  local x, y, w, h, label = b.x, b.y, b.w, b.h, b.label
  -- draw box
  for yy = y, y+h-1 do
    term.setCursorPos(x, yy)
    local line = ""
    for xx = 1, w do line = line .. " " end
    term.write(line)
  end
  -- border (simple)
  term.setCursorPos(x, y)
  term.write("[" .. string.rep("-", w-2) .. "]")
  term.setCursorPos(x, y+h-1)
  term.write("[" .. string.rep("-", w-2) .. "]")
  -- label centered
  local cx = x + math.floor((w - #label)/2)
  local cy = y + math.floor(h/2)
  term.setCursorPos(cx, cy)
  if inverted then
    term.write(label)
  else
    term.write(label)
  end
end

local function rebuild_buttons()
  ui.buttons = {}
  local x = 2
  local y = 2
  local bw = 16
  local bh = 3
  local gapx = 2
  local gapy = 1

  local function add(label, action)
    table.insert(ui.buttons, {x=x, y=y, w=bw, h=bh, label=label, action=action})
    y = y + bh + gapy
    if y + bh > ui.height - 2 then
      y = 2
      x = x + bw + gapx
    end
  end

  -- Boutons TARDIS
  add("POWER ON", function() tardis_power_on() end)
  add("DEMATERIALISE", function() tardis_dematerialise() end)
  add("LAND", function() tardis_land() end)
  add("SHORT FLIGHT", function() tardis_short_flight() end)
  add("DENY FLIGHT", function() tardis_denied() end)
  add("OPEN DOOR", function() tardis_open_door() end)
  add("CLOSE DOOR", function() tardis_close_door() end)
  add("CLOISTER TOGGLE", function() tardis_toggle_cloister() end)
  add("BIP TOGGLE", function() tardis_toggle_bip() end)
  add("SHUTDOWN", function() tardis_shutdown() end)
  add("EMERGENCY", function() play_and_wait("emergencyshutdown") end)

  -- second column spacing: add sound triggers for testing
  -- small inline buttons on right
  local rx = ui.width - 20
  local ry = 2
  local rw = 18
  local rh = 3
  local function add_right(label, action)
    table.insert(ui.buttons, {x=rx, y=ry, w=rw, h=rh, label=label, action=action})
    ry = ry + rh + gapy
  end

  add_right("PLAY STARTUP", function() play_and_wait("startup_tardis") end)
  add_right("PLAY AMBIANCE", function() start_loop("ambiance") end)
  add_right("STOP AMBIANCE", function() stop_loop("ambiance") end)
  add_right("PLAY FLIGHT", function() start_loop("flight") end)
  add_right("STOP FLIGHT", function() stop_loop("flight") end)
  add_right("PLAY SHORT", function() play_and_wait("short_flight") end)
  add_right("PLAY DENY", function() play_and_wait("denied_flight") end)
  add_right("PLAY SHUTDOWN", function() play_and_wait("shutdowntardis") end)

  ui.needs_redraw = true
end

local function draw_ui()
  term.clear()
  term.setCursorPos(1,1)
  local w,h = term.getSize()
  ui.width = w
  ui.height = h

  -- header
  term.setCursorPos(1,1)
  term.write("=== TARDIS Soundboard (Terminal UI) ===")
  term.setCursorPos(1,2)
  term.write(string.rep("-", ui.width))

  -- status area
  term.setCursorPos(1,4)
  term.write("Power: "..(TARDIS.powered and "ON" or "OFF"))
  term.setCursorPos(1,5)
  local loops_status = {}
  for k,v in pairs(loops) do
    table.insert(loops_status, k..":"..(v.running and "ON" or "OFF"))
  end
  term.setCursorPos(1,6)
  term.write("Loops: "..table.concat(loops_status, "  "))

  -- draw buttons
  for i,b in ipairs(ui.buttons) do
    draw_button(b)
  end

  term.setCursorPos(1, ui.height)
  term.write("Click a button with the mouse. Resize supported.")
  ui.needs_redraw = false
end

-- détecte clics sur boutons
local function handle_mouse_click(mx,my)
  for i,b in ipairs(ui.buttons) do
    if rect_contains(b.x, b.y, b.w, b.h, mx, my) then
      -- exécuter l'action dans un pcall pour éviter plantage interface
      local ok, err = pcall(b.action)
      if not ok then
        print("Erreur action bouton: "..tostring(err))
      end
      ui.needs_redraw = true
      return
    end
  end
end

-- Interface main loop
local function ui_loop()
  rebuild_buttons()
  draw_ui()

  while true do
    if ui.needs_redraw then draw_ui() end
    local ev = { os.pullEventRaw() }
    local et = ev[1]
    if et == "mouse_click" then
      local button, mx, my = ev[2], ev[3], ev[4]
      handle_mouse_click(mx, my)
    elseif et == "term_resize" then
      -- rebuild layout
      rebuild_buttons()
      ui.needs_redraw = true
    elseif et == "key" then
      -- touches utiles: q pour quitter proprement (non détruit par défaut)
      if ev[2] == keys.q and (ev[3] and (ev[3] & keys.leftCtrl == keys.leftCtrl)) then
        -- ctrl+q: quit safely
        return
      end
    end
  end
end

-- ===========================
-- DÉMARRAGE GÉNÉRAL
-- ===========================
-- Lancer les workers: ambiance, flight, cloister, bip, et interface
local function main()
  -- s'assurer que les sons listés sont présents (téléchargement non bloquant)
  -- nous essayons de télécharger les fichiers manquants dès le départ
  local ok, err = pcall(ensure_all_sounds)
  if not ok then
    print("Warning: ensure_all_sounds: "..tostring(err))
  end

  -- préparer workers (chaque worker appelle loop_worker pour la clé correspondante)
  local workers = {
    function() loop_worker("ambiance") end,
    function() loop_worker("flight") end,
    function() loop_worker("cloister") end,
    function() loop_worker("bip") end,
    function() ui_loop() end,
  }

  print("Lancement du soundboard. Utilisez la souris pour cliquer sur les boutons.")
  parallel.waitForAny(table.unpack(workers))
end

-- Exécuter main dans un pcall pour capturer erreurs
local status, err = pcall(main)
if not status then
  print("Erreur critique: "..tostring(err))
end
