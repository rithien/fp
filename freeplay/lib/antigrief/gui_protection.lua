local Session = require 'lib.sessions'
local Jail = require 'lib.jail'
local FancyTime = require 'lib.fancy_time'
local Task = require 'lib.task'
local Token = require 'lib.token'
local Server = require 'lib.server'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local AdminPresence = require 'lib.antigrief.admin_presence'
local AG = Constants.antigrief
local AUDIT = Constants.audit
local format = string.format
local floor = math.floor
local abs = math.abs
local random = math.random
local match = string.match
local sub = string.sub
local color_yellow = { r = 1, g = 1, b = 0 }
local GuiProtection = {}
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
local vehicle_types = {
    ['car'] = true, ['spider-vehicle'] = true, ['locomotive'] = true,
}
local gui_open_whitelist = AG.gui_open_whitelist or {}
local function is_player_in_vehicle(player, entity)
    if not vehicle_types[entity.type] then return false end
    local character = player.character
    local function is_self(occupant)
        if not occupant then return false end
        if occupant.object_name == 'LuaPlayer' then return occupant == player end
        return occupant == character or (occupant.player and occupant.player == player) or false
    end
    return is_self(entity.get_driver()) or is_self(entity.get_passenger())
end
local function on_gui_opened(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    if event.gui_type == defines.gui_type.entity and entity.name ~= 'character-corpse'
        and not gui_open_whitelist[entity.name]
        and should_hard_block(player, entity) and not is_player_in_vehicle(player, entity) then
        if AdminPresence.is_permissive() then
            log_admin_override(player, format(AUDIT.override_gui, entity.name, get_owner_name(entity)))
            return
        end
        player.opened = nil
        tamper_warn_or_strike(player, 'gui', format(AUDIT.gui_tamper, entity.name, get_owner_name(entity)))
        return
    end
    if entity.name ~= 'character-corpse' then return end
    if is_logging_muted_for(player) then return end
    local corpse_owner = game.get_player(entity.character_corpse_player_index)
    if not corpse_owner then return end
    if corpse_owner.force.name ~= player.force.name then return end
    if player.controller_type == defines.controllers.spectator then return end
    local corpse_content = #entity.get_inventory(defines.inventory.character_corpse)
    if corpse_content <= 0 then return end
    if player.name ~= corpse_owner.name then
        action_warning('[Corpse]', format(AUDIT.corpse_looting, player.name, corpse_owner.name),
            { 'fp-antigrief.corpse-looting', player.name, corpse_owner.name })
        if not this.corpse_history then
            this.corpse_history = {}
        end
        if this.limit > 0 and #this.corpse_history > this.limit then
            overflow(this.corpse_history)
        end
        local t = abs(floor((game.tick) / 60))
        local formatted = FancyTime.short_fancy_time(t)
        local str = '[' .. formatted .. '] '
        str = str .. player.name .. ' opened '
        str = str .. corpse_owner.name .. ' body'
        str = str .. ' at X:'
        str = str .. floor(entity.position.x)
        str = str .. ' Y:'
        str = str .. floor(entity.position.y)
        str = str .. ' '
        str = str .. 'surface:' .. entity.surface.index
        increment(this.corpse_history, str)
        Server.log_antigrief_data('corpse', str, nil, player.name)
    end
end
local pending_paste_mirror = nil
local function on_pre_entity_settings_pasted(event)
    pending_paste_mirror = nil
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local dest = event.destination
    if not dest or not dest.valid then return end
    if not should_hard_block(player, dest) then return end
    if AdminPresence.is_permissive() then return end
    if not game.surfaces.gulag then
        game.create_surface('gulag', { width = 32, height = 32 })
    end
    local gulag = game.surfaces.gulag
    local ok, mirror = pcall(function()
        local pos = gulag.find_non_colliding_position(dest.name, { x = 0, y = 0 }, 16, 1) or { x = 0, y = 0 }
        return dest.clone({ position = pos, surface = gulag, create_build_effect_smoke = false })
    end)
    if ok and mirror and mirror.valid then
        pending_paste_mirror = { mirror = mirror, dest_un = dest.unit_number }
    end
end
local function on_entity_settings_pasted(event)
    local mirror_data = pending_paste_mirror
    pending_paste_mirror = nil
    local player = game.get_player(event.player_index)
    local dest = event.destination
    local blocked = player and player.valid and dest and dest.valid and should_hard_block(player, dest)
    if blocked and mirror_data and mirror_data.mirror and mirror_data.mirror.valid
        and mirror_data.dest_un == dest.unit_number then
        pcall(function() dest.copy_settings(mirror_data.mirror) end)
    end
    if mirror_data and mirror_data.mirror and mirror_data.mirror.valid then
        mirror_data.mirror.destroy()
    end
    if blocked then
        if AdminPresence.is_permissive() then
            log_admin_override(player, format(AUDIT.override_paste, dest.name, get_owner_name(dest)))
        else
            tamper_warn_or_strike(player, 'paste', format(AUDIT.paste_tamper, dest.name, get_owner_name(dest)))
        end
    end
end
GuiProtection.is_player_in_vehicle = is_player_in_vehicle
GuiProtection.on_gui_opened = on_gui_opened
GuiProtection.on_pre_entity_settings_pasted = on_pre_entity_settings_pasted
GuiProtection.on_entity_settings_pasted = on_entity_settings_pasted
return GuiProtection
