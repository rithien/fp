local Event = require 'lib.event'
local Manager = require 'lib.manager'
local Jail = require 'lib.jail'
local Core = require 'lib.antigrief.core'
local EntityProtection = require 'lib.antigrief.entity_protection'
local GuiProtection = require 'lib.antigrief.gui_protection'
local Combat = require 'lib.antigrief.combat'
local Weapons = require 'lib.antigrief.weapons'
local Logging = require 'lib.antigrief.logging'
local AdminPresence = require 'lib.antigrief.admin_presence'
local ActionLog = require 'lib.antigrief.action_log'
local de = defines.events
local log_msg = Core.log_msg
local Public = {}
local this
Core.register_binder(function(s) this = s end)
function Public.set_enabled(value)
    this.enabled = value and true or false
    log_msg('[Antigrief]', this.enabled and 'enabled' or 'disabled')
end
function Public.set_admin_temp_trust(value)
    this.admin_temp_trust = value and true or false
    log_msg('[Antigrief]', this.admin_temp_trust and 'admin-temp-trust enabled' or 'admin-temp-trust disabled')
    AdminPresence.reevaluate()
end
function Public.set_capsule_bomb_threshold(value)
    this.capsule_bomb_threshold = value or 1500
    return this.capsule_bomb_threshold
end
function Public.damage_entity_threshold(value)
    if value then
        this.damage_entity_threshold = value
    end
    return this.damage_entity_threshold
end
function Public.get(key)
    if key then
        return this[key]
    else
        return this
    end
end
function Public.set(key, value)
    if key and (value or value == false) then
        this[key] = value
        return this[key]
    elseif key then
        return this[key]
    else
        return this
    end
end
function Public.is_ammo_blocked_for(player, item_name)
    return Weapons.is_ammo_blocked_for(player, item_name)
end
Event.on_init(Core.bind_storage)
Event.on_configuration_changed(Core.bind_storage)
Event.on_load(Core.rebind)
Event.on_init(Logging.on_init)
Event.on_configuration_changed(Logging.apply_default_permission_tweaks)
Event.on_nth_tick(60, Logging.flush_robot_mining_logs)
Event.on_nth_tick(60, ActionLog.flush)
Event.add(de.on_player_mined_entity, EntityProtection.on_player_mined_entity)
Event.add(de.on_entity_died, Combat.on_entity_died)
Event.add(de.on_entity_damaged, Combat.on_entity_damaged)
Event.add(de.on_built_entity, Weapons.on_built_entity)
Event.add(de.on_built_entity, Logging.on_built_entity)
Event.add(de.on_gui_opened, GuiProtection.on_gui_opened)
Event.add(de.on_gui_closed, GuiProtection.on_gui_closed)
Event.add(de.on_player_left_game, GuiProtection.on_player_left_game)
Event.add(de.on_entity_settings_pasted, GuiProtection.on_entity_settings_pasted)
Event.add(de.on_marked_for_deconstruction, EntityProtection.on_marked_for_deconstruction)
Event.add(de.on_pre_ghost_deconstructed, EntityProtection.on_pre_ghost_deconstructed)
Event.add(de.on_player_deconstructed_area, Logging.on_player_deconstructed_area)
Event.add(de.on_marked_for_upgrade, EntityProtection.on_marked_for_upgrade)
Event.add(de.on_cancelled_deconstruction, EntityProtection.on_cancelled_deconstruction)
Event.add(de.on_player_ammo_inventory_changed, Weapons.on_player_ammo_inventory_changed)
Event.add(de.on_player_built_tile, Logging.on_player_built_tile)
Event.add(de.on_pre_player_mined_item, EntityProtection.on_pre_player_mined_item)
Event.add(de.on_player_used_capsule, Weapons.on_player_used_capsule)
Event.add(de.on_player_cursor_stack_changed, Weapons.on_player_cursor_stack_changed)
Event.add(de.on_player_cancelled_crafting, Logging.on_player_cancelled_crafting)
Event.add(de.on_player_joined_game, Logging.on_player_joined_game)
Event.add(de.on_permission_group_added, Logging.on_permission_group_added)
Event.add(de.on_permission_group_deleted, Logging.on_permission_group_deleted)
Event.add(de.on_permission_group_edited, Logging.on_permission_group_edited)
Event.add(de.on_permission_string_imported, Logging.on_permission_string_imported)
Event.add(de.on_console_command, Logging.on_console_command)
Event.add(de.on_console_chat, Logging.on_console_chat)
Event.add(de.on_player_muted, Logging.on_player_muted)
Event.add(de.on_player_unmuted, Logging.on_player_unmuted)
Event.add(de.on_robot_mined_entity, Logging.on_robot_mined_entity)
Event.add(de.on_player_rotated_entity, EntityProtection.on_player_rotated_entity)
Event.add(de.on_player_flipped_entity, EntityProtection.on_player_flipped_entity)
Event.add(de.on_player_fast_transferred, GuiProtection.on_player_fast_transferred)
Event.add(de.on_player_driving_changed_state, Weapons.on_player_driving_changed_state)
Event.add(de.on_player_joined_game, AdminPresence.on_player_joined_game)
Event.add(de.on_player_left_game, AdminPresence.on_player_left_game)
Event.add(de.on_player_promoted, AdminPresence.on_player_promoted)
Event.add(de.on_player_demoted, AdminPresence.on_player_demoted)
Event.add(Manager.events.on_manager_changed, AdminPresence.on_manager_changed)
Jail.on_jail_state_changed(function() AdminPresence.reevaluate() end)
return Public
