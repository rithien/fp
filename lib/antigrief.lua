local Event = require 'lib.event'
local FancyTime = require 'lib.fancy_time'
local Server = require 'lib.server'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local EntityProtection = require 'lib.antigrief.entity_protection'
local GuiProtection = require 'lib.antigrief.gui_protection'
local Combat = require 'lib.antigrief.combat'
local Weapons = require 'lib.antigrief.weapons'
local Logging = require 'lib.antigrief.logging'
local AdminPresence = require 'lib.antigrief.admin_presence'
local de = defines.events
local format = string.format
local floor = math.floor
local abs = math.abs
local increment = Core.increment
local overflow = Core.overflow
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
function Public.insert_into_capsule_history(player, position, msg)
    if not this.capsule_history then
        this.capsule_history = {}
    end
    if this.limit > 0 and #this.capsule_history > this.limit then
        overflow(this.capsule_history)
    end
    local t = abs(floor((game.tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local str = '[' .. formatted .. '] ' .. msg
    str = str .. ' at X:'
    str = str .. floor(position.x)
    str = str .. ' Y:'
    str = str .. floor(position.y)
    str = str .. ' '
    str = str .. 'surface:' .. player.surface.index
    increment(this.capsule_history, str)
    Server.log_antigrief_data('capsule', str, nil, player.name)
end
function Public.reset_tables()
    this.landfill_history = {}
    this.capsule_history = {}
    this.friendly_fire_history = {}
    this.mining_history = {}
    this.whitelist_mining_history = {}
    this.corpse_history = {}
    this.message_history = {}
    this.cancel_crafting_history = {}
end
function Public.whitelist_types(key, value)
    if key and value then
        this.whitelist_types[key] = value
    end
    return this.whitelist_types[key]
end
function Public.do_not_check_trusted(value)
    this.do_not_check_trusted = value or false
    return this.do_not_check_trusted
end
function Public.set_capsule_bomb_threshold(value)
    this.capsule_bomb_threshold = value or 1500
    return this.capsule_bomb_threshold
end
function Public.set_max_count_decon(value)
    this.max_count_decon = value or 1500
    return this.max_count_decon
end
function Public.enable_capsule_warning(value)
    this.enable_capsule_warning = value or false
    return this.enable_capsule_warning
end
function Public.enable_capsule_cursor_warning(value)
    this.enable_capsule_cursor_warning = value or false
    return this.enable_capsule_cursor_warning
end
function Public.enable_jail(value)
    this.enable_jail = value or false
    return this.enable_jail
end
function Public.enable_jail_when_decon(value)
    this.enable_jail_when_decon = value or false
    return this.enable_jail_when_decon
end
function Public.enable_jail_on_long_texts(value)
    this.enable_jail_on_long_texts = value or false
    return this.enable_jail_on_long_texts
end
function Public.decon_surface_blacklist(value)
    this.decon_surface_blacklist = value or 'nauvis'
    return this.decon_surface_blacklist
end
function Public.filtered_types_on_decon(tbl)
    if tbl then
        this.filtered_types_on_decon = tbl
    end
end
function Public.damage_entity_threshold(value)
    if value then
        this.damage_entity_threshold = value
    end
    return this.damage_entity_threshold
end
function Public.set_limit_per_table(value)
    if value then
        if value == 0 then
            this.limit = 0
        elseif value > 10 then
            this.limit = value
        end
    end
    return this.limit
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
Public.append_scenario_history = Core.append_scenario_history
Event.on_init(Core.bind_storage)
Event.on_configuration_changed(Core.bind_storage)
Event.on_load(Core.rebind)
Event.on_init(Logging.on_init)
Event.on_configuration_changed(Logging.apply_default_permission_tweaks)
Event.on_nth_tick(60, Logging.flush_robot_mining_logs)
Event.add(de.on_player_mined_entity, EntityProtection.on_player_mined_entity)
Event.add(de.on_entity_died, Combat.on_entity_died)
Event.add(de.on_entity_damaged, Combat.on_entity_damaged)
Event.add(de.on_built_entity, Weapons.on_built_entity)
Event.add(de.on_gui_opened, GuiProtection.on_gui_opened)
Event.add(de.on_pre_entity_settings_pasted, GuiProtection.on_pre_entity_settings_pasted)
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
Event.add(de.on_player_joined_game, AdminPresence.on_player_joined_game)
Event.add(de.on_player_left_game, AdminPresence.on_player_left_game)
Event.add(de.on_player_promoted, AdminPresence.on_player_promoted)
Event.add(de.on_player_demoted, AdminPresence.on_player_demoted)
return Public
