local Session = require 'lib.sessions'
local Jail = require 'lib.jail'
local FancyTime = require 'lib.fancy_time'
local Task = require 'lib.task'
local Token = require 'lib.token'
local Server = require 'lib.server'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local AdminPresence = require 'lib.antigrief.admin_presence'
local EntityProtection = require 'lib.antigrief.entity_protection'
local AG = Constants.antigrief
local AUDIT = Constants.audit
local format = string.format
local floor = math.floor
local abs = math.abs
local random = math.random
local match = string.match
local sub = string.sub
local color_yellow = { r = 1, g = 1, b = 0 }
local Combat = {}
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
local log_admin_override = Core.log_admin_override
local chests =
{
    ['container'] = true,
    ['logistic-container'] = true
}
local function driver_player(vehicle)
    if not (vehicle and vehicle.valid) then return nil end
    local d = vehicle.get_driver()
    if not d then return nil end
    if d.object_name == 'LuaPlayer' then return d end
    if d.player then return d.player end 
    return nil
end
local function resolve_combat_attacker(cause)
    if not (cause and cause.valid) then return nil end
    local t = cause.type
    if t == 'character' then return cause.player end
    if t == 'car' or t == 'spider-vehicle' then return driver_player(cause) end
    return nil
end
local function combat_recreate(event)
    local attacker = resolve_combat_attacker(event.cause)
    if not (attacker and attacker.valid) then return false end
    local victim = event.entity
    if not (victim and victim.valid) then return false end
    if victim.force.name ~= attacker.force.name then return false end
    if not should_hard_block(attacker, victim) then return false end
    if AdminPresence.is_permissive() then
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
    hard_block_action(attacker, 'destroy',
        format(AUDIT.combat_destroy, victim.name, get_owner_name(victim)))
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
        if not this.friendly_fire_history then
            this.friendly_fire_history = {}
        end
        if this.limit > 0 and #this.friendly_fire_history > this.limit then
            overflow(this.friendly_fire_history)
        end
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
        increment(this.friendly_fire_history, str)
        Server.log_antigrief_data('friendly_fire', str, nil, name)
    elseif this.whitelist_types[event.entity.type] then
        if cause then
            if cause.force.name ~= 'player' then
                return
            end
        end
        if attacker and is_logging_muted_for(attacker) then
            return
        end
        if not this.friendly_fire_history then
            this.friendly_fire_history = {}
        end
        if this.limit > 0 and #this.friendly_fire_history > this.limit then
            overflow(this.friendly_fire_history)
        end
        local t = abs(floor((game.tick) / 60))
        local formatted = FancyTime.short_fancy_time(t)
        local str = '[' .. formatted .. '] '
        if attacker then
            str = str .. attacker.name .. ' destroyed '
        else
            str = str .. 'someone destroyed '
        end
        str = str .. event.entity.name
        str = str .. ' at X:'
        str = str .. floor(event.entity.position.x)
        str = str .. ' Y:'
        str = str .. floor(event.entity.position.y)
        str = str .. ' '
        str = str .. 'surface:' .. event.entity.surface.index
        if attacker then
            increment(this.friendly_fire_history, str)
            Server.log_antigrief_data('friendly_fire', str, nil, attacker.name)
        else
            increment(this.friendly_fire_history, str)
            Server.log_antigrief_data('friendly_fire', str)
        end
    end
end
local clear_damage_history_token =
    Token.register(
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
local function on_entity_damaged(event)
    local player = resolve_combat_attacker(event.cause)
    if not player or not player.valid then return end
    local entity = event.entity
    if not entity or not entity.valid then return end
    if not entity.last_user then return end
    if entity.force.name ~= player.force.name then return end
    if not should_hard_block(player, entity) then return end
    if AdminPresence.is_permissive() then return end
    if entity.health then
        entity.health = math.min(entity.max_health, entity.health + event.final_damage_amount)
    end
    this.damage_history = this.damage_history or {}
    local entry = this.damage_history[player.index]
    local count = (entry and entry.count or 0) + 1
    local now = game.tick
    this.damage_history[player.index] = { count = count, last_tick = now }
    Task.set_timeout_in_ticks(AG.damage_history_ttl_ticks, clear_damage_history_token,
        { player_index = player.index, scheduled_tick = now })
    if count == 1 then
        player.print({ 'fp-antigrief.friendly-fire-block', entity.name }, { r = 1, g = 1, b = 0 })
    end
    if count >= this.damage_entity_threshold then
        this.damage_history[player.index] = nil
        hard_block_action(player, 'damage', format(AUDIT.damage, entity.name, get_owner_name(entity)))
    end
end
Combat.on_entity_died = on_entity_died
Combat.on_entity_damaged = on_entity_damaged
return Combat
