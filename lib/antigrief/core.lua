local Session = require 'lib.sessions'
local Jail = require 'lib.jail'
local FancyTime = require 'lib.fancy_time'
local Task = require 'lib.task'
local Token = require 'lib.token'
local Server = require 'lib.server'
local Constants = require 'constants'
local AG = Constants.antigrief
local AUDIT = Constants.audit
local format = string.format
local floor = math.floor
local abs = math.abs
local random = math.random
local color_yellow = { r = 1, g = 1, b = 0 }
local prefix = '## - '
local Core = {}
local function get_defaults()
    return {
        enabled = true,
        max_count_decon = 1500,
        landfill_history = {},
        capsule_history = {},
        friendly_fire_history = {},
        mining_history = {},
        whitelist_mining_history = {},
        corpse_history = {},
        message_history = {},
        cancel_crafting_history = {},
        deconstruct_history = {},
        scenario_history = {},
        whisper_history = {},
        whitelist_types = {},
        permission_group_editing = {},
        players_warned = {},
        damage_history = {},
        punish_cancel_craft = false,
        do_not_check_trusted = false,
        admin_temp_trust = true,
        admin_temp_trust_announced = false,
        enable_autokick = false,
        enable_autoban = false,
        enable_jail = true,
        punish_mode = Constants.jail.default_punish_mode,
        enable_capsule_warning = false,
        enable_capsule_cursor_warning = true,
        required_playtime = AG.required_playtime_ticks,
        capsule_bomb_threshold = AG.capsule_bomb_threshold,
        damage_entity_threshold = AG.damage_entity_threshold,
        enable_jail_when_decon = true,
        enable_jail_on_long_texts = true,
        filtered_types_on_decon = {},
        decon_surface_blacklist = 'nauvis',
        players_warn_when_decon = {},
        players_warn_on_long_texts = {},
        on_cancelled_deconstruction = { tick = 0, count = 0 },
        limit = AG.history_limit_per_table,
        admin_button_validation = {},
        robot_mining_pending = {},
        players_warned_hard_block = {},
        players_warned_tamper = {},
        pending_mine_blocks = {},
    }
