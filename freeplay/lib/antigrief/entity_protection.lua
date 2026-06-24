local Session = require 'lib.sessions'
local Jail = require 'lib.jail'
local FancyTime = require 'lib.fancy_time'
local Task = require 'lib.task'
local Token = require 'lib.token'
local Server = require 'lib.server'
local Constants = require 'constants'
local Core = require 'lib.antigrief.core'
local AdminPresence = require 'lib.antigrief.admin_presence'
local Compat = require 'lib.compat'  
local AG = Constants.antigrief
local AUDIT = Constants.audit
local format = string.format
local floor = math.floor
local abs = math.abs
local random = math.random
local match = string.match
local sub = string.sub
local color_yellow = { r = 1, g = 1, b = 0 }
local EntityProtection = {}
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
local create_ghost_token =
    Token.register(
        function (event)
            local player_index = event.player_index
            local player = game.get_player(player_index)
            if not player or not player.valid then
                return
            end
            local ghost = event.ghost
            if not ghost or not ghost.valid then
                return
            end
            local position = event.position
            local surface = event.surface_index and game.get_surface(event.surface_index) or nil
            if not (surface and surface.valid) then
                surface = player.surface
            end
            ghost.clone({ position = position, force = player.force, surface = surface, create_build_effect_smoke = false })
            ghost.destroy()
        end,
        true
    )
local function on_marked_for_deconstruction(event)
    if not event.player_index then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    if this.do_not_check_trusted then return end
    local entity = event.entity
    if not entity or not entity.valid then return end
    if should_hard_block(player, entity) then
        if AdminPresence.is_permissive() then
            log_admin_override(player, format(AUDIT.override_decon, entity.name, get_owner_name(entity)))
            return
        end
        entity.cancel_deconstruction(player.force.name, player.index)
        hard_block_action(player, 'deconstruct',
            format(AUDIT.deconstruct_mark, entity.name, get_owner_name(entity)))
        return
    end
end
local function on_pre_ghost_deconstructed(event)
    bind_storage() 
    if not event.player_index then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    if this.do_not_check_trusted then return end
    local ghost = event.ghost
    if not ghost or not ghost.valid then return end
    if should_hard_block(player, ghost) then
        if AdminPresence.is_permissive() then
            log_admin_override(player, format(AUDIT.override_ghost, ghost.ghost_name or ghost.name, get_owner_name(ghost)))
            return
        end
        if not game.surfaces.gulag then
            game.create_surface('gulag', { width = 32, height = 32 })
        end
        local new_ghost = ghost.clone({ position = { x = 0, y = 0 }, force = player.force, surface = game.surfaces.gulag, create_build_effect_smoke = false })
        Task.set_timeout_in_ticks(AG.create_ghost_delay_ticks, create_ghost_token, { player_index = player.index, ghost = new_ghost, position = ghost.position, surface_index = ghost.surface.index })
        hard_block_action(player, 'deconstruct',
            format(AUDIT.deconstruct_ghost, ghost.ghost_name or ghost.name, get_owner_name(ghost)))
        return
    end
end
local main_inventory_indices = Compat.main_inventory_indices
local function plain_id(v)
    if type(v) == 'table' then return v.name end
    return v
end
local function normalize_filter(f)
    if type(f) == 'string' then return f end
    if type(f) ~= 'table' then return nil end
    return { name = plain_id(f.name), quality = plain_id(f.quality), comparator = f.comparator }
