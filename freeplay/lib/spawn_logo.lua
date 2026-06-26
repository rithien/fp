local Event = require 'lib.event'
local Constants = require 'constants'
local Config = require 'lib.config'
local DebugLog = require 'lib.debug_log'
local TOGGLE_ID = 'spawn_logo'
local RENDER_VERSION = 6
local SWEEP_INTERVAL = 600
local reasserted_after_load = false
local Public = {}
local function safe_destroy(obj)
    if obj and obj.valid then obj.destroy() end
end
local function ensure_storage()
    if not storage.spawn_logo then
        storage.spawn_logo = { surfaces = {} }
    end
    local s = storage.spawn_logo
    if not s.surfaces then s.surfaces = {} end
    if s.sprite ~= nil or s.light ~= nil or s.texts ~= nil then
        safe_destroy(s.sprite)
        safe_destroy(s.light)
        if type(s.texts) == 'table' then
            for _, t in pairs(s.texts) do safe_destroy(t) end
        end
        s.sprite = nil
        s.light = nil
        s.texts = nil
        s.code_version = nil 
    end
end
local function is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
local function is_logo_surface(surface)
    local ok_pf, platform = pcall(function() return surface.platform end)
    if ok_pf and platform then return false end
    if surface == game.surfaces[1] then return true end
    local ok_pl, planet = pcall(function() return surface.planet end)
    if ok_pl and planet then return true end
    return false