end
local this
local binders = {}
function Core.register_binder(fn) binders[#binders + 1] = fn end
function Core.state() return this end
function Core.bind_storage()
    storage.antigrief = storage.antigrief or get_defaults()
    storage.antigrief.punish_mode = storage.antigrief.punish_mode or Constants.jail.default_punish_mode
    local s = storage.antigrief
    for i = 1, #binders do binders[i](s) end
end
function Core.rebind()
    local s = storage.antigrief
    for i = 1, #binders do binders[i](s) end
end
Core.register_binder(function(s) this = s end)
local function action_warning(warning_prefixes, msg, broadcast)
    game.print({ '', prefix, broadcast or msg }, { color = color_yellow })
    msg = format('%s %s', warning_prefixes, msg)
    log(msg)
    Server.to_discord_antigrief_bold(msg) 
end
local function print_to(player_ident, msg, color)
    local player
    if type(player_ident) == 'userdata' and player_ident.valid then
        player = player_ident
    elseif type(player_ident) == 'string' or type(player_ident) == 'number' then
        player = game.get_player(player_ident)
    end
    color = color or color_yellow
    if player then
        player.print({ '', prefix, msg }, color)
    else
        game.print({ '', prefix, msg }, color)
    end
end
local function log_msg(warning_prefixes, msg)
    msg = format('%s %s', warning_prefixes, msg)
    log(msg)
end
local function is_logging_muted_for(player)
    if not player or not player.valid then return false end
    return player.admin and true or false
end
local function increment(t, v)
    t[#t + 1] = (v or 1)
end
local function overflow(t)
    table.remove(t, 1)
end
local function get_entities(item_name, entities)
    local set = {}
    for i = 1, #entities do
        local e = entities[i]
        local name = e.name
        if name ~= item_name and name ~= 'entity-ghost' then
            local count = set[name]
            if count then
                set[name] = count + 1
            else
                set[name] = 1
            end
        end
    end
    local list = {}
    local i = 1
    for k, v in pairs(set) do
        list[i] = v
        i = i + 1
        list[i] = ' '
        i = i + 1
        list[i] = k
        i = i + 1
        list[i] = ', '
        i = i + 1
    end
    list[i - 1] = nil
    return table.concat(list)
end
local function damage_player(player, kill, print_to_all)
    if player.character then
        if kill then
            player.character.die('enemy')
            if print_to_all then
                game.print({ 'fp-antigrief.backfired', player.name }, { color = color_yellow })
            end
            return
        end
        player.character.health = player.character.health - random(50, 100)
        player.character.surface.create_entity({ name = 'water-splash', position = player.position })
        player.print({ 'fp-antigrief.ouch-' .. random(1, 3) }, { color = color_yellow })
        if player.character.health <= 0 then
            player.character.die('enemy')
            game.print({ 'fp-antigrief.backfired', player.name }, { color = color_yellow })
            return
        end
    end
end
local clear_capsule_warning_token =
    Token.register(
        function(event)
            local player_index = event.player_index
            local scheduled_tick = event.scheduled_tick
            if not this.players_warned then return end
            local entry = this.players_warned[player_index]
            if type(entry) ~= 'table' then
                this.players_warned[player_index] = nil
                return
            end
            if entry.last_tick ~= scheduled_tick then return end
            this.players_warned[player_index] = nil
        end
    )
local function do_action(player, action_prefix, msg, ban_msg, kill)
    if not action_prefix or not msg or not ban_msg then
        return
    end
    kill = kill or false
    damage_player(player, kill)
    action_warning(action_prefix, msg)
    local idx = player.index
    local entry = this.players_warned[idx]
    local count = (type(entry) == 'table' and entry.count) or (type(entry) == 'number' and entry) or 0
    if count == 2 then
        if this.enable_autoban then
            game.ban_player(player.name, ban_msg) 
        end
    elseif count == 1 then
        count = 2
        if this.enable_jail then
            game.ban_player(player.name, msg) 
        elseif this.enable_autokick then
            game.kick_player(player, msg)
        end
    else
        count = 1
    end
    local now = game.tick
    this.players_warned[idx] = { count = count, last_tick = now }
    Task.set_timeout_in_ticks(AG.strike_ttl_ticks, clear_capsule_warning_token,
        { player_index = idx, scheduled_tick = now })
end
local clear_hard_block_warning_token =
    Token.register(
        function(event)
            local player_index = event.player_index
            local scheduled_tick = event.scheduled_tick
            if not this.players_warned_hard_block then return end
            local entry = this.players_warned_hard_block[player_index]
            if not entry then return end
            if entry.last_strike_tick ~= scheduled_tick then return end
            if entry.kicks and entry.kicks > 0 then
                entry.count = 0
            else
                this.players_warned_hard_block[player_index] = nil
            end
        end
    )
local clear_hard_block_kick_token =
    Token.register(
        function(event)
            local player_index = event.player_index
            local scheduled_tick = event.scheduled_tick
            if not this.players_warned_hard_block then return end
            local entry = this.players_warned_hard_block[player_index]
            if not entry then return end
            if entry.last_strike_tick ~= scheduled_tick then return end
            this.players_warned_hard_block[player_index] = nil
        end
    )
local function get_owner_name(entity)
    if entity and entity.valid and entity.last_user and entity.last_user.valid then
        return entity.last_user.name
    end
    return 'unknown'
end
local function should_hard_block(player, entity)
    if not player or not player.valid then return false end
    if player.admin then return false end
    if this.do_not_check_trusted then return false end
    if Session.get_trusted_player(player) then return false end
    if not entity or not entity.valid then return false end
    local last_user = entity.last_user
    if not last_user then return false end
    if not last_user.valid then return false end
    if last_user.name == player.name then return false end
    return true
end
local function enforce_punish(player, reason)
    if not player or not player.valid then return end
    if this.punish_mode == 'jail' then
        Jail.jail_player(player.name, reason, 'antigrief')
    else
        game.ban_player(player.name, reason)
    end
end
local function hard_block_action(player, category, action_msg)
    if not player or not player.valid then return end
    this.players_warned_hard_block = this.players_warned_hard_block or {}
    local entry = this.players_warned_hard_block[player.index]
    local strikes = (entry and entry.count or 0) + 1
    local kicks = (entry and entry.kicks or 0)
    local now = game.tick
    this.players_warned_hard_block[player.index] = { count = strikes, kicks = kicks, last_strike_tick = now }
    Task.set_timeout_in_ticks(AG.strike_ttl_ticks, clear_hard_block_warning_token,
        { player_index = player.index, scheduled_tick = now })
    if kicks > 0 then
        Task.set_timeout_in_ticks(AG.kick_ttl_ticks, clear_hard_block_kick_token,
            { player_index = player.index, scheduled_tick = now })
    end
    local t = abs(floor((game.tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local log_str = format('[%s] %s [strike %d/%d] %s', formatted, player.name, strikes, AG.strikes_per_cycle, action_msg)
    Server.log_antigrief_data(category, log_str, 'block', player.name)
    if strikes >= AG.strikes_per_cycle then
        if kicks >= AG.kicks_before_ban then
            enforce_punish(player,
                format(AUDIT.hard_block_ban, category, strikes, action_msg))
            this.players_warned_hard_block[player.index] = nil
        else
            local new_kicks = kicks + 1
            this.players_warned_hard_block[player.index] = { count = 0, kicks = new_kicks, last_strike_tick = now }
            Task.set_timeout_in_ticks(AG.kick_ttl_ticks, clear_hard_block_kick_token,
                { player_index = player.index, scheduled_tick = now })
            player.print({ 'fp-antigrief.hard-block-kick', category }, { r = 1, g = 0.3, b = 0.3 })
            game.kick_player(player, format(AUDIT.hard_block_kick, category))
        end
    elseif strikes == AG.strikes_per_cycle - 1 then
        player.print({ 'fp-antigrief.hard-block-strike-2', category, strikes, AG.strikes_per_cycle }, { r = 1, g = 0.3, b = 0.3 })
        damage_player(player)
    else
        player.print({ 'fp-antigrief.hard-block-strike-1', category, strikes, AG.strikes_per_cycle }, { r = 1, g = 1, b = 0 })
    end
end
local clear_tamper_warn_token =
    Token.register(
        function(event)
            local player_index = event.player_index
            local scheduled_tick = event.scheduled_tick
            if not this.players_warned_tamper then return end
            local entry = this.players_warned_tamper[player_index]
            if not entry then return end
            if entry.last_tick ~= scheduled_tick then return end
            this.players_warned_tamper[player_index] = nil
        end
    )
local function tamper_warn_or_strike(player, category, action_msg)
    if not player or not player.valid then return end
    this.players_warned_tamper = this.players_warned_tamper or {}
    local entry = this.players_warned_tamper[player.index]
    local count = (entry and entry.count or 0) + 1
    local now = game.tick
    this.players_warned_tamper[player.index] = { count = count, last_tick = now }
    Task.set_timeout_in_ticks(AG.tamper_warn_ttl_ticks, clear_tamper_warn_token,
        { player_index = player.index, scheduled_tick = now })
    if count > AG.tamper_warn_before_strike then
        hard_block_action(player, category, action_msg)
    else
        player.print({ 'fp-antigrief.tamper-warn', category }, color_yellow)
        Server.log_antigrief_data(category, format('[tamper-warn] %s %s', player.name, action_msg), nil, player.name)
    end
end
local function log_admin_override(player, action_msg)
    if not player or not player.valid then return end
    local t = abs(floor((game.tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local log_str = format('[%s] %s [admin-override] %s', formatted, player.name, action_msg)
    Server.log_antigrief_data('admin_override', log_str, nil, player.name)
end
function Core.append_scenario_history(player, entity, message)
    if not this.scenario_history then
        this.scenario_history = {}
    end
    if this.limit > 0 and #this.scenario_history > this.limit + 8000 then
        overflow(this.scenario_history)
    end
    local t = abs(floor((game.tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local str = '[' .. formatted .. '] ' .. message
    str = str .. ' at X:'
    str = str .. floor(entity.position.x)
    str = str .. ' Y:'
    str = str .. floor(entity.position.y)
    str = str .. ' '
    str = str .. 'surface:' .. player.surface.index
    increment(this.scenario_history, str)
    Server.log_antigrief_data('scenario', str, nil, player and player.name or nil)
end
Core.action_warning = action_warning
Core.print_to = print_to
Core.log_msg = log_msg
Core.is_logging_muted_for = is_logging_muted_for
Core.increment = increment
Core.overflow = overflow
Core.get_entities = get_entities
Core.damage_player = damage_player
Core.do_action = do_action
Core.get_owner_name = get_owner_name
Core.should_hard_block = should_hard_block
Core.enforce_punish = enforce_punish
Core.hard_block_action = hard_block_action
Core.tamper_warn_or_strike = tamper_warn_or_strike
Core.log_admin_override = log_admin_override
Core.get_defaults = get_defaults
return Core