end
local function capture_config_extras(entity, snapshot)
    for _, idx in ipairs(main_inventory_indices) do
        local iok, inv = pcall(function() return entity.get_inventory(idx) end)
        if iok and inv and inv.valid then
            if inv.supports_bar() then
                local bok, bar = pcall(function() return inv.get_bar() end)
                if bok and bar and bar >= 1 and bar <= #inv then
                    snapshot.bars = snapshot.bars or {}
                    snapshot.bars[idx] = bar
                end
            end
            if inv.supports_filters() and inv.is_filtered() then
                for i = 1, #inv do
                    local fok, f = pcall(function() return inv.get_filter(i) end)
                    local nf = fok and f and normalize_filter(f) or nil
                    if nf then
                        snapshot.slot_filters = snapshot.slot_filters or {}
                        snapshot.slot_filters[idx] = snapshot.slot_filters[idx] or {}
                        snapshot.slot_filters[idx][i] = nf
                    end
                end
            end
        end
    end
    local scok, slot_count = pcall(function() return entity.filter_slot_count end)
    if scok and slot_count and slot_count > 0 then
        for i = 1, slot_count do
            local fok, f = pcall(function() return entity.get_filter(i) end)
            local nf = fok and f and normalize_filter(f) or nil
            if nf then
                snapshot.entity_filters = snapshot.entity_filters or {}
                snapshot.entity_filters[i] = nf
            end
        end
    end
    if entity.type == 'splitter' then
        pcall(function()
            snapshot.splitter = {
                filter = entity.splitter_filter and normalize_filter(entity.splitter_filter) or nil,
                input_priority = entity.splitter_input_priority,
                output_priority = entity.splitter_output_priority,
            }
        end)
    end
end
local function restore_config_extras(recreated, pending)
    if pending.bars then
        for idx, bar in pairs(pending.bars) do
            local inv = recreated.get_inventory(idx)
            if inv and inv.valid and inv.supports_bar() then
                pcall(function() inv.set_bar(bar) end)
            end
        end
    end
    if pending.slot_filters then
        for idx, slots in pairs(pending.slot_filters) do
            local inv = recreated.get_inventory(idx)
            if inv and inv.valid and inv.supports_filters() then
                for i, f in pairs(slots) do
                    pcall(function() inv.set_filter(i, f) end)
                end
            end
        end
    end
    if pending.entity_filters then
        for i, f in pairs(pending.entity_filters) do
            pcall(function() recreated.set_filter(i, f) end)
        end
    end
    if pending.splitter then
        local sp = pending.splitter
        pcall(function()
            if sp.filter then recreated.splitter_filter = sp.filter end
            if sp.input_priority then recreated.splitter_input_priority = sp.input_priority end
            if sp.output_priority then recreated.splitter_output_priority = sp.output_priority end
        end)
    end
end
local function apply_config_to_ghost(ghost, pending)
    if pending.bars then
        for idx, bar in pairs(pending.bars) do
            pcall(function() ghost.set_inventory_bar(idx, bar) end)
        end
    end
    if pending.slot_filters then
        for idx, slots in pairs(pending.slot_filters) do
            for i, f in pairs(slots) do
                pcall(function() ghost.set_inventory_filter(idx, i, f) end)
            end
        end
    end
end
local function recreate_from_snapshot(pending)
    local surface = game.get_surface(pending.surface_index)
    if not (surface and surface.valid) then return nil end
    local existing = surface.find_entity(pending.name, pending.position)
    if existing and existing.valid and existing.unit_number ~= pending.unit_number then
        return existing
    end
    local owner = pending.last_user_name and game.get_player(pending.last_user_name) or nil
    local recreated = surface.create_entity({
        name = pending.name,
        position = pending.position,
        direction = pending.direction,
        force = pending.force,
        player = owner,
        spill = false,
        raise_built = false,
    })
    if not (recreated and recreated.valid) then return nil end
    if pending.health then recreated.health = pending.health end
    if owner then recreated.last_user = owner end
    if pending.recipe_name then
        pcall(function() recreated.set_recipe(pending.recipe_name, pending.recipe_quality) end)
    end
    if pending.modules then
        local minv = recreated.get_module_inventory()
        if minv and minv.valid then
            for _, s in pairs(pending.modules) do
                minv.insert({ name = s.name, count = s.count, quality = s.quality })
            end
        end
    end
    if pending.main_contents then
        for _, item in pairs(pending.main_contents) do
            pcall(function() recreated.insert(item) end)
        end
    end
    restore_config_extras(recreated, pending)
    return recreated
end
local function clear_recreate_collision(surface, pending)
    local p = pending.position
    local area = { { p.x - 1.5, p.y - 1.5 }, { p.x + 1.5, p.y + 1.5 } }
    for _, b in pairs(surface.find_entities_filtered({ area = area, type = { 'character', 'car', 'spider-vehicle' } })) do
        if b and b.valid then
            local np = surface.find_non_colliding_position(b.name, b.position, AG.recreate_teleport_radius, 0.5)
            if np then b.teleport(np) end
        end
    end