end
local function target_surfaces()
    local result = {}
    for _, surface in pairs(game.surfaces) do
        if surface and surface.valid and is_logo_surface(surface) then
            result[#result + 1] = surface
        end
    end
    return result
end
local function logo_position(surface)
    local cfg = Constants.spawn_logo
    local off = cfg.position_offset or { x = 0, y = 0 }
    local spawn = { x = 0, y = 0 }
    local pforce = game.forces.player
    if pforce then
        local sp = pforce.get_spawn_position(surface)
        if sp then spawn = sp end
    end
    return { x = spawn.x + (off.x or 0), y = spawn.y + (off.y or 0) }
end
local function destroy_entry(idx)
    local s = storage.spawn_logo
    local entry = s.surfaces[idx]
    if not entry then return end
    safe_destroy(entry.sprite)
    safe_destroy(entry.light)
    for _, t in pairs(entry.texts or {}) do safe_destroy(t) end
    s.surfaces[idx] = nil
end
local function destroy_all()
    ensure_storage()
    local s = storage.spawn_logo
    local n = 0
    for idx in pairs(s.surfaces) do
        destroy_entry(idx)
        n = n + 1
    end
    DebugLog.log('[spawn_logo] destroy_all — render-objekty usunięte (%d powierzchni)', n)
end
Public.destroy_all = destroy_all
local function prune_dead_surfaces()
    local s = storage.spawn_logo
    for idx in pairs(s.surfaces) do
        local surf = game.get_surface(idx)
        if not (surf and surf.valid) then
            destroy_entry(idx)
        end
    end
end
local function draw(surface)
    local cfg = Constants.spawn_logo
    local pos = logo_position(surface)
    local entry = { sprite = nil, light = nil, texts = {} }
    local ok, sprite = pcall(function()
        return rendering.draw_sprite({
            sprite = cfg.sprite,
            render_layer = cfg.render_layer or 'floor',
            target = pos,
            x_scale = cfg.scale,
            y_scale = cfg.scale,
            surface = surface,
        })
    end)
    if not ok or not sprite then
        DebugLog.log('[spawn_logo] draw — sprite "%s" niegotowy na "%s" (early lifecycle), ponowię przy następnym sweepie',
            tostring(cfg.sprite), surface.name)
        return pos
    end
    entry.sprite = sprite
    if cfg.light and cfg.light.enabled then
        entry.light = rendering.draw_light({
            sprite = cfg.light.sprite or 'utility/light_medium',
            render_layer = cfg.render_layer or 'floor',
            target = pos,
            scale = cfg.light.scale or 6,
            surface = surface,
            minimum_darkness = cfg.light.minimum_darkness or 0.1,
        })
    end
    for _, line in pairs(cfg.text_lines or {}) do
        entry.texts[#entry.texts + 1] = rendering.draw_text({
            text = line.text,
            surface = surface,
            target = { pos.x, pos.y + (line.y or 0) },
            scale = line.scale or 2.0,
            color = line.color or { r = 1, g = 1, b = 1 },
            alignment = 'center',
            vertical_alignment = line.vertical_alignment or 'middle',
            draw_on_ground = line.draw_on_ground ~= false, 
            scale_with_zoom = false,
        })
    end
    storage.spawn_logo.surfaces[surface.index] = entry
    DebugLog.log('[spawn_logo] draw — surface "%s" @ (%.1f,%.1f) scale=%s lines=%d',
        surface.name, pos.x, pos.y, tostring(cfg.scale), #entry.texts)
    return pos
end
local function cleanup_legacy_info_panel()
    if storage.spawn_logo and storage.spawn_logo.legacy_info_panel_cleaned then return end
    local removed = 0
    if storage.info_panel and storage.info_panel.panels then
        for _, e in pairs(storage.info_panel.panels) do
            if e and e.valid then e.destroy(); removed = removed + 1 end
        end
    end
    storage.info_panel = nil 
    if prototypes.entity['display-panel'] then
        for _, surface in pairs(game.surfaces) do
            if surface and surface.valid then
                local panels = surface.find_entities_filtered({ name = 'display-panel', area = { { -2, -2 }, { 2, 2 } } })
                for _, e in pairs(panels) do
                    if e.valid and not e.destructible and not e.minable then
                        e.destroy(); removed = removed + 1
                    end
                end
            end
        end
    end
    if storage.spawn_logo then storage.spawn_logo.legacy_info_panel_cleaned = true end
    if removed > 0 then
        log(string.format('[spawn_logo] legacy info-panel cleanup: usunięto %d osierocony(ch) display-panel', removed))
    end
end
local function ensure_surface(surface)
    local entry = storage.spawn_logo.surfaces[surface.index]
    if entry and entry.sprite and entry.sprite.valid then
        return 
    end
    draw(surface)
end
local function ensure()
    ensure_storage()
    cleanup_legacy_info_panel()
    if not is_enabled() then
        destroy_all()
        return
    end
    local s = storage.spawn_logo
    if not reasserted_after_load or s.code_version ~= RENDER_VERSION then
        destroy_all()
        s.code_version = RENDER_VERSION
        reasserted_after_load = true
    end
    prune_dead_surfaces()
    for _, surface in pairs(target_surfaces()) do
        ensure_surface(surface)
    end
end
Public.ensure = ensure
local function redraw()
    destroy_all()
    if is_enabled() then
        prune_dead_surfaces()
        for _, surface in pairs(target_surfaces()) do
            draw(surface)
        end
        storage.spawn_logo.code_version = RENDER_VERSION
    end
end
Public.redraw = redraw
function Public.apply(state)
    if state then ensure() else destroy_all() end
end
Event.on_init(ensure)
Event.on_configuration_changed(ensure)
Event.add(defines.events.on_player_joined_game, function()
    ensure()
end)
Event.add(defines.events.on_surface_created, function()
    ensure()
end)
Event.on_nth_tick(SWEEP_INTERVAL, ensure)
local Commands = require 'lib.commands'
Commands.new('spawnlogo', 'Force-redraw the spawn logo on every planet and report status (admin)')
    :require_admin()
    :callback(function(cmd)
        ensure_storage()
        redraw()
        local cfg = Constants.spawn_logo
        local s = storage.spawn_logo
        local lines = {
            string.format('[spawn_logo] toggle=%s sprite="%s" scale=%s',
                tostring(is_enabled()), tostring(cfg.sprite), tostring(cfg.scale)),
        }
        local surfaces = target_surfaces()
        if #surfaces == 0 then
            lines[#lines + 1] = '  surfaces: NONE (brak powierzchni-planet)'
        else
            for _, surface in pairs(surfaces) do
                local entry = s.surfaces[surface.index]
                local pos = logo_position(surface)
                lines[#lines + 1] = string.format('  surface "%s" pos=(%.1f,%.1f) sprite=%s light=%s texts=%d',
                    surface.name, pos.x, pos.y,
                    tostring(entry ~= nil and entry.sprite ~= nil and entry.sprite.valid),
                    tostring(entry ~= nil and entry.light ~= nil and entry.light.valid),
                    entry and #(entry.texts or {}) or 0)
            end
        end
        local report = table.concat(lines, '\n')
        log(report)
        if cmd.player_index then
            local p = game.get_player(cmd.player_index)
            if p and p.valid then p.print(report) end
        end
    end)
return Public
