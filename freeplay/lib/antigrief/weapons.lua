local Session = require 'lib.sessions'
local Jail = require 'lib.jail'
local FancyTime = require 'lib.fancy_time'
local Task = require 'lib.task'
local Token = require 'lib.token'
local Server = require 'lib.server'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local AG = Constants.antigrief
local AUDIT = Constants.audit
local format = string.format
local floor = math.floor
local abs = math.abs
local random = math.random
local match = string.match
local sub = string.sub
local color_yellow = { r = 1, g = 1, b = 0 }
local Weapons = {}
local this
Core.register_binder(function(s) this = s end)
local should_hard_block = Core.should_hard_block
local hard_block_action = Core.hard_block_action
local enforce_punish = Core.enforce_punish
local tamper_warn_or_strike = Core.tamper_warn_or_strike
local do_action = Core.do_action
local damage_player = Core.damage_player
local get_owner_name = Core.get_owner_name
local action_warning = Core.action_warning
local print_to = Core.print_to
local log_msg = Core.log_msg
local is_logging_muted_for = Core.is_logging_muted_for
local increment = Core.increment
local overflow = Core.overflow
local get_entities = Core.get_entities
local append_scenario_history = Core.append_scenario_history
local bind_storage = Core.bind_storage
local ammo_names =
{
    ['artillery-targeting-remote'] = true,
    ['poison-capsule'] = true,
    ['cluster-grenade'] = true,
    ['atomic-bomb'] = true,
    ['cliff-explosives'] = true,
    ['rocket'] = true,
    ['explosive-rocket'] = true,
    ['flamethrower-ammo'] = true,
    ['cannon-shell'] = true,
    ['explosive-cannon-shell'] = true,
    ['uranium-cannon-shell'] = true,
    ['artillery-shell'] = true,
    ['railgun-ammo'] = true,
    ['tesla-ammo'] = true,
}
local function on_player_ammo_inventory_changed(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    if player.admin then
        return
    end
    if Session.get_trusted_player(player) or this.do_not_check_trusted then
        return
    end
    if this.enable_capsule_cursor_warning then
        for ammo_name in pairs(ammo_names) do
            if prototypes.item[ammo_name] then
                local removed = player.remove_item({ name = ammo_name, count = 1000 })
                if removed > 0 then
                    if ammo_name == 'atomic-bomb' then
                        action_warning('[Nuke]', format(AUDIT.nuke_equip, player.name),
                            { 'fp-antigrief.nuke', player.name })
                    else
                        action_warning('[Capsule]', format(AUDIT.capsule_equip, player.name, ammo_name),
                            { 'fp-antigrief.capsule', player.name, ammo_name })
                    end
                    damage_player(player)
                end
            end
        end
    end
end
local function on_built_entity(event)
    bind_storage() 
    local created_entity = event.entity
    if created_entity.type == 'entity-ghost' then
        local player = game.get_player(event.player_index)
        if not player or not player.valid then
            return
        end
        if player.admin then
            return
        end
        if Session.get_trusted_player(player) or this.do_not_check_trusted then
            return
        end
        created_entity.destroy()
        player.print({ 'fp-antigrief.no-blueprint' }, { color = { r = 0.22, g = 0.99, b = 0.99 } })
    end
end
local function on_player_used_capsule(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end 
    if player.admin then 
        return
    end
    if Session.get_trusted_player(player) or this.do_not_check_trusted then
        return 
    end
    local item = event.item
    if not item then
        return
    end
    local name = item.name
    local position = event.position
    local x, y = position.x, position.y
    local surface = player.surface
    if ammo_names[name] then
        local msg
        local severity = 'info'
        if this.enable_capsule_warning then
            if surface.count_entities_filtered({ force = 'enemy', area = { { x - 10, y - 10 }, { x + 10, y + 10 } }, limit = 1 }) > 0 then
                return
            end
            local count = 0
            local entities = player.surface.find_entities_filtered { force = player.force, area = { { x - 5, y - 5 }, { x + 5, y + 5 } } }
            for i = 1, #entities do
                local e = entities[i]
                local entity_name = e.name
                if entity_name ~= name and entity_name ~= 'entity-ghost' then
                    count = count + 1
                end
            end
            if count <= this.capsule_bomb_threshold then
                return
            end
            local action_prefix = '[Capsule]'
            msg = format(AUDIT.capsule_damage, player.name, get_entities(name, entities), name)
            local ban_msg = format(AUDIT.capsule_ban, get_entities(name, entities), name)
            do_action(player, action_prefix, msg, ban_msg, true)
            severity = 'block'
        else
            msg = player.name .. ' used ' .. name
        end
        if is_logging_muted_for(player) then return end
        if not this.capsule_history then
            this.capsule_history = {}
        end
        if this.limit > 0 and #this.capsule_history > this.limit then
            overflow(this.capsule_history)
        end
        local t = abs(floor((game.tick) / 60))
        local formatted = FancyTime.short_fancy_time(t)
        local str = '[' .. formatted .. '] '
        str = str .. msg
        str = str .. ' at X:'
        str = str .. floor(position.x)
        str = str .. ' Y:'
        str = str .. floor(position.y)
        str = str .. ' '
        str = str .. 'surface:' .. player.surface.index
        increment(this.capsule_history, str)
        Server.log_antigrief_data('capsule', str, severity, player.name)
    end
end
local function on_player_cursor_stack_changed(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    if player.admin then
        return
    end
    if Session.get_trusted_player(player) or this.do_not_check_trusted then
        return
    end
    local item = player.cursor_stack
    if not item then
        return
    end
    if not item.valid_for_read then
        return
    end
    local name = item.name
    if this.enable_capsule_cursor_warning and ammo_names[name] then
        local item_to_remove = player.remove_item({ name = name, count = 1000 })
        if item_to_remove > 0 then
            action_warning('[Capsule]', format(AUDIT.capsule_equip, player.name, name),
                { 'fp-antigrief.capsule', player.name, name })
            damage_player(player)
        end
    end
end
local function on_player_driving_changed_state(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    if not player.driving then
        return 
    end
    if player.admin then
        return
    end
    if Session.get_trusted_player(player) or this.do_not_check_trusted then
        return
    end
    local vehicle = event.entity
    if not vehicle or not vehicle.valid then
        return
    end
    if not AG.blocked_vehicles or not AG.blocked_vehicles[vehicle.name] then
        return
    end
    player.driving = false
    action_warning('[Vehicle]', format(AUDIT.vehicle_blocked, player.name, vehicle.name),
        { 'fp-antigrief.vehicle-blocked', player.name, vehicle.name })
end
Weapons.on_player_ammo_inventory_changed = on_player_ammo_inventory_changed
Weapons.on_built_entity = on_built_entity
Weapons.on_player_used_capsule = on_player_used_capsule
Weapons.on_player_cursor_stack_changed = on_player_cursor_stack_changed
Weapons.on_player_driving_changed_state = on_player_driving_changed_state
return Weapons