end
local function place_restore_ghost(surface, pending)
    local existing = surface.find_entity('entity-ghost', pending.position)
    if existing and existing.valid and existing.ghost_name == pending.name then return existing end
    local owner = pending.last_user_name and game.get_player(pending.last_user_name) or nil
    local ghost = surface.create_entity({
        name = 'entity-ghost',
        inner_name = pending.name,
        position = pending.position,
        direction = pending.direction,
        force = pending.force,
        player = owner,
        raise_built = false,
    })
    if not (ghost and ghost.valid) then return nil end
    if pending.recipe_name then
        pcall(function() ghost.set_recipe(pending.recipe_name, pending.recipe_quality) end)
    end
    apply_config_to_ghost(ghost, pending)
    return ghost
end
local function notify_online_admins(localised_msg)
    for _, p in pairs(game.connected_players) do
        if p.admin then p.print(localised_msg, { r = 1, g = 0.6, b = 0.2 }) end
    end
end
local recreate_retry_token
recreate_retry_token = Token.register(function(params)
    local pending = params.pending
    if not pending then return end
    if recreate_from_snapshot(pending) then return end 
    local attempts = (params.attempts or 0) + 1
    local surface = game.get_surface(pending.surface_index)
    if attempts == 1 and surface and surface.valid then
        clear_recreate_collision(surface, pending)
    end
    if attempts < AG.recreate_max_attempts then
        Task.set_timeout_in_ticks(AG.recreate_retry_ticks, recreate_retry_token,
            { pending = pending, attempts = attempts, griefer = params.griefer })
        return
    end
    local can_place = (surface and surface.valid and surface.can_place_entity({
        name = pending.name,
        position = pending.position,
        direction = pending.direction,
        force = pending.force,
    })) or false
    local blockers = {}
    if surface and surface.valid then
        for _, e in pairs(surface.find_entities_filtered({ position = pending.position, radius = 0.5 })) do
            if e.valid then blockers[#blockers + 1] = e.name end
        end
    end
    local blocked_by = (#blockers > 0 and table.concat(blockers, '/')) or 'none'
    local owner_name = pending.last_user_name or 'unknown'
    local px, py = floor(pending.position.x), floor(pending.position.y)
    local ghost = (surface and surface.valid) and place_restore_ghost(surface, pending) or nil
    local audit_msg
    if ghost then
        audit_msg = format(AUDIT.mine_restore_ghost, pending.name, px, py, pending.surface_index, owner_name)
        Server.log_antigrief_data('mining_restore_ghost', audit_msg, 'block', params.griefer or 'unknown')
    else
        audit_msg = format(AUDIT.mine_restore_failed, pending.name, px, py,
            pending.surface_index, tostring(can_place), owner_name, blocked_by)
        Server.log_antigrief_data('mining_restore_failed', audit_msg, 'block', params.griefer or 'unknown')
    end
    log('[Antigrief] ' .. audit_msg)
    notify_online_admins({ 'fp-antigrief.restore-failed-admin',
        pending.name, px .. ',' .. py, blocked_by, ghost and 'ghost placed (rebuild needed)' or 'entity LOST' })
end, true)
local function restore_entity(snapshot, griefer_name)
    if not snapshot then return end
    if recreate_from_snapshot(snapshot) then return end 
    Task.set_timeout_in_ticks(AG.recreate_retry_ticks, recreate_retry_token,
        { pending = snapshot, attempts = 0, griefer = griefer_name })
end
local function on_player_mined_entity(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local queue = this.pending_mine_blocks and this.pending_mine_blocks[player.index]
    if queue and queue.name then queue = { queue } end
    local pending = queue and queue[1]
    if pending then
        table.remove(queue, 1)
        if #queue == 0 then
            this.pending_mine_blocks[player.index] = nil
        else
            this.pending_mine_blocks[player.index] = queue
        end
        if event.buffer and event.buffer.valid then
            event.buffer.clear()
        end
        restore_entity(pending, player.name)
        hard_block_action(player, 'mining',
            format(AUDIT.mine, pending.name, pending.last_user_name or 'unknown'))
        return
    end
    if is_logging_muted_for(player) then return end
    local entity = event.entity
    if not entity or not entity.valid then
        return
    end
    if this.whitelist_types[entity.type] then
        if not this.whitelist_mining_history then
            this.whitelist_mining_history = {}
        end
        if this.limit > 0 and #this.whitelist_mining_history > this.limit then
            overflow(this.whitelist_mining_history)
        end
        local t = abs(floor((game.tick) / 60))
        local formatted = FancyTime.short_fancy_time(t)
        local str = '[' .. formatted .. '] '
        str = str .. player.name .. ' mined '
        str = str .. entity.name
        str = str .. ' at X:'
        str = str .. floor(entity.position.x)
        str = str .. ' Y:'
        str = str .. floor(entity.position.y)
        str = str .. ' '
        str = str .. 'surface:' .. entity.surface.index
        increment(this.whitelist_mining_history, str)
        Server.log_antigrief_data('whitelist_mining', str, nil, player.name)
        return
    end
    if not entity.last_user then
        return
    end
    if entity.last_user.name == player.name then
        return
    end
    if entity.force.name ~= player.force.name then
        return
    end
    if not this.mining_history then
        this.mining_history = {}
    end
    if this.limit > 0 and #this.mining_history > this.limit then
        overflow(this.mining_history)
    end
    local t = abs(floor((game.tick) / 60))
    local formatted = FancyTime.short_fancy_time(t)
    local str = '[' .. formatted .. '] '
    str = str .. player.name .. ' mined '
    str = str .. event.entity.name
    str = str .. ' at X:'
    str = str .. floor(event.entity.position.x)
    str = str .. ' Y:'
    str = str .. floor(event.entity.position.y)
    str = str .. ' '
    str = str .. 'surface:' .. event.entity.surface.index
    increment(this.mining_history, str)
    Server.log_antigrief_data('mining', str, nil, player.name)
end
local function capture_main_contents(entity)
    local out
    for _, idx in ipairs(main_inventory_indices) do
        local inv = entity.get_inventory(idx)
        if inv and inv.valid and not inv.is_empty() then
            for _, item in pairs(inv.get_contents()) do
                out = out or {}
                out[#out + 1] = item
            end
        end
    end
    return out
end
local function capture_entity_state(entity)
    if not entity or not entity.valid then return nil end
    local snapshot = {
        name = entity.name,
        position = { x = entity.position.x, y = entity.position.y },
        direction = entity.direction,
        force = entity.force.name,
        last_user_name = entity.last_user and entity.last_user.valid and entity.last_user.name or nil,
        health = entity.health,
        surface_index = entity.surface.index,
        type = entity.type,
        unit_number = entity.unit_number, 
    }
    local ok, recipe, quality = pcall(function() return entity.get_recipe() end)
    if ok and recipe then
        snapshot.recipe_name = recipe.name
        snapshot.recipe_quality = quality and quality.name or nil
    end
    local mok, minv = pcall(function() return entity.get_module_inventory() end)
    if mok and minv and minv.valid and not minv.is_empty() then
        snapshot.modules = minv.get_contents()
    end
    local cok, contents = pcall(capture_main_contents, entity)
    if cok and contents then
        snapshot.main_contents = contents
    end
    pcall(capture_config_extras, entity, snapshot)
    return snapshot
end
local function on_pre_player_mined_item(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local entity = event.entity
    if not entity or not entity.valid then
        return
    end
    if should_hard_block(player, entity) then
        if AdminPresence.is_permissive() then
            log_admin_override(player, format(AUDIT.override_mine, entity.name, get_owner_name(entity)))
            return
        end
        this.pending_mine_blocks = this.pending_mine_blocks or {}
        local queue = this.pending_mine_blocks[player.index]
        if queue and queue.name then queue = { queue } end 
        if not queue then queue = {} end
        local snapshot = capture_entity_state(entity)
        if snapshot then table.insert(queue, snapshot) end
        this.pending_mine_blocks[player.index] = queue
        return
    end
    if is_logging_muted_for(player) then return end
    if entity.name ~= 'character-corpse' then
        return
    end
    local corpse_owner = game.get_player(entity.character_corpse_player_index)
    if not corpse_owner then
        return
    end
    local corpse_content = #entity.get_inventory(defines.inventory.character_corpse)
    if corpse_content <= 0 then
        return
    end
    if corpse_owner.force.name ~= player.force.name then
        return
    end
    if player.name ~= corpse_owner.name then
        action_warning('[Corpse]', format(AUDIT.corpse_looted, player.name, corpse_owner.name),
            { 'fp-antigrief.corpse-looted', player.name, corpse_owner.name })
        if not this.corpse_history then
            this.corpse_history = {}
        end
        if this.limit > 0 and #this.corpse_history > this.limit then
            overflow(this.corpse_history)
        end
        local t = abs(floor((game.tick) / 60))
        local formatted = FancyTime.short_fancy_time(t)
        local str = '[' .. formatted .. '] '
        str = str .. player.name .. ' mined '
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
local function on_marked_for_upgrade(event)
    local entity = event.entity
    local player_index = event.player_index
    local player = game.players[player_index]
    if not (entity and entity.valid) then
        return
    end
    if not (player and player.valid) then
        return
    end
    if should_hard_block(player, entity) then
        if AdminPresence.is_permissive() then
            log_admin_override(player, format(AUDIT.override_upgrade, entity.name, get_owner_name(entity)))
            return
        end
        entity.cancel_upgrade(player.force.name, player.index)
        local target_name = event.target and event.target.name or '?'
        hard_block_action(player, 'upgrade',
            format(AUDIT.upgrade, entity.name, target_name, get_owner_name(entity)))
        return
    end
    if is_logging_muted_for(player) then return end
    local target = event.target
    if not target then return end
    append_scenario_history(player, entity, player.name .. ' upgraded entity (' .. entity.name .. ') to target (' .. target.name .. ')')
end
local function on_player_rotated_entity(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    if should_hard_block(player, entity) then
        if AdminPresence.is_permissive() then
            log_admin_override(player, format(AUDIT.override_rotate, entity.name, get_owner_name(entity)))
            return
        end
        entity.direction = event.previous_direction
        hard_block_action(player, 'rotate',
            format(AUDIT.rotate, entity.name, get_owner_name(entity)))
        return
    end
end
local function on_cancelled_deconstruction(event)
    local player_index = event.player_index
    if player_index then
        return
    end
    local tick = event.tick
    if this.mass_decon_cancel_tick == tick then
        return
    end
    local entity = event.entity
    if not entity or not entity.valid then
        return
    end
    local handler = this.on_cancelled_deconstruction
    if tick ~= handler.tick then
        handler.tick = tick
        handler.count = 0
    end
    handler.count = handler.count + 1
    local player = entity.last_user
    if player and player.valid and player.connected then
        local is_trusted = Session.get_trusted_player(player)
        if not is_trusted then
            return
        end
    end
    if entity.force.name == 'neutral' then
        return
    end
    if tick == handler.tick and handler.count >= this.max_count_decon then
        return
    end
    entity.order_deconstruction(entity.force)
end
EntityProtection.on_marked_for_deconstruction = on_marked_for_deconstruction
EntityProtection.on_pre_ghost_deconstructed = on_pre_ghost_deconstructed
EntityProtection.recreate_from_snapshot = recreate_from_snapshot
EntityProtection.restore_entity = restore_entity
EntityProtection.clear_recreate_collision = clear_recreate_collision
EntityProtection.place_restore_ghost = place_restore_ghost
EntityProtection.notify_online_admins = notify_online_admins
EntityProtection.on_player_mined_entity = on_player_mined_entity
EntityProtection.capture_main_contents = capture_main_contents
EntityProtection.capture_entity_state = capture_entity_state
EntityProtection.on_pre_player_mined_item = on_pre_player_mined_item
EntityProtection.on_marked_for_upgrade = on_marked_for_upgrade
EntityProtection.on_player_rotated_entity = on_player_rotated_entity
EntityProtection.on_cancelled_deconstruction = on_cancelled_deconstruction
return EntityProtection
