local Event = require 'lib.event'
local Constants = require 'constants'
local Config = require 'lib.config'
local DebugLog = require 'lib.debug_log'
local TOGGLE_ID = 'spawn_logo'
local Public = {}
local function ensure_storage()
    if not storage.spawn_logo then
        storage.spawn_logo = { sprite = nil, light = nil, texts = {} }
    end
    if not storage.spawn_logo.texts then storage.spawn_logo.texts = {} end
end
local function is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
local function target_surface()
    local surface = game.surfaces[1]
    if surface and surface.valid then return surface end
    return nil
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
local function safe_destroy(obj)
    if obj and obj.valid then obj.destroy() end
end
local function destroy_all()
    ensure_storage()
    local s = storage.spawn_logo
    safe_destroy(s.sprite)
    safe_destroy(s.light)
    for _, t in pairs(s.texts) do safe_destroy(t) end
    s.sprite = nil
    s.light = nil
    s.texts = {}
    DebugLog.log('[spawn_logo] destroy_all — render-objekty usunięte')
end
Public.destroy_all = destroy_all
local function draw(surface)
    local cfg = Constants.spawn_logo
    local pos = logo_position(surface)
    local s = storage.spawn_logo
    s.sprite = rendering.draw_sprite({
        sprite = cfg.sprite,
        render_layer = cfg.render_layer or 'floor',
        target = pos,
        x_scale = cfg.scale,
        y_scale = cfg.scale,
        surface = surface,
    })
    if cfg.light and cfg.light.enabled then
        s.light = rendering.draw_light({
            sprite = cfg.light.sprite or 'utility/light_medium',
            render_layer = cfg.render_layer or 'floor',
            target = pos,
            scale = cfg.light.scale or 6,
            surface = surface,
            minimum_darkness = cfg.light.minimum_darkness or 0.1,
        })
    end
    s.texts = {}
    for _, line in pairs(cfg.text_lines or {}) do
        s.texts[#s.texts + 1] = rendering.draw_text({
            text = line.text,
            surface = surface,
            target = { pos.x, pos.y + (line.y or 0) },
            scale = line.scale or 2.0,
            color = line.color or { r = 1, g = 1, b = 1 },
            alignment = 'center',
            draw_on_ground = true,
            scale_with_zoom = false,
        })
    end
    DebugLog.log('[spawn_logo] draw — surface "%s" @ (%.1f,%.1f) scale=%s lines=%d',
        surface.name, pos.x, pos.y, tostring(cfg.scale), #s.texts)
    return pos
end
local function ensure()
    ensure_storage()
    if not is_enabled() then
        destroy_all()
        return
    end
    local surface = target_surface()
    if not surface then return end
    if storage.spawn_logo.sprite and storage.spawn_logo.sprite.valid then
        return 
    end
    draw(surface)
end
Public.ensure = ensure
local function redraw()
    destroy_all()
    if is_enabled() then
        local surface = target_surface()
        if surface then draw(surface) end
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
local Commands = require 'lib.commands'
Commands.new('spawnlogo', 'Force-redraw the spawn logo and report status (admin)')
    :require_admin()
    :callback(function(cmd)
        ensure_storage()
        redraw()
        local cfg = Constants.spawn_logo
        local surface = target_surface()
        local s = storage.spawn_logo
        local lines = {
            string.format('[spawn_logo] toggle=%s sprite="%s" scale=%s',
                tostring(is_enabled()), tostring(cfg.sprite), tostring(cfg.scale)),
        }
        if surface then
            local pos = logo_position(surface)
            lines[#lines + 1] = string.format('  surface "%s" pos=(%.1f,%.1f)', surface.name, pos.x, pos.y)
        else
            lines[#lines + 1] = '  surface: NONE (game.surfaces[1] niedostępna)'
        end
        lines[#lines + 1] = string.format('  render: sprite=%s light=%s texts=%d',
            tostring(s.sprite ~= nil and s.sprite.valid),
            tostring(s.light ~= nil and s.light.valid),
            #s.texts)
        local report = table.concat(lines, '\n')
        log(report)
        if cmd.player_index then
            local p = game.get_player(cmd.player_index)
            if p and p.valid then p.print(report) end
        end
    end)
return Public
