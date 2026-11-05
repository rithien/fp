local FancyTime = require 'lib.fancy_time'
local Server = require 'lib.server'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local DebugLog = require 'lib.debug_log'
local AUDIT = Constants.audit
local format = string.format
local floor = math.floor
local abs = math.abs
local GuiProtection = {}
local get_owner_name = Core.get_owner_name
local action_warning = Core.action_warning
local is_logging_muted_for = Core.is_logging_muted_for
local is_foreign_same_force = Core.is_foreign_same_force
local log_player_action = Core.log_player_action
local should_hard_block = Core.should_hard_block
local this
Core.register_binder(function(s) this = s end)
local function restore_owner(player_index)
    local opened = this and this.gui_owner and this.gui_owner[player_index]
    if not opened then return end
    this.gui_owner[player_index] = nil
    local entity, owner = opened.entity, game.get_player(opened.owner_index)
    local last_user = entity and entity.valid and entity.last_user
    if last_user and last_user.index == player_index and owner and owner.valid then
        entity.last_user = owner
    end
end
local function on_gui_opened(event)
    restore_owner(event.player_index)
    local entity = event.entity
    if not entity or not entity.valid then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    if entity.name ~= 'character-corpse' and should_hard_block(player, entity) then
        if not (this and this.gui_owner) then Core.bind_storage() end 
        this.gui_owner[player.index] = { entity = entity, owner_index = entity.last_user.index }
        return
    end
    if entity.name ~= 'character-corpse' then return end
    if is_logging_muted_for(player) then return end
    local corpse_owner = game.get_player(entity.character_corpse_player_index)
    if not corpse_owner then return end
    if corpse_owner.force.name ~= player.force.name then return end
    if player.controller_type == defines.controllers.spectator then return end
    local corpse_inv = entity.get_inventory(defines.inventory.character_corpse)
    if not corpse_inv or not corpse_inv.valid or corpse_inv.is_empty() then return end
    if player.name ~= corpse_owner.name then
        action_warning('[Corpse]', format(AUDIT.corpse_looting, player.name, corpse_owner.name),
            { 'fp-antigrief.corpse-looting', player.name, corpse_owner.name })
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
        str = str .. Core.surface_label(entity.surface)
        Server.log_antigrief_data('corpse', str, nil, player.name)
    end
end
local function on_entity_settings_pasted(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local dest = event.destination
    if not dest or not dest.valid then return end
    if is_logging_muted_for(player) then return end
    if not is_foreign_same_force(player, dest) then return end
    log_player_action(player, 'paste', format(AUDIT.paste_settings, dest.name, get_owner_name(dest)), dest)
    DebugLog.log('[antigrief.paste] %s pasted onto %s owner=%s', player.name, dest.name, get_owner_name(dest))
end
local function on_player_fast_transferred(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local entity = event.entity
    if not entity or not entity.valid then return end
    if is_logging_muted_for(player) then return end
    if not is_foreign_same_force(player, entity) then return end
    log_player_action(player, 'fast_transfer', format(AUDIT.fast_transfer, entity.name, get_owner_name(entity)), entity)
    DebugLog.log('[antigrief.fast_transfer] %s <-> %s owner=%s', player.name, entity.name, get_owner_name(entity))
end
local function on_gui_closed_or_left(event)
    restore_owner(event.player_index)
end
GuiProtection.on_gui_opened = on_gui_opened
GuiProtection.on_gui_closed = on_gui_closed_or_left
GuiProtection.on_player_left_game = on_gui_closed_or_left
GuiProtection.on_entity_settings_pasted = on_entity_settings_pasted
GuiProtection.on_player_fast_transferred = on_player_fast_transferred
return GuiProtection
