local Event = require 'lib.event'
local Constants = require 'constants'
local PANEL_NAME = 'display-panel'
local Public = {}
local function ensure_storage()
    if not storage.info_panel then
        storage.info_panel = { panels = {} }
    end
end
local function is_planet_surface(surface)
    return surface and surface.valid and surface.planet ~= nil
end
local function find_existing_panel(surface, pos)
    local area = { { pos.x - 1.5, pos.y - 1.5 }, { pos.x + 1.5, pos.y + 1.5 } }
    return surface.find_entities_filtered({ name = PANEL_NAME, area = area })[1]
end
local function configure(panel)
    panel.force = 'player'
    panel.destructible = false   
    panel.minable = false        
    panel.operable = false       
    panel.rotatable = false
    panel.display_panel_icon = Constants.info_panel.icon          
    panel.display_panel_always_show = true                        
    panel.display_panel_show_in_chart = true                      
    panel.display_panel_text = Constants.info_panel.text          
end
local function ensure_panel(surface)
    if not prototypes.entity[PANEL_NAME] then return end   
    if not is_planet_surface(surface) then return end
    ensure_storage()
    local tracked = storage.info_panel.panels[surface.index]
    if tracked and tracked.valid then
        configure(tracked)
        return
    end
    local pos = Constants.info_panel.position
    local panel = find_existing_panel(surface, pos)
    if not (panel and panel.valid) then
        local cx = math.floor(pos.x / 32)
        local cy = math.floor(pos.y / 32)
        if not surface.is_chunk_generated({ cx, cy }) then
            surface.request_to_generate_chunks(pos, 1)
            surface.force_generate_chunk_requests()
        end
        panel = surface.create_entity({
            name = PANEL_NAME,
            position = pos,
            force = 'player',
        })
        if not (panel and panel.valid) then
            log(string.format('[info_panel] create_entity FAILED %s na "%s" (pos %s,%s, chunk_generated=%s)',
                PANEL_NAME, surface.name, pos.x, pos.y, tostring(surface.is_chunk_generated({ cx, cy }))))
            return
        end
        log(string.format('[info_panel] panel utworzony na surface "%s": żądano (%s,%s), faktyczna (%.2f,%.2f)',
            surface.name, pos.x, pos.y, panel.position.x, panel.position.y))
    end
    configure(panel)
    storage.info_panel.panels[surface.index] = panel
    local pp = panel.position
    panel.force.chart(surface, { { pp.x - 1, pp.y - 1 }, { pp.x + 1, pp.y + 1 } })
end
Public.ensure_panel = ensure_panel
local function ensure_all()
    ensure_storage()
    for _, surface in pairs(game.surfaces) do
        local ok, err = pcall(ensure_panel, surface)
        if not ok then
            log(string.format('[info_panel] ensure_panel("%s") error: %s', surface.name, tostring(err)))
        end
    end
end
Public.ensure_all = ensure_all
Event.on_init(ensure_all)
Event.on_configuration_changed(ensure_all)
Event.add(defines.events.on_surface_created, function(event)
    local surface = game.get_surface(event.surface_index)
    if surface then ensure_panel(surface) end
end)
Event.add(defines.events.on_player_joined_game, function()
    ensure_all()
end)
local Commands = require 'lib.commands'
Commands.new('infopanel', 'Force-create/refresh info panels on all planets and report status (admin)')
    :require_admin()
    :callback(function(cmd)
        ensure_all()
        local pos = Constants.info_panel.position
        local lines = { string.format('[info_panel] prototype "%s" present=%s; position=(%s,%s)',
            PANEL_NAME, tostring(prototypes.entity[PANEL_NAME] ~= nil), pos.x, pos.y) }
        for _, surface in pairs(game.surfaces) do
            local planet = is_planet_surface(surface)
            local desc
            if not planet then
                desc = 'not a planet (skipped)'
            else
                local panel = find_existing_panel(surface, pos)
                if panel and panel.valid then
                    local txt = panel.display_panel_text
                    local txt_info
                    if type(txt) == 'string' then txt_info = string.format('%q', txt)
                    elseif txt == nil then txt_info = 'nil'
                    else txt_info = 'set(' .. type(txt) .. ')' end
                    desc = string.format('panel @ (%.2f,%.2f) always_show=%s show_in_chart=%s text=%s',
                        panel.position.x, panel.position.y,
                        tostring(panel.display_panel_always_show),
                        tostring(panel.display_panel_show_in_chart),
                        txt_info)
                else
                    local wide = surface.find_entities_filtered({ name = PANEL_NAME })
                    desc = string.format('NO panel near (0,0); %d display-panel(s) on whole surface', #wide)
                end
            end
            lines[#lines + 1] = string.format('  surface "%s" planet=%s -> %s', surface.name, tostring(planet), desc)
        end
        local report = table.concat(lines, '\n')
        log(report)
        if cmd.player_index then
            local p = game.get_player(cmd.player_index)
            if p and p.valid then p.print(report) end
        end
    end)
return Public
