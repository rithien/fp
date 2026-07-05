local Session = require 'lib.sessions'
local FancyTime = require 'lib.fancy_time'
local Task = require 'lib.task'
local Token = require 'lib.token'
local Server = require 'lib.server'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local AdminPresence = require 'lib.antigrief.admin_presence'
local EntityProtection = require 'lib.antigrief.entity_protection'
local DebugLog = require 'lib.debug_log'
local AG = Constants.antigrief
local AUDIT = Constants.audit
local format = string.format
local floor = math.floor
local abs = math.abs
local Combat = {}
local this
Core.register_binder(function(s) this = s end)
local hard_block_action = Core.hard_block_action
local get_owner_name = Core.get_owner_name
local is_logging_muted_for = Core.is_logging_muted_for
local log_admin_override = Core.log_admin_override
local is_foreign_same_force = Core.is_foreign_same_force
local log_player_action = Core.log_player_action
local chests =
{
    ['container'] = true,
    ['logistic-container'] = true
}
local function occupant_player(occupant)
    if not occupant then return nil end
    if occupant.object_name == 'LuaPlayer' then return occupant end
    if occupant.player then return occupant.player end 
    return nil
end
local function is_exempt(player)
    if not player or not player.valid then return true end
    if player.admin then return true end
    if this.do_not_check_trusted then return true end
    return Session.get_trusted_player(player) and true or false
end
local function vehicle_attacker(vehicle)
    if not (vehicle and vehicle.valid) then return nil end
    local driver = occupant_player(vehicle.get_driver())
    local passenger = occupant_player(vehicle.get_passenger())
    if not driver then return passenger end
    if not passenger then return driver end
    if not is_exempt(driver) then return driver end
    if not is_exempt(passenger) then return passenger end
    return driver
end
local function resolve_combat_attacker(cause)
    if not (cause and cause.valid) then return nil end
    local t = cause.type
    if t == 'character' then return cause.player end
    if t == 'car' or t == 'spider-vehicle' then return vehicle_attacker(cause) end
    return nil
end
local clear_damage_history_token =
    Token.register_named('antigrief.clear_damage_history',
        function(event)
            local player_index = event.player_index
            local scheduled_tick = event.scheduled_tick
            if not this.damage_history then return end
            local entry = this.damage_history[player_index]
            if not entry then return end
            if entry.last_tick ~= scheduled_tick then return end
            this.damage_history[player_index] = nil
        end
    )
local function add_ff_hit(player)
    this.damage_history = this.damage_history or {}
    local entry = this.damage_history[player.index]
    local count = (entry and entry.count or 0) + 1
    local now = game.tick
    this.damage_history[player.index] = { count = count, last_tick = now }
    Task.set_timeout_in_ticks(AG.damage_history_ttl_ticks, clear_damage_history_token,
        { player_index = player.index, scheduled_tick = now })
    return count
end
local function combat_recreate(event)
    local attacker = resolve_combat_attacker(event.cause)
    if not (attacker and attacker.valid) then return false end
    local victim = event.entity
    if not (victim and victim.valid) then return false end
    if not is_foreign_same_force(attacker, victim) then return false end
    if attacker.admin then return false end
    if this.do_not_check_trusted then return false end
    local trusted = Session.get_trusted_player(attacker)
    if AdminPresence.is_permissive() then
        if trusted then return false end
        log_admin_override(attacker, format(AUDIT.override_combat, victim.name, get_owner_name(victim)))
        return true
    end
    local snapshot = EntityProtection.capture_entity_state(victim)
    if snapshot then
        snapshot.health = nil
        snapshot.main_contents = nil
        snapshot.modules = nil
    end
    EntityProtection.restore_entity(snapshot, attacker.name)
    if trusted then
        log_player_action(attacker, 'destroy',
            format(AUDIT.combat_destroy_trusted, victim.name, get_owner_name(victim)), victim)
        local count = add_ff_hit(attacker)
        DebugLog.log('[antigrief.ff] destroy %s trusted=true count=%d/%d', attacker.name, count, this.damage_entity_threshold_trusted)
        if count >= this.damage_entity_threshold_trusted then
            this.damage_history[attacker.index] = nil
            hard_block_action(attacker, 'destroy',
                format(AUDIT.combat_destroy, victim.name, get_owner_name(victim)))
        end
    else
        hard_block_action(attacker, 'destroy',
            format(AUDIT.combat_destroy, victim.name, get_owner_name(victim)))
    end
    return true
end
local function on_entity_died(event)
    if combat_recreate(event) then return end
    local cause = event.cause
    local name
    local attacker = resolve_combat_attacker(cause)
    if attacker and cause.force.name == event.entity.force.name then
        local player = attacker
        if is_logging_muted_for(player) then return end
        name = player.name
        local chest
        if chests[event.entity.type] then
            local entity = event.entity
            local inv = entity.get_inventory(1)
            if inv and inv.valid then
                local contents = inv.get_contents()
                local item_types = ''
                for _, item in ipairs(contents) do
                    if item.name == 'explosives' then
                        item_types = item_types .. item.name .. ' count: ' .. item.count .. ' '
                    end
                end
                if string.len(item_types) > 0 then
                    chest = event.entity.name .. ' with content ' .. item_types
                else
                    chest = event.entity.name
                end
            else
                chest = event.entity.name
            end
        else
            chest = event.entity.name
        end
        local t = abs(floor((game.tick) / 60))
        local formatted = FancyTime.short_fancy_time(t)
        local str = '[' .. formatted .. '] '
        str = str .. name .. ' destroyed '
        str = str .. chest
        str = str .. ' at X:'
        str = str .. floor(event.entity.position.x)
        str = str .. ' Y:'
        str = str .. floor(event.entity.position.y)
        str = str .. ' '
        str = str .. 'surface:' .. event.entity.surface.index
        Server.log_antigrief_data('friendly_fire', str, nil, name)
    end
end
local function on_entity_damaged(event)
    local player = resolve_combat_attacker(event.cause)
    if not player or not player.valid then return end
    local entity = event.entity
    if not entity or not entity.valid then return end
    if not is_foreign_same_force(player, entity) then return end
    if player.admin then return end
    if this.do_not_check_trusted then return end
    if AdminPresence.is_permissive() then return end
    local trusted = Session.get_trusted_player(player)
    local threshold = trusted and this.damage_entity_threshold_trusted or this.damage_entity_threshold
    if entity.health then
        entity.health = math.min(entity.max_health, entity.health + event.final_damage_amount)
    end
    local count = add_ff_hit(player)
    if count == 1 then
        player.print({ 'fp-antigrief.friendly-fire-block', entity.name }, { r = 1, g = 1, b = 0 })
    end
    DebugLog.log('[antigrief.ff] damage %s trusted=%s count=%d/%d', player.name, tostring(trusted and true or false), count, threshold)
    if count >= threshold then
        this.damage_history[player.index] = nil
        hard_block_action(player, 'damage', format(AUDIT.damage, entity.name, get_owner_name(entity)))
    end
end
Combat.on_entity_died = on_entity_died
Combat.on_entity_damaged = on_entity_damaged
return Combat
