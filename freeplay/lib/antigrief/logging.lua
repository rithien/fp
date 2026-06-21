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
local Logging = {}
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
local clear_player_decon_warnings =
    Token.register(
        function (event)
            local player_index = event.player_index
            if this.players_warn_when_decon[player_index] then
                this.players_warn_when_decon[player_index] = nil
            end
        end
    )
local clear_players_warn_on_long_texts =
    Token.register(
        function (event)
            local player_index = event.player_index
            if this.players_warn_on_long_texts[player_index] then
                this.players_warn_on_long_texts[player_index] = nil
            end
        end
    )
local function on_player_joined_game(event)
    bind_storage() 
    local player = game.get_player(event.player_index)
    if not player then
        return
    end
    if match(player.name, '^[Ili1|]+$') then
        game.ban_player(player.name, '') 
    end
end
local function on_player_built_tile(event)
    local placed_tiles = event.tiles
    if placed_tiles[1].old_tile.name ~= 'deepwater' and placed_tiles[1].old_tile.name ~= 'water' and placed_tiles[1].old_tile.name ~= 'water-green' then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end 
    if is_logging_muted_for(player) then return end
    local surface = event.surface_index
    if not this.landfill_history then
        this.landfill_history = {}
    end
    if this.limit > 0 and #this.landfill_history > this.limit then
        overflow(this.landfill_history)
    end
    local t = abs(floor((game.tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local str = '[' .. formatted .. '] '
    str = str .. player.name .. ' at X:'
    str = str .. placed_tiles[1].position.x
    str = str .. ' Y:'
    str = str .. placed_tiles[1].position.y
    str = str .. ' '
    str = str .. 'surface:' .. surface
    increment(this.landfill_history, str)
    Server.log_antigrief_data('landfill', str, nil, player.name)
end
local function on_console_command(event)
    bind_storage() 
    if not event.player_index then
        return
    end
    local valid_commands =
    {
        ['r'] = true,
        ['whisper'] = true
    }
    if not valid_commands[event.command] then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end 
    if is_logging_muted_for(player) then return end
    if not this.whisper_history then
        this.whisper_history = {}
    end
    if this.limit > 0 and #this.whisper_history > this.limit then
        overflow(this.whisper_history)
    end
    local parameters = event.parameters
    local name, message = parameters:match('(%a+)%s(.*)')
    if not message and event.command == 'whisper' then
        return
    end
    local chat_message
    if event.command == 'r' then
        chat_message = ' replied: "' .. parameters .. '"'
    else
        chat_message = ' whispered: "' .. name .. ' ' .. message .. '"'
    end
    if chat_message:len() == 0 then
        return
    end
    local t = abs(floor((game.tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local str = '[' .. formatted .. '] '
    str = str .. player.name .. chat_message
    increment(this.whisper_history, str)
    Server.log_antigrief_data('whisper', str, nil, player.name)
end
local function on_console_chat(event)
    if not event.player_index then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end 
    if not this.message_history then
        this.message_history = {}
    end
    if this.limit > 0 and #this.message_history > this.limit then
        overflow(this.message_history)
    end
    local t = abs(floor((game.tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local str = '[' .. formatted .. '] '
    local message = event.message
    str = str .. player.name .. ': ' .. message
    increment(this.message_history, str)
    local message_length = string.len(message) >= 500
    if message_length then
        if this.enable_jail_on_long_texts and not player.admin then
            if not this.players_warn_on_long_texts[player.index] then
                this.players_warn_on_long_texts[player.index] = 1
                Task.set_timeout_in_ticks(AG.long_text_warn_ttl_ticks, clear_players_warn_on_long_texts, { player_index = player.index })
            end
            local warnings = this.players_warn_on_long_texts[player.index]
            if warnings then
                if warnings == 1 or warnings == 2 then
                    print_to(player, { 'fp-antigrief.spam-warn' })
                    this.players_warn_on_long_texts[player.index] = this.players_warn_on_long_texts[player.index] + 1
                elseif warnings == 3 then
                    print_to(player, { 'fp-antigrief.spam-warn-final' })
                    this.players_warn_on_long_texts[player.index] = this.players_warn_on_long_texts[player.index] + 1
                else
                    enforce_punish(player, AUDIT.long_text_spam_ban) 
                    this.players_warn_on_long_texts[player.index] = nil
                end
            end
        end
    end
end
local function on_player_cancelled_crafting(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end 
    if is_logging_muted_for(player) then return end
    local main_inv = player.get_main_inventory()
    if not main_inv then return end
    local crafting_queue_item_count = event.items.get_item_count()
    local free_slots = main_inv.count_empty_stacks()
    local crafted_items = #event.items
    if crafted_items > free_slots then
        if this.punish_cancel_craft and player.character then
            player.character.character_inventory_slots_bonus = crafted_items + #main_inv
            for i = 1, crafted_items do
                player.character.get_main_inventory().insert(event.items[i])
            end
            player.character.die('player')
            action_warning('[Crafting]', format(AUDIT.crafting, player.name, event.recipe.name, crafting_queue_item_count, crafted_items),
                { 'fp-antigrief.crafting', player.name, event.recipe.name, crafting_queue_item_count, crafted_items })
        end
        if not this.cancel_crafting_history then
            this.cancel_crafting_history = {}
        end
        if this.limit > 0 and #this.cancel_crafting_history > this.limit then
            overflow(this.cancel_crafting_history)
        end
        local t = abs(floor((game.tick) / 60))
        local formatted = FancyTime.short_fancy_time(t)
        local str = '[' .. formatted .. '] '
        str = str .. player.name .. ' canceled item ' .. event.recipe.name
        str = str .. ' count was a total of: ' .. crafting_queue_item_count
        str = str .. ' at X:'
        str = str .. floor(player.position.x)
        str = str .. ' Y:'
        str = str .. floor(player.position.y)
        str = str .. ' '
        str = str .. 'surface:' .. player.surface.index
        increment(this.cancel_crafting_history, str)
        Server.log_antigrief_data('cancel_crafting', str, nil, player.name)
    end
end
local function apply_default_permission_tweaks()
    local default = game.permissions.get_group('Default')
    if default then
        default.set_allows_action(defines.input_action.flush_opened_entity_fluid, false)
        default.set_allows_action(defines.input_action.flush_opened_entity_specific_fluid, false)
    end
end
local function on_init()
    apply_default_permission_tweaks()
end
local function on_permission_group_added(event)
    bind_storage() 
    local player = event.player_index and game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local group = event.group
    if group then
        log_msg('[Permission_Group]', player.name .. ' added ' .. group.name)
    end
end
local function on_permission_group_deleted(event)
    bind_storage() 
    local player = event.player_index and game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local name = event.group_name
    local id = event.id
    if name then
        log_msg('[Permission_Group]', player.name .. ' deleted ' .. name .. ' with ID: ' .. id)
    end
end
local function on_player_deconstructed_area(event)
    if not game.is_multiplayer() then
        return
    end
    local surface = event.surface
    local surface_name = this.decon_surface_blacklist
    if sub(surface.name, 0, #surface_name) ~= surface_name then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    if player.admin then
        return
    end
    local area = event.area
    local count = surface.count_entities_filtered({ area = area, type = 'resource', invert = true })
    local max_count = 0
    local is_trusted = Session.get_trusted_player(player)
    if is_trusted or AdminPresence.is_permissive() then
        max_count = this.max_count_decon
    end
    if next(this.filtered_types_on_decon) then
        local filtered_count = surface.count_entities_filtered({ area = area, type = this.filtered_types_on_decon })
        if filtered_count and filtered_count > 0 then
            surface.cancel_deconstruct_area
            {
                area = area,
                force = player.force
            }
        end
    end
    if count and count > 0 and count >= max_count then 
        this.mass_decon_cancel_tick = game.tick
        surface.cancel_deconstruct_area
        {
            area = area,
            force = player.force
        }
        local msg = format(AUDIT.mass_decon_alert, player.name, count)
        print_to(nil, { 'fp-antigrief.massdecon-alert', player.name, count })
        Server.to_discord_antigrief_embed(msg) 
        if not this.deconstruct_history then
            this.deconstruct_history = {}
        end
        if this.limit > 0 and #this.deconstruct_history > this.limit then
            overflow(this.deconstruct_history)
        end
        local t = abs(floor((game.tick) / 60))
        local formatted = FancyTime.short_fancy_time(t)
        local str = '[' .. formatted .. '] '
        str = str .. msg
        str = str .. ' at lt_x:'
        str = str .. floor(area.left_top.x)
        str = str .. ' at lt_y:'
        str = str .. floor(area.left_top.y)
        str = str .. ' at rb_x:'
        str = str .. floor(area.right_bottom.x)
        str = str .. ' at rb_y:'
        str = str .. floor(area.right_bottom.y)
        str = str .. ' '
        str = str .. 'surface:' .. player.surface.index
        increment(this.deconstruct_history, str)
        Server.log_antigrief_data('deconstruct', str, 'block', player.name)
        if this.enable_jail_when_decon then 
            if not this.players_warn_when_decon[player.index] then
                this.players_warn_when_decon[player.index] = 1
                local r = random(AG.decon_warn_ttl_min_ticks, AG.decon_warn_ttl_max_ticks)
                Task.set_timeout_in_ticks(r, clear_player_decon_warnings, { player_index = player.index })
            end
            local warnings = this.players_warn_when_decon[player.index]
            if warnings then
                if warnings == 1 or warnings == 2 then
                    print_to(player, { 'fp-antigrief.decon-warn' })
                    this.players_warn_when_decon[player.index] = this.players_warn_when_decon[player.index] + 1
                elseif warnings == 3 then
                    print_to(player, { 'fp-antigrief.decon-warn-final' })
                    this.players_warn_when_decon[player.index] = this.players_warn_when_decon[player.index] + 1
                else
                    enforce_punish(player, AUDIT.mass_decon_ban) 
                    this.players_warn_when_decon[player.index] = nil
                end
            end
        end
    end
end
local function on_permission_group_edited(event)
    bind_storage() 
    local player = event.player_index and game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local group = event.group
    if group then
        local action = ''
        for k, v in pairs(defines.input_action) do
            if event.action == v then
                action = k
            end
        end
        log_msg('[Permission_Group]', player.name .. ' edited ' .. group.name .. ' with type: ' .. event.type .. ' with action: ' .. action)
    end
    if event.other_player_index then
        local other_player = game.get_player(event.other_player_index)
        if other_player and other_player.valid then
            log_msg('[Permission_Group]', player.name .. ' moved ' .. other_player.name .. ' with type: ' .. event.type .. ' to group: ' .. ((group and group.name) or '?')) 
        end
    end
    local old_name = event.old_name
    local new_name = event.new_name
    if old_name and new_name then
        log_msg('[Permission_Group]', player.name .. ' renamed ' .. ((group and group.name) or '?') .. '. New name: ' .. new_name .. '. Old Name: ' .. old_name) 
    end
end
local function on_permission_string_imported(event)
    bind_storage() 
    local player = event.player_index and game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    log_msg('[Permission_Group]', player.name .. ' imported a permission string')
end
local function on_player_muted(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end 
    local message =
    {
        title = 'Muted :mute:',
        description = 'A player was muted.',
        color = 'failure',
        fields =
        {
            {
                title = 'Player:',
                description = player.name,
                inline = 'false'
            }
        }
    }
    Server.to_discord_antigrief_embed_parsed(message) 
end
local function on_player_unmuted(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end 
    local message =
    {
        title = 'Unmuted :speaker:',
        description = 'A player was unmuted.',
        color = 'success',
        fields =
        {
            {
                title = 'Player:',
                description = player.name,
                inline = 'false'
            }
        }
    }
    Server.to_discord_antigrief_embed_parsed(message) 
end
local function get_distance(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math.sqrt(dx * dx + dy * dy)
end
local function flush_robot_mining_logs()
    bind_storage() 
    local current_tick = game.tick
    local time_threshold = AG.robot_mining_cluster_time_threshold_ticks
    for player_index, clusters in pairs(this.robot_mining_pending) do
        local player = game.get_player(player_index)
        if not player or not player.valid then
            this.robot_mining_pending[player_index] = nil
        else
            local clusters_to_remove = {}
            local clusters_to_process = {}
            for cluster_id, cluster in pairs(clusters) do
                if current_tick - cluster.last_tick >= time_threshold or cluster.total_count >= AG.robot_mining_cluster_max_count then
                    table.insert(clusters_to_process, cluster_id)
                end
            end
            for _, cluster_id in pairs(clusters_to_process) do
                local cluster = clusters[cluster_id]
                if not this.mining_history then
                    this.mining_history = {}
                end
                if this.limit > 0 and #this.mining_history > this.limit then
                    overflow(this.mining_history)
                end
                local t = abs(floor((cluster.last_tick) / 60))
                local formatted = FancyTime.short_fancy_time(t)
                local batch_size = 100
                local processed = 0
                local entities_to_remove = {}
                for entity_name, count in pairs(cluster.entities) do
                    if processed >= batch_size then
                        break
                    end
                    if this.limit > 0 and #this.mining_history > this.limit then
                        overflow(this.mining_history)
                    end
                    local str = '[' .. formatted .. '] '
                    str = str .. player.name .. ' (robot) mined '
                    if count > 1 then
                        str = str .. count .. 'x ' .. entity_name
                    else
                        str = str .. entity_name
                    end
                    str = str .. ' at X:'
                    str = str .. floor(cluster.position.x)
                    str = str .. ' Y:'
                    str = str .. floor(cluster.position.y)
                    str = str .. ' '
                    str = str .. 'surface:' .. cluster.surface_index
                    increment(this.mining_history, str)
                    Server.log_antigrief_data('mining', str, nil, player.name)
                    entities_to_remove[entity_name] = true
                    processed = processed + 1
                end
                for entity_name in pairs(entities_to_remove) do
                    local count = cluster.entities[entity_name]
                    cluster.total_count = cluster.total_count - count
                    cluster.entities[entity_name] = nil
                end
                if cluster.total_count == 0 or not next(cluster.entities) then
                    table.insert(clusters_to_remove, cluster_id)
                end
            end
            for _, cluster_id in pairs(clusters_to_remove) do
                clusters[cluster_id] = nil
            end
            if not next(clusters) then
                this.robot_mining_pending[player_index] = nil
            end
        end
    end
end
local function on_robot_mined_entity(event)
    bind_storage() 
    local entity = event.entity
    if not entity or not entity.valid then
        return
    end
    local robot = event.robot
    if not robot or not robot.valid then
        return
    end
    local net_point = robot.logistic_network
    if net_point and net_point.storage_points then
        for _, point in pairs(net_point.storage_points) do
            if point then
                if point.owner and point.owner.valid and point.owner.name == 'character' then
                    local player = point.owner.player
                    if not player or not player.valid then
                        return
                    end
                    if is_logging_muted_for(player) then return end
                    if not this.robot_mining_pending[player.index] then
                        this.robot_mining_pending[player.index] = {}
                    end
                    local clusters = this.robot_mining_pending[player.index]
                    local current_tick = game.tick
                    local distance_threshold = AG.robot_mining_cluster_distance_threshold
                    local time_threshold = AG.robot_mining_cluster_time_threshold_ticks
                    local entity_pos = { x = entity.position.x, y = entity.position.y }
                    local entity_surface = entity.surface.index
                    local found_cluster = nil
                    for _, cluster in pairs(clusters) do
                        if cluster.surface_index == entity_surface then
                            local distance = get_distance(cluster.position, entity_pos)
                            local time_diff = current_tick - cluster.last_tick
                            if distance <= distance_threshold and time_diff <= time_threshold then
                                found_cluster = cluster
                                break
                            end
                        end
                    end
                    if not found_cluster then
                        local cluster_id = #clusters + 1
                        found_cluster =
                        {
                            entities = {},
                            total_count = 0,
                            position = { x = entity.position.x, y = entity.position.y },
                            surface_index = entity_surface,
                            first_tick = current_tick,
                            last_tick = current_tick
                        }
                        clusters[cluster_id] = found_cluster
                    end
                    if not found_cluster.entities[entity.name] then
                        found_cluster.entities[entity.name] = 0
                    end
                    found_cluster.entities[entity.name] = found_cluster.entities[entity.name] + 1
                    found_cluster.total_count = found_cluster.total_count + 1
                    found_cluster.last_tick = current_tick
                    if found_cluster.total_count >= AG.robot_mining_cluster_max_count then
                        flush_robot_mining_logs()
                    end
                    return
                end
            end
        end
    end
end
Logging.on_player_joined_game = on_player_joined_game
Logging.on_player_built_tile = on_player_built_tile
Logging.on_console_command = on_console_command
Logging.on_console_chat = on_console_chat
Logging.on_player_cancelled_crafting = on_player_cancelled_crafting
Logging.apply_default_permission_tweaks = apply_default_permission_tweaks
Logging.on_init = on_init
Logging.on_permission_group_added = on_permission_group_added
Logging.on_permission_group_deleted = on_permission_group_deleted
Logging.on_player_deconstructed_area = on_player_deconstructed_area
Logging.on_permission_group_edited = on_permission_group_edited
Logging.on_permission_string_imported = on_permission_string_imported
Logging.on_player_muted = on_player_muted
Logging.on_player_unmuted = on_player_unmuted
Logging.get_distance = get_distance
Logging.flush_robot_mining_logs = flush_robot_mining_logs
Logging.on_robot_mined_entity = on_robot_mined_entity
return Logging
