-- Interface loop for terminal (complete)
local function interface_loop_terminal()
    local button_defs = {
        {id = "power", text_func = function() return powered and "POWER OFF" or "POWER ON" end, action = power_toggle, is_active = function() return true end, can_click = function() return true end},
        {id = "takeoff", text = "TAKEOFF", action = takeoff, is_active = function() return powered and current_loop ~= "tardis_flight_loop" end, can_click = function() return powered and current_loop ~= "tardis_flight_loop" end},
        {id = "landing", text = "LANDING", action = landing, is_active = function() return powered and current_loop == "tardis_flight_loop" end, can_click = function() return powered and current_loop == "tardis_flight_loop" end},
        {id = "short_flight", text = "SHORT FLIGHT", action = short_flight_func, is_active = function() return powered end, can_click = function() return powered end},
        {id = "denied", text = "DENIED", action = denied, is_active = function() return powered end, can_click = function() return powered end},
        {id = "cloister", text = "CLOISTER", action = cloister_toggle, is_active = function() return powered and current_loop == "cloister_ding" end, can_click = function() return powered end},
        {id = "bip", text = "ERROR BIP", action = bip_toggle, is_active = function() return powered and current_loop == "bip_sound_error_1" end, can_click = function() return powered end},
        {id = "door", text_func = function() return door_state == "closed" and "OPEN DOOR" or "CLOSE DOOR" end, action = door_toggle, is_active = function() return powered end, can_click = function() return powered end},
    }

    local function get_status_text()
        local status = powered and "ACTIVE" or "INACTIVE"
        if powered and current_loop == "tardis_flight_loop" then
            status = status .. " (IN FLIGHT)"
        end
        return status
    end

    local function redraw()
        term.setBackgroundColor(colors.black)
        term.clear()
        local w, h = term.getSize()
        -- Title top left
        term.setCursorPos(1, 1)
        term.setTextColor(colors.orange)
        term.write("ARTRON OS TYPE 40")
        -- Separator line
        term.setCursorPos(1, 2)
        term.setTextColor(colors.orange)
        term.write(string.rep("-", w))
        
        -- Power button top left (below title)
        local power_b = button_defs[1]
        local power_text = power_b.text_func()
        term.setCursorPos(1, 3)
        if power_b.is_active() then
            term.setBackgroundColor(colors.orange)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.brown)
            term.setTextColor(colors.orange)
        end
        term.write("[" .. power_text .. "]")
        power_b.curr_x = 1
        power_b.curr_y = 3
        power_b.curr_w = #power_text + 2
        power_b.curr_h = 1
        
        -- Other buttons top right: SHORT FLIGHT, DENIED, CLOISTER, ERROR BIP, DOOR
        local other_buttons = {button_defs[4], button_defs[5], button_defs[6], button_defs[7], button_defs[8]}
        local max_other_w = 0
        for _, b in ipairs(other_buttons) do
            local btn_text = b.text or b.text_func()
            max_other_w = math.max(max_other_w, #btn_text + 2)
        end
        local other_x = w - max_other_w + 1
        local other_y = 3
        for i, b in ipairs(other_buttons) do
            local y = other_y + i - 1
            local btn_text = b.text or b.text_func()
            term.setCursorPos(other_x, y)
            if b.is_active() then
                term.setBackgroundColor(colors.orange)
                term.setTextColor(colors.white)
            else
                term.setBackgroundColor(colors.brown)
                term.setTextColor(colors.orange)
            end
            term.write("[" .. btn_text .. "]")
            b.curr_x = other_x
            b.curr_y = y
            b.curr_w = #btn_text + 2
            b.curr_h = 1
        end
        
        -- Flight status/buttons bottom: TAKEOFF | FLIGHT | LANDING
        local flight_text = "FLIGHT"
        local takeoff_b = button_defs[2]
        local landing_b = button_defs[3]
        local is_in_flight = current_loop == "tardis_flight_loop"
        local takeoff_text = takeoff_b.text
        local landing_text = landing_b.text
        local total_width = #takeoff_text + 2 + #flight_text + 2 + #landing_text + 2 + 4
        local flight_start_x = math.floor((w - total_width) / 2) + 1
        -- TAKEOFF button
        term.setCursorPos(flight_start_x, h)
        if takeoff_b.is_active() then
            term.setBackgroundColor(colors.orange)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.brown)
            term.setTextColor(colors.orange)
        end
        term.write("[" .. takeoff_text .. "]")
        takeoff_b.curr_x = flight_start_x
        takeoff_b.curr_y = h
        takeoff_b.curr_w = #takeoff_text + 2
        takeoff_b.curr_h = 1
        -- | FLIGHT |
        local flight_x = flight_start_x + takeoff_b.curr_w + 2
        term.setCursorPos(flight_x, h)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.orange)
        if is_in_flight then
            term.setBackgroundColor(colors.orange)
            term.setTextColor(colors.white)
        end
        term.write("[" .. flight_text .. "]")
        -- LANDING button
        local landing_x = flight_x + #flight_text + 2 + 2
        term.setCursorPos(landing_x, h)
        if landing_b.is_active() then
            term.setBackgroundColor(colors.orange)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.brown)
            term.setTextColor(colors.orange)
        end
        term.write("[" .. landing_text .. "]")
        landing_b.curr_x = landing_x
        landing_b.curr_y = h
        landing_b.curr_w = #landing_text + 2
        landing_b.curr_h = 1
        -- Status lines, each on separate line, centered above bottom
        local status_lines = {
            "TARDIS Status: " .. get_status_text(),
            "Speakers Connected: " .. #speakers,
            "Chat Box: " .. (chat_box and "Connected" or "Not Connected")
        }
        local status_start_y = h - #status_lines - 1
        for i, line in ipairs(status_lines) do
            term.setCursorPos(math.floor((w - #line) / 2) + 1, status_start_y + i - 1)
            term.setTextColor(colors.orange)
            term.setBackgroundColor(colors.black)
            term.write(line)
        end
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    update_redstone()

    while true do
        redraw()
        while true do
            local event, param1, param2, param3 = os.pullEvent()
            if event == "term_resize" then
                break
            elseif event == "mouse_click" then
                local button, x, y = param1, param2, param3
                local clicked = false
                for _, b in ipairs(button_defs) do
                    if b.curr_x and x >= b.curr_x and x < b.curr_x + b.curr_w and y >= b.curr_y and y < b.curr_y + b.curr_h then
                        if b.can_click() then
                            b.action()
                            clicked = true
                        end
                        break
                    end
                end
                if clicked then
                    break
                end
            end
        end
    end
end

-- Interface loop for monitor (condensed)
local function interface_loop_monitor()
    local button_defs = {
        {id = "power", text_func = function() return powered and "OFF" or "ON" end, action = power_toggle, is_active = function() return true end, can_click = function() return true end},
        {id = "takeoff", text = "TK", action = takeoff, is_active = function() return powered and current_loop ~= "tardis_flight_loop" end, can_click = function() return powered and current_loop ~= "tardis_flight_loop" end},
        {id = "landing", text = "LD", action = landing, is_active = function() return powered and current_loop == "tardis_flight_loop" end, can_click = function() return powered and current_loop == "tardis_flight_loop" end},
    }

    local function redraw()
        monitor.setBackgroundColor(colors.black)
        monitor.clear()
        local w, h = monitor.getSize()
        
        -- Title centered top
        local title = "R3OS TYPE 40"
        monitor.setCursorPos(math.floor((w - #title) / 2) + 1, 1)
        monitor.setTextColor(colors.orange)
        monitor.write(title)
        
        -- Power button centered
        local power_b = button_defs[1]
        local power_text = power_b.text_func()
        local power_w = #power_text + 2
        local power_x = math.floor((w - power_w) / 2) + 1
        monitor.setCursorPos(power_x, 3)
        if power_b.is_active() then
            monitor.setBackgroundColor(colors.orange)
            monitor.setTextColor(colors.white)
        else
            monitor.setBackgroundColor(colors.brown)
            monitor.setTextColor(colors.orange)
        end
        monitor.write("[" .. power_text .. "]")
        power_b.curr_x = power_x
        power_b.curr_y = 3
        power_b.curr_w = power_w
        power_b.curr_h = 1
        
        -- TAKEOFF and LANDING buttons side by side, centered
        local takeoff_b = button_defs[2]
        local landing_b = button_defs[3]
        local takeoff_text = takeoff_b.text
        local landing_text = landing_b.text
        local buttons_width = #takeoff_text + 2 + 2 + #landing_text + 2  -- +2 for spacing
        local buttons_start_x = math.floor((w - buttons_width) / 2) + 1
        
        monitor.setCursorPos(buttons_start_x, 5)
        if takeoff_b.is_active() then
            monitor.setBackgroundColor(colors.orange)
            monitor.setTextColor(colors.white)
        else
            monitor.setBackgroundColor(colors.brown)
            monitor.setTextColor(colors.orange)
        end
        monitor.write("[" .. takeoff_text .. "]")
        takeoff_b.curr_x = buttons_start_x
        takeoff_b.curr_y = 5
        takeoff_b.curr_w = #takeoff_text + 2
        takeoff_b.curr_h = 1
        
        local landing_x = buttons_start_x + takeoff_b.curr_w + 2
        monitor.setCursorPos(landing_x, 5)
        if landing_b.is_active() then
            monitor.setBackgroundColor(colors.orange)
            monitor.setTextColor(colors.white)
        else
            monitor.setBackgroundColor(colors.brown)
            monitor.setTextColor(colors.orange)
        end
        monitor.write("[" .. landing_text .. "]")
        landing_b.curr_x = landing_x
        landing_b.curr_y = 5
        landing_b.curr_w = #landing_text + 2
        landing_b.curr_h = 1
        
        -- Flight status at bottom if in flight
        if current_loop == "tardis_flight_loop" then
            local flight_text = "FLIGHT"
            monitor.setCursorPos(math.floor((w - #flight_text) / 2) + 1, h)
            monitor.setBackgroundColor(colors.orange)
            monitor.setTextColor(colors.white)
            monitor.write(flight_text)
        end
        
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)
    end

    while true do
        redraw()
        while true do
            local event, side, x, y = os.pullEvent()
            if event == "monitor_resize" then
                break
            elseif event == "monitor_touch" then
                local clicked = false
                for _, b in ipairs(button_defs) do
                    if b.curr_x and x >= b.curr_x and x < b.curr_x + b.curr_w and y >= b.curr_y and y < b.curr_y + b.curr_h then
                        if b.can_click() then
                            b.action()
                            clicked = true
                        end
                        break
                    end
                end
                if clicked then
                    break
                end
            end
        end
    end
end

-- Main interface loop dispatcher
local function interface_loop()
    if is_monitor then
        interface_loop_monitor()
    else
        interface_loop_terminal()
    end
end
